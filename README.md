# BP EPGP

An EPGP loot addon for our guild, for World of Warcraft retail (Midnight).

BP EPGP is a fork of [Core Loot Manager](https://github.com/CoreLootManager/CoreLootManager) v5.7.8, stripped down to the EPGP workflow we actually use: one roster, raids with an on-time bonus, open auctions with named tier buttons, decay, and automatic officer sync.

> **Status:** work in progress towards v1.0, not released yet. EPGP-only, test mode, standings import and sync hardening are done; the UI redesign is in progress. See the status in the [v1.0 release plan](docs/release-plan-v1.md#6-work-plan-phases).

## Documentation

- [docs/](docs/README.md): release plans, planned features and ideas
- [ARCHITECTURE.md](ARCHITECTURE.md): how the addon is structured
- [CLAUDE.md](CLAUDE.md): working notes and rules for development (also read by Claude Code)

## Development

- Work on a branch and open a pull request to `master`; `master` is protected (no direct force pushes).

- Link the addon folder into `World of Warcraft\_retail_\Interface\AddOns\` (a directory junction works on Windows) and use `/reload` in-game.
- Install BugSack + !BugGrabber to see Lua errors.
- Test in **test mode** (`/bpepgp test`): a separate ledger and sync channel, local-only chat, and a simulated raid group and bidders (`/bpepgp testgroup 10`, *Simulate bids*). See [docs/features/test-mode.md](docs/features/test-mode.md).
- Lint with [luacheck](https://github.com/lunarmodules/luacheck) (config in `.luacheckrc`).
- `python -I scripts/check_addon.py` checks that every file referenced from the TOC/XML exists, that no packager-only code remains, and that Lua blocks are balanced. `scripts/genxmls.py` regenerates the `_filelist.xml` load lists.
- All libraries are vendored in `Libs/` (see its README), so a git clone runs as-is.

## License

Apache License 2.0, see [LICENSE](LICENSE). Based on Core Loot Manager, heavily modified; all files were changed for BP EPGP.

Copyright 2021-2023 Lantis and the Classic Loot Manager contributors (original Core Loot Manager).
Modifications copyright 2026 Jurre Bakker.
Third-party libraries in `BP_EPGP/Libs` are subject to their own licenses.
