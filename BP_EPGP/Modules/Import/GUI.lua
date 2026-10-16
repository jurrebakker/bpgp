-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local AceGUI = LibStub("AceGUI-3.0")
---@cast AceGUI AceGUI

local POPUP_APPLY = "BPEPGP_STANDINGS_IMPORT_APPLY"

local colorGreen = {r = 0.27, g = 0.93, b = 0.27, a = 1.0}
local colorTurquoise = {r = 0.2, g = 0.93, b = 0.93, a = 1.0}
local colorRed = {r = 0.93, g = 0.27, b = 0.2, a = 1.0}

local STATUS_COLOR = {
    [CONSTANTS.IMPORT_STATUS.UPDATE]    = colorGreen,
    [CONSTANTS.IMPORT_STATUS.ADD]       = colorTurquoise,
    [CONSTANTS.IMPORT_STATUS.NOT_GUILD] = colorRed,
    [CONSTANTS.IMPORT_STATUS.DUPLICATE] = colorRed,
    [CONSTANTS.IMPORT_STATUS.INVALID]   = colorRed,
}

---@class StandingsImportGUI
---@field top AceGUIFrameWidget
---@field input AceGUIMultiLineEditBox
---@field overwrite AceGUICheckBox
---@field table table
---@field rows StandingsImportRow[]
---@field _initialized boolean
local StandingsImportGUI = {}

local function UpdateStatus(self)
    local toImport, toAdd, skipped = CLM.MODULES.StandingsImport:Count(self.rows)
    self.top:SetStatusText(string.format(CLM.L["%s to import (%s new on the roster), %s skipped"], toImport, toAdd, skipped))
    local hasHistory = CLM.MODULES.StandingsImport:RosterHasHistory()
    self.overwrite:SetDisabled(not hasHistory)
    if not hasHistory then self.overwrite:SetValue(false) end
end

function StandingsImportGUI:Preview()
    self.rows = CLM.MODULES.StandingsImport:Parse(self.input:GetText())
    local data = {}
    for _, row in ipairs(self.rows) do
        local color = STATUS_COLOR[row.status]
        data[#data + 1] = { cols = {
            {value = row.line},
            {value = CONSTANTS.IMPORT_STATUS_GUI[row.status], color = color},
            {value = row.name},
            {value = row.ep or ""},
            {value = row.gp or ""},
            {value = row.note},
        }}
    end
    self.table:SetData(data)
    UpdateStatus(self)
end

function StandingsImportGUI:RequestApply()
    self:Preview()
    local toImport, toAdd, skipped = CLM.MODULES.StandingsImport:Count(self.rows)
    if toImport == 0 then
        LOG:Message(CLM.L["Nothing to import."])
        return
    end
    if CLM.MODULES.StandingsImport:RosterHasHistory() and not self.overwrite:GetValue() then
        LOG:Message(CLM.L["The roster already has points or loot. Tick overwrite to import anyway."])
        return
    end
    StaticPopup_Show(POPUP_APPLY, string.format(
        CLM.L["Set EP and GP for %s players (%s new on the roster)? %s lines are skipped."], toImport, toAdd, skipped))
end

local function Create(self)
    local f = AceGUI:Create("Window")
    f:SetTitle(CLM.L["Import standings"])
    f:SetLayout("Flow")
    f:EnableResize(false)
    f:SetWidth(640)
    f:SetHeight(600)
    self.top = f

    local help = AceGUI:Create("Label")
    help:SetFullWidth(true)
    help:SetText(CLM.L["Paste one player per line: Name, EP, GP. Comma, semicolon or tab separated (you can paste from a spreadsheet). Only guild members can be imported. Players on the roster that are not in the list keep their values."])
    f:AddChild(help)

    local input = AceGUI:Create("MultiLineEditBox")
    input:SetLabel(CLM.L["Standings"])
    input:SetFullWidth(true)
    input:SetNumLines(8)
    input:DisableButton(true)
    self.input = input
    f:AddChild(input)

    local preview = AceGUI:Create("Button")
    preview:SetText(CLM.L["Preview"])
    preview:SetWidth(150)
    preview:SetCallback("OnClick", function() self:Preview() end)
    f:AddChild(preview)

    local overwrite = AceGUI:Create("CheckBox")
    overwrite:SetLabel(CLM.L["Overwrite existing standings"])
    overwrite:SetWidth(260)
    self.overwrite = overwrite
    f:AddChild(overwrite)

    local apply = AceGUI:Create("Button")
    apply:SetText(CLM.L["Apply"])
    apply:SetWidth(150)
    apply:SetCallback("OnClick", function() self:RequestApply() end)
    f:AddChild(apply)

    local list = AceGUI:Create("BPEPGPLibScrollingTable")
    list:SetDisplayCols({
        {name = CLM.L["Line"],   width = 40},
        {name = CLM.L["Status"], width = 100},
        {name = CLM.L["Name"],   width = 130},
        {name = CLM.L["EP"],     width = 70},
        {name = CLM.L["GP"],     width = 70},
        {name = CLM.L["Note"],   width = 180},
    })
    list:SetDisplayRows(12, 18)
    list:EnableSelection(false)
    self.table = list
    f:AddChild(list)

    self.rows = {}
    UTILS.MakeFrameCloseOnEsc(f.frame, "BPEPGP_StandingsImport_GUI")
    f:Hide()
end

local function RegisterPopup(self)
    StaticPopupDialogs[POPUP_APPLY] = {
        text = "%s\n\n" .. CLM.L["This writes ledger entries that sync to the whole guild."],
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            if CLM.MODULES.StandingsImport:Apply(self.rows, self.overwrite:GetValue()) then
                -- Show the result once the entries are applied
                C_Timer.After(1, function() self:Preview() end)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function StandingsImportGUI:Initialize()
    LOG:Trace("StandingsImportGUI:Initialize()")
    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER) then return end
    Create(self)
    RegisterPopup(self)
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
    self.top:Show()
    UpdateStatus(self)
end

CLM.GUI.StandingsImport = StandingsImportGUI
