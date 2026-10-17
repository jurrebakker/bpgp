# BP EPGP: notes for Claude

EPGP loot addon for our guild, **WoW retail (Midnight, 12.x) only**. It's a fork of Core Loot Manager (CLM) v5.7.8, stripped down to EPGP only. The plan and every decision live in `docs/`. Read `docs/release-plan-v1.md` (phases), `docs/sync-and-security.md` and `docs/features/*` before changing behaviour.

**How we develop:** follow [DEVELOPMENT-GUIDELINES.md](DEVELOPMENT-GUIDELINES.md) (workflow, code layout, Lua style, ledger rules, security, Midnight rules, UI conventions, checks, in-game testing, releasing). This file is the short version; the guidelines are the full reference.

## Where we are

- **Status:** see the table at the top of `docs/release-plan-v1.md` §6. Phases 0-8 are done (Phase 8's in-game test is postponed to Phase 10). Phase 9 is the UI redesign: 9a (shared UI pieces), 9b (main window in `Modules/MainWindow/`) and 9c (Settings tab), 9d (Auctioning and Bidding windows), 9e (Award, Auction history, Trade list, Import, toasts, minimap) and 9f (unused UI libraries removed) are done.
- **Next:** **Phase 10**, the full test run (release plan §7): the user runs a real raid evening (bosses, auctions, awards, pass on loot) plus the postponed Phase 8 sync test with a second account. Then Phase 11, the release. The spec is in `docs/features/ui-redesign.md`, including decisions R1-R11 (they override the design where they differ). The visual reference is `docs/design/bp-epgp-redesign.dc.html`.
- Decisions are recorded in the docs with the user's call. Don't reopen them without asking. When something needs a decision, ask with concrete options and a recommendation.

## Git workflow

- GitHub: `jurrebakker/bpgp`. **`master` is protected**: changes go in through a pull request, with no force pushes and no branch deletion.
- Start every piece of work on a branch (`feat/phase-9b-main-window`, `docs/...`, `fix/...`), commit per step, push, then open a PR to `master`. Commit or push only when the user asks; they usually ask at the end of a phase.
- Commit messages: a short title (`Phase 9b: ...`), a body listing what changed, and the Co-Authored-By line.

## Layout

- `BP_EPGP/` is the addon (was `ClassicLootManager/`). The internal Lua namespace stays `CLM` in v1 to keep diffs reviewable.
- `BP_EPGP/Libs/` holds all libraries, vendored (see `Libs/README.md`). Don't edit third-party libs. `LibEventSourcing` is the exception: it's part of the CLM source and is ours to change (Phase 8 hardened it).
- `BP_EPGP/Modules/UI/` holds the shared Blizzard-template UI pieces for the redesign: `UI.lua` (windows, tabs, buttons, inputs, dropdown, menus, item buttons, progress bar) and `List.lua` (ScrollBox list with headers, sort and selection). `Demo.lua` is `/bpepgp uitest`. New windows are built from these, not from AceGUI.
- `scripts/check_addon.py` checks that TOC/XML references resolve, that no packager markers remain, and that Lua blocks are balanced.
- See `ARCHITECTURE.md` for the module map.

## How the code works

- **Event sourcing.** State (standings, raids, settings) is never written directly. Every change is a ledger entry submitted with `CLM.MODULES.LedgerManager:Submit(entry)`, and state is rebuilt by replaying entries through mutators registered with `LedgerManager:RegisterEntryType`. Undo = `LedgerManager:Remove(entry)` (an ignore entry).
- **Sync.** Officers broadcast week hashes to GUILD; clients request and merge missing weeks (`Libs/LibEventSourcing/source/ListSync.lua`). Receivers check the *sender's* guild rank (`Modules/Common/ACL`). A bad entry is skipped, not fatal. Checksums include each entry's content.
- **Permissions.** One officer level: guild ranks with "Is Officer" (rank flags 11/12, verified in-game). Every officer check must also be enforced on **receive**, not only in the UI.
- **One roster.** It's created with "Set up BP EPGP" in the Standings tab. Only guild members can be on it; raids never add players.
- **Auctions** are always Open, with named tier buttons (5 tiers, each with its own GP), OS, Pass and Cancel.
- **Test mode** (`Modules/Common/TestMode`) is fixed per session; switching reloads the UI. In test mode:
  - the ledger is `ledger_test`;
  - comms use the `BPEPT` prefix;
  - chat is printed locally;
  - a simulated raid group and bidders are available.
- **Startup** is staged (`Core.lua`, `CORE:_Initialize`, stages 0.1 s apart).
- **GUI:** every window is built on `Modules/UI` (Blizzard templates). The main window is `Modules/MainWindow/` (pages register with `MainWindow:RegisterPage`). AceGUI, lib-st and LibUIDropDownMenu are gone (9f); only AceConfigCmd remains, for the `/bpepgp` slash commands.

## Rules

- **No packager-only code.** Never add `--@do-not-package@`, `--@debug@` or `@non-debug@` blocks: they make a git clone behave differently from a release (security issue C1). `scripts/check_addon.py` fails on them.
- **Retail only.** Use `C_*` APIs. Guard everything that can hit Midnight restrictions:
  - chat lockdown: send chat through `UTILS.SendChatMessage`, which queues it;
  - addon-message lockdown: `Comms:Send` queues messages;
  - secret values: check with `UTILS.IsSecret`.
- **Blizzard templates can change between patches.** Create frames with fallbacks (`UI.CreateWithTemplates`), so a missing template degrades the look instead of breaking the load.
- **We start a fresh ledger in v1.0**, so entry types and fields may change until the 1.0 release. After 1.0, entry formats are frozen: an unknown or changed entry type breaks replay for everyone. `RosterConfiguration` fields are stored by position in raid entries, so add new ones at the end only.
- **Coexist with CLM.** The guild still runs the real CLM, and both addons may be loaded together. Anything global must have a BP EPGP name:
  - SavedVariables: `BPEPGP_*`;
  - comm prefix: `BPEP`;
  - frame and popup names: `BPEPGP_*`;
  - AceGUI widget types and AceConfig app names;
  - the LibStub names of our forked libraries: `BPEPGP-EventSourcing/*`, `BPEPGP-EventDispatcher`.

  LibStub shares libraries between addons, so a forked lib under CLM's name would be silently swapped for CLM's copy.
- Comment density and naming follow the existing code.

## Checking changes

- `python -I scripts/check_addon.py` must report 0 problems.
- luacheck (config `.luacheckrc`) runs in CI (`.github/workflows/lint.yml`). It isn't installed locally, so add any new WoW globals to `.luacheckrc` by hand.
- **In-game testing is done by the user.** After every change that needs testing, give a **numbered step-by-step checklist**: what to type or click, and what they should see. Ask them to report BugSack errors with the step number. Do risky things in **test mode** first (`/bpepgp test`, `/bpepgp testgroup 10`, *Simulate bids*). To check that live data is untouched, compare the minimap tooltip's "N events (0x…)" before and after.
- The addon folder is linked into `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\` with a directory junction, so `/reload` picks up changes. Adding or removing files that WoW loads by itself (like `Bindings.xml`) needs a full game restart.

## Tooling notes (this machine)

- Windows, Git Bash. Python 3.14 is available; there's no Lua interpreter and no luacheck.
- **Bash heredocs mangle backslashes** (Lua paths like `"Interface\\Icons"`). For multi-line edits, write a Python script to the scratchpad with the Write tool and run it with `python -I`, or use the Edit tool. Check every write of a Lua string that contains backslashes.
- Writing a file can fail with a transient `Errno 22`. Check what was applied, then re-run only the remaining steps.
