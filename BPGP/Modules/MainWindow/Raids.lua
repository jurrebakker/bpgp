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
    Raids tab: every raid with its status. Officers get a side panel to create a raid (with the
    on-time bonus override) and a right-click menu to start, end, join or remove one.
]]--

local SIDE_WIDTH = 200

local STATUS_COLOR = {
    [CONSTANTS.RAID_STATUS.CREATED]     = UI.COLOR.GOLD,
    [CONSTANTS.RAID_STATUS.IN_PROGRESS] = UI.COLOR.EP,
    [CONSTANTS.RAID_STATUS.FINISHED]    = UI.COLOR.GREY,
    [CONSTANTS.RAID_STATUS.STALE]       = UI.COLOR.BAD,
}

local Raids = {
    key = "raids",
    order = 3,
    title = CLM.L["Raids"],
}

local function StatusText(raid)
    return CONSTANTS.RAID_STATUS_GUI[raid:Status()] or CLM.L["Unknown"]
end

local function ShowTooltip(row, rowFrame)
    local raid = row.raid
    local tooltip = GameTooltip
    tooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
    tooltip:AddDoubleLine(raid:Name(), StatusText(raid), 1, 0.82, 0, (STATUS_COLOR[raid:Status()] or UI.COLOR.WHITE):GetRGB())
    local finished = not raid:IsActive()
    local profiles = raid:Profiles(finished)
    tooltip:AddDoubleLine(finished and CLM.L["Participated"] or CLM.L["In Raid"], tostring(#profiles))
    if #profiles > 0 then
        UTILS.buildPlayerListForTooltip(profiles, tooltip)
    end
    local configuration = raid:Configuration()
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(CLM.L["Auction Time"], tostring(configuration:Get("auctionTime")), nil, nil, nil, 1, 1, 1)
    tooltip:AddDoubleLine(CLM.L["Anti-snipe"], tostring(configuration:Get("antiSnipe")), nil, nil, nil, 1, 1, 1)
    if configuration:Get("onTimeBonus") then
        tooltip:AddDoubleLine(CLM.L["On Time Bonus"], tostring(configuration:Get("onTimeBonusValue")), nil, nil, nil, 1, 1, 1)
    else
        tooltip:AddDoubleLine(CLM.L["On Time Bonus"], CLM.L["Off"], nil, nil, nil, 1, 1, 1)
    end
    tooltip:Show()
end

--[[
 * Officer actions *
]]--

local function ShowRowMenu(self, row, rowFrame)
    local raid = row.raid
    local name = raid:Name()
    local status = raid:Status()
    UI.ShowContextMenu(rowFrame, name, {
        { text = CLM.L["Start raid"], disabled = status ~= CONSTANTS.RAID_STATUS.CREATED, func = function()
            UI.Confirm(string.format(CLM.L["Start raid %s? Raid members are added to it and the on-time bonus is awarded."], name),
                function() CLM.MODULES.RaidManager:StartRaid(raid) end)
        end },
        { text = CLM.L["End raid"], disabled = not raid:IsActive(), func = function()
            CLM.MODULES.RaidManager:ConfirmEndRaid(raid)
        end },
        { text = CLM.L["Join raid"], disabled = not raid:IsActive(), func = function()
            UI.Confirm(string.format(CLM.L["Join raid %s?"], name), function() CLM.MODULES.RaidManager:JoinRaid(raid) end)
        end },
        { divider = true },
        { text = CLM.L["Remove raid"], color = UI.COLOR.BAD, func = function()
            UI.Confirm(string.format(CLM.L["Remove raid %s? This writes an undo entry for everyone."], name), function()
                CLM.MODULES.LedgerManager:Remove(raid:Entry(), true)
                self.list:ClearSelection()
            end)
        end },
    })
end

-- The new raid starts from the roster configuration; the panel only overrides the on-time bonus
local function NewConfiguration()
    local roster = CLM.MODULES.RosterManager:GetRoster()
    if not roster then return nil end
    return CLM.MODELS.RosterConfiguration:New(UTILS.DeepCopy(roster.configuration))
end

local function CreateRaid(self)
    local roster = CLM.MODULES.RosterManager:GetRoster()
    local configuration = NewConfiguration()
    if not roster or not configuration then
        LOG:Message(CLM.L["Set up BPGP first (Standings tab)."])
        return
    end
    configuration:Set("onTimeBonus", self.onTimeCheck:GetChecked() and true or false)
    local bonus = tonumber(self.onTimeInput:GetText())
    if bonus then configuration:Set("onTimeBonusValue", bonus) end
    local name = self.nameInput:GetText()
    if name == "" then name = nil end
    local text = string.format(CLM.L["Create raid %s? You join it and leave any other raid you are in."], name or CLM.L["(no name)"])
    UI.Confirm(text, function()
        CLM.MODULES.RaidManager:CreateRaid(roster, name, configuration)
        self.nameInput:SetText("")
    end)
end

local function BuildSidePanel(self, content)
    local panel = CreateFrame("Frame", nil, content)
    panel:SetPoint("TOPRIGHT")
    panel:SetPoint("BOTTOMRIGHT")
    panel:SetWidth(SIDE_WIDTH)

    self.currentRaid = UI.CreateLabel(panel, "", "GameFontHighlightSmall")
    self.currentRaid:SetPoint("TOPLEFT")
    self.currentRaid:SetWidth(SIDE_WIDTH)
    self.currentRaid:SetWordWrap(true)

    local title = UI.CreateLabel(panel, CLM.L["New raid"], "GameFontNormal")
    title:SetPoint("TOPLEFT", 0, -36)
    local nameLabel = UI.CreateLabel(panel, CLM.L["Raid Name"], "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -S.S)
    self.nameInput = UI.CreateInput(panel, SIDE_WIDTH - 6, false)
    self.nameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 6, -S.XS)

    self.onTimeCheck = UI.CreateCheckbox(panel, CLM.L["On Time Bonus"])
    self.onTimeCheck:SetPoint("TOPLEFT", self.nameInput, "BOTTOMLEFT", -8, -S.S)
    self.onTimeInput = UI.CreateInput(panel, 50, true)
    self.onTimeInput:SetPoint("LEFT", self.onTimeCheck.Label, "RIGHT", S.S + 4, 0)

    self.createButton = UI.CreateButton(panel, CLM.L["Create raid"], SIDE_WIDTH, function() CreateRaid(self) end)
    self.createButton:SetPoint("TOPLEFT", self.onTimeCheck, "BOTTOMLEFT", 2, -S.M)
end

function Raids:Build(content)
    local inset = UI.CreateInset(content)
    inset:SetPoint("TOPLEFT")
    if self.isOfficer then
        BuildSidePanel(self, content)
        inset:SetPoint("BOTTOMRIGHT", -(SIDE_WIDTH + S.M), 0)
    else
        inset:SetPoint("BOTTOMRIGHT")
    end
    self.list = UI.CreateList(inset, {
        columns = {
            { key = "name", title = CLM.L["Name"], width = 0 },
            { key = "status", title = CLM.L["Status"], width = 90,
              color = function(row) return STATUS_COLOR[row.raid:Status()] end },
            { key = "players", title = CLM.L["Players"], width = 60, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true },
            { key = "created", title = CLM.L["Created"], width = 110, defaultDesc = true,
              text = function(row) return date(CLM.L["%m/%d %H:%M"], row.values.created) end,
              color = function() return UI.COLOR.GREY end },
        },
        sortKey = "created",
        sortDesc = true,
        onRightClick = self.isOfficer and function(row, rowFrame) ShowRowMenu(self, row, rowFrame) end or nil,
        onEnter = ShowTooltip,
    })
    self.list:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.list:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
end

function Raids:OnShow()
    if not self.isOfficer then return end
    -- Fill the on-time bonus from the roster settings each time the tab is opened
    local configuration = NewConfiguration()
    if configuration then
        self.onTimeCheck:SetChecked(configuration:Get("onTimeBonus") and true or false)
        self.onTimeInput:SetText(tostring(configuration:Get("onTimeBonusValue") or 0))
    end
end

function Raids:Refresh()
    local rows = {}
    for _, raid in pairs(CLM.MODULES.RaidManager:ListRaids()) do
        local finished = not raid:IsActive()
        rows[#rows + 1] = {
            id = raid:UID(),
            raid = raid,
            values = { name = raid:Name(), status = StatusText(raid), players = #raid:Profiles(finished), created = raid:CreatedAt() },
        }
    end
    self.list:SetData(rows)

    local myRaid = CLM.MODULES.RaidManager:IsInRaid() and CLM.MODULES.RaidManager:GetRaid()
    self.window:SetSubtitle(myRaid and string.format(CLM.L["You are in %s"], myRaid:Name()) or "")
    if self.isOfficer then
        local inActive = CLM.MODULES.RaidManager:IsInActiveRaid()
        self.createButton:SetEnabled(not inActive)
        self.nameInput:SetEnabled(not inActive)
        self.currentRaid:SetText(inActive and CLM.L["You are in an active raid. End it before creating a new one."] or "")
        self.window:SetPageFooter(CLM.L["Right-click a raid: Start · End · Join · Remove"])
    else
        self.window:SetPageFooter("")
    end
end

CLM.GUI.MainWindow:RegisterPage(Raids)
