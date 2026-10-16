# UI overhaul

- **Status:** idea
- **Target version:** after v1.0. v1.0 keeps the CLM UI, only trimmed.

## Problem

The UI we inherit from CLM was built to expose every feature CLM has: DKP and EPGP, multiple rosters, several auction types, bench, alt linking. Once v1.0 strips those out, the screens will still be laid out for that larger feature set.

_To fill in: concrete pain points from officers and raiders._

## How the UI is built today

- **Toolkit:** AceGUI-3.0 windows and widgets, with tables from lib-st (LibScrollingTable) wrapped as an AceGUI widget (`Modules/GUI/AceGUIWidget-LibScrollingTable.lua`).
- **Main window:** `Modules/GUI/UnifiedGUI.lua`. One window with tabs (Standings, History, Raids, Profiles, Audit). Each tab is a scrolling table plus an AceConfig options panel used as a filter/action sidebar.
- **Separate windows:** auction (`AuctionManager/MultiGUI.lua`), bidding (`BiddingManager/MultiGUI.lua`), award (`LootManager/AwardGUI.lua`), auction history, trade list (`AutoAssign/GUI.lua`).
- **Settings:** AceConfig in the Blizzard settings panel (`Rosters/RosterManager/Options.lua`, `Modules/Global/GlobalConfigs.lua`).

## Possible directions

Nothing has been decided yet. Options to weigh:

- **Restyle only:** keep AceGUI and lib-st, but clean up the layout, cut options that no longer apply, and use better defaults. This carries the least risk.
- **Raider-first bidding window:** put the item, the tier buttons and the current standing (EP / GP / PR) in one compact frame. This is the window most guild members see.
- **Officer dashboard:** one view for running a raid: start/end raid, award EP, open auctions from the loot list, and see trade status.
- **Native frames:** replace AceGUI with plain Blizzard frame templates (`ScrollBox`/`DataProvider` for tables) to match the retail look and drop dependencies. This is the most work.

## Open questions

- Which screens do officers actually use during a raid, and which only outside raids?
- What do raiders need besides the bidding window and their own standing?
- Should we support ElvUI skinning? `UnifiedGUI.lua` already checks for it.
- Do we want a mockup before deciding (e.g. a quick HTML or Figma sketch)?
