# BPGP: architecture reference

> **Audience:** developers working on the addon.
> Covers structure, key design patterns, data flow and module responsibilities.
> BPGP is a fork of Core Loot Manager (CLM) v5.7.8, trimmed to EPGP only on retail (Midnight, 12.x). The internal Lua namespace is still `CLM`. Players see effort points as **Boomer Points (BP)**; the code and these docs still call them EP.
> Plans and decisions live in [`docs/`](docs/README.md).

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
│       ├── Raids/RaidManager/       # Raids, raid members, on-time bonus
│       ├── Points/PointManager/     # EP/GP award, set and decay
│       ├── Loot/LootManager/        # Loot awards (GP charges), Award window
│       ├── Auctioning/              # AuctionManager (officer), BiddingManager (raider), AuctionHistory, TradeHelper, Common
│       ├── Import/                  # Standings import (Name, EP, GP)
│       ├── Global/                  # Slash commands, chat handlers, global configs, guild change handler
│       ├── UI/                      # Shared Blizzard-template UI pieces (windows, tabs, lists, inputs, menus)
│       ├── MainWindow/              # Main window and its pages (Standings, Auction, Trade, History, Raids, Roster, Audit, Settings)
│       └── Alerts/                  # Alert toasts (points received, bid accepted/denied)
├── docs/                            # Release plan, decisions, feature docs, design spec (not packaged)
└── scripts/                         # check_addon.py (TOC/XML references, packager markers, Lua balance)
```

Phase 9 of the release plan replaces the AceGUI/lib-st windows with Blizzard templates, built from shared pieces in `Modules/UI/` ([docs/features/ui-redesign.md](docs/features/ui-redesign.md)).

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
- AceGUI widget types, and the LibStub names of the forked libraries: `BPGP-EventSourcing/*`, `BPGP-EventDispatcher`.

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
3. **Sync** happens over the `LedgerS3` (control) and `LedgerD3` (data) channels:
   - officers advertise week hashes on GUILD;
   - clients request the weeks they're missing;
   - a new entry is pushed live to the guild.

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

- **Undo:** `LedgerManager:Remove(entry)` writes an ignore entry; the target is skipped on replay.
- **Hardening** (Phase 8, [docs/sync-and-security.md](docs/sync-and-security.md)):
  - A failing or unknown entry is skipped and recorded, not fatal.
  - Checksums include each entry's content.
  - Only officers advertise or send data.
  - A live push must come from the entry's creator.
  - Entries dated in the future are dropped.
- **Entry formats are free to change until 1.0**, because v1.0 starts with a fresh ledger. After 1.0 they're frozen.

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

**Test mode** is fixed for a session; switching reloads the UI ([docs/features/test-mode.md](docs/features/test-mode.md)). In test mode:
- `DB:Ledger()` returns the test ledger;
- comms use the `BPGPT` prefix;
- chat is printed locally instead of sent.

---

## 7. Domain models

### Roster (`CLM.MODELS.Roster`)

There is **one roster**, created with "Set up BPGP" in the Standings tab.

```
Roster
├── uid
├── configuration        RosterConfiguration (starting EP/GP, min GP, rounding, on-time bonus,
│                        min standing, OS, auction length, anti-snipe, roll time, ...)
├── defaultSlotValues    GP per gear slot × 5 tiers (Base, Small, Medium, Large, Max)
├── itemValues           per-item overrides (written automatically when an auction starts)
├── fieldNames           tier button names
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

- `TrustInfoProvider` reads the guild roster and rank permissions.
- `ACL:CheckLevel(level, name)` gates actions, both when sending and when receiving.
- Officer checks are enforced on **receive** too, not only in the UI.

---

## 9. Communications (`CLM.MODULES.Comms`)

Comms wraps AceComm-3.0 and handles serialisation, compression and a security callback per channel. Addon messages are queued during Midnight's chat or encounter lockdown.

| Channel | Constant | Accepted from | Purpose |
|---------|----------|---------------|---------|
| `LedgerS3` | `LEDGER.SYNC` | guild members | Hash advertisements (officers only), week requests, peer state |
| `LedgerD3` | `LEDGER.DATA` | officers | Week data and live entries |
| `Auction5` | `AUCTION` | officer raid leader/assistant | Auction start/stop, anti-snipe, bid accepted/denied |
| `Bidding5` | `BIDDING` | anyone (validated by the auctioneer) | Bids |
| `Bids2<n>` | `BIDANNOUNCE` | officer raid leader/assistant | Bid list for raiders (open auction) |
| `Version2` | `GLOBAL` | anyone | Version announcements |

---

## 10. Auctioning

- **AuctionManager:** runs on the auctioneer's client (an officer who is raid leader/assistant). It owns the auction, broadcasts items, timers and bids, validates bids, and awards the winner (a GP ledger entry).
- **BiddingManager:** runs on every raider's client. It shows the bidding window and sends bids.
- **AuctionInfo / AuctionItem:** shared models of the auction in progress.
- **AuctionHistoryManager:** keeps finished auctions with their bids.
- **TradeHelper:** tracks awarded items per winner and puts them in the trade window.

Auctions are always **Open** with **named tier buttons**: each of the 5 tiers has its own GP, plus OS, Pass and Cancel. GP values come from the slot table or item overrides. Anti-snipe and a `/roll` phase are supported.

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

Shared pieces for every window are in `Modules/UI/` ([docs/features/ui-redesign.md](docs/features/ui-redesign.md)).

---

## 13. Midnight (12.x) specifics

- **Chat lockdown:** `UTILS.SendChatMessage` queues messages during `C_ChatInfo.InChatMessagingLockdown()`.
- **Addon-message lockdown:** `Comms:Send` queues messages during lockdown or a boss encounter.
- **Secret values:** `UTILS.IsSecret` guards raid-roster reads (updates wait and retry), loot and `/roll` parsing, target GUIDs and the chat filter.

---

## 14. Adding a feature: checklist

1. **Ledger entry** in the manager's `LedgerEntries.lua`, with a unique short class id. Formats are frozen after 1.0.
2. **Mutator** registered in the manager's `Initialize()`. Make it robust: a throwing mutator is skipped, not fatal, but the change is lost.
3. **Manager** initialized in `CORE:_InitializeFeatures()` at the right position.
4. **GUI** in `CLM.GUI`. It reads from managers and writes through them.
5. **ACL:** gate officer actions with `ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER, sender)`, also on receive.
6. **Globals** get BPGP names (see §3). Never add packager-only blocks (`@do-not-package@`, `@debug@`).
7. **Check:** run `python -I scripts/check_addon.py`, then test in-game, in **test mode** first.
