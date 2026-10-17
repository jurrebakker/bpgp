# Sync & security analysis

- **Status:** implemented. C1 in Phase 1, S1/S2 in Phase 3, S3-S7, S9 and L2 in Phase 8 (2026-10-16). Decisions at the bottom; ✅ = as recommended.
- **Scope:** how officers' data reaches everyone, and whether "officers can edit, players can't" actually holds.
- **Code read:**
  - `Libs/LibEventSourcing/source/*` (ListSync, StateManager, LedgerFactory, LogEntry, SortedList)
  - `Modules/Ledger/LedgerManager/LedgerManager.lua`
  - `Modules/Common/Comms/Comms.lua`
  - `Modules/Common/ACL/*`
  - the auction comm handlers

## TL;DR

The design is sound for a guild addon. The root of trust is the **guild roster from the WoW server**, and addon-message sender names can't be spoofed. However:

1. **In a git clone (unpackaged) there is no security at all.** Dev-only code lets everyone do everything. This must go before anyone uses the addon (already in release plan §5.2).
2. **Permissions are enforced in the UI, not on the wire.** The receiver only checks "is the sender an officer", never "is this sender allowed to make *this kind* of change". Any officer-ish rank with a modified client can do manager-only things.
3. **One bad entry can freeze the addon for the whole guild.** Entries aren't validated, and a failing entry stops all further processing. The bad entry is saved and re-synced to everyone.
4. **The sync checksum ignores entry content.** Two clients can hold different data and both show "in sync".

v1.0 starts a **fresh ledger**, so we can change entry formats and the hash for free. That makes this the right moment to fix 2–4.

---

## 1. How sync works (high-level)

### Building blocks

| Concept | What it is | Code |
|---|---|---|
| **Entry** | One change: "award 50 EP to X", "charge 200 GP", "decay 10%", "change setting". Its identity is `(timestamp, counter, creator realm, creator id)`, where the creator is the integer part of the character GUID. | `LogEntry.lua` |
| **Ledger** | The list of all entries, sorted by identity and stored in SavedVariables. Never edited, only appended to. | `SortedList.lua`, `LedgerManager.lua` |
| **State** | Standings, raids, settings. They are **never saved or sent**: every client rebuilds them by replaying the whole ledger through *mutator* functions. An entry inserted in the past triggers a full replay. | `StateManager.lua` |
| **Undo** | An `IGN` (ignore) entry pointing at another entry. During replay, the pointed-at entry is skipped. | `IgnoreEntry.lua` |
| **Trust levels** | Read from **guild rank permissions** every time the guild roster updates: *view officer note* → ASSISTANT, *edit officer note* → MANAGER, rank 1 → GUILD_MASTER, everyone else → PLEBS. On Midnight both officer-note permissions sit under one "Is Officer" checkbox (§2a). | `TrustInfoProvider.lua:64-104`, `ACL.lua` |

### Message flow

```
 Officer A (creates entry)               Everyone in guild
 ─────────────────────────               ─────────────────
 Submit(entry)
   ├─ local check: am I ASSISTANT+? ──┐
   ├─ insert in own ledger            │
   └─ BulkData{entry} ── GUILD ──────►│ Comms: sender is ASSISTANT+?  (LedgerD3/LedgerS3 channels)
                                      │ ListSync: sender is ASSISTANT+?
                                      │ → queue → insert into ledger → replay → standings update

 Every 10 s, each officer (ASSISTANT+) with sending enabled:
   AdvertiseHash{ for the last 8 weeks + 8 rolling older weeks:
                  (week, checksum of entry IDs, entry count),
                  overall state checksum }  ── GUILD ──►  every client
                                                          compares each week with its own
                                                          mismatch → RequestWeek(w) ── GUILD ──►
 Officers that advertised week w (alphabetically first name wins, 3-8 s random delay):
   WeekData{w, all entries of week w} ── GUILD ──► everyone merges the missing entries (dedup by ID)
```

Some properties of this design:

- **Eventually consistent.** Everyone ends up with the union of all entries ever accepted. Nothing is deleted; undo is just another entry.
- **Only officers send data.** Raiders only listen, compare hashes and ask for missing weeks.
- **Live updates and catch-up use the same data:** a single entry when it's created, and whole weeks when someone was offline.
- **Auctions are not part of this.** Auction start/stop/bids are live RAID/WHISPER messages (`Auction5`, `Bidding5`). Only the *result* (the GP charge) becomes a ledger entry.

### Where authorization is checked today

| Check | Where | What it checks |
|---|---|---|
| Creating an entry | `LedgerFactory.lua:77` → `LedgerManager.lua:43-45` | *Your own* client: am I ASSISTANT+? The entry itself is ignored. |
| Which buttons you see | GUI files (`UnifiedGUI_Standings.lua:429-434`, `Options.lua` `disableManage`, …) | ASSISTANT gets award/raid buttons; MANAGER gets settings, decay, etc. **Purely visual.** |
| Receiving any message | `Comms.lua:222` | `LedgerS3` (sync control): **anyone**. `LedgerD3` (week data): ASSISTANT+. Checked *before* decoding, so large junk is cheap to drop. |
| Receiving entries | `ListSync.lua:198, 218` | `authorizationHandler(nil, sender)`: is the **sender** ASSISTANT+? Entry type, creator and timestamp are never checked. |
| Replaying entries | `StateManager.lua:48-83` | Nothing. Every entry in the ledger is applied. |

What is solid:

- **Sender names are authenticated by the WoW server.** Addon messages can't fake their sender.
- **Guild ranks and rank permissions come from the server too,** and only the GM can change them.
- **Non-officers can't inject data at all** (in a packaged build), because data from them is dropped at the comms layer before it's even decoded.
- **Editing your own SavedVariables only affects you,** because raiders never send data.

---

## 2. Issues found

Severity is judged for *our* situation: a single guild, a handful of trusted officers, and raiders who might run a modified addon.

### Critical

**C1. Unpackaged builds disable all security.** The `--@do-not-package@` / `--@debug@` blocks are only stripped by the BigWigs packager. In a git clone, or a zip made without the packager:

| Location | Effect |
|---|---|
| `ACL.lua:75-78` | `CheckLevel` always returns true. Every guild member is GM in their own client, **and every client accepts ledger data from every sender.** |
| `RaidManager.lua:807-809` | Anyone can run auctions, and raiders accept auction messages from anyone. |
| `Comms.lua:302-304` | GUILD traffic is sent over RAID, so pugs in the raid can receive and send ledger data. |

→ **Fix:** delete these blocks (already in plan Phase 1 / §5.2). Add a luacheck/CI grep that fails the build if `@do-not-package@`, `@debug@` or `@non-debug@` appear again.

### High

**H1. Manager-only actions are only enforced in the UI.** The wire check is the same for every entry type: *sender is ASSISTANT+*. So anyone with **view officer note** can, with a modified client or `/run`:
- change guild settings (GP values, tier names, min GP, auction rules);
- decay, set or overwrite standings;
- undo any entry by anyone (see M3).

The ASSISTANT/MANAGER split is therefore cosmetic.

→ **Fix:** give every entry type a required level, check it on **receive** (per entry, not per message), and drop or flag entries that fail. Or simplify to one officer level (S1), which makes the distinction moot.

**H2. A single bad entry freezes everyone ("poison pill").** Two ways in:
- **Unknown class.** `createLogEntryFromList` → `castLogEntry` raises `error("Unknown class")`, and the whole incoming message is dropped (`StateManager.lua:187-194`). Merely inconvenient.
- **Bad payload.** A known class with a bad payload (a string where a number is expected, `nil` profile, NaN/huge numbers) makes the mutator throw. `StateManager` then **cancels its update ticker**, so no further entries are applied (`StateManager.lua:313-319`). CLM registers no `MutatorFailed` listener, so this is silent apart from a log line.

Because the entry is saved and advertised, every client that syncs it freezes too. It can also be caused by a **bug** in our own code (e.g. after trimming entry fields), not only by malice.

→ **Fix:**
- Validate each entry's fields (types, ranges, referenced roster/profile exists) **before** inserting it.
- Wrap each mutator call in `pcall`. On failure, skip that entry, mark it in the Audit tab and carry on, instead of halting.
- Register a `MutatorFailed` listener that shows a visible warning.

**H3. Creator and timestamp are not tied to the sender.** The creator ID and timestamp are just fields in the entry. When entries are relayed through week sync, the sender is *legitimately* someone other than the creator. So an officer (or a compromised officer client) can:
- create entries that the Audit/History tabs attribute to **another officer**;
- **backdate** entries. A backdated entry is inserted in history and triggers a full replay. Anything after it changes (e.g. awarded before a decay, so it gets decayed);
- **future-date** entries. Advertisements only cover the current week and older, so a future-week entry never syncs through catch-up and only reaches those online at the time. That produces permanent divergence until the date passes.

→ **Fix (partial, no crypto):**
- **Live pushes:** for a single-entry `BulkData`, require `creator == sender`.
- **Relays:** accept week data only from officers. Optionally also require the entry's creator to be an officer according to the current roster; this has a demotion caveat, see S7.
- **Timestamps:** reject entries more than ~10 min in the future. Flag (don't block) entries that arrive live with a timestamp older than a few minutes; legitimate live entries are always "now" once time travel is removed.

A full fix would need digital signatures per officer. That's possible in pure Lua but heavy; see "Out of scope".

### Medium

**M1. The checksum doesn't cover entry content.** `LogEntry.numbersForHash` hashes only `(time, counter, realm, creator)` (`LogEntry.lua:128-130`), and `uniqueInsert` drops any second entry with the same ID (`SortedList.lua:68-85`). Two clients holding the same ID with different payloads will both report **synced** forever. Normally IDs are unique per creator; but a buggy or malicious officer can send different contents to different people (e.g. by whisper), and nothing would ever detect it.

→ **Fix:** include a digest of the payload fields in the hash. This changes the hash format, which is free now because v1 starts a fresh ledger.

**M2. Non-officers can stall sync.** The sync-control channel `LedgerS3` accepts messages from anyone (`LedgerManager.lua:25`). `handleAdvertiseMessage`:
- makes an officer **withdraw its own advertisement** when the advertiser's name sorts alphabetically earlier (`ListSync.lua:167-170`);
- makes clients request weeks based on the advertised hashes;
- lets anyone mark a client as "synced" by echoing its state hash.

A raider, or a pug over RAID, sending fake advertisements can keep officers from ever serving week data. That's a denial of service, not a data change. Fake requests are rate-limited (30 s per week), so amplification is bounded.

→ **Fix:** process `AdvertiseHash` only from ASSISTANT+ senders, and only from `GUILD`/`WHISPER` distributions. Ignore `State` / `RequestState` from outside the guild.

**M3. Anyone ASSISTANT+ can undo anything.** `IgnoreEntry` is authorized like any other entry (`LedgerFactory.lua:86-96`), with no check on *whose* entry or *what type* it undoes. An assistant can silently undo a manager's settings change or another officer's awards. Undoing an undo restores the original.

→ **Fix:** an undo requires at least the level of the entry it undoes. Optionally, undoing *another* officer's entry is MANAGER-only. Show undos prominently in the Audit tab.

**M4. Auction control is accepted from any raid leader or assistant.** Raiders accept `Auction5` messages from anyone who is raid leader/assistant (`BiddingManager.lua:66-75` → `IsAllowedToAuction(name, relaxed=true)`, `RaidManager.lua:806-827`). The "relaxed" mode skips the guild-rank check (meant for cross-guild raids, which we're removing). A non-officer raid assist could pop up fake auctions. Real GP charges still need an officer's ledger entry, so this is confusing rather than damaging. It's related to release plan §5.2, "Raiders accept START/STOP auction from anyone".

→ **Fix:** drop relaxed mode. An auctioneer must be ASSISTANT+ **and** raid leader/assistant.

### Low

| # | Issue | Fix |
|---|---|---|
| L1 | Trust follows rank *permissions*, not rank names. Flags 11/12 (`TrustInfoProvider.lua:69-72`) were verified on 12.x from both a GM and a Member client: they follow "Is Officer" (§2a). ✅ Remaining risk: giving a rank "Is Officer" silently gives it ledger rights. | Document the officer setup in the README. |
| L2 | `enableSending` is decided once at startup (`LedgerManager.lua:125-127`). A newly promoted officer doesn't serve sync until `/reload`; a demoted officer keeps advertising (receivers drop their data, so this is harmless). | Re-evaluate on `GUILD_ROSTER_UPDATE`. |
| L3 | Before the guild roster has loaded, the trust cache is empty and all data is dropped. This fails safe, but the first sync is slower. | Fine as is. Optionally request the roster earlier. |
| L4 | The sync status ("synced") shown on the minimap can be faked by M2. | Fixed by M2. |
| L5 | `Wipe events` and `Disable sync` let a user break their *own* client. | Both are being removed (UI overhaul decisions). |

### 2a. Guild rank permissions on Midnight (from the GM's Guild Control screenshots)

The Rank Permissions screen in 12.x no longer has separate *View officer note* / *Edit officer note* checkboxes. There is one **"Is Officer"** checkbox. It bundles: access officer channels, remove people from voice chat, delete others' chat messages and guild events, **view and edit officer notes**, edit public notes, edit guild info and MotD, Guild Finder listing/invites, link guild chat to Discord. The other permissions (promote, demote, invite, remove, guildchat speak, neighborhood manager, guild bank) are separate checkboxes.

Our guild's ranks:

| # | Rank | Is Officer | Role in BPGP |
|---|---|---|---|
| 1 | Guild Master | (always) | GUILD_MASTER |
| 2 | Officer | ✅ | officer |
| 3 | Officers Alt | ✅ | officer (alts of officers) |
| 4-8 | Veteran, Boomer, Member, Members Alt, Trial | ❌ (assumed) | raider, read-only |

What this means:

- **CLM's two officer levels collapse into one.** Viewing and editing officer notes now always come together, so every "Is Officer" rank gets *both* ASSISTANT and MANAGER at once (confirmed below). The game has already made S1 for us: in practice there is one officer level.
- **Flag check, done in-game on a GM and a Member client (2026-10-16).** Output of `/run … GuildControlGetRankFlags(i)` per rank:

  | # | Rank | Flags on |
  |---|---|---|
  | 1 | Guild Master | 1-13, 15, 16, 17, 19, 20, 21, 22 |
  | 2 | Officer | 1-13, 15, 16, 17, 19, 20, 21, 22 |
  | 3 | Officers Alt | 1-13, 15, 16, 17, 20, 22 |
  | 4 | Veteran | 1, 2, 7, 15 |
  | 5 | Boomer | 1, 2, 15 |
  | 6 | Member | 1, 2, 15 |
  | 7 | Members Alt | 1, 2 |
  | 8 | Trial | 1, 2 |

  - **Flags 11 and 12 still work.** They are on for exactly the "Is Officer" ranks and off for everyone else. There is no separate checkbox for them any more, so they now follow "Is Officer". Result: GM, Officer and Officers Alt → MANAGER (and ASSISTANT); everyone else → PLEBS. That's what we want, with no code change.
  - 19 and 21 are the two permissions that Officers Alt lacks compared with Officer (Neighborhood Manager and Modify Bank Tabs in the screenshots). They're irrelevant to us.
  - **A raider's client sees the same flags.** The same command run on a **Member** character gave identical output for all 8 ranks. Raiders therefore classify officers correctly and accept their data.

  The check command, for reference:

  ```
  /run for i=1,GuildControlGetNumRanks() do local f,t=C_GuildInfo.GuildControlGetRankFlags(i),{} for k,v in pairs(f) do if v then t[#t+1]=k end end print(i,GuildControlGetRankName(i),table.concat(t,",")) end
  ```
- **Officer alts are officers.** "Officers Alt" has "Is Officer", so an officer's alt can award EP and run auctions, including to their own main. That's probably what you want (officers often raid on alts), but it's a choice. If you don't want it, S2 option b fixes it.

### Out of scope / inherent limits

- **Officers are trusted.** Without per-officer digital signatures, a malicious officer can always write arbitrary entries; H3 only makes forgery harder. Pure-Lua ed25519 exists, but key distribution (who vouches for an officer's public key?) and replay cost make it overkill for a guild. The **Audit tab + undo** is the practical safety net.
- **Data is public within the guild.** All standings and history are broadcast to GUILD. That's intended for EPGP.

---

## 3. Decisions for you

| # | Question | Options | Recommendation | Your call |
|---|---|---|---|---|
| S1 | How many officer levels? | a) keep two levels (Assistant: award EP, run auctions, raids · Manager: settings, decay, set standings, undo others) and enforce them per entry type · b) one **Officer** level that can do everything; raiders read-only | **b**. Midnight's single "Is Officer" permission already merges the two levels (§2a). Simpler code and UI, and H1/M3 mostly disappear. | **b: one Officer level** ✅ (follows from S2 and Midnight) |
| S2 | What makes someone an officer? | a) the rank has **"Is Officer"** (today: Officer + Officers Alt) · b) the GM ticks ranks in Guild settings (a GM-only ledger entry, e.g. only "Officer") · c) rank index ≤ N | **a** for v1: zero setup, and it follows what you already configure in Guild Control. **b** if officer alts shouldn't have rights. | **a: "Is Officer" ranks** ✅ |
| S3 | Validate entries + skip bad ones instead of freezing (H2) | yes / no | **yes**, required for v1 | **yes** ✅ |
| S4 | Include entry content in the sync checksum (M1) | yes / no | **yes**, while the fresh ledger makes it free | **yes** ✅ |
| S5 | Only accept sync-control messages from officers (M2) | yes / no | **yes** | **yes** ✅ |
| S6 | Timestamp rules (H3) | a) reject > 10 min future + flag stale live entries · b) nothing | **a** | **a** ✅ |
| S7 | Creator checks (H3) | a) live pushes need `creator == sender`; relays only from officers · b) additionally reject relayed entries whose creator isn't an officer *now* (breaks entries from demoted officers on fresh installs) · c) nothing | **a** | **a** ✅ |
| S8 | Undo rules (M3), only relevant if S1 = a | a) undo needs ≥ level of the undone entry · b) only MANAGER may undo others' entries | **a** | n/a (S1 = b) |
| S9 | Auction control (M4) | require officer **and** raid lead/assist | **yes** | **yes** ✅ |

These are scheduled in the release plan: C1 in Phase 1, everything else in Phase 8 (Sync hardening).
