# Vendored libraries

All libraries are committed so the addon runs straight from a git clone; `.pkgmeta` needs no externals.

The third-party libraries below were copied on 2026-10-16 from the packaged **CLM v5.8.0** (CurseForge build, Interface 120105). That's the same set CLM's `.pkgmeta` pulls in, packaged by the BigWigs packager. To update one, replace its folder with a newer release from its source and update this table.

| Folder | Version | Source | License |
|---|---|---|---|
| `LibStub` | minor 2 | wowace.com/projects/libstub | public domain |
| `CallbackHandler-1.0` | minor 8 | wowace.com/projects/callbackhandler | BSD (Ace3) |
| `Ace3` | release r1403 (2026-08-12) | wowace.com/projects/ace3 | BSD, `Ace3/LICENSE.txt` |
| `lib-st` | 4.1.3 | github.com/ddumont/lib-st | GPL-3.0, `lib-st/COPYING` |
| `LibCandyBar-3.0` | minor 110 | wowace.com/projects/libcandybar-3-0 | to verify |
| `LibDBIcon-1.0` | packaged latest | wowace.com/projects/libdbicon-1-0 | to verify |
| `LibDeflate` | 1.0.2-release | github.com/SafeteeWoW/LibDeflate | zlib, `LibDeflate/LICENSE.txt` |
| `LibSerialize` | minor 4 (v1.1.3) | github.com/rossnichols/LibSerialize | MIT |
| `LibUIDropDownMenu` | 4.0, minor 90146 | wowace.com/projects/libuidropdownmenu | to verify |
| `LibSharedMedia-3.0` | 12.0.0 v4 | wowace.com/projects/libsharedmedia-3-0 | LGPL-2.1 |
| `AceGUI-3.0-SharedMediaWidgets` | data version 9004 | wowace.com/projects/ace-gui-3-0-shared-media-widgets | to verify |
| `LibLogger` | packaged latest | github.com/lantisnt/LibLogger | to verify |

Libraries that were already in the repository (part of the CLM source): `LibDataBroker-1.1`, `LibDeformat-3.0`, `LibEventDispatcher`, `LibEventSourcing`, `LibExpiringTimer`.

**Licensing to-do (release plan §8):** add the missing license files. Also check that lib-st's GPL-3.0 is acceptable for an Apache-2.0 addon, or replace lib-st when the UI is reworked.
