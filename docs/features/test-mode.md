# Test mode

- **Status:** in progress (Phase 4a: switch and isolation done). Decisions made 2026-10-16 (T1-T5 at the bottom; ✅ = as recommended)
- **Target version:** v1.0

## Problem

Everything in BP EPGP writes to the **live ledger**, and the live ledger syncs to the whole guild. Testing an EP award, a decay, an auction or the standings import today means doing it for real: everyone receives it, and the only way back is an undo that stays visible in the Audit tab forever.

There is also no way to test alone. Auctions need you to be raid leader/assistant in a real raid (`RaidManager:IsAllowedToAuction`), loot has to come from a corpse or your bags, and bids need other players.

## What CLM has today (and why it isn't enough)

| CLM feature | What it does | Problem |
|---|---|---|
| **Sandbox mode** (`SandboxManager`, Audit tab) | Deep-copies the ledger and switches **all** comms off. "Apply" or "Discard" on exit. | Solo only: no sync, no bidding with a second person. "Apply" merges test changes into live data. Tied to time travel, which we're removing. |
| **Dev fakes** (`AuctionManager:FakeBids`, `BiddingManager:FakeAuction`, `AutoAssign:FakeTrack`) | Random bids from raid members, a fake auction in the bidding window, fake trade entries | Live only inside `--@do-not-package@` blocks, which we're deleting (security issue C1). They also need a real raid. |

## Proposal: an isolated test environment

A **Test mode** switch (Advanced tab + `/bpepgp test`). While it's on, BP EPGP runs against a completely separate world:

| Area | Live mode | Test mode |
|---|---|---|
| Ledger | `BPEPGP_DB` live section | separate **test** section in the same SavedVariables. Live data is never read or written. |
| Sync / auction comms | prefix `BPEP…` | prefix `BPEPT…`. Only other clients in test mode see this traffic, and live clients never do. |
| Chat output (raid warnings, award announcements) | RAID_WARNING / RAID / GUILD | printed locally with a `[TEST]` prefix only (T3). Raid warnings are never sent in test mode. |
| Permissions | "Is Officer" ranks | **the same.** Test mode never loosens who may write data. |
| Indicator | — | orange **TEST MODE** banner on the main window and a different minimap icon colour |
| Leaving test mode | — | back to live data instantly. There's no "apply": test data can never be merged into live. |

Because test data lives on its own comm prefix, **several people can test together**. For example, an officer and a raider (or your own alt on a second account) can both switch on test mode and run a full auction with real bidding and sync, without the rest of the guild noticing.

### Simulation tools (only available in test mode)

| Tool | What it does | Replaces |
|---|---|---|
| **Test roster** | The setup button creates the roster with our defaults. Optionally fill it with guild members or N simulated players (T4). | — |
| **Simulated raid** | Start or end a raid without being in a group. Members are you plus chosen guild members or simulated players. On-time bonus works as usual. | needing a real raid |
| **Add item to auction** | Add any item by link or item ID to the auction list, without looting it. | needing loot |
| **Auction without raid lead** | You can open and run auctions solo. | `IsAllowedToAuction` dev override |
| **Simulated bidders** | Raid members (simulated or real names) place random tier/OS/pass bids, so you can test awarding, ties, anti-snipe and the `/roll` phase. | `FakeBids` |
| **Preview bidding window** | Shows the raider's bidding window with a fake auction, to check the layout. | `FakeAuction` |
| **Reset test data** | Wipes the test ledger, optionally copying today's live data as a new starting point (T2). | — |

### Typical uses

1. **Developing / before every release:** run the in-game checklist (release plan §7) in test mode first.
2. **Dry-run the standings import:** paste the guild's EP/GP list into the import window in test mode, check the result, then do it for real.
3. **Trying settings:** change GP values, tier names or decay % in test mode (starting from a copy of live data) and see the effect on standings before touching live.
4. **Teaching new officers** how to run auctions, without risk.

## Design notes

- **Isolation is enforced structurally:** the mode is fixed when the addon starts (switching reloads the UI), `Database:Ledger()` returns the `ledger_test` section in test mode, and every comm prefix is `BPEPT…` instead of `BPEP…`. A live client never registers a test prefix, so it can't receive test data, and a test client never holds a reference to the live ledger table. This replaces the planned `test` flag in the ledger header: it gives the same guarantee without changing the entry format.
- **Comm prefix length:** WoW allows 16 characters. `BPEPT` + channel name must fit, so channel names stay ≤ 11 characters.
- **Switching modes** reloads the UI. Switching during a running auction is blocked.
- The simulation tools are normal, shipped code, guarded by `TestMode:IsOn()`, so they behave the same in a git clone and in a packaged build. That's the opposite of the CLM dev fakes, which only existed in unpackaged builds.

## Effect on the feature list

- **#47 "Time travel and sandbox mode"** stays removed. Sandbox is replaced by this test mode; time travel stays gone.
- **New keep item:** test mode + simulation tools.

## Decisions

| # | Question | Options | Recommendation | Your call |
|---|---|---|---|---|
| T1 | Who can switch test mode on? | a) everyone · b) officers only | **a**. Raiders need it to bid in a test auction, and it can't affect live data. | **a: everyone** ✅ |
| T2 | Starting data for the test ledger | a) always empty · b) copy of live data · c) choose on each reset | **c** | **c: choose on each reset** ✅ |
| T3 | Chat output in test mode | a) local only · b) local, plus PARTY/RAID when testers are grouped together (never GUILD) | **a**, with b as an Advanced-tab toggle for testing raid warnings | **a: local only** |
| T4 | Simulated players | a) generated names (`Test1`…`Test20`) · b) real guild members' names and classes | **b**, falling back to a when not in a guild | **b: guild names** (fallback generated) ✅ |
| T5 | Keep test data across `/reload` and logout? | a) yes, until "Reset test data" · b) no, wiped on logout | **a** | **a: keep until reset** ✅ |
