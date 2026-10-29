# BPGP: architecture reference

> **Audience:** developers working on the addon.
> Covers structure, key design patterns, data flow and module responsibilities.
> BPGP is a fork of Core Loot Manager (CLM) v5.7.8, trimmed to EPGP only on retail (Midnight, 12.x). The internal Lua namespace is still `CLM`. Players see effort points as **Boomer Points (BP)**; the code and these docs still call them EP ([GLOSSARY.md](GLOSSARY.md)).
> Binding decisions (S3, R16, …) are in [docs/decisions.md](docs/decisions.md).

---

## 1. Bird's-eye view

BPGP manages EPGP loot for one guild: EP for raiding, GP for loot, priority PR = EP ÷ GP. Two architectural choices define it:

1. **Event sourcing via LibEventSourcing.** Every change is appended to a ledger as an immutable entry. State (standings, raids, settings) is rebuilt by replaying the entries. Sync between guild members means syncing the ledger. Undo is another entry.
2. **Managers and GUI kept apart.** Managers own state and business logic. GUI modules read from managers and change state only through manager methods, which write ledger entries.

---

## 2. Repository layout

```
bp-epgp/
├── BPGP/                         # The addon (packaged as BPGP)
│   ├── BPGP.toc
│   ├── Core.lua                     # Namespace, staged initialization
│   ├── Utils.lua                    # CLM.UTILS, retail API wrappers, Midnight helpers
│   ├── MinimapIcon.lua              # LibDBIcon button + tooltip
│   ├── Locale/                      # enUS only (missing keys fall back to the key)
│   ├── Media/Icons/                 # bpgp-32.png
│   ├── Libs/                        # All libraries vendored (see Libs/README.md)
│   └── Modules/
│       ├── Common/                  # ACL, Comms, ConfigManager, Database, EventManager, Hooks, Logger, TestMode, Version
│       ├── Ledger/LedgerManager/    # Wrapper around LibEventSourcing
│       ├── Profiles/                # ProfileManager (one character = one profile), ProfileInfoManager (versions)
│       ├── Rosters/RosterManager/   # The single roster, its configuration, slot values, item overrides
│       ├── Raids/                   # RaidManager (raids, raid members, on-time bonus), RaidReminders (start/end raid prompts)
│       ├── Points/PointManager/     # EP/GP award, set and decay
│       ├── Loot/LootManager/        # Loot awards (GP charges), Award window
│       ├── Auctioning/              # AuctionManager (officer), BiddingManager (raider), AuctionHistory, TradeHelper, Common
│       ├── Import/                  # Standings import (Name, EP, GP) and its window
│       ├── Global/                  # Slash commands, chat handlers, global configs, guild change handler,
│       │                            # loot roll handler (Pass on loot, Need on everything)
│       ├── UI/                      # Shared Blizzard-template UI pieces (windows, tabs, lists, inputs, menus)
│       ├── MainWindow/              # Main window and its pages (Standings, Auction, Trade, History, Raids, Roster, Audit, Settings)
│       └── Alerts/                  # Alert toasts (points received, bid accepted/denied)
├── docs/                            # Decisions, plans for upcoming work, CurseForge reference (not packaged)
└── scripts/                         # check_addon.py (TOC/XML references, packager markers, Lua balance)
```

---

## 3. Global namespace

All files share one addon table via `local name, CLM = ...`. It's also exposed as `_G.BPGP`.

| Namespace | Contents |
|-----------|----------|
| `CLM.MODULES` | Runtime modules (managers), keyed by name |
| `CLM.MODELS` | Data models (Roster, Profile, Loot, Raid, …) and `CLM.MODELS.LEDGER` entry types |
| `CLM.GUI` | GUI modules, initialized after all managers |
| `CLM.OPTIONS` | Option modules (empty since Phase 9c; settings are in the Settings tab) |
| `CLM.EXTERNAL` | Externally registered modules (unused for now) |
| `CLM.UTILS` | Utility functions |
| `CLM.CONSTANTS` | Shared constants |
| `CLM.COMM_CHANNEL` | Comm channel names |
| `CLM.LOG` | Logger (LibLogger) |
| `CLM.L` | Localisation table |

**Coexisting with CLM:** the guild still runs the real CLM, and both addons can be loaded together. That's why everything global has a BPGP name:
- SavedVariables: `BPGP_DB`, `BPGP_Logs`, `BPGP_Minimap`;
- comm prefix: `BPGP` (`BPGPT` in test mode);
- frames and popups: `BPGP_*`;
- AceConfig app names, and the LibStub names of the forked libraries: `BPGP-EventSourcing/*`, `BPGP-EventDispatcher`.

---

## 4. Initialization

Initialization is **asynchronous and staged**. It starts after `GUILD_ROSTER_UPDATE` (the database is keyed by guild), with a 10-second fallback timer.

```
OnInitialize()
  └─ SavedVariables, logger, version
  └─ Register GUILD_ROSTER_UPDATE, C_Timer.After(10, _ExecuteInitialize)

_SequentialInitialize(stage), 0.1 s apart:
  1  _InitializeDatabase   (retries until the guild name resolves)
  2  _InitializeCore       (ConfigManager, ACL, Hooks)
  3  _InitializeBackend    (Logger, Comms, TestMode, EventManager, TrustInfoProvider, LedgerManager)
  4  _InitializeMinimap
  5  _InitializeFeatures   (managers, then global handlers)
  6  _InitializeOptions
  7  _InitializeGUI        (every CLM.GUI module)
  8  _InitializeExternal
  ✓  _Enable               (Comms:Enable, LedgerManager:Enable)
```

---

## 5. Event sourcing / ledger

This is the most important thing to understand.

1. **Every change** (create roster, add profiles, award EP, charge GP, decay, settings) is a `LogEntry` submitted to the ledger. It is never applied to state directly.
2. **State is a replay.** Registered *mutators* rebuild all in-memory state from the entries. An entry inserted in the past triggers a full replay.
3. **Sync** keeps every client's ledger the same (§9).

```lua
-- 1. Entry type (LedgerEntries.lua next to the manager)
local MyEntry = LogEntry:extend("XY")          -- short, unique class id
function MyEntry:new(rosterUid, value) ... end
function MyEntry:fields() return mergeLists(LogEntry:fields(), {"r", "v"}) end

-- 2. Mutator, registered in the manager's Initialize()
CLM.MODULES.LedgerManager:RegisterEntryType(MyEntry, function(entry)
    -- update in-memory state from entry
end)

-- 3. Submit; it's applied locally and broadcast
CLM.MODULES.LedgerManager:Submit(MyEntry:new(uid, 10), true)
```

- **Identity:** an entry is identified by `(timestamp, counter, creator realm, creator id)`, where the creator is the integer part of the character GUID. The ledger is sorted by identity and only ever appended to.
- **Undo:** `LedgerManager:Remove(entry)` writes an ignore (`IGN`) entry; the target is skipped on replay.
- **A failing or unknown entry** is skipped and shown in the Audit tab, not fatal (S3). Its change is lost for everyone, so mutators must check their input.
- **Entry formats are frozen** since v1.0.0 (V7): add new entry types, never change or remove old ones.

---

## 6. Database

`CLM.MODULES.Database` wraps the SavedVariables table `BPGP_DB`. The key is `retail <faction> <realm> <guild>` (lowercase).

| Accessor | Storage | Purpose |
|----------|---------|---------|
| `DB:Global()` | `BPGP_DB.global` | Account-wide settings |
| `DB:Personal(table, schema)` | `BPGP_DB[key].personal[table]` | Personal data and settings |
| `DB:GUI(table, schema)` | `BPGP_DB[key].personal.gui[table]` | Window positions and GUI state |
| `DB:Ledger()` | `BPGP_DB[key].ledger`, or `.ledger_test` in test mode | The event log |
| `DB:Server()` | `BPGP_DB[key]` | The whole guild-scoped table |

The optional `schema` fills in missing keys on load.

**Test mode** (`Modules/Common/TestMode`, V10) is fixed for a session; switching reloads the UI, and is blocked during a running auction. Isolation is structural:
- `DB:Ledger()` returns `ledger_test`, so a test client never holds a reference to the live ledger;
- every comm prefix is `BPGPT…` instead of `BPGP…`, and a live client never registers it. Prefix + channel name must fit WoW's 16 characters, so channel names stay ≤ 11;
- chat is printed locally with a `[TEST]` prefix; raid warnings are never sent;
- permissions are unchanged: test mode never loosens who may write.

Simulation tools are normal shipped code behind `TestMode:IsOn()`:
- **Simulated raid group:** `TestMode:GetSimulatedGroup()` returns you (raid leader) plus guild members, roster members first. `RaidManager` reads it instead of the raid roster while you're not in a real group. It's stored in the personal DB.
- **Solo auctions:** without a real group, `Comms:Send` turns RAID/PARTY traffic into a whisper to yourself, so your own Bidding window receives the auction. Whispers to simulated players are dropped.
- **Simulated bidders:** each other raid member gets a random tier bid, OS bid, pass or no response, passed to `AuctionManager:HandleSubmitBid` like a received bid.
- In a real group (several testers), the real raid roster and comms are used on the `BPGPT` prefix.

---

## 7. Domain models

### Roster (`CLM.MODELS.Roster`)

There is **one roster**, created with "Set up BPGP" in the Standings tab.

```
Roster
├── uid
├── configuration        RosterConfiguration (starting EP/GP, min GP, rounding, on-time bonus,
│                        min standing, OS, auction length, anti-snipe, roll time, ...)
├── defaultSlotValues    GP per gear slot × tier key; only Base, Small and Medium are used (Minor, Major, BiS, R16)
├── itemValues           per-item overrides (written automatically when an auction starts)
├── fieldNames           old custom tier names: still replayed, no longer shown
├── inRoster / standings (EP) / pointInfo (GP and totals)
├── pointHistory / profilePointHistory
└── raidLoot / profileLoot
```

`RosterConfiguration` fields are stored by position in some entries, so add new fields at the end only.

### Profile (`CLM.MODELS.Profile`)

One character: GUID, name, class, plus the addon version reported by the player. Profiles are created for guild members when they're added to the roster (Manage roster tab or standings import).

### Raid (`CLM.MODELS.Raid`)

A raid session for the roster: status (created / in progress / finished / stale), players, configuration snapshot (on-time bonus). The raid group comes from the WoW raid roster, or from a simulated group in test mode.

### Loot (`CLM.MODELS.Loot`)

An awarded item: item, GP charged, time, raid, player. Rebuilt from loot entries on replay.

---

## 8. Access control

| Level | Who |
|-------|-----|
| `PLEBS` | Any guild member (read-only) |
| `OFFICER` | Guild ranks with **"Is Officer"** (rank permission flags 11/12) |
| `GUILD_MASTER` | Guild Master |

- `TrustInfoProvider` reads the guild roster and rank permissions every time the guild roster updates. Ranks and permissions come from the server, and only the GM can change them.
- On Midnight the Rank Permissions screen has one **"Is Officer"** checkbox instead of separate view/edit officer note boxes. Flags 11 and 12 (`C_GuildInfo.GuildControlGetRankFlags`) are on for exactly those ranks, on a GM's and a raider's client alike (verified in-game 2026-10-16). Giving a rank "Is Officer" therefore gives it full ledger rights (S1, S2).
- `ACL:CheckLevel(level, name)` gates actions, both when sending and when receiving.
- Officer checks are enforced on **receive** too, not only in the UI. Hiding a button is a convenience; the receiving side is the security.
- Before the guild roster has loaded the trust cache is empty and all data is dropped: this fails safe, the first sync is just slower.

---

## 9. Sync and security

Every client ends up with the union of all accepted entries (eventually consistent). Only officers send data; raiders listen, compare hashes and ask for missing weeks. Live updates and catch-up carry the same entries: one entry when it's created, whole weeks for someone who was offline.

```
 Officer A (creates entry)               Everyone in guild
 ─────────────────────────               ─────────────────
 Submit(entry)
   ├─ local check: am I an officer?
   ├─ insert in own ledger
   └─ entry ── LedgerD3, GUILD ───────► sender is an officer? creator == sender? not in the future?
                                        → insert into ledger → replay → standings update

 Every 10 s, each officer:
   AdvertiseHash{ last 8 weeks + 8 rolling older weeks:
                  (week, checksum incl. entry content, entry count),
                  overall state checksum }  ── LedgerS3, GUILD ──►  every client compares each week
                                                                    mismatch → RequestWeek(w)
 Officers that advertised week w (alphabetically first name wins, 3-8 s random delay):
   WeekData{w, all entries of week w} ── LedgerD3, GUILD ──► everyone merges missing entries (dedup by identity)
```

The receive-side rules are S3-S7 in [docs/decisions.md](docs/decisions.md). The code is `Libs/LibEventSourcing/source/ListSync.lua` (adverts, requests, week data), `StateManager.lua` (replay), `Modules/Ledger/LedgerManager/LedgerManager.lua` (authorization handlers) and `Modules/Common/Comms/Comms.lua` (per-channel checks, before decoding, so junk is cheap to drop).

**What holds:**
- Addon-message sender names are set by the WoW server and can't be faked.
- Non-officers can't inject data: their data is dropped at the comms layer.
- Editing your own SavedVariables only affects you, because raiders never send data.

**Inherent limits (accepted):**
- **Officers are trusted.** Without per-officer signatures, a malicious officer can still write arbitrary entries, including ones relayed in week data that claim another officer as creator. The Audit tab and undo are the safety net.
- **Data is public within the guild.** Standings and history are broadcast to GUILD, as EPGP intends.
- **Auctions are not ledger data.** Auction start/stop and bids are live RAID/WHISPER messages; only the result (the GP charge) becomes an entry.

### Communications (`CLM.MODULES.Comms`)

Comms wraps AceComm-3.0 and handles serialisation, compression and a security callback per channel. Addon messages are queued during Midnight's chat or encounter lockdown.

| Channel | Constant | Accepted from | Purpose |
|---------|----------|---------------|---------|
| `LedgerS3` | `LEDGER.SYNC` | guild members | Hash advertisements (officers only), week requests, peer state |
| `LedgerD3` | `LEDGER.DATA` | officers | Week data and live entries |
| `Auction5` | `AUCTION` | an officer in your raid group (S9, R19) | Auction start/stop, anti-snipe, bid accepted/denied |
| `Bidding5` | `BIDDING` | anyone (validated by the auctioneer) | Bids |
| `Bids2<n>` | `BIDANNOUNCE` | an officer in your raid group | Bid list for raiders (open auction) |
| `Version2` | `GLOBAL` | anyone | Version announcements |

---

## 10. Auctioning

- **AuctionManager:** runs on the auctioneer's client: an officer who is raid leader/assistant, or the officer with *Need on everything* on (R19). It owns the auction, broadcasts items, timers and bids, validates bids, and awards the winner (a GP ledger entry).
- **BiddingManager:** runs on every raider's client. It shows the bidding window and sends bids.
- **AuctionInfo / AuctionItem:** shared models of the auction in progress.
- **AuctionHistoryManager:** keeps finished auctions with their bids.
- **TradeHelper:** tracks awarded items per winner and puts them in the trade window.

Auctions are always **Open**. Bidders choose one of three fixed tiers (BiS, Major, Minor, R16), each with its own GP from the slot table or item overrides, or OS or Transmog (both 0 GP, R14, R29), Pass or Cancel. Ranking: tier → OS → Transmog, then PR, then roll; among Transmog bids PR doesn't count. Anti-snipe and a `/roll` phase are supported.

The auction list fills from corpses, the auctioneer's own loot and the Loot Rolls history, keeping only tradeable Epic+ Weapon, Armor and Miscellaneous items (R20, R26, R28). `Global/GlobalLootRollHandler.lua` handles *Pass on loot* and *Need on everything* for the same item classes.

---

## 11. Points

`PointManager` writes point entries:
- **Modify:** award EP or add GP.
- **Set:** used by the standings import.
- **Decay:** EP, GP or both, by %.

Each works for selected players, the whole roster, or the current raid. PR is EP ÷ max(GP, minimum GP). The only automatic award is the on-time bonus when a raid starts.

---

## 12. GUI

- `Modules/MainWindow/MainWindow.lua` hosts the main window (`CLM.GUI.MainWindow`): a portrait frame with bottom tabs, a page header, a footer with the sync state, and a syncing overlay. Pages register with `MainWindow:RegisterPage` and implement `Build`, `Refresh` and optionally `OnShow`. Officers get Standings, Auction, Trade, History, Raids, Roster, Audit and Settings; raiders get Standings, History, Raids and Settings. While an auction runs, a Bid button right of the page header reopens the Bidding window (`MainWindow:UpdateBidButton`, called by the Bidding window on auction start and end).
- Refreshes are coalesced to one per frame and only run while the window is visible (ledger updates, group and guild roster changes).
- Every write asks first through `UI.Confirm` (a shared `StaticPopup`).
- The Settings tab (`Settings.lua`) is built with `UI.CreateForm` and calls the modules' own getters and setters. Guild settings and gear values are ledger entries (`RosterManager:SetRosterConfiguration`, `SetRosterDefaultSlotTierValue`, …). `ConfigManager` only registers `/bpgp` slash commands.
- The auctioning UI is the Auction tab (`MainWindow/Auction.lua`, R12); `CLM.GUI.AuctionManager` is a small adapter that opens it.
- Separate windows, all on `Modules/UI`: Bidding (`BiddingWindow.lua`), Award (`AwardGUI.lua`), Auction history and Import standings (each module's `GUI.lua`). The trade list is the Trade tab (`Modules/MainWindow/Trade.lua`).
- The rule: GUI reads from managers and writes only through manager methods.

Shared pieces for every window are in `Modules/UI/` (`UI.lua`, `List.lua`); `/bpgp uitest` shows them. The conventions are in [DEVELOPMENT-GUIDELINES.md §7](DEVELOPMENT-GUIDELINES.md#7-ui-conventions).

---

## 13. Midnight (12.x) specifics

- **Chat lockdown:** `UTILS.SendChatMessage` queues messages during `C_ChatInfo.InChatMessagingLockdown()`.
- **Addon-message lockdown:** `Comms:Send` queues messages during lockdown or a boss encounter.
- **Secret values:** `UTILS.IsSecret` guards raid-roster reads (updates wait and retry), loot and `/roll` parsing, target GUIDs and the chat filter.

---

## 14. Adding a feature: checklist

1. **Ledger entry** in the manager's `LedgerEntries.lua`, with a unique short class id. Existing formats are frozen: add a new type instead of changing one.
2. **Mutator** registered in the manager's `Initialize()`. Make it robust: a throwing mutator is skipped, not fatal, but the change is lost.
3. **Manager** initialized in `CORE:_InitializeFeatures()` at the right position.
4. **GUI** in `CLM.GUI`. It reads from managers and writes through them.
5. **ACL:** gate officer actions with `ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER, sender)`, also on receive.
6. **Globals** get BPGP names (see §3). Never add packager-only blocks (`@do-not-package@`, `@debug@`).
7. **Check:** run `python -I scripts/check_addon.py`, then test in-game, in **test mode** first.
