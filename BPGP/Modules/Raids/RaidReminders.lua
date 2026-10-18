-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI
local S = UI.SPACE

--[[
    Raid reminders (raid feedback 2026-10-18), in a small draggable window:
      - Start: the officer who created a raid that isn't started yet, on entering a raid
        instance (or right away when the raid is created inside one). Once per raid.
      - End: the officer who started a raid that is still in progress, on leaving the raid group.
    In test mode the simulated group counts as being in a raid instance, and removing it
    counts as leaving the group.
]]--

local whoamiGUID = UTILS.whoamiGUID()

local function IsOfficer()
    return CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER)
end

local function InRaidInstance()
    if CLM.MODULES.TestMode:GetSimulatedGroup() then return true end
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid"
end

local function InRaidGroup()
    return IsInRaid() or CLM.MODULES.TestMode:GetSimulatedGroup() ~= nil
end

---@class RaidRemindersGUI
---@field db table
---@field window table?
local RaidReminders = {}

local function Build(self)
    local window = UI.CreateWindow({ name = "BPGP_RaidReminder", title = CLM.L["BPGP raid"], width = 340, height = 130, dbKey = "raidReminder" })
    local text = UI.CreateLabel(window, "", "GameFontHighlight")
    text:SetPoint("TOPLEFT", S.M, -36)
    text:SetPoint("RIGHT", -S.M, 0)
    text:SetWordWrap(true)
    window.Text = text
    window.Later = UI.CreateButton(window, CLM.L["Not now"], 96, function() window:Hide() end)
    window.Later:SetPoint("BOTTOMRIGHT", -S.M, S.M)
    window.Action = UI.CreateButton(window, "", 96)
    window.Action:SetPoint("RIGHT", window.Later, "LEFT", -6, 0)
    self.window = window
end

---@param text string
---@param actionText string
---@param action function
local function Show(self, text, actionText, action)
    if not self.window then Build(self) end
    local window = self.window
    window.Text:SetText(text)
    window.Action:SetText(actionText)
    window.Action:SetScript("OnClick", function()
        window:Hide()
        action()
    end)
    window:Show()
    PlaySound(SOUNDKIT.RAID_WARNING)
end

-- Remind the creator to start their raid
function RaidReminders:CheckStart()
    local raidManager = CLM.MODULES.RaidManager
    if not raidManager:IsInCreatedRaid() or not IsOfficer() then return end
    local raid = raidManager:GetRaid()
    if not raid or raid:Creator() ~= whoamiGUID then return end
    if self.db.startShownFor == raid:UID() then return end
    if not InRaidInstance() then return end
    self.db.startShownFor = raid:UID()
    Show(self, string.format(CLM.L["Raid %s is created but not started yet. Start it now? Raid members are added to it and the on-time bonus is awarded."], raid:Name()),
        CLM.L["Start raid"], function()
            -- By UID: a ledger replay since the reminder was shown replaces the Raid objects
            local current = raidManager:GetRaidByUid(raid:UID())
            if current then raidManager:StartRaid(current) end
        end)
end

-- Remind the starter to end their raid after leaving the group
function RaidReminders:CheckEnd()
    local raidManager = CLM.MODULES.RaidManager
    if not raidManager:IsInProgressingRaid() or not IsOfficer() then return end
    local raid = raidManager:GetRaid()
    if not raid or raid:Starter() ~= whoamiGUID then return end
    if InRaidGroup() then return end
    Show(self, string.format(CLM.L["You left the raid group, but raid %s is still in progress. End it now?"], raid:Name()),
        CLM.L["End raid"], function()
            -- By UID: a ledger replay since the reminder was shown replaces the Raid objects
            local current = raidManager:GetRaidByUid(raid:UID())
            if current then raidManager:ConfirmEndRaid(current, true) end
        end)
end

function RaidReminders:Initialize()
    LOG:Trace("RaidReminders:Initialize()")
    self.db = CLM.MODULES.Database:Personal('raidReminders', { startShownFor = "" })
    CLM.MODULES.EventManager:RegisterWoWEvent({"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA"}, function()
        C_Timer.After(2, function() self:CheckStart() end)
    end)
    CLM.MODULES.EventManager:RegisterWoWEvent({"GROUP_LEFT"}, function()
        C_Timer.After(1, function() self:CheckEnd() end)
    end)
    -- After a reload, and right after creating a raid while already inside the instance
    CLM.MODULES.LedgerManager:RegisterOnUpdate(function(lag, uncommitted)
        if lag ~= 0 or uncommitted ~= 0 then return end
        self:CheckStart()
    end)
end

CLM.GUI.RaidReminders = RaidReminders
