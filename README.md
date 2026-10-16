# BP EPGP

An EPGP loot addon for our guild, for World of Warcraft retail (Midnight).

BP EPGP is a fork of [Core Loot Manager](https://github.com/CoreLootManager/CoreLootManager) v5.7.8, stripped down to the EPGP workflow we actually use: one roster, raids with an on-time bonus, open auctions with named tier buttons, decay, and automatic officer sync.

> **Status:** work in progress. The code is still the unmodified CLM fork; see the [v1.0 release plan](docs/release-plan-v1.md) for what will change.

## Documentation

- [docs/](docs/README.md): release plans, planned features and ideas
- [ARCHITECTURE.md](ARCHITECTURE.md): how the inherited CLM codebase is structured

## Development

- Link the addon folder into `World of Warcraft\_retail_\Interface\AddOns\` (a directory junction works on Windows) and use `/reload` in-game.
- Install BugSack + !BugGrabber to see Lua errors.
- Lint with [luacheck](https://github.com/lunarmodules/luacheck) (config in `.luacheckrc`).
- `scripts/genxmls.py` regenerates the `_filelist.xml` load lists; `scripts/verify-dependencies.sh <file.toc>` checks every referenced file exists.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
Based on Core Loot Manager by Lantis and contributors; see [CREDITS.md](CREDITS.md).
