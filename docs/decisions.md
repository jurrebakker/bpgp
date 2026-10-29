# Decisions

Decisions that still bind: a change that breaks one needs the user's call first. Each keeps the ID it was made under, so code comments like "R28" resolve here. Executed one-offs and superseded decisions are not listed; git has them.

## Scope

| ID | Date | Decision | Why |
|---|---|---|---|
| V1 | 2026-10-16 | Retail (Midnight, 12.x) only. No Classic branches or expansion checks. | The guild only plays retail. |
| V2 | 2026-10-16 | EPGP only: no DKP, SK, bench/standby, alt-main linking, profile locking, time travel, exporters, cross-guild sync. | Only what the guild uses; less to keep working on Midnight. |
| V3 | 2026-10-16 | One roster, guild members only. Raids never add players; the roster is created with *Set up BPGP* (D7) and filled from the guild or the standings import. | One guild, one standings list. |
| V4 | 2026-10-16 | The only automatic EP is the on-time bonus at raid start. Decay is a manual action (EP, GP or both). | Matches how the guild runs EPGP. |
| V5 | 2026-10-16 | English only. `enUS.lua` returns the key, so the key is the text. | One guild, one language. |
| V6 | 2026-10-17 | The addon is **BPGP**, and players see effort points as **Boomer Points (BP)**; PR = BP/GP. Code, ledger fields and internal docs keep `ep`. See [GLOSSARY.md](../GLOSSARY.md). | Guild branding without renaming the ledger. |

## Ledger and sync

| ID | Date | Decision | Why |
|---|---|---|---|
| V7 | 2026-10-16 | v1.0 started a fresh ledger (no CLM data); standings were imported once. **Since v1.0.0 (2026-10-18) entry formats are frozen:** add new entry types, never change or remove old ones. `RosterConfiguration` fields only get appended. | An unknown or changed entry breaks replay for everyone who has it. |
| S3 | 2026-10-16 | Entries are validated; a bad or unknown entry is skipped and shown in the Audit tab, never fatal. | One bad entry used to freeze sync for the whole guild. |
| S4 | 2026-10-16 | Sync checksums include each entry's content. | Otherwise two clients with different data both show "synced". |
| S5 | 2026-10-16 | Sync-control messages (hash adverts, requests) only from guild members, and adverts only from officers. | Stops a raider or pug from stalling sync. |
| S6 | 2026-10-16 | Entries more than 10 minutes in the future are rejected; stale live entries are flagged. | Limits backdating and future-dated entries that never sync. |
| S7 | 2026-10-16 | A live push needs `creator == sender`; relayed week data is only accepted from officers. | Makes forging another officer's entries harder, without crypto. |

## Permissions

| ID | Date | Decision | Why |
|---|---|---|---|
| S1 | 2026-10-16 | One officer level: officers can do everything, raiders are read-only. | Midnight's single "Is Officer" permission already merges CLM's two levels. |
| S2 | 2026-10-16 | An officer is any guild rank with "Is Officer" (rank flags 11/12), officer alts included. | Zero setup; follows Guild Control. |
| C1 | 2026-10-16 | No packager-only code (`@do-not-package@`, `@debug@`, `@non-debug@`); `scripts/check_addon.py` fails on it. | Those blocks disabled all security in a git clone. |
| S9 | 2026-10-16 | Auctioneer = officer **and** raid leader/assistant. Widened by R19. The officer rank is always checked on receive. | Stops non-officers popping fake auctions. |
| R19 | 2026-10-18 | The officer with *Need on everything* on may also auction without assist. Raiders accept auction messages from any officer in their raid group. | The officer who collects the loot runs the auction. |
| D3 | 2026-10-16 | Everyone sees Guild settings and Gear values; only officers can edit them. | Raiders can check the rules. |
| R11 | 2026-10-16 | Officer-only UI is hidden for raiders (own row pinned, *Your PR* big in the header). Read-only settings are the exception: shown, disabled. | A raider's window shows only what they can use. |
| T1 | 2026-10-16 | Everyone can switch test mode on. | Raiders need it to bid in a test auction; it can't touch live data. |

## Auctions and loot

| ID | Date | Decision | Why |
|---|---|---|---|
| V8 | 2026-10-16 | Auctions are always Open. Anti-snipe, auction history, trade helper and a `/roll` phase stay. | The guild bids openly. |
| R16 | 2026-10-18 | Three fixed tiers: **BiS** (purple), **Major** (blue), **Minor** (green). Names are hardcoded and reuse the GP keys Medium, Small and Base. Large and Max stay valid ledger keys but are never offered or accepted. | Fewer buttons once OS and Transmog were built in; the guild's GP values keep their meaning. |
| R14 | 2026-10-18 | A Transmog bid below OS (tiers → OS → Transmog). It costs 0 GP, and PR doesn't count among Transmog bids: the highest roll wins. Guild setting *Transmog* (`useTransmog`, default on). | Lets people take transmog without spending GP. |
| R29 | 2026-10-22 | An OS bid costs 0 GP. OS still ranks above Transmog and is ranked by PR. Auction comm version 6. | OS gear shouldn't cost main-spec priority. |
| R10 | 2026-10-16 | When the timer ends the winner is preselected (tier → OS → Transmog, then PR, then roll) and the value filled; Enter awards; the next queued item loads after Award. | Fast awarding during a raid. |
| R25 | 2026-10-18 | The preselected winner is highlighted in the bid list. | The selection always matches who Award gives the item to. |
| R30 | 2026-10-29 | The Value box is filled whenever the winner changes and cleared after every award. The award confirmation shows the winner's bid next to the GP. No hard block on a manual price. | A Transmog winner was charged the previous item's GP. |
| R20 | 2026-10-18 | Only tradeable items fill the auction list (not bound, or bound with a trade timer). | Untradeable loot can't be given away. |
| R26 | 2026-10-18 | The auction list also fills from the Loot Rolls history (`C_LootHistory`); the chat-line path stays as a backup. Each drop is added once. *Add from loot rolls* adds the last boss's won items. | Loot was missing from the list (2 of 7 drops). |
| R28 | 2026-10-19 | No settings for filling the list: only Epic or better Weapon, Armor or Miscellaneous items (`CONSTANTS.AUCTION_ITEM_CLASSES`). Pass on loot and Need on everything follow the same classes. Adding by hand has no filter. | Keeps sparks, reagents and consumables out, and lets raiders roll on them. |
| V9 | 2026-10-17 | *Pass on loot* (on by default) only works in our own raids: a BPGP raid in progress, started less than 12 hours ago, in a raid instance, led by one of our officers. If any of that can't be verified, nothing is passed. CLM's exclusions stay. | One officer loots everything, but pugging someone else's raid never passes. |
| R15 | 2026-10-18 | *Need on everything* (officers only, off by default) rolls Need, else Greed, else Transmog on boss loot, with Pass on loot's safety rules; it wins over Pass on loot. | The officer who collects the loot gets it. |
| R24 | 2026-10-18 | Turning *Need on everything* on when you aren't raid leader or assistant asks for confirmation first. | Avoids collecting loot in someone else's raid by accident. |
| R22 | 2026-10-18 | Items the auctioneer awards to themselves are not put on the trade list. | Nothing to trade. |
| R27 | 2026-10-18 | Awarding an item to another player whispers them to open a trade. Ending a raid with items still on the trade list warns first. | Awarded items were left untraded. |
| R23 | 2026-10-18 | Ending a raid with *Need on everything* on asks to decay 10% BP and GP for the whole roster (Yes / Not now). | The weekly decay happens right after raid. |

## UI

| ID | Date | Decision | Why |
|---|---|---|---|
| D2 | 2026-10-16 | No Options → AddOns pages. All settings are in the main window's Settings tab; new settings go there. | One place for settings. |
| R3 | 2026-10-16 | One Settings tab with sections: Personal, Guild, Gear values, Advanced. | Replaces separate settings tabs. |
| D7 | 2026-10-16 | Officers create the roster with a *Set up BPGP* button when none exists. | One roster, no roster management UI. |
| D9 | 2026-10-16 | The main window is resizable (minimum 720×480) and remembers its size per character. | |
| R1 | 2026-10-16 | Two award rows: BP field + Award, GP field + Award. | As officers are used to. |
| R2 | 2026-10-16 | Standings always shows the whole roster: no search box or Raid/All filter. | |
| R4 | 2026-10-16 | Audit is its own tab, not a History filter. | |
| R5 | 2026-10-16 | Awards take a free-text note (shown in History); no reason presets. | |
| R6 | 2026-10-16 | Every write asks for confirmation (`UI.Confirm`), no undo-link instead. | A wrong award syncs to the whole guild. |
| R7 | 2026-10-16 | Standings → right-click → *Award item* opens the Award window prefilled. | |
| R9 | 2026-10-16 | The Bidding window has one layout with the countdown in its header. The separate timer bar is optional, off by default. | |
| R12 | 2026-10-17 | Auctioning is the main window's Auction tab (officers only, after Standings); alt-click and `/bpgp auction` open it. | No separate Auctioning window. |
| R13 | 2026-10-17 | A Bid button in the main window header reopens the Bidding window while an auction runs. | Raiders could only reopen it with `/bpgp bid`. |
| R17 | 2026-10-18 | The trade list is the main window's Trade tab (officers only, after Auction); `/bpgp trade` opens it. | |
| R18 | 2026-10-18 | The Bidding window has an item icon strip on the left: the shown item highlighted, bid green, passed grey, denied red. | Replaces "Item 1 of 3" text. |
| R21 | 2026-10-18 | Raid reminders in a small draggable window: *Start raid?* for the creator of a not-yet-started raid on entering a raid instance; *End raid?* for the officer who started it, on leaving the raid group. | Raids were left unstarted or unended. |
| D6 | 2026-10-16 | Any click on the minimap icon opens the main window; there is no right-click menu. | Other windows open with `/bpgp` commands. |

## Test mode

| ID | Date | Decision | Why |
|---|---|---|---|
| V10 | 2026-10-16 | Test mode is fixed per session (switching reloads the UI) and fully isolated: its own ledger (`ledger_test`), comm prefix `BPGPT`, chat printed locally. Test data can never be merged into live. | Testing must never touch the guild's data. |
| T2 | 2026-10-16 | Resetting test data asks each time: start empty or from a copy of live data. | |
| T3 | 2026-10-16 | Chat output in test mode is local only; raid warnings are never sent. | |
| T4 | 2026-10-16 | Simulated players use real guild members' names and classes, falling back to generated names outside a guild. | |
| T5 | 2026-10-16 | Test data is kept across `/reload` and logout until *Reset test data*. | |

## Release

| ID | Date | Decision | Why |
|---|---|---|---|
| V11 | 2026-10-17 | Everything global has a BPGP name: SavedVariables `BPGP_*`, comm prefix `BPGP`/`BPGPT`, frames and popups `BPGP_*`, forked LibStub names `BPGP-*`. | The guild still runs the real CLM next to BPGP. |
| V12 | 2026-10-16 | All libraries are vendored, so a git clone runs as-is. | No packager-only differences (C1). |
| V13 | 2026-10-20 | A `v*` tag publishes a GitHub Release and uploads the same build to CurseForge (separate job, so a failed upload never blocks the GitHub Release). | |
| V14 | 2026-10-29 | Raiders install and update from CurseForge, or download the zip from the GitHub Release. BPGP Updater still works for the few who use it, so the zip keeps `BPGP/BPGP.toc` with a filled-in `## Version:`. Replaces the 2026-10-18 decision that the updater was *the* install route. | Most raiders already use CurseForge. |
