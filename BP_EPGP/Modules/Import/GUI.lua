-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI
local S = UI.SPACE

--[[
    Standings import window (Phase 6, rebuilt on Modules/UI in 9e). Officers only.
    Paste "Name, EP, GP" lines, Preview checks every line, Apply writes the SET entries.
]]--

local WIDTH, HEIGHT = 640, 560

local STATUS_COLOR = {
    [CONSTANTS.IMPORT_STATUS.UPDATE]    = UI.COLOR.EP,
    [CONSTANTS.IMPORT_STATUS.ADD]       = CreateColor(0.25, 0.88, 0.82),
    [CONSTANTS.IMPORT_STATUS.NOT_GUILD] = UI.COLOR.BAD,
    [CONSTANTS.IMPORT_STATUS.DUPLICATE] = UI.COLOR.BAD,
    [CONSTANTS.IMPORT_STATUS.INVALID]   = UI.COLOR.BAD,
}

---@class StandingsImportGUI
---@field window table?
---@field input table EditBox
---@field overwrite table CheckButton
---@field rows StandingsImportRow[]
---@field _initialized boolean
local StandingsImportGUI = { rows = {} }

local function UpdateStatus(self)
    local toImport, toAdd, skipped = CLM.MODULES.StandingsImport:Count(self.rows)
    self.status:SetText(string.format(CLM.L["%s to import (%s new on the roster), %s skipped"], toImport, toAdd, skipped))
    local hasHistory = CLM.MODULES.StandingsImport:RosterHasHistory()
    self.overwrite:SetEnabled(hasHistory)
    if not hasHistory then self.overwrite:SetChecked(false) end
end

function StandingsImportGUI:Preview()
    self.rows = CLM.MODULES.StandingsImport:Parse(self.input:GetText())
    local data = {}
    for index, row in ipairs(self.rows) do
        data[#data + 1] = {
            id = index,
            status = row.status,
            values = {
                line = row.line, status = CONSTANTS.IMPORT_STATUS_GUI[row.status] or "",
                name = row.name or "", ep = row.ep or "", gp = row.gp or "", note = row.note or "",
            },
        }
    end
    self.list:SetData(data)
    UpdateStatus(self)
end

function StandingsImportGUI:RequestApply()
    self:Preview()
    local toImport, toAdd, skipped = CLM.MODULES.StandingsImport:Count(self.rows)
    if toImport == 0 then
        LOG:Message(CLM.L["Nothing to import."])
        return
    end
    local overwrite = self.overwrite:GetChecked() and true or false
    if CLM.MODULES.StandingsImport:RosterHasHistory() and not overwrite then
        LOG:Message(CLM.L["The roster already has points or loot. Tick overwrite to import anyway."])
        return
    end
    UI.Confirm(string.format(CLM.L["Set EP and GP for %s players (%s new on the roster)? %s lines are skipped."], toImport, toAdd, skipped)
        .. "\n\n" .. CLM.L["This writes ledger entries that sync to the whole guild."], function()
        if CLM.MODULES.StandingsImport:Apply(self.rows, overwrite) then
            -- Show the result once the entries are applied
            C_Timer.After(1, function() self:Preview() end)
        end
    end)
end

-- Multi-line paste box: a scroll frame around a multi-line EditBox, on an inset
local function CreatePasteBox(parent)
    local inset = UI.CreateInset(parent)
    local scroll = UI.CreateWithTemplates("ScrollFrame", nil, inset, { "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" })
    scroll:SetPoint("TOPLEFT", S.S, -S.S)
    scroll:SetPoint("BOTTOMRIGHT", -26, S.S)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(WIDTH - 80)
    edit:SetHeight(120)
    edit:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    -- Keep the cursor in view while pasting long lists (Blizzard helpers; skipped if a patch drops them)
    if ScrollingEdit_OnCursorChanged and ScrollingEdit_OnUpdate and ScrollingEdit_OnTextChanged then
        edit:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
        edit:SetScript("OnUpdate", function(box, elapsed) ScrollingEdit_OnUpdate(box, elapsed, scroll) end)
        edit:SetScript("OnTextChanged", function(box) ScrollingEdit_OnTextChanged(box, scroll) end)
    end
    scroll:SetScrollChild(edit)
    scroll:HookScript("OnSizeChanged", function(_, width) edit:SetWidth(math.max(width, 1)) end)
    -- Clicking anywhere in the box focuses it, not only on the text
    inset:EnableMouse(true)
    inset:SetScript("OnMouseDown", function() edit:SetFocus() end)
    return inset, edit
end

local function Build(self)
    local window = UI.CreateWindow({
        name = "BPEPGP_StandingsImportWindow",
        title = CLM.L["Import standings"],
        width = WIDTH, height = HEIGHT,
        dbKey = "importwindow",
    })
    self.window = window
    local top = 30
    local banner = UI.CreateTestModeBanner(window)
    if banner then
        banner:SetPoint("TOPLEFT", S.S, -26)
        banner:SetPoint("TOPRIGHT", -S.S, -26)
        top = top + 24
    end

    local help = UI.CreateLabel(window, CLM.L["Paste one player per line: Name, EP, GP. Comma, semicolon or tab separated (you can paste from a spreadsheet). Only guild members can be imported. Players on the roster that are not in the list keep their values."], "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", S.M, -top)
    help:SetPoint("RIGHT", -S.M, 0)
    help:SetWordWrap(true)

    local box
    box, self.input = CreatePasteBox(window)
    box:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -S.S)
    box:SetPoint("RIGHT", -S.M, 0)
    box:SetHeight(140)

    local preview = UI.CreateButton(window, CLM.L["Preview"], 110, function() self:Preview() end)
    preview:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -S.S)
    self.overwrite = UI.CreateCheckbox(window, CLM.L["Overwrite existing standings"])
    self.overwrite:SetPoint("LEFT", preview, "RIGHT", S.M, 0)

    local listInset = UI.CreateInset(window)
    listInset:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -S.S)
    listInset:SetPoint("BOTTOMRIGHT", -S.M, S.BUTTON + S.M * 2)
    self.list = UI.CreateList(listInset, {
        columns = {
            { key = "line", title = CLM.L["Line"], width = 40, align = "RIGHT", font = "NumberFontNormal",
              color = function() return UI.COLOR.GREY end },
            { key = "status", title = CLM.L["Status"], width = 100,
              color = function(row) return STATUS_COLOR[row.status] end },
            { key = "name", title = CLM.L["Name"], width = 130 },
            { key = "ep", title = CLM.L["EP"], width = 70, align = "RIGHT", font = "NumberFontNormal",
              color = function() return UI.COLOR.EP end },
            { key = "gp", title = CLM.L["GP"], width = 70, align = "RIGHT", font = "NumberFontNormal",
              color = function() return UI.COLOR.GP end },
            { key = "note", title = CLM.L["Note"], width = 0,
              color = function() return UI.COLOR.GREY end },
        },
        sortKey = "line",
    })
    self.list:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.list:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)

    self.status = UI.CreateLabel(window, "", "GameFontHighlight")
    self.status:SetPoint("BOTTOMLEFT", S.M, S.M + 4)
    local apply = UI.CreateButton(window, CLM.L["Apply"], 110, function() self:RequestApply() end)
    apply:SetPoint("BOTTOMRIGHT", -S.M, S.M)
end

function StandingsImportGUI:Initialize()
    LOG:Trace("StandingsImportGUI:Initialize()")
    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER) then return end
    CLM.MODULES.ConfigManager:RegisterSlash({
        import = {
            type = "execute",
            name = CLM.L["Import standings"],
            desc = CLM.L["Open the standings import window (officers)"],
            handler = self,
            func = "Show",
        }
    })
    self._initialized = true
end

function StandingsImportGUI:Show()
    if not self._initialized then return end
    if not self.window then Build(self) end
    self.window:Show()
    UpdateStatus(self)
end

function StandingsImportGUI:Reset()
    if not self.window then return end
    self.window:ClearAllPoints()
    self.window:SetPoint("CENTER", 0, 0)
end

CLM.GUI.StandingsImport = StandingsImportGUI
