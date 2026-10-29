# BPGP docs

Docs hold what is still true. A plan or spec is deleted once it has been carried out; git keeps the history.

| What | Where |
|---|---|
| Decisions that still bind | [decisions.md](decisions.md) |
| Words we use | [GLOSSARY.md](../GLOSSARY.md) |
| How the addon works | [ARCHITECTURE.md](../ARCHITECTURE.md) |
| How we work | [DEVELOPMENT-GUIDELINES.md](../DEVELOPMENT-GUIDELINES.md) |
| CurseForge setup and project texts | [curseforge.md](curseforge.md) |
| Agreed features, not built yet | [features/](features/) |
| Loose ideas | [ideas/](ideas/) |

## From idea to feature

1. **Idea:** add a file to `ideas/` (copy the template below). Write down the problem and any thoughts. Nothing needs to be decided yet.
2. **Feature:** once we decide to build it, move the file to `features/` with `git mv`, then fill in scope and how we'll test it. Set the status to `planned`.
3. **Shipped:** decisions that still bind go to [decisions.md](decisions.md), new terms to the glossary, structure to ARCHITECTURE.md. Then delete the file.

An idea we drop is deleted too, with the reason in the commit message.

## Template

```markdown
# <Title>

- **Status:** idea | planned | in progress

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
