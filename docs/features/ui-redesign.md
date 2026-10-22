# UI redesign: native Blizzard look

- **Status:** in progress, v1.0, Phase 9 (decisions R1-R11 made 2026-10-16). all steps (9a-9f) built; 9a-9e checked in-game, the rest is covered by the Phase 10 test run.
- **Source:** Claude Design spec made from [ui-design-brief.md](ui-design-brief.md): [design/bp-epgp-redesign.dc.html](../design/bp-epgp-redesign.dc.html). Open it in a browser; it needs `support.js` next to it. It's reference material only, not shipped (`docs` is in the `.pkgmeta` ignore list).
- **Replaces:** the AceGUI/lib-st windows. It also updates [ui-overhaul.md](ui-overhaul.md) decisions D4 and D8 (see R3).

## Decisions

The design proposes a few things that conflict with earlier choices. Your calls:

| # | Design proposal | Your call |
|---|---|---|
| R1 | One *Amount* field with *Award EP* / *Charge GP* buttons | **Keep two rows**: EP field + Award EP, GP field + Award GP (as built in Phase 3). |
| R2 | Search box and Raid/All dropdown in the Standings header | **Keep both out.** Standings always shows the whole roster. |
| R3 | One *Settings* tab in a 720 px window | **One Settings tab**, with sections inside: Personal, Guild, Gear values, Advanced. Replaces D4 (separate tabs) and D8 (own Advanced tab). |
| R4 | Audit merged into History as a filter | **Keep a separate Audit tab.** |
| R5 | *Reason* field + Boss / On time / Prog presets | **Note only** (free text, shown in History). No presets. |
| R6 | Undo link instead of confirmations for single-player awards | **Confirm everything**, as now. |
| R7 | Award window via right-click; Trade list as an "Untraded" filter in Auction history | **Award via right-click: yes** (Standings → right-click → *Award item* opens the Award window prefilled). **Trade list stays its own window.** |
| R8 | Scope | **Everything in v1.0**: main window, settings, auctioning, bidding, award, auction history, trade list, timer, toasts, minimap, popups. |
| R9 | Bidding window in comfortable + compact layouts, countdown docked in the header | **Comfortable only + docked countdown.** The separate timer bar becomes optional (off by default). |
| R10 | Winner preselected when the timer ends (highest tier → PR → roll), value filled, Enter awards; next queued item loads after Award | **Yes, both.** |
| R11 | Raiders: officer tabs hidden, own row pinned, *Your PR* big in the header | **Yes.** |
| R12 | (2026-10-17, after 9d) How do officers open auctioning from the GUI? | **An Auction tab in the main window with the full auctioning UI** (officers only, right after Standings). The separate Auctioning window is gone; alt-click and `/bpgp auction` open the tab. |
| R13 | (2026-10-17) How does a raider reopen the Bidding window after closing it? (only `/bpgp bid` did) | **A Bid button in the main window header**, shown to everyone while an auction runs. |
| R14 | (2026-10-18) A **Transmog** bid next to OS | **Yes.** Transmog costs **0 GP** and ranks below OS (tiers → OS → Transmog). Among Transmog bids PR doesn't count: the highest roll wins. It has its own guild setting *Transmog* (`useTransmog`, default on), separate from OS. Bid type `TRANSMOG = 5`; auction comm version 5, so older clients are told to update. |
| R15 | (2026-10-18, raid test) Officer collects all loot | **Need on everything**: a checkbox under *Pass on loot*, officers only, off by default. Rolls Need, else Greed, else Transmog on boss loot, with the same safety rules and exclusions as Pass on loot, and wins over it. BoP confirmations are accepted automatically. |
| R16 | (2026-10-18, raid test) Fewer bid buttons now OS and Transmog are built in | **Three fixed tiers: BiS (purple), Major (blue), Minor (green).** Names are hardcoded (the *button name* settings are gone). They reuse the Base / Small / Medium GP keys (Minor = Base, Major = Small, BiS = Medium), so the guild's GP values keep their meaning. Large and Max stay valid ledger keys but are never offered or accepted as a bid. OS still costs the Minor value (changed by R29: OS is free). |
| R17 | (2026-10-18, raid test) Trade list | **A Trade tab in the main window**, right of Auction, officers only. Replaces R7's "stays its own window". `/bpgp trade` opens the tab. |
| R18 | (2026-10-18, raid test) Bidding window shows "Item 1 of 3" as text | **An item icon strip on the left, like the Auction tab.** The shown item is highlighted; items you bid on get a green border, passed grey, denied red. Click an icon to switch. The "Item N of M" text is gone. |
| R19 | (2026-10-18, raid feedback) Hand the auctioneer role to the officer who collects the loot | **The officer with *Need on everything* on may auction**, no assist needed (others: officer + lead/assist as before). Raiders accept auction messages from any officer in their raid group; the officer rank is still checked on receive (S9). |
| R20 | (2026-10-18, raid feedback) Which looted items fill the auction list | **Only tradeable ones**: not bound, or bound with the trade timer. The quality and class filters still apply (R28). |
| R21 | (2026-10-18, raid feedback) Raid reminders | **A small draggable window.** *Start raid?* for the creator of a not-yet-started raid, once per raid, on entering a raid instance (right away when created inside one). *End raid?* for the officer who started a raid still in progress, on leaving the raid group. |
| R22 | (2026-10-18, raid feedback) Items the auctioneer awards to themselves | **Not put on the trade list.** |
| R23 | (2026-10-18, raid feedback 3) Weekly decay after the raid | **Ending a raid with *Need on everything* on asks "Decay 10% BP & GP to everyone in roster?"** (Yes / Not now). Yes decays the whole roster (total, like the Standings decay). |
| R24 | (2026-10-18, raid feedback 3) *Need on everything* when you are not raid leader or assistant | **Turning it on then asks for confirmation first** (a warning popup; cancelling leaves it off). |
| R25 | (2026-10-18, raid feedback 3) Auction tab: loading the next item | **The preselected winner (the first player in the bid list) is highlighted in the list**, so the selection always matches who Award gives the item to. |
| R26 | (2026-10-18, raid feedback) Loot missing from the auction list (2 of 7 Fyrakk drops) | **Also fill it from the Loot Rolls history** (`C_LootHistory`): every roll the auctioneer wins is added, with no bag check (won rolls can be traded in the raid). The chat-line path stays as a backup and now checks the bags for up to ~19 s. Each drop is added once, whichever source sees it first. New icon button in the Auction tab, *Add from loot rolls*, adds the items won at the last boss that aren't in the list yet. |
| R27 | (2026-10-18, raid feedback 4) Getting awarded items traded | **Awarding an item to another player whispers them to open a trade.** Ending a raid while the trade list still has items warns first (how many, to whom; End raid / Cancel). The leave-group reminder's *End raid* and *Start raid* now find the raid by UID, so they still work after a ledger replay or after another officer removed you from the raid. |
| R28 | (2026-10-19, raid feedback) Settings for filling the auction list | **No settings; the section is gone from Settings → Personal.** The auctioneer always fills from corpses and from their own loot. Only Epic or better items of class Weapon (2), Armor (4) or Miscellaneous (15, tier tokens and mounts) are added; everything else (crafting sparks, reagents, consumables) is left out. The old TBC/WotLK item ignore list is gone. Adding an item by hand (alt-click) has no filter. **Pass on loot** follows the same classes: it only passes on Weapon, Armor and Miscellaneous rolls, so raiders roll normally on consumables, housing decor and the like (the old exceptions still apply). *Need on everything* follows the same classes, so raiders get the rest. The classes live in `CONSTANTS.AUCTION_ITEM_CLASSES`. |
| R29 | (2026-10-22) What an OS bid costs | **0 GP**, like Transmog. The bidding window sends 0 and the auctioneer only accepts 0 for an OS bid. OS still ranks above Transmog and is ranked by PR. Auction comm version 6, so older clients are told to update. |

Things in the design that conflict with earlier decisions are left out without asking:
- the "Set alt" right-click item (alt linking removed in Phase 3);
- "standby" counts and rows (bench removed);
- "Right-click: options" in the minimap tooltip (right-click menu removed);
- the decay % shown as a weekly guild setting (decay is a manual action).

## Design language (taken as-is from the spec)

- **Frame chrome:**
  - Primary windows (main, auctioning, bidding) use `PortraitFrameTemplate`, with the BPGP logo set via `SetPortraitToAsset`.
  - Utility windows (award, auction history, trade list) use `DefaultPanelFlatTemplate`.
  - Close button: `UIPanelCloseButtonDefaultAnchors`.
  - All windows are movable and clamped to the screen, with their position saved per character.
- **Tabs** sit along the bottom (`PanelTabButtonTemplate`), like the Character frame.
- **Backgrounds:**
  - content wells: `InsetFrameTemplate`;
  - column headers: `ColumnDisplayTemplate`;
  - selected row: `UI-QuestTitleHighlight` (ADD, gold);
  - alternating rows: white at alpha 0.035.
- **Spacing:** 4 px base grid.
  - 8 between controls and from the frame edge to the inset,
  - 12 between groups,
  - rows 20,
  - buttons and dropdowns 22, inputs 20,
  - a top band of 60 on portrait frames, to clear the portrait.
- **Buttons:**
  - one red primary button per area, bottom-right;
  - secondary buttons use the same template, placed left of the primary;
  - icon buttons: `UIPanelSquareButton`;
  - disabled = `:Disable()`.
  - Bid tier buttons are 74×40 with two lines (name + GP).
- **Fonts:** GameFont objects only.
  - `GameFontNormalHuge`: your PR.
  - `GameFontNormalLarge`: section titles.
  - `GameFontNormal`: labels (gold).
  - `GameFontHighlight`: values (white).
  - `GameFontDisableSmall`: meta text.
  - `NumberFontNormal`: EP / GP / PR.
- **Colours:**
  - class colours for names, item quality colours for items;
  - green for EP, gold for GP and PR, grey for decay, red for problems;
  - bid tiers coloured like item qualities (Max orange, Large purple, Medium blue, Small green, Base white), OS gold-ish, Pass grey;
  - orange only in test mode.
- **Test mode:** orange frame edge (NineSlice vertex colour), tinted portrait, " — TEST MODE" in the title, and a one-line orange banner: "Changes are local. Leaving test mode reloads the UI."

## Windows

| Window | Size | Notes / deviations from the spec |
|---|---|---|
| **Main: Standings (officer)** | 720×480 min, resizable (D9) | Columns: # · class icon + Name · EP · GP · PR (sorted), multi-select. The right panel holds **Act on** (Selected / Raid / Roster, with the selected names listed under it) · Note · EP + Award EP · GP + Award GP (R1) · Decay % + type + Decay. Footer: sync status and event count. Right-click a player: Award item (R7) · Remove from roster. Every action confirms (R6). |
| **Main: Standings (raider)** | 520×440 | Own row pinned on top, "YOUR PR · #3 OF 18" + PR big in the header; footer "Min. standing N to bid" + sync status (R11). |
| **Main: History** | | Columns: Time · Type (EP/GP/DEC) · Player · Amount · Note/Item · By. Header: type dropdown and player search, as the spec's History header. |
| **Main: Raids** | | Same columns as today (Name · Status · Created), new chrome; officer panel to create raids with the on-time bonus. |
| **Main: Roster** (officers) | | Today's *Manage roster* with new chrome. Filter checkboxes and search stay in the side panel (they're useful here). |
| **Main: Audit** (officers) | | Separate tab (R4). Skipped ledger entries (Phase 8, S3) show in red, with a count in the footer. |
| **Main: Bid button** | | Right of the page header, everyone, only while an auction runs (R13). Opens the Bidding window. |
| **Main: Settings** | | One tab (R3), with section navigation on the left: **Personal** (everyone), **Guild** and **Gear values** (everyone sees them; only officers edit, D3), **Advanced**: test mode for everyone (T1); logging and remove roster for officers. |
| **States** | | Empty ("No standings yet…"), syncing overlay (`LoadingSpinnerTemplate` + progress bar, replaces "BPGP is processing"), test mode, read-only settings. |
| **Auctioning** | Auction tab (R12; was 540×470) | Item queue on the left (36 px item buttons, border colour shows state); item + note; five tier GP fields (named); length, anti-snipe, *Simulate bids* (test mode), roll, Clear list, **Start/Stop**; bid list (Name · Bid · PR · Roll · equipped items); Remove on award (default on) · Value · **Award**. States: idle / running (inputs locked, timer in header) / finished (winner preselected, Enter awards, R10). |
| **Bidding** | 480×440 | Header: "Item 2 of 4 · 14s left", "YOUR PR 1.82". Item row with ilvl and slot, **Next ›**. One row of 5 tier buttons with GP on the button; OS · Transmog (R14) · Pass · Cancel; status line (accepted/denied); open bid list. Clicking another tier replaces your bid. Only an unusable item asks for confirmation. Comfortable layout only (R9). |
| **Timer bar** | 270×24 | Optional, off by default (R9). Turns red under 5 s, shows "+5s" on anti-snipe; clicking it opens Bidding. |
| **Alert toasts** | 276×72 | Existing AlertFrame subsystems with `LootWonAlertFrameTemplate` art. |
| **Award** | 300×205 | Item, player dropdown, GP + tier/slot hint, Cancel · **Award**. Opened by right-click in Standings (prefilled) or the award modifier click. |
| **Auction history** | 265×400 | Entries expandable to show bids; right-click (MenuUtil): Post bids · Remove auction · Remove older than 7 days · Remove all…. |
| **Trade list** | Trade tab (R17) | Columns: item · winner; right-click: Open trade · Remove; Alt-click opens the trade. |
| **Minimap** | 31×31 | Tooltip: version, TEST MODE, sync status, events, "Left-click: open BPGP". |
| **Popups** | 320 wide | `StaticPopup` for every confirmation (R6). |

## Building blocks

The spec's component list maps onto a small set of shared pieces in a new `Modules/UI/` folder. Windows use these pieces instead of AceGUI and lib-st:

| Piece | Built on |
|---|---|
| Window factory (portrait / flat, title, close, movable, clamped, saved position, test-mode tint) | `PortraitFrameTemplate`, `DefaultPanelFlatTemplate` |
| Bottom tabs | `PanelTabButtonTemplate`, `PanelTemplates_SetTab` |
| List with sortable column headers, hover/selection, multi-select, right-click | `WowScrollBoxList`, `MinimalScrollBar`, `CreateScrollBoxListLinearView`, `ColumnDisplayTemplate` |
| Buttons (primary, secondary, icon, bid tier) | `UIPanelButtonTemplate`, `UIPanelSquareButton` |
| Inputs (numeric, item link, search) | `InputBoxTemplate`, `SearchBoxTemplate` |
| Dropdown | `WowStyle1DropdownTemplate` |
| Checkbox | `UICheckButtonTemplate` |
| Context menus | `MenuUtil.CreateContextMenu` (replaces LibUIDropDownMenu) |
| Item buttons + state border | `ItemButtonTemplate`, `UI-ActionButton-Border` |
| Settings rows (label + control, read-only state) | the pieces above |

Data stays where it is: the table feeders, managers and ledger code don't change. Only the view layer is replaced. AceGUI, AceConfigDialog, lib-st and LibUIDropDownMenu can be removed from `Libs/` once nothing uses them. The slash commands keep AceConfigCmd, or get a small handler.

**Before building, verify every template and atlas name in-game** (`/tinspect`, the Texture Atlas Viewer). Names change between patches; the spec says so too.

## Phase 9 breakdown

| Step | Content | Done when |
|---|---|---|
| **9a** | Shared pieces in `Modules/UI/` (table above), a test window to try them, and the test-mode tint | Every piece works in a scratch window at UI scale 0.64 and 1.15 |
| **9b** | Main window rebuilt on the pieces: Standings (officer + raider view), History, Raids, Roster, Audit, empty and syncing states; resizable; right-click *Award item* | All main-window actions from Phases 3-6 work in the new window |
| **9c** | Settings tab (Personal, Guild, Gear values, Advanced); remove all Options → AddOns pages; `/bpgp config` | Every K/F setting from ui-overhaul.md is reachable; nothing is left under Options → AddOns |
| **9d** | Auctioning and Bidding windows, docked countdown, optional timer bar, winner preselect + Enter, auto-advance | The test-mode raid evening (Phase 4 list) runs in the new windows |
| **9e** | Award, Auction history, Trade list, alert toasts, minimap tooltip, popups | No AceGUI window is left |
| **9f** | Remove AceGUI / AceConfigDialog / lib-st / LibUIDropDownMenu / unused LibSharedMedia widgets; update the libs README and licences | `Libs/` only has what's used; check_addon passes |

Each step ends with an in-game check list, like the earlier phases.
