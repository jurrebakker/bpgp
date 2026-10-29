# BPGP v1.0.8 (2026-10-29)

## Changes
### Award price
Fixed: after awarding an item, the Auction tab's Value box could keep the previous item's GP, so pressing Enter charged a Transmog or OS winner that price. The box now follows the selected winner and is cleared after every award. The award confirmation shows the winner's bid, e.g. "Award X to Y (Transmog) for 0 GP?".

# BPGP v1.0.7 (2026-10-22)

## Changes
### OS bids are free
An OS bid costs 0 GP, like Transmog. OS still ranks above Transmog and is ranked by PR. Raiders on an older version are told to update.

# BPGP v1.0.6 (2026-10-19)

## Changes
### Auction list filling
The auction list always fills from boss corpses and from the auctioneer's own loot, with Epic or better weapons, armor and miscellaneous items (like tier tokens) only. Crafting sparks, reagents, consumables and the like are no longer added. The "Filling the auction list" settings are gone. Adding an item by hand (auction click) still works for any item.
### Pass on loot and Need on everything
Both now only roll on weapons, armor and miscellaneous items. Raiders roll on everything else themselves, like consumables and housing decor.

# BPGP v1.0.0 (2026-10-18)

## Changes
### First release
BPGP is a fork of Core Loot Manager v5.7.8, trimmed down to our guild's BPGP workflow on retail (Midnight).
### Coexists with Core Loot Manager
Own name, icon, saved data, slash command (`/bpgp`) and sync channels, so it can be installed next to CLM.
### BPGP only
One roster with BPGP standings (PR = BP/GP), officers defined by the guild rank's "Is Officer" permission, new rosters default to Open auctions with Tiered named buttons. Use "Set up BPGP" in the Standings tab to create the roster. The Standings tab has separate BP and GP award rows.
### Guild members only
The Profiles tab is now "Manage roster": it lists the guild's max level members, and officers add or remove them from the roster there. Only guild members can be added. Raids no longer add players to the roster by themselves.
### Auctions
Auctions are always Open with named tier buttons (each tier its own GP). Raiders get one button per tier, plus OS, Transmog, Pass and Cancel; cancelling and passing are always allowed. Transmog is free (0 GP) and ranks below OS; among Transmog bids the highest roll wins, PR doesn't count. Officers can turn OS and Transmog off separately in the guild settings. Tiers without a custom name show as Base/Small/Medium/Large/Max. Fixed: anti-snipe now restarts the countdown, and the auction and award click modifiers can't be set to the same keys.
### Standings import
Officers can paste a `Name, BP, GP` list (e.g. from a spreadsheet) in *Import standings*, check the preview and set everyone's standings in one go.
### Test mode
`/bpgp test` switches to a separate test ledger and sync channel; chat output stays local. Simulate a raid group (`/bpgp testgroup N`) and bidders (*Simulate bids*) to run a whole raid evening alone.
### New main window
The main window is rebuilt with native Blizzard frames: a portrait window with tabs along the bottom (Standings, History, Raids, plus Roster and Audit for officers). It can be resized with the grip in the bottom-right corner. Officers get an *Act on* panel (Selected, Raid or Roster) with BP and GP award rows and decay; every change asks for confirmation. Right-click a name for *Award item* (opens the Award window with the player filled in) or *Remove from roster*. Raiders see their own row pinned on top and their PR in the header. History has a type filter and a player/item search; Audit shows skipped ledger entries in red. While data is syncing, the window shows a progress bar instead of a separate banner.
### Settings in the main window
All settings are in the new Settings tab (`/bpgp config`): Personal, Guild, Gear values and Advanced. Everyone can see the guild settings and gear values; only officers can change them. There are no BPGP pages under Options → AddOns any more. `/bpgp minimap` shows or hides the minimap icon.
### New auctioning and bidding
Auctioning moved into an **Auction** tab in the main window (officers). It shows the item queue, the five tier values, the bids sorted by tier, PR and roll, and a countdown in the header. When the auction ends the winner is selected for you (highest tier, then PR, then roll); press Enter to award, and the next item with bids loads. The bidding window shows "Item 2 of 4 · 14s left" and your PR in the header, one row of tier buttons with their GP, and whether your bid was accepted. Closed it by accident? While an auction runs, the main window has a **Bid** button that opens it again. The separate timer bar is now off by default (*Show timer bar* in Settings); it turns red for the last 5 seconds and shows "+5s" when anti-snipe extends the auction.
### Other windows
The Award, Auction history, Trade list and Import standings windows are rebuilt with native Blizzard frames. Auction history entries open to show their bids; right-click for Post bids or removing entries. Toasts show the BPGP logo with BP in green and GP in gold. The minimap tooltip shows the same sync status as the main window.
### Pass on loot
New checkbox in Settings → Personal → Loot (on by default): in our own BPGP raids you automatically pass on boss loot rolls, so the officer running the auctions loots the items. It only works in a BPGP raid started less than 12 hours ago, in a raid group led by one of our officers; when you pug another raid nothing is ever passed. Quest items, legendaries, stacks, recipes, mounts, toys and cosmetics are never passed.
### Installing and updating
Raiders install and update BPGP with [BPGP Updater](https://github.com/Blood-Promise/bpgp-updater), which also shows the raid schedule.
### Removed
Classic support, non-English translations, the in-game changelog window, the Tracker and Integrations add-ons, auto-roll options (only "Pass on loot" remains), GP prices in item tooltips, sandbox mode, time travel, cross-guild sync, DKP, point caps, zero-sum bank, tax, dynamic item values, class multipliers, boss-kill/interval/raid-completion bonuses, bench/standby, alt-main linking, profile locking, profile pruning, attendance tracking, disenchanting, keybindings, the minimap right-click menu, "Fill from guild/raid" and "Add target", the Standings filters and search, award reasons (awards are always a manual adjustment), Sealed/Vickrey/Anonymous auctions, Ascending and Single-priced bidding, All-In, auto-update bid values, the "new highest bid" raid warning, master-loot auto-assign, guild-chat award announcements, posting corpse loot to raid chat, "Master/Group loot only" filling, the "Disable data synchronisation" and "Wipe events" options, and the timer bar font and texture choice. The Alerts add-on is now built in.
