# Phase 10: the full test run

The script for the full in-game test before release 1.0 ([release plan](release-plan-v1.md) §6, Phase 10). Work through it in order and tick the boxes. When something goes wrong, note the **step number** and copy the BugSack error (or the chat line).

**You need:**
- **A:** your officer character. **B:** a second account in the guild. Parts 2 and 4 need B to be an officer at least once; for the non-officer checks, B needs a non-officer rank, or another raider can help.
- BugSack + !BugGrabber on both accounts. The same BPGP build on both: same commit, and the version is shown in Settings.
- For part 3, a real raid with at least one other tester who also switches on test mode.

**Where it runs:** parts 1-3 run in **test mode** (`/bpgp test`), so the live ledger stays empty until the release. Part 4 is a short live check, done at the rollout. Write down the live event count first (step 1.3) and compare it at the end of each part.

---

## Part 1: solo checks (A, before the raid)

**Startup**
- [ ] 1.1 Log in with CLM **and** BPGP enabled. BugSack stays empty, and the chat shows "BPGP … initialization complete".
- [ ] 1.2 The AddOns list shows **BPGP** with the logo. Nothing from BPGP appears under Options → AddOns.
- [ ] 1.3 Hover the minimap icon. It shows "BPGP <version>" and "N events (0x…)". **Write down N and the hash.**
- [ ] 1.4 `/bpgp gui` opens the main window. The officer tabs are Standings, Auction, History, Raids, Roster, Audit, Settings, and the footer says *In-Sync*.
- [ ] 1.5 `/bpepgp` does nothing. `/bpgp config` opens the Settings tab, and `/bpgp minimap` hides and shows the icon.

**Test mode and setup**
- [ ] 1.6 `/bpgp test`: the UI reloads, the orange TEST MODE banner shows, and the minimap icon is orange.
- [ ] 1.7 Standings → **Set up BPGP**. The roster is created, and the columns are BP · GP · PR.
- [ ] 1.8 Settings → Guild: set Starting BP, Minimum GP, on-time bonus BP, tier button names, auction length, anti-snipe and minimum standing. Settings → Gear values: set a few slot values. Everything saves (reopen the tab to check).
- [ ] 1.9 Roster tab: add a few guild members. They appear in Standings with the starting BP.
- [ ] 1.10 Standings → **Import standings**: paste 3 lines `Name, BP, GP` (one with a typo). The preview marks the typo, and **Apply** sets the other two exactly.

**Points**
- [ ] 1.11 Select two players, *Act on: Selected*, enter 50 and click **Award BP**. A confirmation appears, then the BP goes up and the PR changes. History shows a *BP* row with your note.
- [ ] 1.12 Same with **Award GP**. History shows a *GP* row.
- [ ] 1.13 *Act on: Roster*, Decay 10 % (BP/GP). After the confirmation, every value drops by 10 % and GP never goes below Minimum GP.
- [ ] 1.14 History: right-click the BP award from 1.11 → remove. The standings go back, and Audit shows the undo entry.
- [ ] 1.15 History: the type filter (BP / GP / Decay) and the search box (a player name) both narrow the list. The header doesn't overlap the table.

**Raid and auction (simulated)**
- [ ] 1.16 `/bpgp testgroup 10`. Raids tab: create a raid, then right-click → **Start raid**. The simulated members get the on-time bonus, and a `[TEST]` raid warning is printed locally.
- [ ] 1.17 Alt-click an item in your bags. The main window opens on the **Auction** tab with the item in the queue and the tier GP filled in from the gear values.
- [ ] 1.18 Tick *Simulate bids* and press **Start**. The bidding window opens (item, time left, tier buttons with their GP), and the main window shows a **Bid** button at the top right.
- [ ] 1.19 Close the bidding window with its cross, then click **Bid** in the main window. The bidding window reopens.
- [ ] 1.20 Bid a tier, then another tier. The status line says *accepted*, and your bid is replaced.
- [ ] 1.21 When the timer ends, the **Bid** button disappears. The winner is preselected (highest tier, then PR, then roll) and the cursor is in Value. Press **Enter** twice to award. GP is charged, a toast shows, and the next item with bids loads.
- [ ] 1.22 `/bpgp auction_history`: the auction is listed, and opening it shows the bids. `/bpgp trade`: the item is on the trade list.
- [ ] 1.23 Standings: right-click a player → **Award item**. The Award window opens with the player filled in. Award an item without an auction.
- [ ] 1.24 Raids tab: end the raid. It shows as ended.
- [ ] 1.25 `/bpgp test` back to live. The minimap tooltip shows **the same N and hash as 1.3**.

---

## Part 2: sync with a second account (A + B, test mode)

Postponed from Phase 8. Both accounts switch on test mode (`/bpgp test`) and log in.

- [ ] 2.1 B (officer) logs in. Within a minute B's footer goes from *Sync ongoing* to *In-Sync*, and B sees the same standings as A.
- [ ] 2.2 Both minimap tooltips show **the same event count and hash**.
- [ ] 2.3 A awards 25 BP to a player. B sees it within ~30 s, and the hashes match again.
- [ ] 2.4 B awards GP to a player. A sees it, so the sync goes both ways.
- [ ] 2.5 A removes B's GP entry in History (undo). B's standings go back too.
- [ ] 2.6 A changes a guild setting (e.g. the on-time bonus BP). B's Settings → Guild shows the new value.
- [ ] 2.7 **Catch-up:** B logs out. A makes 3-4 changes (award, decay, undo). B logs back in: *Sync ongoing* with a progress bar, then *In-Sync*, with the same hash as A.
- [ ] 2.8 **Non-officer:** B on a non-officer rank (or another raider). The Auction, Roster and Audit tabs are hidden, the Award and Decay panels are missing, and Guild settings and Gear values are read-only.
- [ ] 2.9 The non-officer's data still syncs: an award by A shows up for them.
- [ ] 2.10 **Rank change:** promote B to officer, then `/reload` on B. The officer tabs appear. Demote B, `/reload`, and they're gone.
- [ ] 2.11 **Auction control:** A and B in one group, with A as raid leader. A starts an auction, and B's bidding window opens. B as a non-officer has no Auction tab, and `/bpgp auction` does nothing.
- [ ] 2.12 Both: `/bpgp test` back to live. The live counts are unchanged.

---

## Part 3: the raid evening (A + at least one tester, test mode)

A runs everything. The testers switch on test mode before the raid and bid normally. The rest of the raid isn't involved: test traffic only reaches clients in test mode, and raid warnings are printed locally.

**Before the first pull**
- [ ] 3.1 A: `/bpgp test`, then Raids → create a raid → **Start raid** in the real raid group. The real raid members are in the raid, the on-time bonus is given to roster members, and the `[TEST]` raid warning is printed.
- [ ] 3.2 Someone joins and someone leaves the group. The Raids tab updates the member list.
- [ ] 3.3 Testers: Settings → Personal → **Pass on loot** is on, and the tooltip explains the conditions.

**Bosses and loot**
- [ ] 3.4 **During a boss fight**, A awards BP to the raid. No error appears. The entry shows up after the fight at the latest (messages queued during chat/addon lockdown), and the testers receive it.
- [ ] 3.5 After the boss: the testers' loot rolls are passed automatically (Pass on loot) and A can loot the items. Quest items, mounts and the like are not passed.
- [ ] 3.6 A alt-clicks the loot. It goes into the Auction tab queue, and A presses **Start**. The testers' bidding windows open, with the right tier names and GP.
- [ ] 3.7 A tester bids in the last seconds. Anti-snipe extends the timer: everyone's countdown jumps up (the timer bar, if switched on, shows "+Ns").
- [ ] 3.8 A tester closes the bidding window and reopens it with **Bid** in the main window during the auction.
- [ ] 3.9 Testers with *Hide in combat*: the window hides when combat starts and comes back after combat while the auction still runs.
- [ ] 3.10 Two testers bid the same tier. The higher PR is preselected. With equal PR, the roll phase (`/roll`) decides.
- [ ] 3.11 A awards (Enter). GP is charged, the PR updates for everyone, the tester sees the "won" toast, and the auction history and trade list have the item.
- [ ] 3.12 A trades the item to the winner. The trade list updates (note what it shows).
- [ ] 3.13 **Auction during a boss** (if a boss drops loot mid-fight, or start one while in combat on trash). It runs without errors, and messages that are queued arrive after the fight.

**End of the evening**
- [ ] 3.14 Raids tab → end the raid. Raid warning printed, raid closed.
- [ ] 3.15 A runs a decay (Standings, *Act on: Roster*). The values are correct for A and the testers.
- [ ] 3.16 A and the testers compare minimap hashes. **All equal.**
- [ ] 3.17 Everyone: `/bpgp test` back to live. The live counts are unchanged (still 0 events if nothing was done live).

---

## Part 4: live check at the rollout (A + B)

Done when the guild switches over (Phase 11). This is the first live data, so it's real.

- [ ] 4.1 A: **Set up BPGP** (live), import the current standings, and check them against the spreadsheet.
- [ ] 4.2 B logs in and gets *In-Sync* with the same hash.
- [ ] 4.3 A awards a small BP amount to B, and B sees it.
- [ ] 4.4 A's chat during a real auction: the raid warning goes out to the raid (live mode sends it for real).

---

## Reporting

For every unticked step, give the step number, what you expected, what happened, and the BugSack error or chat text. A screenshot helps for layout problems. Things that work but feel wrong (wording, spacing, clicks too many) are worth noting too, marked as *polish*.
