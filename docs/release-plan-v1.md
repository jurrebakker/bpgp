# BP EPGP — v1.0 Release Plan

> Fork of [Core Loot Manager](https://github.com/CoreLootManager/CoreLootManager) v5.7.8 (Apache 2.0), stripped down to the
> EPGP features our guild actually uses, for **retail (Midnight, 12.x) only**.
>
> Status: **plan** — nothing has been changed in the code yet.

---

## 1. Goals & non-goals

**Goals for v1.0**

1. Loads and works on retail Midnight (Interface 120100 / 120105).
2. Covers exactly our guild's EPGP workflow (see §3) — nothing more.
3. Fully independent from CLM: own name, own SavedVariables, own comm channels. Can be installed next to CLM without conflicts.
4. Officers stay in sync automatically (event-sourced ledger, kept from CLM).
5. Runs straight from a git clone (all libraries vendored) and can be published on CurseForge / Wago.

**Non-goals for v1.0**

- DKP, SK, Classic/TBC/Wrath/Cata/MoP/SoD/Hardcore support.
- Multiple rosters in the UI, bench/standby, alt-main linking, profile locking.
- Importers/exporters, cross-guild sync, time travel, translations.
- Keeping compatibility with existing CLM data or CLM clients (we start a fresh ledger and import standings once).

---

## 2. Decisions (from the Q&A)

| Topic | Decision |
|---|---|
| Game version | Retail Midnight only |
| Point system | EPGP only |
| Rosters | **One roster** (model stays, UI assumes a single roster) |
| Raids | Create / start / end raids — **keep** |
| Automatic EP | **On-time bonus only** (given at raid start). Drop boss-kill, interval and raid-end bonuses |
| Manual EP | Award EP to player / raid / roster — **keep** |
| Decay | **Keep** (EP, GP, EP+GP decay) |
| Bench / standby | **Remove** |
| Profiles | Plain "one character = one profile". **Remove** alt-main linking, profile locking, spec/role display |
| Auction type | **Open** only (remove Sealed, Vickrey, Anonymous Open) |
| Bidding | **Named tiers** (custom-named buttons, each its own GP) — keep Tiered + Named buttons. Remove Ascending (DKP style) |
| Gear values | Per-slot default values — **keep**; per-item overrides — keep (auction start writes them automatically) |
| Auction extras | Keep **anti-snipe, auction history, trade helper, /roll mode** |
| Admin | Keep **Audit tab** (view + undo entries). Remove time travel / sandbox, export, disenchant |
| UI extras | Keep **minimap icon, alert popups, raid warnings**. Remove item-tooltip GP prices |
| Existing data | Start a **fresh ledger**; officer pastes current EP/GP list into a new **import window** |
| Name | Title **BP EPGP**, folder `BP_EPGP`, slash `/bpepgp`, comm prefix `BPEP` |
| Language | English only (other locales removed; `enUS` returns the key itself, so nothing breaks) |

Because we start a fresh ledger, we are **free to delete ledger entry types and trim their fields**. (In CLM an unknown entry type crashes replay — `LibEventSourcing/source/StateManager.lua:187-245` — so this freedom only exists because we don't import the old CLM ledger.)

---

## 3. Feature inventory — keep vs. remove

### 3.1 Keep (the v1.0 feature set)

| Feature | Where it lives today |
|---|---|
| Roster with EPGP standings (EP, GP, PR = EP/GP), min GP, base EP/GP, rounding | `Modules/Rosters/RosterManager/*` |
| Default GP per gear slot (with tiers) | `Roster.lua` default slot values, `Options.lua:472-513` (R6 entries) |
| Per-item value overrides | R7/R8/RR entries; written automatically on auction start (`AuctionManager.lua:843-850`) |
| Named bid buttons (tier names) | RF entries, `Options.lua:1109-1114, 1280-1302` |
| Create / start / end raid, auto-add raid members to roster | `Modules/Raids/RaidManager/*` |
| On-time bonus at raid start | `RaidManager.lua:411-422` |
| Award EP (player / raid / roster), set points | `Modules/Points/PointManager/*` |
| Decay (EP / GP / both) | `PointManager.lua:587-606`, DD/DT entries |
| Open auction, tiered + named buttons, OS/Pass/Cancel, min EP, anti-snipe, item notes, upgrade info | `Modules/Auctioning/AuctionManager`, `BiddingManager`, `Common` |
| `/roll` phase in auction window | `AuctionManager.lua:877-972` |
| GP charge on award (II/IA entries) + raid warning announce | `Modules/Loot/LootManager/*` |
| Auction history window | `Modules/Auctioning/AuctionHistoryManager/*` |
| Trade helper (track & open trades for awarded items) | `Modules/Auctioning/AutoAssign/*` (trade part only) |
| Officer sync (ledger + ACL from guild rank permissions) | `Modules/Ledger/LedgerManager`, `Libs/LibEventSourcing`, `Modules/Common/ACL` |
| Standings / History / Raids / Manage roster / Audit tabs | `Modules/GUI/*` |
| Minimap icon (incl. sync status) | `MinimapIcon.lua` |
| Alert popups | `ClassicLootManager_Alerts` → merged into main addon |
| Raid warnings (auction start/countdown/winner, raid start/end) | `Utils.lua:1220` `SendChatMessage` callers |
| Version check between guild members | `Modules/Common/Version` |
| **Test mode** (new): isolated test ledger + comm prefix, simulated raid/bidders, add items by ID ([features/test-mode.md](features/test-mode.md)) | replaces `SandboxManager` and the dev fakes |
| `/bpepgp` slash commands, settings (as tabs in the main window, Phase 9). Keybindings were removed after the Phase 3 smoke test | `Modules/Global/*`, `ConfigManager` |

### 3.2 Remove

| Feature | Location | Approx. LOC |
|---|---|---|
| Non-English locales (deDE, esES, frFR, ruRU, zhCN, zhTW) | `Locale/` | 15,200 |
| Integrations addon (CSV/MonolithDKP/CEPGP/Gargul/RCLC import, XML/JSON export, WoW DKP bot) | `ClassicLootManager_Integrations/` | 3,400 |
| In-game changelog module | `Modules/Common/Changelog/` | 2,550 |
| Tracker addon (who-got-what tooltip) | `ClassicLootManager_Tracker/` | 360 |
| Item tooltip GP prices | `Tooltips.lua` | 140 |
| Dev annotations | `_annotations/` | 870 |
| DKP point type + DKP-only options (zero-sum bank, caps, weekly caps, tax, allow-below-min) | ~45 branch sites across Rosters/Points/Loot/GUI/Auctioning | ~800 |
| Ascending bidding, All-In, auto-update bid, "new highest bid" RW | `AuctionManager.lua:1080-1130`, `BiddingManager/MultiGUI.lua` | ~200 |
| Sealed / Vickrey / Anonymous Open | AuctionInfo, AuctionManager, MultiGUI | ~50 |
| Dynamic item values (EPGPWeb/Wowpedia formulas) | `ItemValueCalculator.lua`, V* entries, `Options.lua:515-620` | ~400 |
| Class award multipliers | RM entry, `Roster.lua:91-94, 554-583`, `Options.lua:780-813` | ~100 |
| Boss-kill / interval / raid-end bonuses + all encounter tables | `AutoAwardManager/` (whole module), `Options.lua:677-778` | ~1,800 |
| Bench / standby (staging, self-subscribe, bench multiplier, auto-bench leavers) | `StandbyStagingManager/`, raid standby lists, Options | ~500 |
| Alt-main linking | P2 entry, `AltMainLinkingGUI.lua`, mirroring in Point/Loot/RosterManager | ~400 |
| Profile locking | P3 entry, filters, checks | ~80 |
| Spec/role tracking (ProfileInfoManager — keep only the version-announce bit) | `Modules/Profiles/ProfileInfoManager/` | ~150 |
| Profile pruning | `ProfileManager.lua:453-549`, `PruneLog.lua` | ~140 |
| Attendance tracker | `AttendanceTracker.lua` + Standings column | ~120 |
| Disenchant (button, ID/IE entries) | LootManager, AuctionManager GUI | ~120 |
| Master-loot auto-assign (`GiveMasterLoot`, removed from retail in 8.0) | `AutoAssign.lua:259-276` | ~40 |
| Cross-guild sync | `Modules/Ledger/CrossGuildSyncManager/` | 190 |
| Time travel / `/timetravel` / ChatOps; sandbox → replaced by test mode | `SandboxManager/`, `LedgerManager.lua:161-251`, LibEventSourcing ChatOps | ~500 |
| Classic shims, IndirectSlotMap (classic tier-token data), classic item ID lists, SSC/Wrath workarounds | `Utils.lua`, `ClassicLootManager.lua`, `IndirectSlotMap.lua`, etc. | ~700 |
| April Fools (`CLM.AF`) + joke sounds | multiple, `Media/Audio` | ~80 |
| `--@do-not-package@` blocks; dev fakes (FakeBids/FakeAuction) → rebuilt as test-mode tools | AuctionManager, BiddingManager, AutoAssign, ACL, Comms | ~200 |
| Auto-roll on loot (GlobalUIHandlers) | `Modules/Global/GlobalUIHandlers.lua` | 150 |
| Unused libs (LibExpiringTimer, AceHook) | `Libs/` | small |
| ~~Build/release scripts we don't need (l10n, changelog generators, itemlink decoder, vendored packager, CLM Discord/GitHub bots)~~ **done**, only `genxmls.py` and `verify-dependencies.sh` remain | `scripts/` | ~4,000 |

**Expected result:** from roughly 52k lines of addon Lua (excluding libraries) down to about **15–18k**.

---

## 4. Architecture

### 4.1 How CLM works (verified against the code)

```
                    ┌───────────────────────────── GUI (CLM.GUI) ──────────────────────────────┐
                    │ UnifiedGUI tabs · Auction window · Bidding window · Options (AceConfig) │
                    └───────────────┬───────────────────────────────────────────▲─────────────┘
                         calls manager methods                             reads state /
                                    │                                       events
                    ┌───────────────▼─────────── Managers (CLM.MODULES) ────────┴─────────────┐
                    │ RosterManager · PointManager · LootManager · RaidManager · ProfileManager │
                    │ AuctionManager (officer) · BiddingManager (raider) · AuctionHistory · ...  │
                    └───────────────┬──────────────────────────────────▲──────────────────────┘
                    Submit(LogEntry)│                                   │ mutator callbacks
                    ┌───────────────▼──────────── LedgerManager ────────┴──────────────────────┐
                    │ LibEventSourcing: sorted entry list → replay → state ; hash-based sync    │
                    └───────────────┬───────────────────────────────────────────────────────────┘
                                    │ Comms (AceComm + LibSerialize + LibDeflate)
                         GUILD: LedgerS3 (hash adverts) / LedgerD3 (week data, ASSISTANT+)
                         RAID/WHISPER: Auction5 / Bidding5 / Bids2x (auction traffic, not in ledger)
```

**Key concepts**

1. **Event sourcing.** Every change (award EP, charge GP, decay, start raid, change config) is a `LogEntry` submitted through `LedgerManager:Submit(entry)` (ARCHITECTURE.md wrongly calls it `Add`). State is never written directly; it is rebuilt by replaying all entries through *mutator* callbacks registered with `LedgerManager:RegisterEntryType`. Undo = an `IgnoreEntry` that hides an earlier entry.
2. **Sync.** Entries are grouped per week. Officers (ASSISTANT+) broadcast a hash of recent weeks to GUILD every ~10 s; a client with a different hash requests that week and receives the entries. The hash covers only entry identity (timestamp, counter, creator), not payloads.
3. **Access control.** Trust levels come from **guild rank permissions**: "view officer note" → ASSISTANT, "edit officer note" → MANAGER, rank 1 → GUILD_MASTER (`TrustInfoProvider.lua:63-104`). Comm channels and ledger entries are checked against these levels.
4. **Auctions are not in the ledger.** Auction state lives only in the officer's client and is broadcast over RAID/WHISPER. Only the *result* (GP charge = loot award entry) goes into the ledger.
5. **Staged startup.** `OnInitialize` waits for `GUILD_ROSTER_UPDATE` (or a 10 s fallback), then runs stages 0.1 s apart: Database → Core → Backend → Minimap → Features → Options → GUI → External → Enable (`ClassicLootManager.lua:262-299`).
6. **Database.** SavedVariables `CLM2_DB` keyed by `"<expansion> <faction> <realm> <guild>"` — on retail 12.x that is `exp11 …`, which **changes every expansion** (data would look empty after 13.0).
7. **Packager-dependent code.** `--@do-not-package@` / `--@debug@` blocks are only stripped by the BigWigs packager. In a raw clone `ACL:CheckLevel` returns `true` for everyone, GUILD sync is remapped to RAID, and anyone can run auctions (`ACL.lua:75-78`, `Comms.lua:302-304`, `RaidManager.lua:807`).

### 4.2 Target architecture for BP EPGP

Same layered design, much less in each layer:

```
BP_EPGP/
├── BP_EPGP.toc                 # Interface 120100,120105 · SavedVariables BPEPGP_DB, BPEPGP_Logs, BPEPGP_Minimap
├── Core.lua                    # (was ClassicLootManager.lua) namespace, staged init — no AF, no ML hook
├── Utils.lua                   # retail-only shims, chat send with lockdown guard, MEDIA_PATH constant
├── Libs/                       # ALL libraries vendored (no .pkgmeta externals needed to run)
├── Locale/enUS.lua
├── Media/                      # icons, bars (own icon replaces CLM logo)
└── Modules/
    ├── Common/      ACL · TrustInfoProvider · Comms · ConfigManager · Database · EventManager · Hooks · Logger · Version
    ├── Ledger/      LedgerManager (no sandbox / cross-guild)
    ├── Profiles/    ProfileManager (create/remove only)
    ├── Rosters/     RosterManager · Roster · RosterConfiguration (EPGP fields only) · Options · LedgerEntries
    ├── Raids/       RaidManager (create/start/end, on-time bonus)
    ├── Points/      PointManager (award, set, decay) · PointHistory
    ├── Loot/        LootManager (award GP) · AwardGUI
    ├── Auctioning/  AuctionManager · BiddingManager · AuctionHistoryManager · TradeHelper (was AutoAssign) · Common
    ├── Import/      NEW: StandingsImport (paste Name,EP,GP)
    ├── Alerts/      merged from ClassicLootManager_Alerts
    ├── Global/      Configs · SlashCommands · GuildChangeHandler · ChatMessageHandlers
    └── GUI/         UnifiedGUI · Standings · History · Raids · ManageRoster · Audit · widgets · Filters
```

**Naming / isolation**

| Item | CLM | BP EPGP |
|---|---|---|
| Folder / TOC | `ClassicLootManager` | `BP_EPGP` |
| Title | Core Loot Manager | BP EPGP |
| Slash | `/clm`, `/classiclootmanager` | `/bpepgp` |
| SavedVariables | `CLM2_DB`, `CLM2_Logs`, `CLM2_MinimapIcon` | `BPEPGP_DB`, `BPEPGP_Logs`, `BPEPGP_Minimap` |
| Comm prefix | `CLM` + channel | `BPEP` + channel (prefix+channel ≤ 16 chars) |
| Global | `_G.CLM` | `_G.BPEPGP` (internal local stays `CLM` in v1 to keep the diff reviewable) |
| DB key | `exp11 <faction> <realm> <guild>` | `retail <faction> <realm> <guild>` (fixed — survives expansions) |
| Frame / binding names | `CLM_*` | `BPEPGP_*` |
| Version | v5.7.8 | v1.0.0 (own version channel, so CLM's v5 broadcasts can't switch us off) |

---

## 5. Known problems to fix (found during analysis)

### 5.1 Likely reasons the addon fails on Midnight / must-fix

We don't yet know the exact startup error. **First step in Phase 1 is to capture it with BugSack/!BugGrabber.** Candidates:

| # | Problem | Location | Fix |
|---|---|---|---|
| 1 | Libraries missing in a git clone (LibStub, Ace3, lib-st, …) → whole chain fails | `Libs/_filelist.xml`, `.pkgmeta` | Vendor all libs, current Ace3 |
| 2 | `hooksecurefunc(MasterLooterFrame, …)` unguarded in `OnInitialize` | `ClassicLootManager.lua:323` | Delete (no master loot on retail) |
| 3 | `SetGuildRosterShowOffline` unguarded | `ClassicLootManager.lua:334` | Guard / use `C_GuildInfo` |
| 4 | Chat filter returns the message during chat lockdown → may hide guild/raid chat or error on secret values | `GlobalChatMessageHandlers.lua:27-28` | Return `false`, skip secret values |
| 5 | `SendChatMessage` global without lockdown check (raid warnings) | `Utils.lua:1220-1223` | `C_ChatInfo.SendChatMessage` + `C_ChatInfo.InChatMessagingLockdown()` check, queue until lockdown ends |
| 6 | Addon messages blocked during encounter lockdown (sync, bids) | Comms / AceComm | Current Ace3/ChatThrottleLib; queue ledger sends while locked down |
| 7 | `GiveMasterLoot` / `GetMasterLootCandidate` called when auto-assign is on (default) | `AutoAssign.lua:268-269` | Delete |
| 8 | `COMBAT_LOG_EVENT_UNFILTERED` registration (SSC workaround) | `AutoAwardManager.lua:255` | Removed with AutoAwardManager |
| 9 | `RAID_ROSTER_UPDATE` registration (may not exist on retail) | `RaidManager.lua:632` | Use `GROUP_ROSTER_UPDATE` only |
| 10 | `ChatOps` overrides `ItemRefTooltip.SetHyperlink` globally (taint) | `LibEventSourcing/libs/ChatOps` | Remove ChatOps |
| 11 | Global `GetItemClassInfo` | `AuctionManager.lua:174` | `C_Item.GetItemClassInfo` |
| 12 | Blizzard `UIDropDownMenuTemplate` with LibUIDropDownMenu | `Utils.lua:742` | Use `L_UIDropDownMenuTemplate` |
| 13 | Secret values in combat: `UnitGUID("raidN")`, `GetRaidRosterInfo`, `CHAT_MSG_LOOT` / `CHAT_MSG_SYSTEM` (roll) parsing | RaidManager, ProfileManager, AuctionManager | `issecretvalue` guards; defer roster updates until out of combat |

### 5.2 Security / correctness bugs

| Problem | Location | Fix |
|---|---|---|
| Dev blocks give everyone officer rights and let anyone auction in an unpackaged build | `ACL.lua:75-78`, `RaidManager.lua:807`, `Comms.lua:302-304` | Delete all `--@do-not-package@` / `--@debug@` blocks, hard-code the release behaviour |
| Raiders accept START/STOP auction from anyone | `BiddingManager.lua:72-74, 147` | Check `IsAuctioneer` on receive |
| Anti-snipe countdown never re-arms (wrong field name) | `AuctionManager.lua:753` vs `:985-987` | Use one field |
| `GetUseOS()` always true (`self.c.o or true`) | `AuctionCommStructures.lua:122-124` | Explicit nil check |
| `self.handlers` nil for untrusted receivers of bid whispers | `AuctionManager.lua:631-636` | Register channel after handlers are set |
| ALT-click opens both Auction and Award windows | `AuctionManager.lua:245-254` & `AwardGUI.lua:271` | Different modifiers / one entry point |
| Ranged weapons map to removed ranged slot → no upgrade info | `BiddingManager.lua:25-35` | Map to main hand on retail |
| `/clm ignore` references non-existent `LedgerManager.ledger` | `GlobalSlashCommands.lua:80` | Fix or drop |
| Stale "!bid / !dkp" whisper hint in raid warning | `AuctionManager.lua:838-840` | Remove |
| Default point type is DKP, default auction type Sealed | `Options.lua:39`, `RosterConfiguration.lua:27` | EPGP + Open, Tiered + named buttons |

---

## 6. Work plan (phases)

Each phase ends with: luacheck clean, `/reload` without Lua errors, and the relevant part of the in-game checklist (§7) passing. Commit per phase.

### Phase 0 — Project setup
- [x] Create `CLAUDE.md` (architecture summary, conventions, "never write state directly — submit ledger entries", how to test in-game).
- [x] Vendor all libraries from `.pkgmeta` *(copied from the packaged CLM v5.8.0; license files still incomplete, see `Libs/README.md`)* into `Libs/` (latest Ace3 for Midnight, LibStub, CallbackHandler, lib-st, LibCandyBar, LibLogger, LibDBIcon, LibDeflate, LibSerialize, LibUIDropDownMenu, LibSharedMedia, AceGUI-SharedMediaWidgets) with their license files.
- [x] Dev setup: symlink/junction *(junction created 2026-10-16)* the addon folder into `World of Warcraft\_retail_\Interface\AddOns\`; install BugSack + !BugGrabber.
- [x] Keep `.luacheckrc` (update globals), add a GitHub Action for luacheck.
- [x] Decide branch strategy *(feature branch per phase or two, e.g. `feat/v1-phase-0-1`)* (`main` for releases, feature branches per phase).

### Phase 1 — Rebrand & boot on Midnight
- [x] Rename folder/TOC to `BP_EPGP`, Title "BP EPGP", Author, remove CLM Curse/Wago IDs and Patreon link.
- [x] Rename SavedVariables, slash command `/bpepgp`, comm prefix `BPEP`, global `_G.BPEPGP`, frame/binding names, `[CLM]` chat prefix, minimap LDB name.
- [x] Introduce `MEDIA_PATH` constant; replace all hard-coded `Interface\AddOns\ClassicLootManager\…` paths.
- [ ] Replace CLM logo with our own icon.
- [x] Fix DB key to `retail <faction> <realm> <guild>`; version to 1.0.0-dev.
- [x] Merge the Alerts addon into the main addon; delete Tracker and Integrations folders.
- [x] Remove `--@do-not-package@` / `--@debug@` / `@non-debug@` dev blocks and dev fakes. Without this a git clone has **no security** ([sync-and-security.md](sync-and-security.md) C1).
- [x] Add a CI/luacheck step *(`scripts/check_addon.py`)* that fails if any of those markers reappear.
- [ ] Capture and fix the actual startup error(s) — §5.1 items 1-4. *(1: libs vendored; 2: MasterLooterFrame hook removed; 3: guarded; 4: chat filter no longer hides messages in lockdown; also ported 5.8.0's `C_Item.GetItemClassInfo` fix. Waiting for the first in-game run.)*
- [x] Isolation from CLM: unique LibStub names for our forked libs (`BPEPGP-EventSourcing/*`, `BPEPGP-EventDispatcher`), AceGUI widget types, AceConfig app names, keybinding names, alert templates. *(found while renaming)*
- **Done when:** addon loads on Midnight with zero errors, shows the UI, two officers see each other as synced.

### Phase 2 — Remove the big unused blocks
- [x] Delete non-English locales *(done in Phase 1)*.
- [x] Delete Changelog module, `_annotations`, April Fools (incl. joke sounds). CHANGELOG.md replaced with our own. (Unused scripts: already removed.)
- [x] Delete CrossGuildSyncManager, SandboxManager + time travel + ChatOps (move `stateManagers` init out of `SlashCommands.lua` first).
- [x] Delete all classic code *(expansion checks now return fixed retail answers until Phase 3 removes the boss-kill code; encounter tables go with it; master-loot paths go in Phase 5)*: `IsClassicEra`/`IsSoD`/`IsHardcore`, expansion branches in `Utils.lua`, classic item ID lists, IndirectSlotMap data, master-loot paths, classic tooltip fallbacks.
- [x] Delete GlobalUIHandlers (auto-roll), Tooltips.lua.

### Phase 3 — EPGP only
- [x] Remove DKP point type: collapse every `POINT_TYPE` branch to the EPGP path; remove zero-sum bank, caps, weekly caps, tax, allow-below-min.
- [x] Remove dynamic item values (ItemValueCalculator + V* entries), class multipliers (RM).
- [x] Remove AutoAwardManager and encounter tables; keep on-time bonus in RaidManager.
- [x] Remove bench/standby (StandbyStagingManager, standby lists in raids, bench multiplier, auto-bench leavers, STANDBY comm channel).
- [x] Remove alt-main linking (P2), profile locking (P3), spec/role tracking, pruning, attendance tracker, disenchant (ID/IE).
- [x] Trim `RosterConfiguration` fields and Options to what's left; set defaults: EPGP, Open, Tiered, named buttons on.
- [x] Single roster: auto-select the only roster everywhere; hide roster dropdowns; block creating a second roster. First-time creation via a "Set up BP EPGP" button ([ui-overhaul](features/ui-overhaul.md) D7).
- [x] One officer level: collapse ASSISTANT/MANAGER checks into a single *officer* check ("Is Officer" rank, verified via rank flags 11/12 on 12.x). See [sync-and-security.md](sync-and-security.md) S1/S2.

### Phase 4 — Test mode ([features/test-mode.md](features/test-mode.md))
- [x] Test mode switch (`/bpepgp test`, and a *Test mode* section in the settings until the Advanced tab exists in Phase 9): separate test ledger section, `BPEPT…` comm prefix, local `[TEST]` chat output, TEST MODE title and orange minimap icon. No "apply" to live. Switching reloads the UI.
- [ ] Live ledger refuses anything flagged as test data (automated check in the test checklist).
- [ ] Simulation tools: simulated raid, add item by ID/link, auction without raid lead, simulated bidders, bidding-window preview, reset test data.
- **Done when:** a full raid evening (raid start → EP → auction → award → decay → undo) can be run solo in test mode, and the live ledger is byte-identical before and after.

### Phase 5 — Auctioning cleanup
- [ ] Remove Sealed / Vickrey / Anonymous Open, Ascending mode, All-In, auto-update bid, Joke/AF.
- [ ] Keep Tiered + named buttons, OS/Pass/Cancel, min EP, anti-snipe, `/roll`, upgrade info, history, item notes.
- [ ] AutoAssign → **TradeHelper**: keep trade tracking + TradeList GUI, drop `GiveMasterLoot`.
- [ ] Fix the auction bugs in §5.2.

### Phase 6 — New: standings import
- [ ] Officer-only window: paste lines `Name,EP,GP` (also accept tab-separated from a spreadsheet).
- [ ] Preview table (unknown names, duplicates, invalid numbers highlighted) before applying.
- [ ] On confirm: create profiles for missing characters, add them to the roster, set EP and GP via ledger entries (verify `PointManager` can *set* GP; add a GP-set entry if it can only set EP).
- [ ] Guard: import only allowed while the roster has no point history yet (or with an explicit "overwrite" confirmation).

### Phase 7 — Midnight hardening
- [ ] Chat lockdown: route all chat sends through one helper that checks `C_ChatInfo.InChatMessagingLockdown()` and queues messages.
- [ ] Addon-message lockdown: queue ledger broadcasts and verify bidding works outside encounters (auctions happen after the boss, normally fine).
- [ ] Secret-value guards in raid roster handling and chat parsing (§5.1 #13).
- [ ] Re-test every event registration on 12.x.

### Phase 8 — Sync hardening ([sync-and-security.md](sync-and-security.md))
- [ ] **S3:** validate every incoming entry (types, ranges, referenced roster/profile) before inserting it. Wrap each mutator in `pcall`; skip and flag failures in the Audit tab instead of halting. Show a warning on `MutatorFailed`.
- [ ] **S4:** include a digest of entry content in the week/state checksums (new hash format; free with the fresh ledger).
- [ ] **S5:** handle `AdvertiseHash` only from officers via GUILD/WHISPER; ignore `State`/`RequestState` from outside the guild.
- [ ] **S6:** reject entries > 10 min in the future; flag live entries with stale timestamps.
- [ ] **S7:** live single-entry pushes require `creator == sender`; week data accepted only from officers.
- [ ] **S9:** raiders accept auction control only from someone who is officer **and** raid leader/assistant (drop "relaxed" mode).
- [ ] Re-evaluate "am I an officer?" on `GUILD_ROSTER_UPDATE` so promotions/demotions take effect without `/reload` (L2).

### Phase 9 — Main window & settings tabs ([features/ui-overhaul.md](features/ui-overhaul.md))
- [ ] Remove all Options → AddOns pages (`AddToBlizOptions`) and the minimap "Configuration" menu item; add `/bpepgp config`.
- [ ] Resizable main window (min size fits 9 tabs on one row, ~1050 px), size remembered per character; tables reflow.
- [ ] New tab kind *page* in `UnifiedGUI`; hand-built pages for **Settings**, **Guild settings**, **Gear values**, **Advanced**.
- [ ] Guild settings / Gear values / officer parts of Advanced: visible to all, editable by officers only.
- [ ] Apply the K/F/D decisions per setting (fixed values hard-coded, dropped settings removed). Check whether LibSharedMedia and its AceGUI widgets can be dropped.

### Phase 10 — Testing (see §7)

### Phase 11 — Release 1.0
- [ ] Licensing checklist (§8).
- [ ] New README (what it is, install, officer setup, raider usage), CHANGELOG starting at 1.0.0.
- [ ] Packaging: BigWigs packager with a new `.pkgmeta` (no externals, libs are vendored), see §10.4.
- [ ] Publish on CurseForge (and optionally Wago) under the new name; tag `v1.0.0`. Full checklist in §10.
- [ ] Guild rollout: officers first, import standings, then raiders install.

---

## 7. Test checklist (in-game)

There is no automated test harness for WoW UI code; luacheck catches syntax/global mistakes. Everything is tested in-game **in test mode first** (Phase 4), then the sync and bidding parts once more on the test channel with a second account, and only then live. The multi-person parts need **at least two accounts/characters in the guild** (one officer, one raider), ideally two officers for sync.

**Startup & sync**
- [ ] `/reload` with zero Lua errors (BugSack empty), with and without CLM installed alongside.
- [ ] Minimap icon shows; `/bpepgp` opens the main window; Settings, Guild settings, Gear values and Advanced tabs open; nothing appears under Options → AddOns.
- [ ] Officer A awards EP → officer B sees it within ~30 s; raider sees standings.
- [ ] Non-officer cannot award, start auctions, or push ledger data.

**Roster & import**
- [ ] Create the roster; set default slot values per tier and tier button names.
- [ ] Import standings list; preview catches typos; standings match the list exactly.

**Raid**
- [ ] Create + start raid → members added to roster, on-time EP given, raid warning posted.
- [ ] Member joins/leaves mid-raid → raid list updates.
- [ ] End raid → raid closed, raid warning posted.

**Points**
- [ ] Award EP to player / whole raid / roster; history shows reason.
- [ ] Decay EP, GP, both — values correct, min GP respected.
- [ ] Undo an entry via Audit tab → standings revert on all clients.

**Auction**
- [ ] Alt-click item → auction window; values come from slot defaults; start auction.
- [ ] Raider sees bidding window with named tier buttons + Pass; bid accepted/denied messages; alert popup.
- [ ] Bid in last seconds → anti-snipe extends timer (and countdown restarts).
- [ ] `/roll` phase works.
- [ ] Award → GP charged correctly, PR updated, raid warning, auction history entry, trade helper lists the item.
- [ ] Repeat with chat/encounter lockdown active (during a boss) → no errors, messages queued.

---

## 8. Licensing & rebranding checklist (Apache 2.0)

- [ ] Keep `LICENSE` unchanged.
- [ ] Keep `NOTICE` and add: `BP EPGP — modified by Jurre Bakker, 2026. Based on Core Loot Manager.`
- [ ] README: "Based on Core Loot Manager by Lantis and contributors, heavily modified."
- [ ] Mark modified files (short header comment or a note in NOTICE/README that all files were modified).
- [ ] Don't use the names "Core Loot Manager" / "CLM" or the CLM logo as our branding (Apache §6 trademarks). Icons in `Media/Icons` are replaced by `bp-epgp-32.png` (done); in-game "CLM" strings remain.
- [ ] Remove CLM's Patreon, Discord, Curse/Wago IDs, "Created by Lantis" in-game strings → move credit to an About/credits line instead. (In-game settings header done: logo + "BP EPGP <version>".)
- [ ] Keep each vendored library's own license file.
- [ ] Update `CREDITS.md` (keep original credits, add ours).

---

## 9. Risks & open questions

| Risk / question | Mitigation |
|---|---|
| We don't know the exact startup error yet | Phase 1 starts by capturing it with BugSack |
| Midnight restrictions (secret values, chat/addon-message lockdown) are still evolving | Central helpers for chat & comms; test during real boss encounters |
| All raiders must install BP EPGP to bid | Announce in guild; version check warns outdated clients |
| Officers on CLM vs BP EPGP during rollout | Separate prefixes → no interference; switch everyone at once on a set date |
| Trade helper with personal loot: winner needs the item traded from whoever looted it | v1 keeps CLM behaviour (works when the item is in the officer's bags); revisit if needed |
| Import of standings is only as good as the list | Preview + officer double-check before applying; Audit tab can undo |
| Decay settings (EP%, GP%, how often) | Keep all three decay types; configure in-game |
| Internal namespace still called `CLM` | Intentional for v1 (smaller diff); optional rename in v1.1 |

---

## 10. Releasing to CurseForge

Research done 2026-10-16. Items marked **(unverified)** could not be confirmed from an official source; check them when we get there.

### 10.1 What matters for us

| Fact | Impact on BP EPGP |
|---|---|
| **Projects can't be private.** There is no private or guild-only mode; once approved, a project is public. | Anyone can install BP EPGP. That's fine: all write actions are gated by guild-rank ACL (§4.1 #3), provided the dev blocks are removed (§5.2). |
| **Experimental status** keeps a project out of website search and out of app sync; files can still be installed via the app's import. Leaving it requires the *legacy* site. Setting it from the new console is **(unverified)**. | Option for an officer-only beta before the guild rollout. |
| **Every project and every file is moderated.** The first review happens after the first file is uploaded, and takes "a few minutes to three workdays". Each later file shows *Under Review* until approved. | Upload at least a week before the rollout date. Don't plan a same-day hotfix release. |
| **Only Release/Beta files sync to the app** for a new project. Alpha-only projects are website-only, and beta/alpha files only reach app users who opt in. | Raiders get the Release channel. Officers can opt in to Beta to test. |
| **Every file needs a changelog.** | `CHANGELOG.md` via `manual-changelog` in `.pkgmeta`. |
| **Forks:** credit and link the original, explain what changed, and don't copy the original's description. Name, logo, summary and description must be our own. | Matches the §8 checklist. Write our own description ("Based on Core Loot Manager by Lantis and contributors…"). |
| **No donation links** (Patreon, Ko-fi) and no external download links. Blizzard's add-on policy also forbids obfuscated code and in-game donation requests. | Remove CLM's Patreon/Discord links (§8). |
| **Zip layout:** the top-level folder name must match the `.toc` name, or the validator can fail the upload. | Zip contains `BP_EPGP/BP_EPGP.toc`. |

Sources: [Creating and Submitting a Project](https://support.curseforge.com/support/solutions/articles/9000197241), [File & Project Types](https://support.curseforge.com/support/solutions/articles/9000197242), [Moderation Policies](https://support.curseforge.com/support/solutions/articles/9000197279), [How to become a CurseForge author](https://blog.curseforge.com/how-to-become-a-curseforge-author/), [Multi-TOC for WoW](https://support.curseforge.com/support/solutions/articles/9000209856-multi-toc-for-world-of-warcraft-addons), [Blizzard UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534).

### 10.2 One-time setup

- [ ] **CurseForge author account.** Sign in at <https://authors.curseforge.com/> with Google, Discord, GitHub or Twitch; there is no password login. Accept the author terms and fill in the profile.
- [ ] **Logo:** our own icon, 1:1, at least 400×400, PNG (not WebP), not a solid colour. The same artwork can replace the CLM icons in `Media/Icons` (§8).
- [ ] **Create the project:** Author Portal → Create Project → World of Warcraft → Addons.
  - **Name:** "BP EPGP". It must be unique on CurseForge; check that it's free.
  - **Summary:** one line, e.g. "Lightweight EPGP loot system with officer sync and open tier bidding."
  - **Description:** in English. Cover what it does, install, officer setup and raider usage, plus the CLM credit and link.
  - **License:** "Apache License version 2.0".
  - **Category:** main = *Guild*; extra = *Auction & Economy* (unrelated categories get the project sent back).
  - **Links:** source repository and issue tracker (optional; needs the repo to be public).
- [ ] Note the numeric **Project ID** (shown in the "About Project" box) and add it to the TOC: `## X-Curse-Project-ID: <id>`.
- [ ] **Upload token:** create one at <https://authors.curseforge.com/#/settings/api-tokens>. This is *not* the CurseForge "Core API" key from console.curseforge.com, which is for third-party apps.
- [ ] *(Optional)* **Wago Addons:** create a project at <https://addons.wago.io/developers>, add `## X-Wago-ID: <id>` to the TOC, and create a token at <https://addons.wago.io/account/apikeys>. Their onboarding and moderation process is **(unverified)**.

### 10.3 Where the build runs

The repo is currently only on this PC. The BigWigs packager (the standard WoW release tool) can run in two places:

| Option | What's needed | Pros / cons |
|---|---|---|
| **A. GitHub + GitHub Action** (recommended) | Push the repo to GitHub (private is fine). Add repository secret `CF_API_TOKEN` (and `WAGO_API_TOKEN`). Add a workflow running `BigWigsMods/packager@v2` on tag push. | Pushing a tag publishes the release. No local tooling, and it also creates a GitHub Release with the zip. A private repo uses free Actions minutes **(verify current limits)**. |
| **B. Locally in Git Bash** | Download `release.sh` into `.release/` (gitignored). Put tokens in `.release/.env`. Install `zip` and `jq`, which Git for Windows doesn't ship, or use WSL. Needs bash 4.3+. | No GitHub needed. Windows isn't officially supported by the packager, and the tokens live on this PC. |
| C. Manual upload | Build the zip yourself, then upload on the website and pick the game version and release type. | Fine as a one-off for the first upload. Easy to get the zip layout or changelog wrong. |

Sketch of the workflow for option A (`.github/workflows/release.yml`):

```yaml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write          # create the GitHub Release
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0       # packager needs history/tags
      - uses: BigWigsMods/packager@v2
        env:
          CF_API_TOKEN: ${{ secrets.CF_API_TOKEN }}
          WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}   # optional
          GH_API_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

The packager docs still use the old names `CF_API_KEY` / `GITHUB_OAUTH`; both are deprecated but still work.

### 10.4 Packaging changes in this repo

- [ ] Rewrite `.pkgmeta`:
  - `package-as: BP_EPGP`
  - Drop all `externals` (libs are vendored) and the CLM `move-folders`.
  - `ignore:` `scripts`, `docs`, `assets`, `ARCHITECTURE.md`, `CLAUDE.md`, `_annotations`, library docs/examples. Dot-files are excluded automatically.
  - `manual-changelog: { filename: CHANGELOG.md, markup-type: markdown }`
  - Optional: `embedded-libraries` with the CurseForge slugs of the vendored libs (`ace3`, `libdbicon-1-0`, …). This only adds metadata on CurseForge.
- [ ] TOC: `## Interface: 120105` (live 12.1.5 as of Oct 2026; 120107 is on the PTR). The packager reads this to set the CurseForge game version. Add `## X-Curse-Project-ID` and optionally `## X-Wago-ID`.
- [ ] `CHANGELOG.md`: replace the CLM history with our own, starting at `1.0.0`. Each release section must describe its changes.
- [ ] Do a dry run first (`release.sh -d`, or the Action on a test tag) and check the zip: a single top-level `BP_EPGP/` folder, no `scripts/`, no `docs/`, and all libs present.

### 10.5 Release flow

Tags map to CurseForge release types (packager rules):

| Tag | Release type | Who gets it |
|---|---|---|
| `v1.0.0-alpha1` (contains "alpha") / untagged build | Alpha | Website only, or opted-in app users |
| `v1.0.0-beta1` (contains "beta") | Beta | Users who opted in to beta, e.g. officers |
| `v1.0.0` | Release | Everyone |

1. Update `CHANGELOG.md` and the TOC `## Version` (or use `@project-version@`).
2. Create an annotated tag: `git tag -a v1.0.0 -m "BP EPGP 1.0.0"`, then `git push --tags`.
3. The Action uploads the build to CurseForge (plus Wago and GitHub Releases).
4. Wait for moderation. The first upload also triggers the project review.
5. Tell the guild to install "BP EPGP" from the CurseForge app (or WowUp/Wago).

For the guild rollout (Phase 11): publish `v1.0.0-beta1` first and have officers opt in to Beta. Then publish `v1.0.0` before rollout day.

### 10.6 Alternatives (if we don't want a public CurseForge page)

- **GitHub Releases + WowUp "Install from URL":** works with a public repo once the packager attaches the zip to a GitHub Release. A private repo would need a GitHub token *per guild member*, which isn't practical. The CurseForge app cannot install from GitHub.
- **Share the zip directly** (Discord): zero setup, but no auto-updates. That's a problem because the version check (§3.1) expects everyone to stay current.

### 10.7 Open questions

- Is "BP EPGP" free as a CurseForge project name, and do we want a longer, more descriptive name?
- Public GitHub repo (source/issue links on CurseForge, WowUp install) or private?
- Do we want Wago as well, or CurseForge only?
- Do we use Experimental status for the officer beta? **(unverified)** whether the new console supports it.
