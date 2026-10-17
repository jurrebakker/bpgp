# Claude Design brief: BPGP UI redesign

Paste everything below the line into Claude Design, and attach the screenshots listed under "Attachments".

---

## Goal

Redesign the UI of **BPGP**, a World of Warcraft addon, so it looks and feels like a native, high-quality Blizzard window instead of a generic addon. Today it's built with the AceGUI library: flat dark panels, generic red buttons everywhere, small dropdown arrows, cramped sidebars, plain tables. I want it to sit next to Blizzard's own frames (Guild & Communities, Group Finder, Auction House, Great Vault, Character frame) and look like it belongs.

Deliver mockups and a component spec that a developer can rebuild **in Lua with Blizzard's own frame templates and texture atlases**. Don't design anything that needs custom art beyond one small addon icon.

## Context

- **Game:** World of Warcraft retail, expansion *Midnight* (patch 12.x). English only.
- **What the addon does:** EPGP loot distribution for one raiding guild. Players earn **EP** (effort points) for raiding and spend **GP** (gear points) when they win loot. **PR = EP ÷ GP** is the priority; the highest PR wins. Officers award EP, run loot auctions and decay points weekly; raiders bid on loot.
- **Two audiences:**
  - **Officers** (guild ranks with "Is Officer"): manage the roster, award/decay points, create raids, run auctions, award loot. They see everything and can edit.
  - **Raiders**: check standings and history, and bid during auctions. Everything they see is read-only, except the bidding window.
- **Usage moment:** mostly during a raid (busy screen, combat, voice chat). Bidding must be fast and obvious: one click per bid, readable at a glance.
- **Test mode:** there's a "test mode" with separate test data. While it's on, windows must clearly show it (today: orange "TEST MODE" in the title and an orange minimap icon).

## Visual direction

- **Native Blizzard look:** use the same frame chrome as Blizzard's panels: `ButtonFrameTemplate` / `PortraitFrameTemplate` (portrait circle top-left with our icon, gold title, close button), `InsetFrameTemplate` content wells, NineSlice borders, parchment or dark-stone backgrounds as in the Guild/Communities frame.
- **Tabs** like Blizzard panels: `PanelTabButtonTemplate` along the bottom edge (Character/Guild frame style), or top tabs as in the Communities frame. Recommend one.
- **Buttons:** red `UIPanelButtonTemplate` only for real actions. Use a clear hierarchy: one primary action per area, secondary actions quieter (e.g. `UIPanelButtonNoTooltipTemplate`, icon buttons, or links).
- **Inputs:** `InputBoxTemplate` / `SearchBoxTemplate`, the modern `WowStyle1DropdownTemplate` dropdown, `UICheckButtonTemplate` checkboxes.
- **Lists:** Blizzard `ScrollBox` lists with `MinimalScrollBar`, column headers like the Guild roster / Communities roster (`ColumnDisplay` style, sortable headers), zebra or hover highlight, selection highlight in Blizzard blue.
- **Typography:** Blizzard fonts only: `GameFontNormal` (gold) for labels/headers, `GameFontHighlight` (white) for values, `GameFontDisable` (grey) for secondary text, `GameFontNormalLarge` for titles. Numbers right-aligned or centred consistently.
- **Colour meaning:**
  - **Class colours** for player names.
  - **Item quality colours** for item links.
  - **Green** for gains and positive PR, **red** for losses and negative PR.
  - **Gold** for labels.
  - **Orange** only for test mode.
- **Icons:** class icons, item icons, and Blizzard atlases (e.g. raid icons, dice for /roll, checkmarks, warning). No custom illustrations.
- **Density:** comfortable but compact, like the Communities roster. It must work at 1920×1080 with UI scale 1.0 and at smaller scales.

## Windows to design

Sizes are today's values; you can change them. Planned: the main window becomes **resizable**, minimum width around **1050 px**, to fit 9 tabs.

### 1. Main window "BPGP" (everyone)

Opened from the minimap icon or `/bpgp gui`. Today it's 800×572: a table on the left and a scrollable options sidebar on the right. Tabs today: **Standings, History, Raids, Manage roster, Audit**. Tabs planned later: **Settings, Guild settings, Gear values, Advanced**. Raiders see every tab but can't edit; officer-only controls are hidden for them.

**1a. Standings tab** (the most used screen)
- **Table:** class icon · Name (class colour) · **PR** (green if > 0, red if < 0, sorted high→low by default) · EP · GP. About 25 visible rows, multi-select. Your own row is highlighted.
- **Hover tooltip on a player:**
  - EP and GP,
  - the latest loot (item links with GP),
  - the latest point changes (EP/GP, note, date).
- **Right-click a player (officers):** "Remove from roster".
- **Officer sidebar:**
  - "Set up BPGP" button. It only appears when no roster exists yet, before the first use.
  - **Action context** dropdown: *Selected players / Whole roster / Current raid*.
  - **Note** text field (max 25 characters; goes into history).
  - **EP** number field + **Award EP** button.
  - **GP** number field + **Award GP** button.
  - **Decay %** number field + **Decay** button + type dropdown (*EP/GP*, *EP*, *GP*).
  - Every award or decay asks for confirmation ("Award 100 EP to 5 selected players?").
- **Empty state:** no roster yet (officer: setup button; raider: "Waiting for an officer to set up BPGP").

**1b. History tab**
- **Table:** icon (item icon for loot, a coin/points icon for EP/GP) · Info (item link or reason + note) · Value (green, with "EP"/"GP") · Date · Player.
- **Sidebar:**
  - **Player** dropdown (everyone, or one player),
  - **History type** (Loot / Points).
- **Right-click (officers):** "Remove selected" (undo).

**1c. Raids tab**
- **Table:** Name · Status (Created / In progress / Finished / Stale) · Created date.
- **Hover:** raid settings (on-time bonus) and member list.
- **Right-click (officers):** Start / End / Join / Remove selected raid.
- **Officer sidebar:**
  - "Overrides" section: On-time bonus checkbox + EP value,
  - Raid name field,
  - **Create raid** button.

**1d. Manage roster tab**
- **Table:** class icon · Name · **In roster** ("Yes" in green, or empty) · addon Version.
  - The list shows all max-level guild members, plus roster members who left the guild.
  - Officers' rows are tinted green.
  - Multi-select.
- **Sidebar for everyone:**
  - **Filter** checkboxes: In raid, In guild, External, plus one checkbox per guild rank (e.g. Guild Master, Officer, Officers Alt, Veteran, Boomer, Member, Member Alt, Trial),
  - **Search** field (name, at least 3 characters).
- **Officer sidebar:** **Add to roster**, **Remove from roster**. The same two actions are in the right-click menu.

**1e. Audit tab** (officers mostly)
- **Table:** # · Time · Type (short code) · Description · Author.
- This is the full change log: points, loot, raids, roster changes.
- **Right-click:** "Remove selected" (undo an entry).

**1f. Settings tabs (planned, design them)**
- **Settings** (personal, everyone):
  - UI scale,
  - addon sounds,
  - minimap icon on/off,
  - bidding-window behaviour (auto-open, close on bid, advance to next item, ignore unusable items, hide in combat),
  - timer bar size, font and texture,
  - alert popups on/off,
  - auction/award click modifiers (e.g. Alt, Alt+Shift).
- **Guild settings** (shared; officers edit, others read-only):
  - starting EP/GP,
  - minimum GP,
  - rounding (EP/GP and PR),
  - on-time bonus,
  - tier button names (5 names for Base, Small, Medium, Large, Max),
  - minimum standing to bid,
  - allow off-spec bids,
  - auction length, anti-snipe seconds, multiply time by item count, /roll time.
- **Gear values** (officers edit):
  - a grid of **gear slots × 5 tiers** with GP values,
  - a list of per-item value overrides (item, 5 values, remove).
- **Advanced** (officers):
  - **Test mode** section: enter/leave, "Reset: empty", "Reset: copy of live", simulated raid group size,
  - logging level,
  - remove roster (danger zone, red, confirm).

### 2. Auctioning window (officers)

Today it's 570 px tall. The officer runs loot auctions here. The Blizzard **Auction House** is a good reference.
- **Left: item list.** A column of 32 px item icons, each with a count overlay and a coloured border by state.
- **Selected item panel:**
  - item icon + item link field (paste or type an item ID; also filled by Alt-clicking an item in bags or loot),
  - **Note** field,
  - **5 GP value fields**, labelled with the tier button names.
- **Auction controls:**
  - auction length (s), anti-snipe (s),
  - **Start / Stop** (primary),
  - **Roll** (dice icon, starts a /roll phase),
  - **Clear list**.
  - Test mode only: **Simulate bids**.
- **Bid list:** class icon · Name · Bid (tier name or "OS"/"Pass"/"Cancel", colour by type) · Current PR · Roll · up to 5 small icons of the bidder's currently equipped items in that slot.
  - Clicking a bid selects the winner and fills the award value.
- **Award row:** Value field + **Award** button (primary), and a "Remove on award" checkbox.
- **States:** idle (building the list), auction running (countdown visible, inputs locked), rolling, finished (pick winner).

### 3. Bidding window (raiders; the most important raider screen)

It opens automatically when an auction starts. Today the title reads "Bidding | Current: 60 PR".
- **Left: vertical list of auctioned items** (icons). The border colour shows state:
  - current = turquoise,
  - bid accepted = green,
  - bid denied = gold,
  - passed/cancelled = blue,
  - can't use = red.
- **Item row:** icon + item link (quality colour, item tooltip on hover) + **Next** button.
- **Bid buttons:** one big button per tier, named by the guild (defaults: *Max, Large, Medium, Small, Base*), each costing its own GP (shown in the tooltip; consider showing it on the button). Also an **OS** (off-spec) button, plus **Pass** and **Cancel**. Today the buttons sit two per row.
- **Bid list** (open auction, everyone sees all bids): class · Name · Bid (tier name) · Current PR · Roll · equipped-item icons.
- **Your PR** must be prominent.
- **Timer bar:** a separate draggable progress bar with the item icon and seconds left. Anti-snipe can extend it.
- **Alert toasts** (Blizzard `AlertFrame` style): "Bid accepted", "Bid denied (reason)", "You received X EP".
- Show the window in compact and comfortable variants; one click must place a bid (with confirmation only when bidding on an unusable item).

### 4. Award window (officers)
- Manual award outside an auction: item icon + item link field, player dropdown, GP value, **Award** button.
- Small (≈ 205 px tall).

### 5. Auction history (officers)
- Narrow window (265 px): past auctions, newest first. Each entry shows the item, winner and price, with the bids expandable.
- **Right-click:** Post bids to chat, Remove auction, Remove old, Remove all.

### 6. Trade list (officers)
- 350 px wide: awarded items not yet traded (item link + winner).
- **Right-click:** Open trade, Remove.
- Items are put into the trade window automatically when you trade the winner.

### 7. Minimap button
- Our round icon. Left-click opens the main window. Orange tint in test mode.
- **Tooltip:**
  - "BPGP vX",
  - "TEST MODE" (orange, when on),
  - sync status ("In-Sync" green / "Sync ongoing" yellow / "Incoherent state" red),
  - number of events.

### 8. Popups
- Confirmations ("Award 100 EP to everyone in raid?", "Switch to test mode? The UI will reload.") use Blizzard `StaticPopup` style.

## Attachments (screenshots)

Current BPGP UI:
- Standings tab (officer view, with sidebar)
- History, Raids, Manage roster, Audit tabs
- Auctioning window during an auction
- Bidding window during an auction (named tier buttons)
- Settings pages under Options → AddOns

Blizzard reference frames:
- Guild & Communities (roster list, tabs, member details)
- Auction House (item list, search, bid/buyout area)
- Group Finder / Premade Groups
- Character frame (portrait frame, bottom tabs)
- Great Vault (reward cards)
- Group Loot roll frame and alert toasts

## What I want back

1. A short **design language**: frame chrome, backgrounds, spacing grid, button hierarchy, typography and colour roles, all mapped to Blizzard templates or atlases by name where you can.
2. **Mockups** for every window above, at 1× scale, with real-looking data:
   - player names in class colours,
   - realistic EP/GP/PR (e.g. EP 1250, GP 830, PR 1.51),
   - Midnight-era item names.
   For the main window, give both an officer view and a raider (read-only) view.
3. **States:** empty, loading/syncing ("BPGP is processing…" today), test mode, read-only, auction running vs finished, bid accepted/denied.
4. A **component list** with sizes, paddings and the Blizzard template/atlas to use for each, so it can be built in Lua.
5. Suggestions for what to **simplify or merge** (fewer clicks during raids), with the reasoning.

## Constraints

- It must be buildable with WoW's Lua UI API and Blizzard's templates and atlases. No web-only effects (no blur, no CSS shadows beyond what Blizzard textures give, no custom fonts).
- One addon icon is available (a red/black round logo); everything else comes from the game.
- Windows are movable and must stay usable when the game's UI scale is 0.64–1.15.
- Officer-only controls are hidden for raiders, not shown disabled (except in the settings tabs, where non-officers see guild settings read-only).
