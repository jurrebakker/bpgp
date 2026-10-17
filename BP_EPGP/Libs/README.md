# Vendored libraries

All libraries are committed so the addon runs straight from a git clone; `.pkgmeta` needs no externals.

The third-party libraries below were copied on 2026-10-16 from the packaged **CLM v5.8.0** (CurseForge build, Interface 120105). That's the same set CLM's `.pkgmeta` pulls in, packaged by the BigWigs packager. To update one, replace its folder with a newer release from its source and update this table.

| Folder | Version | Source | License |
|---|---|---|---|
| `LibStub` | minor 2 | wowace.com/projects/libstub | public domain |
| `CallbackHandler-1.0` | minor 8 | wowace.com/projects/callbackhandler | BSD (Ace3) |
| `Ace3` | release r1403 (2026-08-12), only AceAddon, AceEvent, AceTimer, AceBucket, AceConsole, AceComm and AceConfig (Registry + Cmd, for the slash commands) | wowace.com/projects/ace3 | BSD, `Ace3/LICENSE.txt` |
| `LibCandyBar-3.0` | minor 110 | wowace.com/projects/libcandybar-3-0 | to verify |
| `LibDBIcon-1.0` | packaged latest | wowace.com/projects/libdbicon-1-0 | to verify |
| `LibDeflate` | 1.0.2-release | github.com/SafeteeWoW/LibDeflate | zlib, `LibDeflate/LICENSE.txt` |
| `LibSerialize` | minor 4 (v1.1.3) | github.com/rossnichols/LibSerialize | MIT |
| `LibLogger` | packaged latest | github.com/lantisnt/LibLogger | to verify |

Libraries that were already in the repository (part of the CLM source): `LibDataBroker-1.1`, `LibDeformat-3.0`, `LibEventDispatcher`, `LibEventSourcing`.

**Removed in Phase 9f (2026-10-17):** AceGUI-3.0, AceConfigDialog-3.0, lib-st, LibUIDropDownMenu, LibSharedMedia-3.0, AceGUI-3.0-SharedMediaWidgets, AceHook-3.0, LibExpiringTimer and the unused Ace3 parts (AceDB, AceDBOptions, AceLocale, AceSerializer, AceTab). Every window is built from Blizzard templates (`Modules/UI`), so nothing needs them.

**Licensing to-do (release plan §8):** add the missing license files. (The lib-st GPL-3.0 question is gone: lib-st was removed in 9f.)
