# BPGP: development guidelines

How we build and maintain BPGP. These are the conventions every change follows, for people and for Claude.

- **What the addon is and how it works:** [ARCHITECTURE.md](ARCHITECTURE.md).
- **What we're building and why:** [docs/](docs/README.md) (release plan, decisions, feature specs).
- **This file:** *how* we write, check, test and ship the code.

When a rule here conflicts with a decision in `docs/`, the decision wins. Fix this file in the same PR.

---

## 1. Workflow

### 1.1 Branches and pull requests

- `master` is protected: no direct pushes, no force pushes, no branch deletion. Everything goes in through a pull request.
- One branch per piece of work, named by kind:

  | Prefix | For | Example |
  |---|---|---|
  | `feat/` | a phase or feature | `feat/phase-9b-main-window` |
  | `fix/` | a bug fix | `fix/award-window-nil-roster` |
  | `docs/` | documentation only | `docs/development-guidelines` |

- Commit per step, not per file. A reviewer should be able to read the history step by step.
- Commit and push when the user asks (usually at the end of a phase).
- Commit messages: a short title (`Phase 9b: main window on Modules/UI`), an empty line, then a body listing what changed. End with the `Co-Authored-By` line when Claude wrote the change.
- The PR description says what changed, what was checked, and links the in-game test checklist.

### 1.2 From idea to code

1. **Idea** → a file in `docs/ideas/` (template in `docs/README.md`).
2. **Decision** → when something has more than one reasonable answer, ask the user with concrete options and a recommendation. Record the answer in the feature doc (for example R1-R11 in `docs/features/ui-redesign.md`). Don't reopen recorded decisions without asking.
3. **Plan** → the phase in `docs/release-plan-v1.md` §6, with a "done when".
4. **Build** → on a branch, following this file.
5. **Check** → static checks (§9) plus an in-game checklist (§10).
6. **Record** → tick the phase, update the status table, the feature doc's status and `CHANGELOG.md`.

### 1.3 Definition of done

A change is done when:

- [ ] `python -I scripts/check_addon.py` reports 0 problems;
- [ ] new WoW globals are added to `.luacheckrc`, and CI's luacheck passes;
- [ ] `/reload` gives no Lua errors (BugSack empty), in normal mode and in test mode;
- [ ] the in-game checklist for the change passes (the user runs it);
- [ ] docs are updated: plan status, feature doc, `ARCHITECTURE.md` if the structure changed, `CHANGELOG.md`.

---

## 2. Code layout

```
BPGP/
├── Core.lua            namespace + staged initialization
├── Utils.lua           CLM.UTILS: shared helpers and Midnight-safe wrappers
├── Locale/enUS.lua     CLM.L (missing keys return the key itself)
├── Libs/               vendored libraries (don't edit, see §8)
└── Modules/<Area>/     one folder per area, loaded through _filelist.xml
```

- **Managers** live in `CLM.MODULES.<Name>`. They own state and business logic.
- **Models** live in `CLM.MODELS`; ledger entry types in `CLM.MODELS.LEDGER`.
- **Windows** live in `CLM.GUI.<Name>`. They read from managers and change state only through manager methods.
- **Shared UI pieces** live in `CLM.UI` (`Modules/UI/`). New windows are built from them, not from AceGUI.
- **Every new file** must be listed in its folder's `_filelist.xml`, in load order. A file can only use modules defined by files loaded before it, except inside functions that run after initialization.
- **Initialization:** modules get an `Initialize()` that `Core.lua` calls in a stage (database → core → backend → minimap → features → options → GUI). `CLM.GUI` modules are initialized in no fixed order, so a GUI module must not depend on another GUI module during `Initialize()`.

---

## 3. Lua style

Match the code around you. The common shape of a file:

```lua
-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --
```

- **Locals first.** Everything is `local` unless it must be global (§5). Cache modules you use often at the top.
- **Indentation:** 4 spaces, no tabs.
- **Naming:**
  - modules and methods: `PascalCase` (`RosterManager:AddProfilesToRoster`);
  - local functions: `PascalCase` for "public inside the file", `camelCase` is fine for small helpers;
  - locals and fields: `camelCase`;
  - constants: `UPPER_SNAKE_CASE` in `CONSTANTS` or as file locals.
- **Methods** use `:` (`function Manager:Do()`); plain helpers take `self` explicitly when they need it.
- **Annotations:** add `---@class`, `---@param` and `---@return` on public functions and module tables. They help the language server and reviewers.
- **Comments** explain *why*, not *what*. Keep the density of the surrounding code. Block comments use `--[[ ... ]]--`.
- **No dead code.** Don't leave commented-out blocks behind; git has the history.
- **Errors:** user-facing problems go through `LOG:Message` / `LOG:Warning`, never `error()`. `error()` is only for programming mistakes caught during development.
- **Strings** shown to the user always go through `CLM.L["..."]` (§6.5).
- **Backslashes:** texture paths are written with doubled backslashes in Lua (`"Interface\\Icons\\..."`). Check every write that contains them; shell heredocs mangle them.

---

## 4. State, ledger and sync

This is where mistakes are expensive: a bad ledger entry syncs to the whole guild.

- **Never write state directly.** Every change is a ledger entry: `CLM.MODULES.LedgerManager:Submit(entry)`. State is rebuilt by replaying entries through mutators registered with `LedgerManager:RegisterEntryType`.
- **Undo** is `LedgerManager:Remove(entry)` (an ignore entry), never a deletion.
- **Mutators are pure state updates.** No chat, no UI, no comms, no `C_Timer` inside a mutator. They run again on every replay.
- **Mutators must be safe.** Check that the referenced roster/profile exists and that values are in range; return early otherwise. A throwing mutator is skipped and recorded, but its change is lost for everyone.
- **Entry formats:**
  - until the 1.0 release we may change entry types and fields (fresh ledger);
  - **after 1.0 they're frozen.** An unknown or changed entry type breaks replay for everyone who has it. Add new entry types instead of changing old ones;
  - `RosterConfiguration` fields are stored by position: add new ones at the end only.
- **Class ids** for entries are short and unique (`"DM"`, `"R6"`). Check `LedgerEntries.lua` files before picking one.
- **Refresh the UI from ledger updates**, not from your own submit: use `LedgerManager:RegisterOnUpdate` and check `lag == 0 and uncommitted == 0` before a full refresh.

---

## 5. Security, permissions and coexisting with CLM

### 5.1 Permissions

- There is one officer level: guild ranks with "Is Officer". Check it with `CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER[, name])`.
- **Every officer check is enforced on receive**, not only in the UI. Hiding a button is a convenience; the receiving side is the security.
- Officer-only UI is **hidden** for raiders, not shown disabled (R11). Read-only settings are the exception: shown, but disabled.
- Comm handlers check the *sender* (guild rank, raid role, creator == sender). See `docs/sync-and-security.md`.

### 5.2 No packager-only code

Never add `--@do-not-package@`, `--@debug@` or `@non-debug@` blocks. They make a git clone behave differently from a release (security issue C1). `scripts/check_addon.py` fails on them. Debug tools go behind test mode or a slash command instead.

### 5.3 Global names

The guild still runs the real CLM, and both addons may be loaded together. Anything global gets a BPGP name:

| Kind | Name |
|---|---|
| SavedVariables | `BPGP_*` |
| Comm prefix | `BPGP` (`BPGPT` in test mode); prefix + channel ≤ 16 characters |
| Frames, popups, tooltips | `BPGP_*` (global frame names are needed for Escape-to-close and tabs) |
| AceGUI widget types, AceConfig app names | `BPGP...` / `bpgp_...` |
| LibStub names of our forked libs | `BPGP-EventSourcing/*`, `BPGP-EventDispatcher` |
| Global functions | only when WoW needs them (`BPGP_ToggleMainWindow` for the addon compartment) |

LibStub shares libraries between addons, so a forked lib under CLM's name would silently be swapped for CLM's copy.

---

## 6. WoW retail (Midnight) rules

### 6.1 APIs

- **Retail only.** Use the `C_*` namespaces (`C_Item`, `C_ChatInfo`, `C_GuildInfo`, `C_ClassColor`, …). No classic branches, no expansion checks.
- Prefer an API that exists over one that might: when in doubt, guard with `if C_Foo and C_Foo.Bar then`.
- Register only events that exist on retail (`GROUP_ROSTER_UPDATE`, not `RAID_ROSTER_UPDATE`).

### 6.2 Midnight restrictions

| Restriction | Rule |
|---|---|
| Chat lockdown | Send chat only through `UTILS.SendChatMessage`; it queues messages during lockdown. |
| Addon-message lockdown | Send only through `CLM.MODULES.Comms:Send`; it queues during lockdown and encounters. |
| Secret values | Check values from raid roster, unit, loot and chat APIs with `UTILS.IsSecret` before comparing or storing them. Skip or retry, never error. |
| Combat | Don't create or reshape secure frames in combat. Plain frames are fine. |

### 6.3 Blizzard templates and atlases

- Templates and atlas names change between patches. Create frames with fallbacks: `UI.CreateWithTemplates(type, name, parent, { "Preferred", "Fallback" })`. A missing template should degrade the look, never break loading.
- Check atlases with `UI.HasAtlas` before `SetAtlas`.
- Verify every new template or atlas name in-game (`/tinspect`, Texture Atlas Viewer) and mention it in the test checklist.

### 6.4 Performance

- Don't rebuild lists on every event. Refresh when the window is visible, and coalesce bursts (for example with `C_Timer.After(0, ...)` or a dirty flag).
- No `OnUpdate` scripts for things an event or timer can do.
- Item data may not be cached yet: use `Item:CreateFrom...():ContinueOnItemLoad` instead of polling.

### 6.5 Text

- All user-facing text goes through `CLM.L["English text"]`. We ship English only; `enUS.lua` returns the key, so the key *is* the text.
- Reuse existing keys where the text matches (search the code first) so wording stays consistent.
- Colours in text: prefer `ColorMixin:WrapTextInColorCode` or `UTILS.ColorCodeText`.

---

## 7. UI conventions (Phase 9 onwards)

The full design language is in `docs/features/ui-redesign.md`. The short version:

- **Build windows from `CLM.UI`:** `UI.CreateWindow`, `UI.CreateTabs`, `UI.CreateList`, `UI.CreateButton`, `UI.CreateInput`, `UI.CreateDropdown`, `UI.CreateCheckbox`, `UI.ShowContextMenu`, `UI.CreateItemButton`, `UI.CreateProgressBar`, `UI.CreateForm` (settings rows), `UI.Confirm` (confirmation popup), `UI.AcceptItems` (shift-click / drag an item into a field). No new AceGUI, AceConfigDialog, lib-st or LibUIDropDownMenu code.
- If a piece is missing, add it to `Modules/UI/` (and to `Demo.lua`, so `/bpgp uitest` shows it) instead of building a one-off in a window.
- **Spacing:** the 4 px grid in `UI.SPACE`. 8 between controls and from frame edge to inset, 12 between groups, rows 20, buttons 22, inputs 20, a 60 px top band on portrait frames.
- **Fonts:** GameFont objects only (`GameFontNormal` labels, `GameFontHighlight` values, `GameFontDisableSmall` meta, `NumberFontNormal` numbers, `GameFontNormalHuge` your PR).
- **Colours:** `UI.COLOR` and `UI.TIER_COLOR`; class colours for names, item quality colours for items. Orange only in test mode.
- **Buttons:** one primary button per area, bottom-right; secondary buttons to its left.
- **Confirm every write** with a `StaticPopup` (R6). Popup names are `BPGP_*`; the text says exactly what will happen ("Award 100 EP to 18 players in the raid?").
- **Windows** are movable, clamped, close on Escape, remember their position (`dbKey`), get the test-mode tint, and respect the UI scale setting.
- **New settings** go in the Settings tab (`Modules/MainWindow/Settings.lua`) as a form row that calls the module's getter and setter. Never add an Options → AddOns page.
- **Views stay thin:** a window turns manager data into rows and calls manager methods on clicks. Business rules (who can be awarded, what a decay does) stay in managers.

---

## 8. Libraries

- All libraries are vendored in `BPGP/Libs/` so a git clone runs as-is. `Libs/README.md` lists each one with its version and licence.
- **Don't edit third-party libraries.** Work around them in our code. If a library must change, update it to a newer upstream version and note it in `Libs/README.md`.
- `LibEventSourcing` is the exception: it's CLM source and ours to change. Keep its LibStub names as `BPGP-*`.
- Adding a library needs a reason (what we can't do with Blizzard APIs), its licence file, and an entry in `Libs/README.md` and `Libs/_filelist.xml`.
- AceGUI, AceConfigDialog, lib-st, LibUIDropDownMenu and LibSharedMedia were removed in Phase 9f. Don't bring them back: build UI from `Modules/UI`.

---

## 9. Static checks

There is no Lua interpreter or test harness for WoW UI code, so the static checks matter.

| Check | How | Catches |
|---|---|---|
| `scripts/check_addon.py` | `python -I scripts/check_addon.py` | missing TOC/XML references (exact case), packager markers, unbalanced Lua blocks |
| luacheck | runs in CI (`.github/workflows/lint.yml`), config `.luacheckrc` | undefined globals, unused variables, shadowing |

- luacheck isn't installed locally: add every new WoW global you use (`MenuUtil`, `ScrollUtil`, …) to `.luacheckrc` by hand.
- Fix warnings; don't silence them with ignores unless the warning is wrong for the whole codebase.

---

## 10. Testing in-game

- **The user runs the in-game tests.** After every change that needs testing, give a **numbered, step-by-step checklist**: what to type or click and what they should see. Ask them to report BugSack errors with the step number.
- **Test mode first** for anything that writes: `/bpgp test` (reloads the UI), `/bpgp testgroup 10`, *Simulate bids*. Test mode uses its own ledger and comm prefix.
- **Check that live data is untouched:** note the minimap tooltip's "N events (0x…)" before and after a test-mode session.
- Test as an officer and, where the change differs for them, as a raider (a non-officer character or the raider view).
- Test at UI scale 0.64 and 1.15 when the change is visual.
- Multi-client parts (sync, bidding) need a second account; collect them for Phase 10 when that isn't possible now.
- The addon folder is linked into `_retail_\Interface\AddOns\` with a directory junction, so `/reload` picks up changes. Adding or removing files that WoW loads by itself needs a full game restart.

---

## 11. Documentation

- Decisions go in `docs/` with the user's call; the code links to them in comments only where it helps ("R6: confirm everything").
- Keep `docs/release-plan-v1.md` §6 status table current: it's the first thing anyone reads.
- `ARCHITECTURE.md` describes the structure. Update it when modules, entry types, channels or windows change.
- `CHANGELOG.md` gets a line for every user-visible change.
- Write docs in plain, short English: lists and tables over long paragraphs.

---

## 12. Releasing

The full process is in `docs/release-plan-v1.md` §10. In short:

- Version in the TOC is `@project-version@`; the packager fills it from the git tag.
- Tags: `v1.0.0-alpha1` (alpha), `v1.0.0-beta1` (beta, officers), `v1.0.0` (release).
- Pushing a `v*` tag runs `.github/workflows/release.yml`: the BigWigs packager creates a GitHub Release with `BPGP-<tag>.zip`, then a separate job uploads the same build to CurseForge (needs the repository variable `CF_PROJECT_ID` and secret `CF_API_TOKEN`, see `docs/curseforge.md`). Raiders install and update with BPGP Updater; alpha/beta tags become pre-releases on GitHub, which the updater skips, and alpha/beta files on CurseForge.
- Every CurseForge file is moderated before it's public (minutes to a few days), so don't count on a same-day CurseForge hotfix; the GitHub Release (and so the updater) is immediate.
- BPGP Updater has its own repository and releases: [Blood-Promise/bpgp-updater](https://github.com/Blood-Promise/bpgp-updater). It needs each addon release to have a `BPGP-*.zip` containing `BPGP/BPGP.toc` with a filled-in `## Version:`. Don't change that layout without changing the updater.
- Before tagging: `CHANGELOG.md` has a section for the version, checks pass, and the in-game checklist (§7 of the release plan) has been run.
- After 1.0, ledger entry formats are frozen (§4) and every client in the guild must run a compatible version.
