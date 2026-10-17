# BP EPGP

An EPGP loot addon for our guild, for World of Warcraft retail (Midnight).

BP EPGP is a fork of [Core Loot Manager](https://github.com/CoreLootManager/CoreLootManager) v5.7.8, stripped down to the EPGP workflow we actually use: one roster, raids with an on-time bonus, open auctions with named tier buttons, decay, and automatic officer sync.

> **Status:** working towards v1.0, not released yet. Every feature is built; the full raid test run (Phase 10) is next. See the [v1.0 release plan](docs/release-plan-v1.md#6-work-plan-phases).

## How EPGP works here

- **EP** (effort points) for raiding: officers award it, plus an on-time bonus when a raid starts.
- **GP** (gear points) for loot: you pay GP when you win an item.
- **PR** = EP ÷ GP. Higher PR wins. A regular decay keeps old points from piling up.
- Everything is stored in a ledger that syncs between guild members automatically. Only officers (guild ranks with "Is Officer") can change it.

## Install

1. Install **BP EPGP** with the CurseForge app (or another addon manager), or unzip it into `World of Warcraft\_retail_\Interface\AddOns\BP_EPGP`.
2. Log in on a character in the guild. The minimap icon (or `/bpepgp gui`) opens the main window.
3. Wait for the first sync: the footer of the main window shows "In-Sync" once your data is up to date.

BP EPGP can be installed next to Core Loot Manager; they don't share data or channels.

## For raiders

- **Standings** shows everyone's EP, GP and PR. Your own row is pinned on top, and your PR is shown in the header.
- **When an auction starts**, the bidding window opens with the item, the time left and one button per tier (each with its GP). Click a tier to bid; clicking another tier replaces your bid. You can also bid **OS**, **Pass** or **Cancel**. The status line tells you whether your bid was accepted.
- **Settings → Personal**: bidding window options (open automatically, close after bidding, skip unusable items, timer bar), sounds, minimap icon and **Pass on loot**.
- **Pass on loot** (on by default): in *our own* raids you automatically pass on boss loot, so the officer running the auctions can loot everything. It never passes outside our raids (pugs, other guilds, dungeons).

## For officers

1. **Set up once:** in the Standings tab, click **Set up BP EPGP**. Then add guild members in the **Roster** tab, or paste the current standings with **Import standings** (`Name, EP, GP` per line).
2. **Guild settings** (Settings → Guild, Gear values): starting EP/GP, minimum GP, rounding, on-time bonus, tier button names, auction length, anti-snipe, and the GP per gear slot and tier. These sync to everyone.
3. **Raid night:**
   - Raids tab: create a raid, then right-click it → **Start raid**. Raid members join it and get the on-time bonus.
   - Award EP from the Standings tab: pick *Act on* (Selected / Raid / Roster), enter EP, **Award EP**.
   - Loot: alt-click an item (the *Auction click*) to add it to the auctioning window, then **Start**. When the timer ends the winner is selected for you (highest tier, then PR, then roll): press **Enter** to award. Right-click a player in Standings → **Award item** to award without an auction.
   - End the raid in the Raids tab.
4. **Weekly:** decay from the Standings tab (*Decay %*).
5. **Mistakes:** remove the entry in History or Audit (right-click). This writes an undo entry that syncs to everyone.

Practise first in **test mode** (`/bpepgp test`): a separate ledger and sync channel, with a simulated raid group and bidders. Leaving test mode reloads the UI and live data is never touched.

### Slash commands

| Command | What it does |
|---|---|
| `/bpepgp gui` | Main window |
| `/bpepgp config` | Settings tab |
| `/bpepgp bid` | Bidding window |
| `/bpepgp auction` | Auctioning window (officers) |
| `/bpepgp award` | Award window (officers) |
| `/bpepgp auction_history` / `trade` | Auction history / Trade list (officers) |
| `/bpepgp import` | Import standings (officers) |
| `/bpepgp minimap` | Show or hide the minimap icon |
| `/bpepgp testbar` | Show the timer bar so you can move it |
| `/bpepgp test` | Enter or leave test mode |

## Documentation

- [docs/](docs/README.md): release plan, decisions, planned features and ideas
- [ARCHITECTURE.md](ARCHITECTURE.md): how the addon is structured
- [DEVELOPMENT-GUIDELINES.md](DEVELOPMENT-GUIDELINES.md): how we develop and maintain it
- [CLAUDE.md](CLAUDE.md): working notes for Claude Code

## Development

- Work on a branch and open a pull request to `master`; `master` is protected.
- Link the addon folder into `World of Warcraft\_retail_\Interface\AddOns\` (a directory junction works on Windows) and use `/reload` in-game.
- Install BugSack + !BugGrabber to see Lua errors.
- Test in **test mode** (`/bpepgp test`, `/bpepgp testgroup 10`, *Simulate bids*). See [docs/features/test-mode.md](docs/features/test-mode.md).
- `python -I scripts/check_addon.py` checks file references, packager-only markers and Lua block balance. luacheck runs in CI (config in `.luacheckrc`).
- All libraries are vendored in `BP_EPGP/Libs` (see its README), so a git clone runs as-is.

## License

Apache License 2.0, see [LICENSE](LICENSE). Based on Core Loot Manager, heavily modified; all files were changed for BP EPGP.

Copyright 2021-2023 Lantis and the Classic Loot Manager contributors (original Core Loot Manager).
Modifications copyright 2026 Jurre Bakker.
Third-party libraries in `BP_EPGP/Libs` are subject to their own licenses.
