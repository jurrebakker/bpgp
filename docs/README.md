# BPGP docs

Planning documents for BPGP. Code-level documentation stays next to the code (`ARCHITECTURE.md`, comments).

**Where are we?** See the status table at the top of [release-plan-v1.md §6](release-plan-v1.md#6-work-plan-phases).

| Folder / file | What goes there |
|---|---|
| [release-plan-v1.md](release-plan-v1.md) | The v1.0 plan: scope, architecture, phases, test checklist, releasing |
| [phase-10-test-run.md](phase-10-test-run.md) | Step-by-step script for the full in-game test before 1.0 (solo, sync with a second account, raid evening, rollout check) |
| [sync-and-security.md](sync-and-security.md) | How ledger sync works, security issues found, decisions S1-S9 |
| [features/](features/) | Planned features: agreed on, scoped, ready to be built |
| [design/](design/) | The Claude Design spec for the UI redesign (open the `.dc.html` in a browser) |
| [ideas/](ideas/) | Loose ideas that may grow into features. Rough notes are fine |

## From idea to feature

1. **Idea:** add a file to `ideas/` (copy the template below). Write down the problem and any thoughts. Nothing needs to be decided yet.
2. **Feature:** once we decide to build it, move the file to `features/` with `git mv`, then fill in scope, design and how we'll test it. Set the status to `planned`.
3. **Done:** when it ships, set the status to `shipped` with the version and leave the file where it is as a record of the decisions.

An idea we drop stays in `ideas/` with status `rejected` and a line explaining why, so we don't have the same discussion twice.

## Template

```markdown
# <Title>

- **Status:** idea | planned | in progress | shipped (vX.Y) | rejected
- **Target version:** -

## Problem
What is wrong or missing today, and for whom (officers, raiders)?

## Idea / proposal
What we want to do about it.

## Scope
What's in, and what's explicitly out.

## Open questions
-

## Testing
How we'll verify it in-game.
```

## Index

### Features
- [UI overhaul: settings in the main window](features/ui-overhaul.md) (built in Phase 9c, v1.0; per-setting keep/drop list. Layout decisions D4/D8 are replaced by the redesign)
- [Test mode: isolated test ledger and simulation tools](features/test-mode.md) (done, v1.0)
- [Claude Design brief: native Blizzard look for every window](features/ui-design-brief.md) (prompt for the UI redesign)
- [UI redesign: native Blizzard windows](features/ui-redesign.md) (in progress, v1.0, Phase 9: 9a-9f built, final check in the Phase 10 test run; spec in [design/](design/))

### Ideas
_None yet._
