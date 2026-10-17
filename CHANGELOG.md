# BP EPGP v1.0.0 (unreleased)

## Changes
### First release
BP EPGP is a fork of Core Loot Manager v5.7.8, trimmed down to our guild's EPGP workflow on retail (Midnight).
### Coexists with Core Loot Manager
Own name, icon, saved data, slash command (`/bpepgp`) and sync channels, so it can be installed next to CLM.
### EPGP only
One roster with EPGP standings (PR = EP/GP), officers defined by the guild rank's "Is Officer" permission, new rosters default to Open auctions with Tiered named buttons. Use "Set up BP EPGP" in the Standings tab to create the roster. The Standings tab has separate EP and GP award rows.
### Guild members only
The Profiles tab is now "Manage roster": it lists the guild's max level members, and officers add or remove them from the roster there. Only guild members can be added. Raids no longer add players to the roster by themselves.
### Auctions
Auctions are always Open with named tier buttons (each tier its own GP). Raiders get one button per tier, plus OS, Pass and Cancel; cancelling and passing are always allowed. Tiers without a custom name show as Base/Small/Medium/Large/Max. Fixed: anti-snipe now restarts the countdown, and the auction and award click modifiers can't be set to the same keys.
### Standings import
Officers can paste a `Name, EP, GP` list (e.g. from a spreadsheet) in *Import standings*, check the preview and set everyone's standings in one go.
### Test mode
`/bpepgp test` switches to a separate test ledger and sync channel; chat output stays local. Simulate a raid group (`/bpepgp testgroup N`) and bidders (*Simulate bids*) to run a whole raid evening alone.
### New main window
The main window is rebuilt with native Blizzard frames: a portrait window with tabs along the bottom (Standings, History, Raids, plus Roster and Audit for officers). It can be resized. Officers get an *Act on* panel (Selected, Raid or Roster) with EP and GP award rows and decay; every change asks for confirmation. Right-click a name for *Award item* (opens the Award window with the player filled in) or *Remove from roster*. Raiders see their own row pinned on top and their PR in the header. History has a type filter and a player/item search; Audit shows skipped ledger entries in red. While data is syncing, the window shows a progress bar instead of a separate banner.
### Settings in the main window
All settings are in the new Settings tab (`/bpepgp config`): Personal, Guild, Gear values and Advanced. Everyone can see the guild settings and gear values; only officers can change them. There are no BP EPGP pages under Options → AddOns any more. `/bpepgp minimap` shows or hides the minimap icon.
### New auctioning and bidding windows
Both windows are rebuilt with native Blizzard frames. The auctioning window shows the item queue, the five tier values, the bids sorted by tier, PR and roll, and a countdown in the header. When the auction ends the winner is selected for you (highest tier, then PR, then roll); press Enter to award, and the next item with bids loads. The bidding window shows "Item 2 of 4 · 14s left" and your PR in the header, one row of tier buttons with their GP, and whether your bid was accepted. The separate timer bar is now off by default (*Show timer bar* in Settings).
### Other windows
The Award, Auction history, Trade list and Import standings windows are rebuilt with native Blizzard frames. Auction history entries open to show their bids; right-click for Post bids or removing entries. Toasts show the BP EPGP logo with EP in green and GP in gold. The minimap tooltip shows the same sync status as the main window.
### Pass on loot
New checkbox in Settings → Personal → Loot (on by default): in our own BP EPGP raids you automatically pass on boss loot rolls, so the officer running the auctions loots the items. It only works in a BP EPGP raid started less than 12 hours ago, in a raid group led by one of our officers; when you pug another raid nothing is ever passed. Quest items, legendaries, stacks, recipes, mounts, toys and cosmetics are never passed.
### Removed
Classic support, non-English translations, the in-game changelog window, the Tracker and Integrations add-ons, auto-roll options (only "Pass on loot" remains), GP prices in item tooltips, sandbox mode, time travel, cross-guild sync, DKP, point caps, zero-sum bank, tax, dynamic item values, class multipliers, boss-kill/interval/raid-completion bonuses, bench/standby, alt-main linking, profile locking, profile pruning, attendance tracking, disenchanting, keybindings, the minimap right-click menu, "Fill from guild/raid" and "Add target", the Standings filters and search, award reasons (awards are always a manual adjustment), Sealed/Vickrey/Anonymous auctions, Ascending and Single-priced bidding, All-In, auto-update bid values, the "new highest bid" raid warning, master-loot auto-assign, guild-chat award announcements, posting corpse loot to raid chat, "Master/Group loot only" filling, the "Disable data synchronisation" and "Wipe events" options, and the timer bar font and texture choice. The Alerts add-on is now built in.
