# BPGP: notes for Claude

EPGP loot addon for our guild, **WoW retail (Midnight, 12.x) only**. A fork of Core Loot Manager (CLM) v5.7.8, stripped down to EPGP. v1.0 is released; work now is fixes and new features.

## Where to look

| When you… | Read |
|---|---|
| change behaviour, or a choice has more than one reasonable answer | [docs/decisions.md](docs/decisions.md): don't break a listed decision without asking |
| need the module map, ledger, sync or permissions model | [ARCHITECTURE.md](ARCHITECTURE.md) |
| add a ledger entry type or mutator | [DEVELOPMENT-GUIDELINES.md §4](DEVELOPMENT-GUIDELINES.md#4-state-ledger-and-sync) |
| touch comms, ACL, sync or anything global | [DEVELOPMENT-GUIDELINES.md §5-6](DEVELOPMENT-GUIDELINES.md#5-security-permissions-and-coexisting-with-clm) |
| build or change a window or setting | [DEVELOPMENT-GUIDELINES.md §7](DEVELOPMENT-GUIDELINES.md#7-ui-conventions) |
| write text players see | [GLOSSARY.md](GLOSSARY.md) |
| finish a change, or it needs testing in-game | [DEVELOPMENT-GUIDELINES.md §9-10](DEVELOPMENT-GUIDELINES.md#9-static-checks) |
| release | [DEVELOPMENT-GUIDELINES.md §12](DEVELOPMENT-GUIDELINES.md#12-releasing) |
| start work on a new feature | [docs/README.md](docs/README.md) |

## Rules whose mistakes reach the whole guild

- **State only through the ledger.** Every change is an entry submitted with `CLM.MODULES.LedgerManager:Submit(entry)`; undo is `LedgerManager:Remove(entry)`. **Entry formats are frozen:** add new entry types, never change or remove old ones. `RosterConfiguration` fields only get appended.
- **Officer checks are enforced on receive**, not only in the UI.
- **Everything global has a BPGP name** (SavedVariables `BPGP_*`, comm prefix `BPGP`, frames `BPGP_*`, forked LibStub names `BPGP-*`): the guild runs the real CLM next to BPGP, and LibStub would swap a forked lib under CLM's name for CLM's copy.

## Working here

- `master` is protected: branch (`feat/`, `fix/`, `docs/`), then PR. Commit or push only when the user asks.
- Ask the user when something needs a decision, with concrete options and a recommendation, and record the answer in `docs/decisions.md`.
- **In-game testing is done by the user.** After every change that needs it, give a **numbered step-by-step checklist** (what to type or click, what they should see) and ask for BugSack errors with the step number.
- `python -I scripts/check_addon.py` must report 0 problems. luacheck only runs in CI: add new WoW globals to `.luacheckrc` by hand.
- The Lua namespace is still `CLM`. Code says EP; players see BP.

## Tooling (Windows, Git Bash)

- No Lua interpreter and no luacheck locally; Python 3 is available.
- **Bash heredocs mangle backslashes** (Lua paths like `"Interface\\Icons"`). For multi-line edits use the Edit tool or a Python script run with `python -I`, and check every write of a Lua string with backslashes.
- Writing a file can fail with a transient `Errno 22`. Check what was applied, then redo only the rest.
