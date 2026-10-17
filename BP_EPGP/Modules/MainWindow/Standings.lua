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
    Standings tab. Officers: multi-select list plus a side panel to award EP/GP and decay (R1, R5, R6).
    Raiders: read-only list with their own row pinned on top and their PR in the header (R11).
]]--

CONSTANTS.ACTION_CONTEXT = {
    SELECTED = 1,
    ROSTER = 2,
    RAID = 3
}

local SIDE_WIDTH = 260
local DECAY_TYPE_WIDTH = 100 -- fits "EP/GP"
local MAX_REMOVE = 10
local MAX_NOTE = 25
local MAX_LISTED_NAMES = 6
local OWN_ROW = CreateColor(0.27, 0.28, 0.93, 0.25)

local Standings = {
    key = "standings",
    order = 1,
    title = CLM.L["Standings"],
    context = CONSTANTS.ACTION_CONTEXT.ROSTER,
    decayType = CONSTANTS.POINT_CHANGE_TYPE.TOTAL,
}

---@return Roster?
local function GetRoster()
    return CLM.MODULES.RosterManager:GetRoster()
end

---@return Profile[]
function Standings:GetSelectedProfiles()
    local profiles = {}
    for _, row in ipairs(self.list:GetSelection()) do
        profiles[#profiles + 1] = row.profile
    end
    return profiles
end

--[[
 * Rows *
]]--

local function BuildRows(roster)
    local rows = {}
    local me = UTILS.whoami()
    for GUID, ep in pairs(roster:Standings()) do
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
        if profile then
            rows[#rows + 1] = {
                id = GUID,
                profile = profile,
                isMe = profile:Name() == me,
                classFile = UTILS.CanonicalClass(profile:ClassInternal()),
                values = { name = profile:Name(), ep = ep, gp = roster:GP(GUID), pr = roster:Priority(GUID) },
            }
        end
    end
    -- "#" is the PR rank, whatever the list is sorted by
    local byPR = {}
    for i, row in ipairs(rows) do byPR[i] = row end
    table.sort(byPR, function(a, b)
        if a.values.pr ~= b.values.pr then return a.values.pr > b.values.pr end
        return a.values.name < b.values.name
    end)
    -- Equal PR shares a rank (1, 1, 3, ...)
    for index, row in ipairs(byPR) do
        local previous = byPR[index - 1]
        row.values.rank = (previous and previous.values.pr == row.values.pr) and previous.values.rank or index
    end
    return rows
end

local function AddTooltip(row, rowFrame)
    local roster = GetRoster()
    if not roster then return end
    local tooltip = GameTooltip
    tooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
    tooltip:SetText(row.profile:ShortName(), UI.GetClassColor(row.classFile):GetRGB())
    tooltip:AddDoubleLine(row.values.ep .. " " .. CLM.L["EP"], row.values.gp .. " " .. CLM.L["GP"],
        UI.COLOR.EP.r, UI.COLOR.EP.g, UI.COLOR.EP.b, UI.COLOR.GP.r, UI.COLOR.GP.g, UI.COLOR.GP.b)

    tooltip:AddLine(" ")
    local lootList = roster:GetProfileLootByGUID(row.id)
    if #lootList > 0 then
        tooltip:AddLine(CLM.L["Latest loot"])
        for i = #lootList, math.max(#lootList - 4, 1), -1 do
            local loot = lootList[i]
            local _, itemLink = UTILS.GetItemInfo(loot:String())
            if itemLink then
                tooltip:AddDoubleLine(itemLink, tostring(loot:Value()) .. " " .. CLM.L["GP"])
            end
        end
    else
        tooltip:AddLine(CLM.L["No loot received"], UI.COLOR.GREY:GetRGB())
    end

    tooltip:AddLine(" ")
    local pointList = roster:GetProfilePointHistoryByGUID(row.id)
    if #pointList > 0 then
        tooltip:AddLine(CLM.L["Latest points"])
        for i = #pointList, math.max(#pointList - 4, 1), -1 do
            local point = pointList[i]
            local reason = point:Reason() or 0
            local value = tostring(point:Value())
            if reason == CONSTANTS.POINT_CHANGE_REASON.DECAY then value = value .. "%" end
            value = value .. " " .. UTILS.DecodePointTypeChangeName(point:Type())
            local label = point:Note() ~= "" and point:Note() or (CONSTANTS.POINT_CHANGE_REASONS.ALL[reason] or "")
            tooltip:AddDoubleLine(label, value, 1, 1, 1, 1, 1, 1)
        end
    else
        tooltip:AddLine(CLM.L["No points received"], UI.COLOR.GREY:GetRGB())
    end
    tooltip:Show()
end

--[[
 * Officer actions *
]]--

---@param awardType number CONSTANTS.POINT_CHANGE_TYPE.POINTS (EP) or SPENT (GP)
---@param awardValue number
---@param profiles Profile[]
local function DoAward(self, awardType, awardValue, profiles)
    local roster = GetRoster()
    if not roster then return end
    local reason = CONSTANTS.POINT_CHANGE_REASON.MANUAL_ADJUSTMENT
    local note = self.note ~= "" and self.note or nil

    if self.context == CONSTANTS.ACTION_CONTEXT.RAID then
        local raid = CLM.MODULES.RaidManager:GetRaid()
        if not raid then LOG:Message(CLM.L["You are not in a raid."]) return end
        CLM.MODULES.PointManager:UpdateRaidPoints(raid, awardValue, reason, CONSTANTS.POINT_MANAGER_ACTION.MODIFY, note, awardType)
    elseif self.context == CONSTANTS.ACTION_CONTEXT.ROSTER then
        CLM.MODULES.PointManager:UpdateRosterPoints(roster, awardValue, reason, CONSTANTS.POINT_MANAGER_ACTION.MODIFY, false, note, awardType)
    else
        CLM.MODULES.PointManager:UpdatePoints(roster, profiles, awardValue, reason, CONSTANTS.POINT_MANAGER_ACTION.MODIFY, note, awardType)
    end
end

---@param awardType number
---@param input table EditBox with the value
local function Award(self, awardType, input)
    local awardValue = tonumber(input:GetText())
    if not awardValue then LOG:Message(CLM.L["Missing award value"]) return end
    if not GetRoster() then LOG:Message(CLM.L["Set up BP EPGP first (Standings tab)."]) return end
    local points = UTILS.DecodePointTypeChangeName(awardType)
    local profiles, text = {}, nil
    if self.context == CONSTANTS.ACTION_CONTEXT.RAID then
        if not CLM.MODULES.RaidManager:IsInRaid() then LOG:Message(CLM.L["You are not in a raid."]) return end
        text = string.format(CLM.L["Award %s %s to everyone in raid."], awardValue, points)
    elseif self.context == CONSTANTS.ACTION_CONTEXT.ROSTER then
        text = string.format(CLM.L["Award %s %s to everyone in roster."], awardValue, points)
    else
        profiles = self:GetSelectedProfiles()
        if #profiles == 0 then LOG:Message(CLM.L["No players selected"]) return end
        text = string.format(CLM.L["Award %s %s to %s selected players."], awardValue, points, #profiles)
    end
    if self.note ~= "" then
        text = text .. "\n" .. CLM.L["Note"] .. ": " .. self.note
    end
    UI.Confirm(text, function() DoAward(self, awardType, awardValue, profiles) end)
end

local function Decay(self)
    local decayValue = tonumber(self.decayInput:GetText())
    if not decayValue then LOG:Message(CLM.L["Missing decay value"]) return end
    if decayValue > 100 or decayValue < 0 then LOG:Message(CLM.L["Decay value should be between 0 and 100%"]) return end
    local roster = GetRoster()
    if not roster then return end
    local points = UTILS.DecodePointTypeChangeName(self.decayType)
    if self.context == CONSTANTS.ACTION_CONTEXT.ROSTER then
        UI.Confirm(string.format(CLM.L["Decay %s%% %s to everyone in roster."], decayValue, points), function()
            CLM.MODULES.PointManager:UpdateRosterPoints(roster, decayValue, CONSTANTS.POINT_CHANGE_REASON.DECAY,
                CONSTANTS.POINT_MANAGER_ACTION.DECAY, true, nil, self.decayType)
        end)
    elseif self.context == CONSTANTS.ACTION_CONTEXT.SELECTED then
        local profiles = self:GetSelectedProfiles()
        if #profiles == 0 then LOG:Message(CLM.L["No players selected"]) return end
        UI.Confirm(string.format(CLM.L["Decay %s%% %s to %s selected players."], decayValue, points, #profiles), function()
            CLM.MODULES.PointManager:UpdatePoints(roster, profiles, decayValue, CONSTANTS.POINT_CHANGE_REASON.DECAY,
                CONSTANTS.POINT_MANAGER_ACTION.DECAY, nil, self.decayType)
        end)
    end
end

local function RemoveFromRoster(self)
    local roster = GetRoster()
    local profiles = self:GetSelectedProfiles()
    if not roster or #profiles == 0 then return end
    if #profiles > MAX_REMOVE then
        LOG:Message(CLM.L["You can remove max %d players from roster at the same time."], MAX_REMOVE)
        return
    end
    local text = #profiles == 1
        and string.format(CLM.L["Remove %s from the roster? Their EP and GP are reset if they are added again."], profiles[1]:ShortName())
        or string.format(CLM.L["Remove %s players from the roster? Their EP and GP are reset if they are added again."], #profiles)
    UI.Confirm(text, function()
        CLM.MODULES.RosterManager:RemoveProfilesFromRoster(roster, profiles)
        self.list:ClearSelection()
    end)
end

local function ShowRowMenu(self, row, rowFrame)
    local award = CLM.GUI.Award
    UI.ShowContextMenu(rowFrame, row.profile:ShortName(), {
        { text = CLM.L["Award item"], disabled = not (award and award._initialized),
          func = function() award:ShowForPlayer(row.profile:Name()) end },
        { divider = true },
        { text = CLM.L["Remove from roster"], color = UI.COLOR.BAD, func = function() RemoveFromRoster(self) end },
    })
end

--[[
 * Building *
]]--

local function UpdateActOn(self)
    local selection = self.list:GetSelection()
    local text
    if self.context == CONSTANTS.ACTION_CONTEXT.SELECTED then
        local names = {}
        for i, row in ipairs(selection) do
            if i > MAX_LISTED_NAMES then
                names[#names + 1] = string.format(CLM.L["+%s more"], #selection - MAX_LISTED_NAMES)
                break
            end
            names[#names + 1] = UI.GetClassColor(row.classFile):WrapTextInColorCode(row.profile:ShortName())
        end
        text = #names > 0 and table.concat(names, ", ") or CLM.L["Click a name to select it. Ctrl-click adds more, shift-click selects a range."]
    elseif self.context == CONSTANTS.ACTION_CONTEXT.RAID then
        local raid = CLM.MODULES.RaidManager:GetRaid()
        text = raid and string.format(CLM.L["%s players in %s"], #raid:Players(), raid:Name()) or CLM.L["You are not in a raid."]
    else
        local roster = GetRoster()
        text = string.format(CLM.L["Everyone on the roster (%s)"], roster and #roster:Profiles() or 0)
    end
    self.selectedNames:SetText(text)
    self.decayButton:SetEnabled(self.context ~= CONSTANTS.ACTION_CONTEXT.RAID)
    self.actOn:Refresh()
end

local function SetContext(self, context)
    self.context = context
    UpdateActOn(self)
end

local function BuildSidePanel(self, content)
    local panel = CreateFrame("Frame", nil, content)
    panel:SetPoint("TOPRIGHT")
    panel:SetPoint("BOTTOMRIGHT")
    panel:SetWidth(SIDE_WIDTH)

    local y = 0
    local function Place(widget, height, x)
        widget:SetPoint("TOPLEFT", panel, "TOPLEFT", x or 0, y)
        y = y - height
    end

    local label = UI.CreateLabel(panel, CLM.L["Act on"], "GameFontNormal")
    Place(label, 14 + S.XS)
    self.actOn = UI.CreateDropdown(panel, SIDE_WIDTH,
        function()
            return {
                { text = CLM.L["Selected"], value = CONSTANTS.ACTION_CONTEXT.SELECTED },
                { text = CLM.L["Raid"],     value = CONSTANTS.ACTION_CONTEXT.RAID },
                { text = CLM.L["Roster"],   value = CONSTANTS.ACTION_CONTEXT.ROSTER },
            }
        end,
        function() return self.context end,
        function(value) SetContext(self, value) end)
    Place(self.actOn, S.BUTTON + S.XS)
    self.selectedNames = UI.CreateLabel(panel, "", "GameFontDisableSmall")
    self.selectedNames:SetWidth(SIDE_WIDTH)
    self.selectedNames:SetHeight(26)
    self.selectedNames:SetJustifyV("TOP")
    self.selectedNames:SetWordWrap(true)
    Place(self.selectedNames, 26 + S.S)

    label = UI.CreateLabel(panel, CLM.L["Note"], "GameFontNormal")
    Place(label, 14 + S.XS)
    local note = UI.CreateInput(panel, SIDE_WIDTH - 6, false, function(text) self.note = text end)
    note:SetMaxLetters(MAX_NOTE)
    Place(note, S.INPUT + S.S, 6)

    local valueWidth, buttonWidth = 64, SIDE_WIDTH - 64 - S.S - 6
    self.epInput = UI.CreateInput(panel, valueWidth, true)
    Place(self.epInput, 0, 6)
    local awardEP = UI.CreateButton(panel, CLM.L["Award EP"], buttonWidth, function() Award(self, CONSTANTS.POINT_CHANGE_TYPE.POINTS, self.epInput) end)
    awardEP:SetPoint("LEFT", self.epInput, "RIGHT", S.S, 0)
    y = y - S.BUTTON - S.XS
    self.gpInput = UI.CreateInput(panel, valueWidth, true)
    Place(self.gpInput, 0, 6)
    local awardGP = UI.CreateButton(panel, CLM.L["Award GP"], buttonWidth, function() Award(self, CONSTANTS.POINT_CHANGE_TYPE.SPENT, self.gpInput) end)
    awardGP:SetPoint("LEFT", self.gpInput, "RIGHT", S.S, 0)
    y = y - S.BUTTON - S.M

    local divider = UI.CreateDivider(panel)
    divider:SetPoint("TOPLEFT", 0, y)
    divider:SetPoint("RIGHT")
    y = y - S.S

    label = UI.CreateLabel(panel, CLM.L["Decay %"], "GameFontNormal")
    Place(label, 14 + S.XS)
    self.decayInput = UI.CreateInput(panel, 40, true)
    Place(self.decayInput, 0, 6)
    local decayType = UI.CreateDropdown(panel, DECAY_TYPE_WIDTH,
        function()
            local options = {}
            for _, value in ipairs({ CONSTANTS.POINT_CHANGE_TYPE.TOTAL, CONSTANTS.POINT_CHANGE_TYPE.POINTS, CONSTANTS.POINT_CHANGE_TYPE.SPENT }) do
                options[#options + 1] = { text = CONSTANTS.EPGP_POINT_DECAY_TYPES_GUI[value], value = value }
            end
            return options
        end,
        function() return self.decayType end,
        function(value) self.decayType = value end)
    decayType:SetPoint("LEFT", self.decayInput, "RIGHT", S.S, 0)
    self.decayButton = UI.CreateButton(panel, CLM.L["Decay"], SIDE_WIDTH - 6 - 40 - DECAY_TYPE_WIDTH - 2 * S.S, function() Decay(self) end)
    self.decayButton:SetPoint("LEFT", decayType, "RIGHT", S.S, 0)
    y = y - S.BUTTON - S.M

    divider = UI.CreateDivider(panel)
    divider:SetPoint("TOPLEFT", 0, y)
    divider:SetPoint("RIGHT")

    local import = UI.CreateButton(panel, CLM.L["Import standings"], SIDE_WIDTH, function() CLM.GUI.StandingsImport:Show() end)
    import:SetPoint("BOTTOMRIGHT")
    import:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(CLM.L["Import standings"])
        GameTooltip:AddLine(CLM.L["Paste a Name, EP, GP list to set standings in one go."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    import:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.note = ""
    return panel
end

local function BuildEmptyState(self, inset)
    local empty = CreateFrame("Frame", nil, inset)
    empty:SetPoint("TOPLEFT", 24, -24)
    empty:SetPoint("BOTTOMRIGHT", -24, 24)
    empty:SetFrameLevel(inset:GetFrameLevel() + 10)
    empty.Title = UI.CreateLabel(empty, CLM.L["No standings yet"], "GameFontNormalLarge", UI.COLOR.GREY)
    empty.Title:SetPoint("BOTTOM", empty, "CENTER", 0, 12)
    empty.Title:SetJustifyH("CENTER")
    empty.Text = UI.CreateLabel(empty, "", "GameFontDisableSmall")
    empty.Text:SetPoint("TOP", empty.Title, "BOTTOM", 0, -S.S)
    empty.Text:SetWidth(320)
    empty.Text:SetJustifyH("CENTER")
    empty.Text:SetWordWrap(true)
    if self.isOfficer then
        empty.Setup = UI.CreateButton(empty, CLM.L["Set up BP EPGP"], 160, function()
            UI.Confirm(CLM.L["Create the guild's EPGP roster with default settings. Only needed once."], function()
                CLM.MODULES.RosterManager:NewRoster("BP EPGP")
            end)
        end)
        empty.Setup:SetPoint("TOP", empty.Text, "BOTTOM", 0, -S.M)
    end
    empty:Hide()
    self.empty = empty
end

local function BuildRaiderHeader(self, header)
    self.myPR = UI.CreateLabel(header, "", "GameFontNormalHuge", UI.COLOR.GOLD)
    self.myPR:SetPoint("RIGHT", header, "RIGHT", -S.XS, -2)
    self.myRank = UI.CreateLabel(header, "", "GameFontNormalSmall")
    self.myRank:SetPoint("RIGHT", self.myPR, "LEFT", -S.S, 0)
end

function Standings:Build(content, header)
    local inset = UI.CreateInset(content)
    inset:SetPoint("TOPLEFT")
    if self.isOfficer then
        BuildSidePanel(self, content)
        inset:SetPoint("BOTTOMRIGHT", -(SIDE_WIDTH + S.M), 0)
    else
        inset:SetPoint("BOTTOMRIGHT")
        BuildRaiderHeader(self, header)
    end

    local officer = self.isOfficer
    self.list = UI.CreateList(inset, {
        columns = {
            { key = "rank", title = "#", width = 32, align = "RIGHT", font = "NumberFontNormal",
              color = function() return UI.COLOR.GREY end },
            { key = "name", title = CLM.L["Name"], width = 0, classIcon = true,
              text = function(row) return row.profile:ShortName() end,
              color = function(row) return UI.GetClassColor(row.classFile) end },
            { key = "ep", title = CLM.L["EP"], width = 72, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true,
              color = function() return UI.COLOR.EP end },
            { key = "gp", title = CLM.L["GP"], width = 72, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true,
              color = function() return UI.COLOR.GP end },
            { key = "pr", title = CLM.L["PR"], width = 64, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true,
              color = function() return UI.COLOR.GOLD end },
        },
        multiSelect = officer,
        sortKey = "pr",
        sortDesc = true,
        pinned = not officer and function(row) return row.isMe end or nil,
        rowTint = function(row) return row.isMe and OWN_ROW or nil end,
        onSelectionChanged = officer and function(selection)
            if #selection > 0 then self.context = CONSTANTS.ACTION_CONTEXT.SELECTED end
            UpdateActOn(self)
        end or nil,
        onRightClick = officer and function(row, rowFrame) ShowRowMenu(self, row, rowFrame) end or nil,
        onEnter = AddTooltip,
    })
    self.list:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.list:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
    BuildEmptyState(self, inset)
end

function Standings:OnShow()
    if not self.isOfficer then return end
    -- Default target: the raid when in one, otherwise the whole roster
    self.list:ClearSelection()
    self.context = CLM.MODULES.RaidManager:IsInRaid() and CONSTANTS.ACTION_CONTEXT.RAID or CONSTANTS.ACTION_CONTEXT.ROSTER
    UpdateActOn(self)
end

local function UpdateEmptyState(self, roster, rows)
    local isEmpty = roster == nil or #rows == 0
    self.empty:SetShown(isEmpty)
    if not isEmpty then return end
    if roster == nil and self.isOfficer then
        self.empty.Text:SetText(CLM.L["Set up BP EPGP creates the guild's roster. It's only needed once; after that it syncs to everyone."])
    elseif self.isOfficer then
        self.empty.Text:SetText(CLM.L["Nobody has EP. Add guild members in the Roster tab, or use Import standings."])
    else
        self.empty.Text:SetText(CLM.L["Nobody has EP. Award EP to start, or wait for the first sync from an officer."])
    end
    if self.empty.Setup then self.empty.Setup:SetShown(roster == nil) end
end

local function UpdateRaiderHeader(self, roster, rows)
    for _, row in ipairs(rows) do
        if row.isMe then
            self.myRank:SetText(string.format(CLM.L["YOUR PR · #%s OF %s"], row.values.rank, #rows))
            self.myPR:SetText(tostring(row.values.pr))
            return
        end
    end
    self.myRank:SetText(roster and CLM.L["You are not on the roster"] or "")
    self.myPR:SetText("")
end

function Standings:Refresh()
    local roster = GetRoster()
    local rows = roster and BuildRows(roster) or {}
    self.list:SetData(rows)
    UpdateEmptyState(self, roster, rows)

    local raid = CLM.MODULES.RaidManager:IsInRaid() and CLM.MODULES.RaidManager:GetRaid()
    self.window:SetSubtitle(raid and string.format(CLM.L["%s in raid"], #raid:Players()) or "")

    if self.isOfficer then
        UpdateActOn(self)
        self.window:SetPageFooter(CLM.L["Right-click a name: Award item · Remove from roster"])
    else
        UpdateRaiderHeader(self, roster, rows)
        local minimum = roster and tonumber(roster:GetConfiguration("minimumPoints")) or 0
        self.window:SetPageFooter(minimum > 0 and string.format(CLM.L["Min. %s EP to bid"], minimum) or "")
    end
end

CLM.GUI.MainWindow:RegisterPage(Standings)
