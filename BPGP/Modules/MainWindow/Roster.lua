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
    Roster tab (officers): max level guild members plus everyone on the roster (also those who
    left the guild), so officers can add guild members to the roster and remove them again.
    Only guild members can be added; raids never add players by themselves.
]]--

local SIDE_WIDTH = 200
local MAX_REMOVE = 10
local OFFICER_TINT = CreateColor(0.12, 1, 0, 0.08)

local Roster = {
    key = "roster",
    order = 4,
    title = CLM.L["Roster"],
    officerOnly = true,
    search = "",
    onlyInRaid = false,
    hideOnRoster = false,
    hideNotOnRoster = false,
}

local function BuildRows(self)
    local rows = {}
    local listed = {}
    local roster = CLM.MODULES.RosterManager:GetRoster()
    local raid = CLM.MODULES.RaidManager:IsInRaid() and CLM.MODULES.RaidManager:GetRaid()

    local function AddRow(GUID, name, classFile, rank, inGuild)
        listed[GUID] = true
        local onRoster = roster and roster:IsProfileInRoster(GUID) or false
        if self.hideOnRoster and onRoster then return end
        if self.hideNotOnRoster and not onRoster then return end
        if self.onlyInRaid and not (raid and raid:IsPlayerInRaid(GUID)) then return end
        if self.search ~= "" and not name:lower():find(self.search, 1, true) then return end
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
        rows[#rows + 1] = {
            id = GUID,
            name = name,
            classFile = classFile,
            onRoster = onRoster,
            inGuild = inGuild,
            isOfficer = CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER, name),
            values = {
                name = name,
                rank = rank or "",
                onRoster = onRoster and CLM.L["Yes"] or "",
                version = profile and profile:VersionString() or "",
            },
        }
    end

    local maxLevel = GetMaxLevelForPlayerExpansion()
    for i = 1, GetNumGuildMembers() do
        local name, rankName, _, level, _, _, _, _, _, _, classFile, _, _, _, _, _, GUID = GetGuildRosterInfo(i)
        if name and GUID and level >= maxLevel then
            AddRow(GUID, UTILS.Disambiguate(name), classFile, rankName, true)
        end
    end

    -- Roster members below max level or no longer in the guild, so they can be removed
    if roster then
        for GUID in pairs(roster:Standings()) do
            local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
            if profile and not listed[GUID] then
                AddRow(GUID, profile:Name(), UTILS.CanonicalClass(profile:ClassInternal()), nil, false)
            end
        end
    end
    return rows
end

--[[
 * Actions *
]]--

local function AddSelectedToRoster(self)
    local roster = CLM.MODULES.RosterManager:GetRoster()
    if not roster then
        LOG:Message(CLM.L["Set up BPGP first (Standings tab)."])
        return
    end
    local guildies = CLM.MODULES.TrustInfoProvider:GetGuildies()
    local toAdd = {}
    for _, row in ipairs(self.list:GetSelection()) do
        if not row.onRoster then
            if guildies[row.name] then
                toAdd[#toAdd + 1] = row
            else
                LOG:Message(CLM.L["%s is not in the guild and can't be added."], row.name)
            end
        end
    end
    if #toAdd == 0 then return end
    local text = #toAdd == 1
        and string.format(CLM.L["Add %s to the roster?"], toAdd[1].name)
        or string.format(CLM.L["Add %s players to the roster?"], #toAdd)
    UI.Confirm(text, function()
        local GUIDs = {}
        for _, row in ipairs(toAdd) do
            if not CLM.MODULES.ProfileManager:GetProfileByGUID(row.id) then
                CLM.MODULES.ProfileManager:NewProfile(row.id, row.name, row.classFile)
            end
            GUIDs[#GUIDs + 1] = row.id
        end
        CLM.MODULES.RosterManager:AddProfilesToRoster(roster, GUIDs)
        self.list:ClearSelection()
    end)
end

local function RemoveSelectedFromRoster(self)
    local roster = CLM.MODULES.RosterManager:GetRoster()
    if not roster then return end
    local toRemove = {}
    for _, row in ipairs(self.list:GetSelection()) do
        if row.onRoster then toRemove[#toRemove + 1] = row end
    end
    if #toRemove == 0 then return end
    if #toRemove > MAX_REMOVE then
        LOG:Message(CLM.L["You can remove max %d players from roster at the same time."], MAX_REMOVE)
        return
    end
    local text = #toRemove == 1
        and string.format(CLM.L["Remove %s from the roster? Their BP and GP are reset if they are added again."], toRemove[1].name)
        or string.format(CLM.L["Remove %s players from the roster? Their BP and GP are reset if they are added again."], #toRemove)
    UI.Confirm(text, function()
        local GUIDs = {}
        for _, row in ipairs(toRemove) do GUIDs[#GUIDs + 1] = row.id end
        CLM.MODULES.RosterManager:RemoveProfilesFromRoster(roster, GUIDs)
        self.list:ClearSelection()
    end)
end

--[[
 * Building *
]]--

local function UpdateButtons(self)
    local add, remove = 0, 0
    for _, row in ipairs(self.list:GetSelection()) do
        if row.onRoster then remove = remove + 1 else add = add + 1 end
    end
    self.addButton:SetEnabled(add > 0)
    self.removeButton:SetEnabled(remove > 0)
    self.selectionText:SetText(string.format(CLM.L["%s selected: %s to add, %s to remove"], add + remove, add, remove))
end

local function BuildSidePanel(self, content)
    local panel = CreateFrame("Frame", nil, content)
    panel:SetPoint("TOPRIGHT")
    panel:SetPoint("BOTTOMRIGHT")
    panel:SetWidth(SIDE_WIDTH)

    local title = UI.CreateLabel(panel, CLM.L["Show"], "GameFontNormal")
    title:SetPoint("TOPLEFT")
    local previous = title
    local function Filter(label, field)
        local check = UI.CreateCheckbox(panel, label, function(checked)
            self[field] = checked
            self:Refresh()
        end)
        check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", previous == title and -4 or 0, previous == title and -S.XS or 0)
        previous = check
        return check
    end
    Filter(CLM.L["In the current raid only"], "onlyInRaid")
    Filter(CLM.L["Hide players on the roster"], "hideOnRoster")
    Filter(CLM.L["Hide players not on the roster"], "hideNotOnRoster")

    self.selectionText = UI.CreateLabel(panel, "", "GameFontDisableSmall")
    self.selectionText:SetPoint("BOTTOMLEFT", 0, (S.BUTTON + S.S) * 2 + S.XS)
    self.selectionText:SetWidth(SIDE_WIDTH)
    self.selectionText:SetWordWrap(true)

    self.removeButton = UI.CreateButton(panel, CLM.L["Remove from roster"], SIDE_WIDTH, function() RemoveSelectedFromRoster(self) end)
    self.removeButton:SetPoint("BOTTOMRIGHT")
    self.addButton = UI.CreateButton(panel, CLM.L["Add to roster"], SIDE_WIDTH, function() AddSelectedToRoster(self) end)
    self.addButton:SetPoint("BOTTOMRIGHT", self.removeButton, "TOPRIGHT", 0, S.S)
end

function Roster:Build(content, header)
    local search = UI.CreateSearchBox(header, 160, function(text)
        self.search = strlower(text or "")
        self:Refresh()
    end)
    search:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    if search.Instructions then search.Instructions:SetText(CLM.L["Search"]) end

    BuildSidePanel(self, content)
    local inset = UI.CreateInset(content)
    inset:SetPoint("TOPLEFT")
    inset:SetPoint("BOTTOMRIGHT", -(SIDE_WIDTH + S.M), 0)
    self.list = UI.CreateList(inset, {
        columns = {
            { key = "name", title = CLM.L["Name"], width = 0, classIcon = true,
              color = function(row) return UI.GetClassColor(row.classFile) end },
            { key = "rank", title = CLM.L["Rank"], width = 110,
              text = function(row) return row.inGuild and row.values.rank or CLM.L["Not in guild"] end,
              color = function(row) return row.inGuild and UI.COLOR.WHITE or UI.COLOR.BAD end },
            { key = "onRoster", title = CLM.L["On roster"], width = 70,
              color = function() return UI.COLOR.EP end },
            { key = "version", title = CLM.L["Version"], width = 70,
              color = function() return UI.COLOR.GREY end },
        },
        multiSelect = true,
        sortKey = "name",
        rowTint = function(row) return row.isOfficer and OFFICER_TINT or nil end,
        onSelectionChanged = function() UpdateButtons(self) end,
        onRightClick = function(row, rowFrame)
            UI.ShowContextMenu(rowFrame, row.name, {
                { text = CLM.L["Add to roster"], disabled = row.onRoster, func = function() AddSelectedToRoster(self) end },
                { text = CLM.L["Remove from roster"], disabled = not row.onRoster, color = UI.COLOR.BAD,
                  func = function() RemoveSelectedFromRoster(self) end },
            })
        end,
    })
    self.list:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.list:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
end

function Roster:Refresh()
    local rows = BuildRows(self)
    self.list:SetData(rows)
    UpdateButtons(self)
    local roster = CLM.MODULES.RosterManager:GetRoster()
    self.window:SetSubtitle(string.format(CLM.L["%s on the roster"], roster and #roster:Profiles() or 0))
    self.window:SetPageFooter(CLM.L["Green rows are officers. Ctrl-click adds a player, shift-click selects a range."])
end

CLM.GUI.MainWindow:RegisterPage(Roster)
