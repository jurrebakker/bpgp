-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI

--[[
    /bpepgp uitest: a scratch window that shows every shared UI piece (Phase 9a), so they can be
    checked in-game at different UI scales before the real windows are rebuilt on them.
    It only shows fake data and never writes anything.
]]--

local S = UI.SPACE

local FAKE_PLAYERS = {
    {"Aldren", "WARRIOR", 1720, 1035}, {"Brisa", "PALADIN", 990, 780}, {"Corvin", "HUNTER", 1640, 1150},
    {"Delwyn", "ROGUE", 1420, 1060}, {"Elowen", "PRIEST", 1380, 905}, {"Fenric", "DEATHKNIGHT", 1890, 980},
    {"Galora", "SHAMAN", 1295, 915}, {"Hesper", "MAGE", 870, 760}, {"Iskander", "WARLOCK", 1060, 890},
    {"Jorah", "MONK", 1250, 830}, {"Kaelis", "DRUID", 1510, 830}, {"Lyra", "DEMONHUNTER", 2140, 1020},
    {"Morwen", "EVOKER", 1180, 960}, {"Nyssa", "DRUID", 760, 710}, {"Orrin", "SHAMAN", 940, 850},
    {"Perrin", "PALADIN", 620, 640}, {"Quill", "MONK", 540, 600}, {"Rhosyn", "SHAMAN", 410, 520},
}

local TIERS = { {"x", "Max", 300}, {"l", "Large", 200}, {"m", "Medium", 120}, {"s", "Small", 60}, {"b", "Base", 20} }

local function FakeRows()
    local rows = {}
    for _, p in ipairs(FAKE_PLAYERS) do
        local name, classFile, ep, gp = p[1], p[2], p[3], p[4]
        rows[#rows + 1] = {
            id = name,
            classFile = classFile,
            values = { name = name, ep = ep, gp = gp, pr = math.floor(ep / gp * 100 + 0.5) / 100 },
        }
    end
    return rows
end

---@class UIDemo
---@field window table?
---@field flat table?
local UIDemo = {}

local function BuildListTab(self, content)
    local inset = UI.CreateInset(content)
    inset:SetPoint("TOPLEFT")
    inset:SetPoint("BOTTOMRIGHT", 0, 18)

    local footer = UI.CreateLabel(content, "", "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", S.XS, 2)

    local list = UI.CreateList(inset, {
        columns = {
            { key = "name", title = CLM.L["Name"], width = 0, classIcon = true,
              color = function(row) return UI.GetClassColor(row.classFile) end },
            { key = "ep", title = CLM.L["EP"], width = 70, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true },
            { key = "gp", title = CLM.L["GP"], width = 70, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true },
            { key = "pr", title = CLM.L["PR"], width = 64, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true,
              text = function(row) return string.format("%.2f", row.values.pr) end,
              color = function() return UI.COLOR.GOLD end },
        },
        multiSelect = true,
        sortKey = "pr",
        sortDesc = true,
        onSelectionChanged = function(selection)
            footer:SetText(string.format("%d selected · ctrl-click adds · shift-click selects a range · right-click for a menu", #selection))
        end,
        onRightClick = function(row, rowFrame)
            UI.ShowContextMenu(rowFrame, row.values.name, {
                { text = "Award item", func = function() LOG:Message("UI test: Award item %s", row.values.name) end },
                { divider = true },
                { text = "Remove from roster", color = UI.COLOR.BAD, func = function() LOG:Message("UI test: remove %s", row.values.name) end },
            })
        end,
        onEnter = function(row, rowFrame)
            GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.values.name, UI.GetClassColor(row.classFile):GetRGB())
            GameTooltip:AddDoubleLine(row.values.ep .. " " .. CLM.L["EP"], row.values.gp .. " " .. CLM.L["GP"], 0.12, 1, 0, 1, 0.82, 0)
            GameTooltip:Show()
        end,
    })
    list:SetPoint("TOPLEFT", S.XS, -S.XS)
    list:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
    list:SetData(FakeRows())
    footer:SetText("0 selected · click a row to select it · click headers to sort")
end

local function BuildControlsTab(self, content)
    local y = -S.XS
    local function Row(height)
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", S.S, y)
        row:SetPoint("RIGHT", -S.S, 0)
        row:SetHeight(height)
        y = y - height - S.M
        return row
    end
    local function Caption(row, text)
        local label = UI.CreateLabel(row, text, "GameFontNormal")
        label:SetPoint("LEFT")
        label:SetWidth(110)
        return label
    end

    -- Buttons
    local row = Row(S.BUTTON)
    Caption(row, "Buttons")
    local disabled = UI.CreateButton(row, CLM.L["Award"], 80)
    disabled:SetPoint("LEFT", 110, 0)
    disabled:Disable()
    local dice = UI.CreateIconButton(row, "Interface\\Buttons\\UI-GroupLoot-Dice-Up", CLM.L["Roll"])
    dice:SetPoint("LEFT", disabled, "RIGHT", S.S, 0)
    local primary = UI.CreateButton(row, CLM.L["Award"], 80, function() LOG:Message("UI test: primary") end)
    primary:SetPoint("RIGHT")
    local secondary = UI.CreateButton(row, "Clear list", 96)
    secondary:SetPoint("RIGHT", primary, "LEFT", -S.S, 0)

    -- Bid tier buttons
    row = Row(40)
    Caption(row, "Bid tiers")
    local previous
    local tierButtons = {}
    for _, tier in ipairs(TIERS) do
        local button = UI.CreateTierButton(row)
        button:SetTier(tier[2], tier[3], UI.TIER_COLOR[tier[1]])
        button:SetScript("OnClick", function(clicked)
            for _, b in ipairs(tierButtons) do b:SetSelected(b == clicked) end
        end)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        else
            button:SetPoint("LEFT", 110, 0)
        end
        previous = button
        tierButtons[#tierButtons + 1] = button
    end

    -- OS / Pass / Cancel
    row = Row(24)
    Caption(row, "Other bids")
    previous = nil
    for _, text in ipairs({ CLM.L["OS"], CLM.L["Pass"], CLM.L["Cancel"] }) do
        local button = UI.CreateButton(row, text, 74)
        button:SetHeight(24)
        if previous then button:SetPoint("LEFT", previous, "RIGHT", 6, 0) else button:SetPoint("LEFT", 110, 0) end
        previous = button
    end

    -- Inputs
    row = Row(S.INPUT)
    Caption(row, "Inputs")
    local amount = UI.CreateInput(row, 64, true)
    amount:SetPoint("LEFT", 116, 0)
    amount:SetText("100")
    local note = UI.CreateInput(row, 160, false)
    note:SetPoint("LEFT", amount, "RIGHT", S.M, 0)
    local search = UI.CreateSearchBox(row, 150)
    search:SetPoint("LEFT", note, "RIGHT", S.M, 0)

    -- Dropdown + checkbox
    row = Row(S.BUTTON + 2)
    Caption(row, "Choices")
    local target = "raid"
    local dropdown = UI.CreateDropdown(row, 140,
        function() return { {text = "Selected", value = "selected"}, {text = "Raid", value = "raid"}, {text = "Roster", value = "roster"} } end,
        function() return target end,
        function(value) target = value end)
    dropdown:SetPoint("LEFT", 110, 0)
    local check = UI.CreateCheckbox(row, CLM.L["Remove on award"])
    check:SetPoint("LEFT", dropdown, "RIGHT", S.M, 0)
    check:SetChecked(true)

    -- Item buttons with queue states
    row = Row(36)
    Caption(row, "Items")
    previous = nil
    local states = { {19019, CreateColor(0.25, 0.88, 0.82)}, {6948, CreateColor(0.12, 1, 0)}, {2589, UI.COLOR.BAD}, {19019, nil} }
    for i, state in ipairs(states) do
        local button = UI.CreateItemButton(row, i == 4 and 24 or 36)
        button:SetItem(state[1])
        button:SetState(state[2])
        if previous then button:SetPoint("LEFT", previous, "RIGHT", S.M, 0) else button:SetPoint("LEFT", 114, 0) end
        previous = button
    end

    -- Progress bar + divider
    row = Row(18)
    Caption(row, "Progress")
    local bar = UI.CreateProgressBar(row, 270, 18)
    bar:SetPoint("LEFT", 110, 0)
    bar:SetProgress(0.42, "412 / 980")
    local divider = UI.CreateDivider(content)
    divider:SetPoint("TOPLEFT", S.S, y + S.XS)
    divider:SetPoint("RIGHT", -S.S, 0)

    -- Utility window
    row = Row(S.BUTTON)
    Caption(row, "Windows")
    local open = UI.CreateButton(row, "Open utility window", 160, function() UIDemo:ToggleFlat() end)
    open:SetPoint("LEFT", 110, 0)
end

local function Build(self)
    local window = UI.CreateWindow({
        name = "BPEPGP_UITestWindow",
        title = "BP EPGP - UI test",
        width = 720, height = 480,
        portrait = true,
        resizable = true,
        dbKey = "uitest",
    })
    local top = S.TOP_BAND
    local banner = UI.CreateTestModeBanner(window)
    if banner then
        banner:SetPoint("TOPLEFT", S.S, -top)
        banner:SetPoint("TOPRIGHT", -S.S, -top)
        top = top + 24 + S.XS
    end
    local heading = UI.CreateLabel(window, "Shared UI pieces", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 60, -32)

    local pages = {}
    for i = 1, 2 do
        local page = CreateFrame("Frame", nil, window)
        page:SetPoint("TOPLEFT", S.S, -top)
        page:SetPoint("BOTTOMRIGHT", -S.S, S.S)
        page:Hide()
        pages[i] = page
    end
    BuildListTab(self, pages[1])
    BuildControlsTab(self, pages[2])
    UI.CreateTabs(window, { "List", "Controls" }, function(id)
        for i, page in ipairs(pages) do page:SetShown(i == id) end
    end)
    UI.SelectTab(window, 1)
    self.window = window
end

function UIDemo:Toggle()
    if not self.window then Build(self) end
    self.window:SetShown(not self.window:IsShown())
end

function UIDemo:ToggleFlat()
    if not self.flat then
        local flat = UI.CreateWindow({ name = "BPEPGP_UITestFlatWindow", title = "Utility window", width = 300, height = 205, dbKey = "uitestflat" })
        local text = UI.CreateLabel(flat, "DefaultPanelFlatTemplate: award, auction history and trade list use this frame.", "GameFontHighlight")
        text:SetPoint("TOPLEFT", S.M, -36)
        text:SetPoint("RIGHT", -S.M, 0)
        text:SetWordWrap(true)
        local award = UI.CreateButton(flat, CLM.L["Award"], 80)
        award:SetPoint("BOTTOMRIGHT", -S.M, S.M)
        local cancel = UI.CreateButton(flat, CLM.L["Cancel"], 80, function() flat:Hide() end)
        cancel:SetPoint("RIGHT", award, "LEFT", -6, 0)
        self.flat = flat
    end
    self.flat:SetShown(not self.flat:IsShown())
end

function UIDemo:Initialize()
    CLM.MODULES.ConfigManager:RegisterSlash({
        uitest = {
            type = "execute",
            name = "UI test",
            desc = "Show the shared UI pieces (development)",
            func = function() UIDemo:Toggle() end,
        }
    })
end

CLM.GUI.UIDemo = UIDemo
