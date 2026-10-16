-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

-- Manage roster: max level guild members plus everyone on the roster (also those who left
-- the guild), so officers can add guild members to the roster and remove them again.
-- Only guild members can be added; raids never add players by themselves.

local MAX_REMOVE = 10

local colorGreen = {r = 0.27, g = 0.93, b = 0.27, a = 1.0}
local colorGreenTransparent = {r = 0.2, g = 0.93, b = 0.2, a = 0.3}

local highlightTrusted = UTILS.getHighlightMethod(colorGreenTransparent, true)

-- Row layout: 1 class, 2 name, 3 in roster, 4 version | hidden: 5 highlight, 6 GUID, 7 class file
local function ST_GetName(row)
    return row.cols[2].value
end

local function ST_GetHighlight(row)
    return row.cols[5].value
end

local function ST_GetGUID(row)
    return row.cols[6].value
end

local function ST_GetClassFile(row)
    return row.cols[7].value
end

---@class UnifiedGUI_ManageRoster
---@field alreadyDisplayed boolean?
---@field RightClickMenu table
local UnifiedGUI_ManageRoster = {
    name = "manage roster",
    filter = CLM.MODELS.Filters:New(
    (function() CLM.GUI.Unified:FilterScrollingTable() end),
    UTILS.Set({"inRaid", "inGuild", "external", "rank"}),
    UTILS.Set({"buttons", "search"}),
    nil, 1),
}

---@return table[] selected rows as { GUID, name, classFile }
function UnifiedGUI_ManageRoster:GetSelection()
    LOG:Trace("UnifiedGUI_ManageRoster:GetSelection()")
    local st = CLM.GUI.Unified:GetScrollingTable()
    local players = {}
    for _,s in pairs(st:GetSelection()) do
        local row = st:GetRow(s)
        players[#players + 1] = { GUID = ST_GetGUID(row), name = ST_GetName(row), classFile = ST_GetClassFile(row) }
    end
    return players
end

local function AddSelectedToRoster()
    local roster = CLM.MODULES.RosterManager:GetRoster()
    if not roster then
        LOG:Message(CLM.L["Set up BP EPGP first (Standings tab)."])
        return
    end
    local guildies = CLM.MODULES.TrustInfoProvider:GetGuildies()
    local toAdd = {}
    for _, player in ipairs(UnifiedGUI_ManageRoster:GetSelection()) do
        if not roster:IsProfileInRoster(player.GUID) then
            if guildies[player.name] then
                if not CLM.MODULES.ProfileManager:GetProfileByGUID(player.GUID) then
                    CLM.MODULES.ProfileManager:NewProfile(player.GUID, player.name, player.classFile)
                end
                toAdd[#toAdd + 1] = player.GUID
            else
                LOG:Message(CLM.L["%s is not in the guild and can't be added."], player.name)
            end
        end
    end
    if #toAdd > 0 then
        CLM.MODULES.RosterManager:AddProfilesToRoster(roster, toAdd)
    end
    CLM.GUI.Unified:ClearSelection()
end

local function RemoveSelectedFromRoster()
    local roster = CLM.MODULES.RosterManager:GetRoster()
    if not roster then return end
    local toRemove = {}
    for _, player in ipairs(UnifiedGUI_ManageRoster:GetSelection()) do
        if roster:IsProfileInRoster(player.GUID) then
            toRemove[#toRemove + 1] = player.GUID
        end
    end
    if #toRemove == 0 then return end
    if #toRemove > MAX_REMOVE then
        LOG:Message(string.format(CLM.L["You can remove max %d players from roster at the same time."], MAX_REMOVE))
        return
    end
    CLM.MODULES.RosterManager:RemoveProfilesFromRoster(roster, toRemove)
    CLM.GUI.Unified:ClearSelection()
end

local function GenerateUntrustedOptions(self)
    return self.filter:GetAceOptions()
end

local function GenerateOfficerOptions(self)
    return {
        management_header = {
            type = "header",
            name = CLM.L["Management"],
            order = 20
        },
        add_to_roster = {
            name = CLM.L["Add to roster"],
            desc = CLM.L["Adds the selected guild members to the roster."],
            type = "execute",
            width = "full",
            func = AddSelectedToRoster,
            confirm = true,
            order = 21
        },
        remove_from_roster = {
            name = CLM.L["Remove from roster"],
            desc = CLM.L["Removes the selected players from the roster. Their EP and GP are reset if they are added again."],
            type = "execute",
            width = "full",
            func = RemoveSelectedFromRoster,
            confirm = true,
            order = 22
        },
    }
end

local function verticalOptionsFeeder()
    local options = {
        type = "group",
        args = {}
    }
    UTILS.mergeDictsInline(options.args, GenerateUntrustedOptions(UnifiedGUI_ManageRoster))
    if CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER) then
        UTILS.mergeDictsInline(options.args, GenerateOfficerOptions(UnifiedGUI_ManageRoster))
    end
    return options
end

local tableStructure = {
    rows = 25,
    -- columns - structure of the ScrollingTable
    columns = {
        {name = "", width = 18, DoCellUpdate = UTILS.LibStClassCellUpdate},
        {name = CLM.L["Name"],  width = 115, DoCellUpdate = UTILS.LibStNameCellUpdate, sort = LibStub("ScrollingTable").SORT_ASC},
        {name = CLM.L["In roster"],  width = 60, color = colorGreen},
        {name = CLM.L["Version"],  width = 70,
            comparesort = UTILS.LibStCompareSortWrapper(UTILS.LibStModifierFnVersion)
        }
    },
    -- Function to filter ScrollingTable
    filter = (function(stobject, row)
        local playerName = ST_GetName(row)
        return UnifiedGUI_ManageRoster.filter:Filter(playerName, nil, {playerName})
    end),
    -- Events to override for ScrollingTable
    events = {
        -- OnEnter handler -> on hover
        OnEnter = (function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            return table.DefaultEvents["OnEnter"](rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
        end),
        -- OnLeave handler -> on hover out
        OnLeave = (function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            local status = table.DefaultEvents["OnLeave"](rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            local rowData = table:GetRow(realrow)
            if not rowData or not rowData.cols then return status end
            local highlight = ST_GetHighlight(rowData)
            if highlight then
                highlight(rowFrame, cellFrame, data, cols, row, realrow, column, true, table, ...)
            end
            return status
        end),
        -- OnClick handler -> click
        OnClick = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
            UTILS.LibStClickHandler(table, UnifiedGUI_ManageRoster.RightClickMenu, rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
            return true
        end
    }
}

---@param classFile string? e.g. "WARRIOR"
---@return string e.g. "Warrior"
local function ClassFromClassFile(classFile)
    return UTILS.NumberToClass(UTILS.CanonicalClassToNumber(classFile) or 0)
end

local function tableDataFeeder()
    LOG:Trace("UnifiedGUI_ManageRoster tableDataFeeder()")
    local data = {}
    local listed = {}
    local roster = CLM.MODULES.RosterManager:GetRoster()

    local function AddRow(GUID, name, classFile)
        listed[GUID] = true
        local class = ClassFromClassFile(classFile)
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
        local highlight
        if CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER, name) then
            highlight = highlightTrusted
        end
        data[#data+1] = { cols = {
            {value = class},
            {value = name, color = UTILS.GetClassColor(class)},
            {value = (roster and roster:IsProfileInRoster(GUID)) and CLM.L["Yes"] or ""},
            {value = profile and profile:VersionString() or ""},
            -- hidden
            {value = highlight},
            {value = GUID},
            {value = classFile}
        },
        DoCellUpdate = highlight
        }
    end

    local maxLevel = GetMaxLevelForPlayerExpansion()
    for i=1,GetNumGuildMembers() do
        local name, _, _, level, _, _, _, _, _, _, classFile, _, _, _, _, _, GUID = GetGuildRosterInfo(i)
        if name and GUID and level >= maxLevel then
            AddRow(GUID, UTILS.Disambiguate(name), classFile)
        end
    end

    -- Roster members below max level or no longer in the guild, so they can be removed
    if roster then
        for GUID in pairs(roster:Standings()) do
            local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
            if profile and not listed[GUID] then
                AddRow(GUID, profile:Name(), UTILS.CanonicalClass(profile:ClassInternal()))
            end
        end
    end
    return data
end

local function initializeHandler()
    LOG:Trace("UnifiedGUI_ManageRoster initializeHandler()")
    UnifiedGUI_ManageRoster.RightClickMenu = CLM.UTILS.GenerateDropDownMenu(
        {
            {
                title = CLM.L["Add to roster"],
                func = AddSelectedToRoster,
                trustedOnly = true
            },
            {
                title = CLM.L["Remove from roster"],
                func = RemoveSelectedFromRoster,
                trustedOnly = true,
                color = "cc0000"
            },
        },
        CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER),
        CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER)
    )
end

local function beforeShowHandler()
    LOG:Trace("UnifiedGUI_ManageRoster beforeShowHandler()")
    if not UnifiedGUI_ManageRoster.alreadyDisplayed then
        verticalOptionsFeeder()
        UnifiedGUI_ManageRoster.alreadyDisplayed = true
    end
end

CLM.GUI.Unified:RegisterTab(
    UnifiedGUI_ManageRoster.name, 4,
    tableStructure,
    tableDataFeeder,
    nil,
    verticalOptionsFeeder,
    {
        initialize = initializeHandler,
        beforeShow = beforeShowHandler
    },
    "Interface\\PvPRankBadges\\PvPRank13.blp"
)
