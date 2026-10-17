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
| R12 | (2026-10-17, after 9d) How do officers open auctioning from the GUI? | **An Auction tab in the main window with the full auctioning UI** (officers only, right after Standings). The separate Auctioning window is gone; alt-click and `/bpepgp auction` open the tab. |
| R13 | (2026-10-17) How does a raider reopen the Bidding window after closing it? (only `/bpepgp bid` did) | **A Bid button in the main window header**, shown to everyone while an auction runs. |

Things in the design that conflict with earlier decisions are left out without asking:
- the "Set alt" right-click item (alt linking removed in Phase 3);
- "standby" counts and rows (bench removed);
- "Right-click: options" in the minimap tooltip (right-click menu removed);
- the decay % shown as a weekly guild setting (decay is a manual action).

## Design language (taken as-is from the spec)

- **Frame chrome:**
  - Primary windows (main, auctioning, bidding) use `PortraitFrameTemplate`, with the BP EPGP logo set via `SetPortraitToAsset`.
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
| **States** | | Empty ("No standings yet…"), syncing overlay (`LoadingSpinnerTemplate` + progress bar, replaces "BP EPGP is processing"), test mode, read-only settings. |
| **Auctioning** | Auction tab (R12; was 540×470) | Item queue on the left (36 px item buttons, border colour shows state); item + note; five tier GP fields (named); length, anti-snipe, *Simulate bids* (test mode), roll, Clear list, **Start/Stop**; bid list (Name · Bid · PR · Roll · equipped items); Remove on award (default on) · Value · **Award**. States: idle / running (inputs locked, timer in header) / finished (winner preselected, Enter awards, R10). |
| **Bidding** | 480×440 | Header: "Item 2 of 4 · 14s left", "YOUR PR 1.82". Item row with ilvl and slot, **Next ›**. One row of 5 tier buttons with GP on the button; OS · Pass · Cancel; status line (accepted/denied); open bid list. Clicking another tier replaces your bid. Only an unusable item asks for confirmation. Comfortable layout only (R9). |
| **Timer bar** | 270×24 | Optional, off by default (R9). Turns red under 5 s, shows "+5s" on anti-snipe; clicking it opens Bidding. |
| **Alert toasts** | 276×72 | Existing AlertFrame subsystems with `LootWonAlertFrameTemplate` art. |
| **Award** | 300×205 | Item, player dropdown, GP + tier/slot hint, Cancel · **Award**. Opened by right-click in Standings (prefilled) or the award modifier click. |
| **Auction history** | 265×400 | Entries expandable to show bids; right-click (MenuUtil): Post bids · Remove auction · Remove older than 7 days · Remove all…. |
| **Trade list** | 350×230 | Columns: item · winner · trade time left; right-click: Open trade · Remove. Stays its own window (R7). |
| **Minimap** | 31×31 | Tooltip: version, TEST MODE, sync status, events, "Left-click: open BP EPGP". |
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
| **9c** | Settings tab (Personal, Guild, Gear values, Advanced); remove all Options → AddOns pages; `/bpepgp config` | Every K/F setting from ui-overhaul.md is reachable; nothing is left under Options → AddOns |
| **9d** | Auctioning and Bidding windows, docked countdown, optional timer bar, winner preselect + Enter, auto-advance | The test-mode raid evening (Phase 4 list) runs in the new windows |
| **9e** | Award, Auction history, Trade list, alert toasts, minimap tooltip, popups | No AceGUI window is left |
| **9f** | Remove AceGUI / AceConfigDialog / lib-st / LibUIDropDownMenu / unused LibSharedMedia widgets; update the libs README and licences | `Libs/` only has what's used; check_addon passes |

Each step ends with an in-game check list, like the earlier phases.
