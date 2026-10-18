# BPGP

A loot addon for our guild, for World of Warcraft retail (Midnight).

BPGP is a fork of [Core Loot Manager](https://github.com/CoreLootManager/CoreLootManager) v5.7.8, stripped down to the BPGP workflow we actually use: one roster, raids with an on-time bonus, open auctions with named tier buttons, decay, and automatic officer sync.

> **Status:** working towards v1.0, not released yet. Every feature is built; the full raid test run (Phase 10) is next. See the [v1.0 release plan](docs/release-plan-v1.md#6-work-plan-phases).

## How BPGP works here

BPGP is EPGP with our own name for the points: Boomer Points (BP) instead of effort points (EP).

- **BP** (Boomer Points) for raiding: officers award it, plus an on-time bonus when a raid starts.
- **GP** (gear points) for loot: you pay GP when you win an item.
- **PR** = BP ÷ GP. Higher PR wins. A regular decay keeps old points from piling up.
- Everything is stored in a ledger that syncs between guild members automatically. Only officers (guild ranks with "Is Officer") can change it.

## Install

1. Download **BPGPUpdater.exe** from the newest [BPGP Updater release](https://github.com/jurrebakker/bpgp/releases?q=updater-v&expanded=true) and run it. It finds your WoW folder (or click **Browse**), and **Install** puts BPGP in `_retail_\Interface\AddOns\BPGP`. Run it again, or tick **Start with Windows**, to get updates; it also updates itself.
   - Windows may show "Windows protected your PC" the first time, because the exe isn't signed: click **More info → Run anyway**.
   - Without the updater: unzip `BPGP-<version>.zip` from the [latest addon release](https://github.com/jurrebakker/bpgp/releases/latest) into `World of Warcraft\_retail_\Interface\AddOns\`.
2. Log in on a character in the guild. The minimap icon (or `/bpgp gui`) opens the main window.
3. Wait for the first sync: the footer of the main window shows "In-Sync" once your data is up to date.

BPGP can be installed next to Core Loot Manager; they don't share data or channels.

## For raiders

- **Standings** shows everyone's BP, GP and PR. Your own row is pinned on top, and your PR is shown in the header.
- **When an auction starts**, the bidding window opens with the item, the time left and one button per tier (each with its GP). Click a tier to bid; clicking another tier replaces your bid. You can also bid **OS**, **Transmog** (free, highest roll wins), **Pass** or **Cancel**. The status line tells you whether your bid was accepted. Closed it? Open the main window (minimap icon) and click **Bid**, or type `/bpgp bid`.
- **Settings → Personal**: bidding window options (open automatically, close after bidding, skip unusable items, timer bar), sounds, minimap icon and **Pass on loot**.
- **Pass on loot** (on by default): in *our own* raids you automatically pass on boss loot, so the officer running the auctions can loot everything. It never passes outside our raids (pugs, other guilds, dungeons).

## For officers

1. **Set up once:** in the Standings tab, click **Set up BPGP**. Then add guild members in the **Roster** tab, or paste the current standings with **Import standings** (`Name, BP, GP` per line).
2. **Guild settings** (Settings → Guild, Gear values): starting BP/GP, minimum GP, rounding, on-time bonus, tier button names, auction length, anti-snipe, and the GP per gear slot and tier. These sync to everyone.
3. **Raid night:**
   - Raids tab: create a raid, then right-click it → **Start raid**. Raid members join it and get the on-time bonus.
   - Award BP from the Standings tab: pick *Act on* (Selected / Raid / Roster), enter BP, **Award BP**.
   - Loot: open the **Auction** tab (or alt-click an item, the *Auction click*, which adds it and opens the tab), then **Start**. When the timer ends the winner is selected for you (highest tier, then PR, then roll): press **Enter** to award. Right-click a player in Standings → **Award item** to award without an auction.
   - End the raid in the Raids tab.
4. **Weekly:** decay from the Standings tab (*Decay %*).
5. **Mistakes:** remove the entry in History or Audit (right-click). This writes an undo entry that syncs to everyone.

Practise first in **test mode** (`/bpgp test`): a separate ledger and sync channel, with a simulated raid group and bidders. Leaving test mode reloads the UI and live data is never touched.

### Slash commands

| Command | What it does |
|---|---|
| `/bpgp gui` | Main window |
| `/bpgp config` | Settings tab |
| `/bpgp bid` | Bidding window |
| `/bpgp auction` | Auction tab (officers) |
| `/bpgp award` | Award window (officers) |
| `/bpgp auction_history` / `trade` | Auction history / Trade list (officers) |
| `/bpgp import` | Import standings (officers) |
| `/bpgp minimap` | Show or hide the minimap icon |
| `/bpgp testbar` | Show the timer bar so you can move it |
| `/bpgp test` | Enter or leave test mode |

## Documentation

- [docs/](docs/README.md): release plan, decisions, planned features and ideas
- [ARCHITECTURE.md](ARCHITECTURE.md): how the addon is structured
- [DEVELOPMENT-GUIDELINES.md](DEVELOPMENT-GUIDELINES.md): how we develop and maintain it
- [CLAUDE.md](CLAUDE.md): working notes for Claude Code

## Development

- Work on a branch and open a pull request to `master`; `master` is protected.
- Link the addon folder into `World of Warcraft\_retail_\Interface\AddOns\` (a directory junction works on Windows) and use `/reload` in-game.
- Install BugSack + !BugGrabber to see Lua errors.
- Test in **test mode** (`/bpgp test`, `/bpgp testgroup 10`, *Simulate bids*). See [docs/features/test-mode.md](docs/features/test-mode.md).
- `python -I scripts/check_addon.py` checks file references, packager-only markers and Lua block balance. luacheck runs in CI (config in `.luacheckrc`).
- All libraries are vendored in `BPGP/Libs` (see its README), so a git clone runs as-is.
- `updater/` is the Windows updater (C#, WPF on .NET Framework 4.8), styled like the addon, with tabs BPGP, Settings and About. Build it with `dotnet publish updater/BPGPUpdater.csproj -c Release -o updater/out` (.NET 8 SDK). It leaves a linked (junction) `AddOns\BPGP` alone.
- Releasing the addon: push a tag like `v1.0.0`. `.github/workflows/release.yml` builds the addon zip and publishes it as a GitHub Release.
- Releasing the updater (separately): push a tag like `updater-v1.0.0`. `.github/workflows/updater-release.yml` builds `BPGPUpdater.exe` and publishes its own release, which is never marked "Latest".

## License

Apache License 2.0, see [LICENSE](LICENSE). Based on Core Loot Manager, heavily modified; all files were changed for BPGP.

Copyright 2021-2023 Lantis and the Classic Loot Manager contributors (original Core Loot Manager).
Modifications copyright 2026 Jurre Bakker.
Third-party libraries in `BPGP/Libs` are subject to their own licenses.
