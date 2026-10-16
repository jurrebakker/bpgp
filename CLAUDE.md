# BP EPGP: notes for Claude

EPGP loot addon for our guild, **WoW retail (Midnight, 12.x) only**. It's a fork of Core Loot Manager (CLM) v5.7.8, being stripped down to EPGP only. The plan and every decision live in `docs/`. Read `docs/release-plan-v1.md` (phases), `docs/sync-and-security.md` and `docs/features/*` before changing behaviour.

## Layout

- `BP_EPGP/` is the addon (was `ClassicLootManager/`). The internal Lua namespace stays `CLM` in v1 to keep diffs reviewable.
- `BP_EPGP/Libs/` holds all libraries, vendored (see `Libs/README.md`). Don't edit third-party libs. `LibEventSourcing` is the exception: it's part of the CLM source and is ours to change.
- `scripts/check_addon.py` checks that TOC/XML references resolve and that no packager markers remain.

## How the code works

- **Event sourcing.** State (standings, raids, settings) is never written directly. Every change is a ledger entry submitted with `CLM.MODULES.LedgerManager:Submit(entry)`, and state is rebuilt by replaying entries through mutators registered with `LedgerManager:RegisterEntryType`. Undo = `LedgerManager:Remove(entry)` (an ignore entry).
- **Sync.** Officers broadcast week hashes to GUILD; clients request and merge missing weeks (`Libs/LibEventSourcing/source/ListSync.lua`). Receivers check the *sender's* guild rank (`Modules/Common/ACL`).
- **Permissions.** They come from guild rank flags 11/12 (= "Is Officer" on Midnight, verified in-game). Every officer check must also be enforced on **receive**, not only in the UI.
- **Startup** is staged (`Core.lua`, `CORE:_Initialize` → stages 0.1 s apart).
- **GUI** is AceGUI + lib-st. The main window is `Modules/GUI/UnifiedGUI.lua` (tabs registered with `RegisterTab`).

## Rules

- **No packager-only code.** Never add `--@do-not-package@`, `--@debug@` or `@non-debug@` blocks: they make a git clone behave differently from a release (security issue C1). `scripts/check_addon.py` fails on them.
- **Retail only.** Use `C_*` APIs. Guard everything that can hit Midnight restrictions: chat lockdown (`C_ChatInfo.InChatMessagingLockdown()`), addon-message lockdown during encounters, and secret values (`issecretvalue`).
- **We start a fresh ledger in v1.0**, so entry types and fields may change until the 1.0 release. After 1.0, entry formats are frozen: an unknown or changed entry type breaks replay for everyone.
- **Coexist with CLM.** The guild still runs the real CLM, and both addons may be loaded together. Anything global must have a BP EPGP name: SavedVariables (`BPEPGP_*`), comm prefix `BPEP`, frame/popup/binding names (`BPEPGP_*`), AceGUI widget types, AceConfig app names, and the LibStub names of our forked libraries (`BPEPGP-EventSourcing/*`, `BPEPGP-EventDispatcher`). LibStub shares libraries between addons, so a forked lib under CLM's name would be silently swapped for CLM's copy.
- Comment density and naming follow the existing CLM code.

## Checking changes

- `python -I scripts/check_addon.py` must report 0 problems.
- luacheck (config `.luacheckrc`) runs in CI (`.github/workflows/lint.yml`). Locally it needs `luarocks install luacheck`.
- In-game: the addon folder is linked into `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\` with a directory junction, so `/reload` picks up changes. BugSack + !BugGrabber show Lua errors. The guild uses the real CLM (also installed), so BP EPGP must never share its folder name, SavedVariables or comm prefixes. Test risky changes in test mode (`docs/features/test-mode.md`) once it exists.
