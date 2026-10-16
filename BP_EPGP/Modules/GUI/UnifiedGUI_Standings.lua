-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local _, _, _, isElvUI = UTILS.GetAddOnInfo("ElvUI")

local colorRed = {r = 0.93, g = 0.276, b = 0.27, a = 1.0}
local colorBlueTransparent = {r = 0.27, g = 0.276, b = 0.93, a = 0.3}
local colorGreen = {r = 0.27, g = 0.93, b = 0.27, a = 1.0}

local function ST_GetName(row)
    return row.cols[2].value
end

local function ST_GetEP(row)
    return row.cols[4].value
end

local function ST_GetGP(row)
    return row.cols[5].value
end

local function ST_GetProfileLoot(row)
    return row.cols[7].value
end

local function ST_GetProfilePoints(row)
    return row.cols[8].value
end

local function ST_GetHighlight(row)
    return row.cols[9].value
end

local function ST_GetClass(row)
    return row.cols[10].value
end

local highlightPlayer = UTILS.getHighlightMethod(colorBlueTransparent, true)

local function refreshFn(...)
    CLM.GUI.Unified:Refresh(...)
end

---@class UnifiedGUI_Standings
---@field context number
---@field roster string?
---@field awardReason number
---@field awardType number?
---@field awardValue string?
---@field decayType number?
---@field decayValue string?
---@field note string?
---@field includeNegative boolean?
---@field RightClickMenu table
local UnifiedGUI_Standings = {
    name = "standings",
    awardReason = CONSTANTS.POINT_CHANGE_REASON.MANUAL_ADJUSTMENT,
    filter = CLM.MODELS.Filters:New(
    (function() CLM.GUI.Unified:FilterScrollingTable() end),
    UTILS.Set({
        "class", "inRaid",
        "inGuild", "external", "rank"
    }),
    UTILS.Set({
        "buttons", "search"
    }),
    nil, 2),
    tooltip = CreateFrame("GameTooltip", "BPEPGPUnifiedGUIStandingsDialogTooltip", UIParent, "GameTooltipTemplate"),
}

local function HandleRosterChange(rosterUid)
    UnifiedGUI_Standings.roster = rosterUid
    UnifiedGUI_Standings.awardType = CONSTANTS.POINT_CHANGE_TYPE.POINTS
    UnifiedGUI_Standings.decayType = CONSTANTS.POINT_CHANGE_TYPE.TOTAL
end

---@return Profile[]
function UnifiedGUI_Standings:GetSelection()
    LOG:Trace("UnifiedGUI_Standings:GetSelection()")
    local st = CLM.GUI.Unified:GetScrollingTable()
    local profiles = {}
    -- Roster
    local roster = CLM.MODULES.RosterManager:GetRosterByUid(self.roster)
    if not roster then
        return profiles
    end
    -- Profiles
    local selected = st:GetSelection()
    if #selected == 0 then
        return profiles
    end
    for _,s in pairs(selected) do
        local profile = CLM.MODULES.ProfileManager:GetProfileByName(ST_GetName(st:GetRow(s)))
        if profile then
            profiles[#profiles+1] = profile
        else
            LOG:Debug("No profile for %s", ST_GetName(st:GetRow(s)))
        end
    end
    return profiles
end

local function GenerateUntrustedOptions(self)
    local options = {}
    options.roster = {
        name = CLM.L["Roster"],
        type = "select",
        values = CLM.MODULES.RosterManager:GetRostersUidMap(),
        set = function(i, v)
            -- self.roster = v
            HandleRosterChange(v)
            self.context = CONSTANTS.ACTION_CONTEXT.ROSTER
            refreshFn()
        end,
        get = function(i) return self.roster end,
        width = "full",
        order = 0
    }
    UTILS.mergeDictsInline(options, self.filter:GetAceOptions())
    return options
end

local function GenerateAssistantOptions(self)
    return {
        award_header = {
            type = "header",
            name = CLM.L["Management"],
            order = 9
        },
        action_context = {
            name = CLM.L["Action context"],
            type = "select",
            values = CONSTANTS.ACTION_CONTEXT_GUI,
            set = function(i, v) self.context = v end,
            get = function(i) return self.context end,
            order = 10,
            width = "full"
        },
        award_dkp_note = {
            name = CLM.L["Note"],
            desc = (function()
                local n = CLM.L["Note to be added to award. Max 25 characters. It is recommended to not include date nor selected reason here. If you will input encounter ID it will be transformed into boss name."]
                if strlen(self.note or "") > 0 then
                    n = n .. "\n\n|cffeeee00Note:|r " .. self.note
                end
                return n
            end),
            type = "input",
            set = function(i, v) self.note = v end,
            get = function(i) return self.note end,
            width = "full",
            order = 12
        },
        award_reason = {
            name = CLM.L["Reason"],
            type = "select",
            values = CONSTANTS.POINT_CHANGE_REASONS.GENERAL,
            set = function(i, v) self.awardReason = v end,
            get = function(i) return self.awardReason end,
            order = 11,
            width = "full"
        },
        award_dkp_value = {
            name = CLM.L["Award value"],
            desc = CLM.L["Points value that will be awarded."],
            type = "input",
            set = function(i, v) self.awardValue = v end,
            get = function(i) return self.awardValue end,
            width = 0.5,
            pattern = CONSTANTS.REGEXP_FLOAT,
            order = 13
        },
        award_dkp = {
            name = CLM.L["Award"],
            desc = CLM.L["Award points to players based on context."],
            type = "execute",
            width = isElvUI and 0.5 or 0.575,
            func = (function(i)
                -- Award Value
                local awardValue = tonumber(self.awardValue)
                if not awardValue then LOG:Debug("UnifiedGUI_Standings(Award): missing award value"); return end
                -- Reason
                local awardReason
                if self.awardReason and CONSTANTS.POINT_CHANGE_REASONS.GENERAL[self.awardReason] then
                    awardReason = self.awardReason
                else
                    LOG:Debug("UnifiedGUI_Standings(Award): missing reason");
                    awardReason = CONSTANTS.POINT_CHANGE_REASON.MANUAL_ADJUSTMENT
                end

                local note = ""
                if self.note and strlen(self.note) > 0 then
                    note = ": " .. tostring(self.note)
                end

                local roster = CLM.MODULES.RosterManager:GetRosterByUid(self.roster)
                if self.context == CONSTANTS.ACTION_CONTEXT.RAID then
                    if CLM.MODULES.RaidManager:IsInRaid() then
                        local raid = CLM.MODULES.RaidManager:GetRaid()
                        CLM.MODULES.PointManager:UpdateRaidPoints(raid, awardValue, awardReason, CONSTANTS.POINT_MANAGER_ACTION.MODIFY, self.note, self.awardType)

                        if CLM.GlobalConfigs:GetAnnounceAwardToGuild() then
                            UTILS.SendChatMessage(
                                string.format(
                                    CLM.L["Awarded %s points for %s to all players in raid %s"] .. note,
                                    awardValue, CONSTANTS.POINT_CHANGE_REASONS.ALL[awardReason] or "", raid:Name()
                                ),
                                "GUILD"
                            )
                        end

                    else
                        LOG:Warning("You are not in raid.")
                    end
                elseif self.context == CONSTANTS.ACTION_CONTEXT.ROSTER then
                    if roster then
                        CLM.MODULES.PointManager:UpdateRosterPoints(roster, awardValue, awardReason, CONSTANTS.POINT_MANAGER_ACTION.MODIFY, false, self.note, self.awardType)

                        if CLM.GlobalConfigs:GetAnnounceAwardToGuild() then
                            UTILS.SendChatMessage(
                                string.format(
                                    CLM.L["Awarded %s points to %s player(s) for %s in <%s>"] .. note,
                                    awardValue, string.lower(CLM.L["All"]), CONSTANTS.POINT_CHANGE_REASONS.ALL[awardReason] or "",
                                    CLM.MODULES.RosterManager:GetRosterNameByUid(roster:UID())
                                ),
                                "GUILD"
                            )
                        end

                    else
                        LOG:Warning("Missing valid roster.")
                    end
                elseif self.context == CONSTANTS.ACTION_CONTEXT.SELECTED then
                    local profiles = UnifiedGUI_Standings:GetSelection()
                    if not profiles or #profiles == 0 then
                        LOG:Message(CLM.L["No players selected"])
                        LOG:Debug("UnifiedGUI_Standings(Award): profiles == 0")
                        return
                    end
                    if roster then
                        CLM.MODULES.PointManager:UpdatePoints(roster, profiles, awardValue, awardReason, CONSTANTS.POINT_MANAGER_ACTION.MODIFY, self.note, self.awardType)

                        if CLM.GlobalConfigs:GetAnnounceAwardToGuild() then

                            UTILS.SendChatMessage(
                                string.format(
                                    CLM.L["Awarded %s points to %s player(s) for %s in <%s>"] .. note,
                                    awardValue, #profiles, CONSTANTS.POINT_CHANGE_REASONS.ALL[awardReason] or "",
                                    CLM.MODULES.RosterManager:GetRosterNameByUid(roster:UID())
                                ),
                                "GUILD"
                            )
                        end

                    else
                        LOG:Warning("Missing valid roster.")
                    end
                end
            end),
            confirm = (function()
                local awardValue = tonumber(self.awardValue)
                if not awardValue then return CLM.L["Missing award value"] end
                local points = UTILS.DecodePointTypeChangeName(self.awardType)
                if self.context == CONSTANTS.ACTION_CONTEXT.RAID then
                    return string.format(CLM.L["Award %s %s to everyone in raid."], awardValue, points)
                elseif self.context == CONSTANTS.ACTION_CONTEXT.ROSTER then
                    return string.format(CLM.L["Award %s %s to everyone in roster."], awardValue, points)
                elseif self.context == CONSTANTS.ACTION_CONTEXT.SELECTED then
                    local profiles = UnifiedGUI_Standings:GetSelection()
                    if not profiles then profiles = {} end
                    return string.format(CLM.L["Award %s %s to %s selected players."], awardValue, points, #profiles)
                end
            end),
            order = 14
        },
        award_type_dropdown = {
            name = CLM.L["Type"],
            type = "select",
            values = CONSTANTS.EPGP_POINT_AWARD_TYPES_GUI,
            set = function(i, v) self.awardType = v end,
            get = function(i) return self.awardType end,
            control = "BPEPGPButtonDropDown",
            order = 15,
            width = 0.2
        },
    }
end

local function GenerateManagerOptions(self)
    return {
        decay_dkp_value = {
            name = CLM.L["Decay %"],
            desc = CLM.L["% that will be decayed."],
            type = "input",
            set = function(i, v) self.decayValue = v end,
            get = function(i) return self.decayValue end,
            width = 0.5,
            pattern = CONSTANTS.REGEXP_FLOAT,
            order = 21
        },
        decay_type_dropodown = {
            name = CLM.L["Type"],
            type = "select",
            values = CONSTANTS.EPGP_POINT_DECAY_TYPES_GUI,
            set = function(i, v) self.decayType = v end,
            get = function(i) return self.decayType end,
            control = "BPEPGPButtonDropDown",
            order = 23,
            width = 0.2
        },
        decay_dkp = {
            name = CLM.L["Decay"],
            desc = CLM.L["Execute decay for players based on context."],
            type = "execute",
            width = isElvUI and 0.5 or 0.575,
            func = (function(i)
                -- Decay Value
                local decayValue = tonumber(self.decayValue)
                if not decayValue then LOG:Debug("UnifiedGUI_Standings(Decay): missing decay value"); return end
                if decayValue > 100 or decayValue < 0 then LOG:Warning("Standings: Decay value should be between 0 and 100%"); return end
                local roster = CLM.MODULES.RosterManager:GetRosterByUid(self.roster)
                if roster == nil then
                    LOG:Debug("UnifiedGUI_Standings(Decay): roster == nil")
                    return
                end
                if self.context == CONSTANTS.ACTION_CONTEXT.ROSTER then
                    CLM.MODULES.PointManager:UpdateRosterPoints(roster, decayValue, CONSTANTS.POINT_CHANGE_REASON.DECAY, CONSTANTS.POINT_MANAGER_ACTION.DECAY, not self.includeNegative, nil, self.decayType)
                elseif self.context == CONSTANTS.ACTION_CONTEXT.SELECTED then
                    local profiles = UnifiedGUI_Standings:GetSelection()
                    if not profiles or #profiles == 0 then
                        LOG:Message(CLM.L["No players selected"])
                        LOG:Debug("UnifiedGUI_Standings(Decay): profiles == 0")
                        return
                    end
                    CLM.MODULES.PointManager:UpdatePoints(roster, profiles, decayValue, CONSTANTS.POINT_CHANGE_REASON.DECAY, CONSTANTS.POINT_MANAGER_ACTION.DECAY, nil, self.decayType)
                else
                    LOG:Warning("Invalid context. You should not decay raid only.")
                end
            end),
            confirm = (function()
                local decayValue = tonumber(self.decayValue)
                if not decayValue then return CLM.L["Missing decay value"] end
                local points = UTILS.DecodePointTypeChangeName(self.decayType)
                if self.context == CONSTANTS.ACTION_CONTEXT.RAID then
                    return CLM.L["Invalid context. You should not decay raid only."]
                elseif self.context == CONSTANTS.ACTION_CONTEXT.ROSTER then
                    return string.format(CLM.L["Decay %s%% %s to everyone in roster."], decayValue, points)
                elseif self.context == CONSTANTS.ACTION_CONTEXT.SELECTED then
                    local profiles = UnifiedGUI_Standings:GetSelection()
                    if not profiles then profiles = {} end
                    return string.format(CLM.L["Decay %s%% %s to %s selected players."], decayValue, points, #profiles)
                end
            end),
            order = 22
        }
    }
end

local function verticalOptionsFeeder()
    local options = {
        type = "group",
        args = {}
    }
    UTILS.mergeDictsInline(options.args, GenerateUntrustedOptions(UnifiedGUI_Standings))
    if CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.ASSISTANT) then
        UTILS.mergeDictsInline(options.args, GenerateAssistantOptions(UnifiedGUI_Standings))
    end
    if CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.MANAGER) then
        UTILS.mergeDictsInline(options.args, GenerateManagerOptions(UnifiedGUI_Standings))
    end
    return options
end

local columns = {
    {   name = "", width = 18, DoCellUpdate = UTILS.LibStClassCellUpdate },
    {   name = CLM.L["Name"], width = 127, DoCellUpdate = UTILS.LibStNameCellUpdate },
    {   name = CLM.L["PR"], width = 80, sort = LibStub("ScrollingTable").SORT_DSC, color = colorGreen },
    {   name = CLM.L["EP"], width = 80 },
    {   name = CLM.L["GP"], width = 80 }
}

local tableStructure = {
    rows = 25,
    -- columns - structure of the ScrollingTable
    columns = columns,
    -- Function to filter ScrollingTable
    filter = (function(stobject, row)
        local playerName = ST_GetName(row)
        local class = ST_GetClass(row)
        return UnifiedGUI_Standings.filter:Filter(playerName, class, {playerName, class})
    end),
    -- Events to override for ScrollingTable
    events = {
        -- OnEnter handler -> on hover
        OnEnter = (function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            local status = table.DefaultEvents["OnEnter"](rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            local rowData = table:GetRow(realrow)
            if not rowData or not rowData.cols then return status end
            local tooltip = UnifiedGUI_Standings.tooltip
            if not tooltip then return end
            tooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
            tooltip:AddDoubleLine(
                UTILS.ColorCodeText(tostring(ST_GetEP(rowData)) .. " ".. CLM.L["EP"], "44ee44"),
                UTILS.ColorCodeText(tostring(ST_GetGP(rowData)) .. " ".. CLM.L["GP"], "44ee44"))
            -- Loot History
            local lootList = ST_GetProfileLoot(rowData)
            tooltip:AddLine("\n")
            if #lootList > 0 then
                tooltip:AddLine(UTILS.ColorCodeText(CLM.L["Latest loot"], "44ee44"))
                local limit = #lootList - 4 -- inclusive (- 5 + 1)
                if limit < 1 then
                    limit = 1
                end
                for i=#lootList, limit, -1 do
                    local loot = lootList[i]
                    local _, itemLink = UTILS.GetItemInfo(loot:String())
                    if itemLink then
                        local value = tostring(loot:Value()) .. " " .. CLM.L["GP"]
                        tooltip:AddDoubleLine(itemLink, value)
                    end
                end
            else
                tooltip:AddLine(UTILS.ColorCodeText(CLM.L["No loot received"], "44ee44"))
            end
            -- Point History
            local pointList = ST_GetProfilePoints(rowData)
            tooltip:AddLine("\n")
            if #pointList > 0 then
                tooltip:AddLine(UTILS.ColorCodeText(CLM.L["Latest points"], "44ee44"))
                local limit = #pointList - 4 -- inclusive (- 5 + 1)
                if limit < 1 then
                    limit = 1
                end
                for i=#pointList, limit, -1 do
                    local point = pointList[i]

                    local reason = point:Reason() or 0
                    local value = tostring(point:Value())

                    if reason == CONSTANTS.POINT_CHANGE_REASON.DECAY then
                        value = value .. "%"
                    end
                    local suffix = UTILS.DecodePointTypeChangeName(point:Type())
                    value = value .. " " .. suffix
                    tooltip:AddDoubleLine(CONSTANTS.POINT_CHANGE_REASONS.ALL[reason] or "", value)
                end
            else
                tooltip:AddLine(UTILS.ColorCodeText(CLM.L["No points received"], "44ee44"))
            end
            -- Display
            tooltip:Show()
            return status
        end),
        -- OnLeave handler -> on hover out
        OnLeave = (function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            local status = table.DefaultEvents["OnLeave"](rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            UnifiedGUI_Standings.tooltip:Hide()
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
            UTILS.LibStClickHandler(table, UnifiedGUI_Standings.RightClickMenu, rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
            UnifiedGUI_Standings.context = CONSTANTS.ACTION_CONTEXT.SELECTED
            CLM.GUI.Unified:RefreshOptionsPane()
            return true
        end
    }
}

local function tableDataFeeder()
    LOG:Trace("UnifiedGUI_Standings tableDataFeeder()")
    local roster = CLM.MODULES.RosterManager:GetRosterByUid(UnifiedGUI_Standings.roster)
    if not roster then return {} end
    local rowId = 1
    local data = {}
    for GUID,value in pairs(roster:Standings()) do
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
        if profile then
            local highlight
            if profile:Name() == UTILS.whoami() then
                highlight = highlightPlayer
            end
            local classColor = UTILS.GetClassColor(profile:ClassInternal())
            local row = { cols = {
        --[[1]]  {value = profile:ClassInternal()},
        --[[2]]  {value = profile:Name(), color = classColor},
        --[[3]]  {value = roster:Priority(GUID), color = (value > 0 and colorGreen or colorRed)},
        --[[4]]  {value = value},
        --[[5]]  {value = roster:GP(GUID)},
            -- not displayed
        --[[6]]  {value = roster:GetPointInfoForPlayer(GUID)},
        --[[7]]  {value = roster:GetProfileLootByGUID(GUID)},
        --[[8]]  {value = roster:GetProfilePointHistoryByGUID(GUID)},
        --[[9]]  {value = highlight},
        --[[10]] {value = profile:Class()}
            },
            DoCellUpdate = highlight
            }
            data[rowId] = row
            rowId = rowId + 1
        end
    end
    return data
end

local function initializeHandler()
    LOG:Trace("UnifiedGUI_Standings initializeHandler()")
    UnifiedGUI_Standings.RightClickMenu = CLM.UTILS.GenerateDropDownMenu(
        {
            {
                title = CLM.L["Remove from roster"],
                func = (function(i)
                    local profiles = UnifiedGUI_Standings:GetSelection()
                    local roster = CLM.MODULES.RosterManager:GetRosterByUid(UnifiedGUI_Standings.roster)
                    if roster == nil then
                        LOG:Debug("UnifiedGUI_Standings(Remove): roster == nil")
                        return
                    end
                    if not profiles or #profiles == 0 then
                        LOG:Debug("UnifiedGUI_Standings(Remove): profiles == 0")
                        return
                    end
                    if #profiles > 10 then
                        LOG:Message(string.format(
                            CLM.L["You can remove max %d players from roster at the same time."],
                            10
                        ))
                        return
                    end
                    CLM.MODULES.RosterManager:RemoveProfilesFromRoster(roster, profiles)
                    refreshFn(true)
                    CLM.GUI.Unified:ClearSelection()
                end),
                trustedOnly = true,
                color = "cc0000"
            },
        },
        CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.ASSISTANT),
        CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.MANAGER)
    )
end

local function refreshHandler()
    CLM.GUI.Unified:GetScrollingTable():SetDisplayCols(columns)
end

local function beforeShowHandler()
    LOG:Trace("UnifiedGUI_Standings beforeShowHandler()")
    UnifiedGUI_Standings.context = CONSTANTS.ACTION_CONTEXT.ROSTER
    if CLM.MODULES.RaidManager:IsInRaid() then
        HandleRosterChange(CLM.MODULES.RaidManager:GetRaid():Roster():UID())
        UnifiedGUI_Standings.filter:SetFilterValue(CONSTANTS.FILTER.IN_RAID, true)
        UnifiedGUI_Standings.context = CONSTANTS.ACTION_CONTEXT.RAID
    else
        UnifiedGUI_Standings.filter:SetFilterValue(CONSTANTS.FILTER.IN_RAID, false)
    end

    refreshHandler() -- this is actually here only for the structure update
end

local function storeHandler()
    LOG:Trace("UnifiedGUI_Standings storeHandler()")
    local storage = CLM.GUI.Unified:GetStorage(UnifiedGUI_Standings.name)
    storage.roster = UnifiedGUI_Standings.roster
end

local function restoreHandler()
    LOG:Trace("UnifiedGUI_Standings restoreHandler()")
    local storage = CLM.GUI.Unified:GetStorage(UnifiedGUI_Standings.name)
    HandleRosterChange(storage.roster)
end

local function dataReadyHandler()
    LOG:Trace("UnifiedGUI_Standings dataReadyHandler()")
    if not CLM.MODULES.RosterManager:GetRosterByUid(UnifiedGUI_Standings.roster) then
        local _, roster = next(CLM.MODULES.RosterManager:GetRosters())
        if roster then
            HandleRosterChange(roster:UID())
        end
    else
        HandleRosterChange(UnifiedGUI_Standings.roster) -- force update of data relying on roster
    end
end

CONSTANTS.ACTION_CONTEXT = {
    SELECTED = 1,
    ROSTER = 2,
    RAID = 3
}

CONSTANTS.ACTION_CONTEXT_GUI = {
    [CONSTANTS.ACTION_CONTEXT.SELECTED] = CLM.L["Selected"],
    [CONSTANTS.ACTION_CONTEXT.ROSTER] = CLM.L["Roster"],
    [CONSTANTS.ACTION_CONTEXT.RAID] = CLM.L["Raid"],
}

CONSTANTS.ACTION_CONTEXT_LIST = {
    CONSTANTS.ACTION_CONTEXT.SELECTED,
    CONSTANTS.ACTION_CONTEXT.ROSTER,
    CONSTANTS.ACTION_CONTEXT.RAID
}

CLM.GUI.Unified:RegisterTab(
    UnifiedGUI_Standings.name, 1,
    tableStructure,
    tableDataFeeder,
    nil,
    verticalOptionsFeeder,
    {
        initialize = initializeHandler,
        refresh = refreshHandler,
        beforeShow = beforeShowHandler,
        store = storeHandler,
        restore = restoreHandler,
        dataReady = dataReadyHandler
    },
    CLM.MEDIA_PATH .. "Icons\\clm-dark-32.png"
)
