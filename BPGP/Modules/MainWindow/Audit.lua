-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
-- local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI
local S = UI.SPACE

--[[
    Audit tab (officers, R4): every ledger entry in order, with a readable description.
    Entries that could not be applied (S3) are shown in red with a count in the footer.
    Right-click removes an entry (an ignore entry, synced to everyone).
]]--

local function safeToString(value)
    return tostring(value) or ""
end

local function boolToString(value)
    return value and CLM.L["True"] or CLM.L["False"]
end

local function safeItemIdToLink(itemId)
    local _, itemLink = UTILS.GetItemInfo(itemId)
    return itemLink or safeToString(itemId)
end

local function decodeReason(reason)
    return CONSTANTS.POINT_CHANGE_REASONS.ALL[reason] or ""
end

local configDecodeFunctions = {
    ["-"] = (function(value)
        return "", ""
    end),
    ---
    auctionTime = (function(value)
        return CLM.L["Auction Time"], safeToString(value)
    end),
    antiSnipe = (function(value)
        return CLM.L["Anti-snipe"], safeToString(value)
    end),
    onTimeBonus = (function(value)
        return CLM.L["On Time Bonus"], boolToString(value)
    end),
    onTimeBonusValue = (function(value)
        return CLM.L["On Time Bonus value"], safeToString(value)
    end),
    roundDecimals = (function(value)
        return CLM.L["Round to"], safeToString(value)
    end),
    minimumPoints = (function(value)
        return CLM.L["Minimum points (DKP / BP)"], safeToString(value)
    end),
    minGP = (function(value)
        return CLM.L["Minimum GP"], safeToString(value)
    end),
}

local function decodeRosterConfig(config, value)
    local fn = configDecodeFunctions[config] or configDecodeFunctions["-"]
    return fn(value)
end

local function decodeSlotValueConfig(entry)
    return CONSTANTS.INVENTORY_TYPES_GUI[entry:slot()] or "", safeToString(CONSTANTS.SLOT_VALUE_TIERS_GUI[entry:tier()]) .. ": " .. safeToString(entry:value())
end

local function decodeItemValueOverride(entry)
    local value = ""
    local values = entry:values()
    for key,_ in pairs(CLM.CONSTANTS.SLOT_VALUE_TIERS) do
        value = value .. safeToString(CONSTANTS.SLOT_VALUE_TIERS_GUI[key]) .. ": " .. safeToString(values[key]or "?")
    end
    return safeItemIdToLink(entry:itemId()), value
end

local function decodeItemValueOverrideSingle(entry)
    return safeItemIdToLink(entry:itemId()), safeToString(CONSTANTS.SLOT_VALUE_TIERS_GUI[entry:tier()]) .. ": " .. safeToString(entry:value())
end

local nameFunctions  = {
    -- Default
    ["-"] = (function(entry)
        return ""
    end),
    -- Profile
    ["P0"] = (function(entry)
        return CLM.L["[Update Profile]: "]
    end),
    ["P1"] = (function(entry)
        return CLM.L["[Remove Profile]: "]
    end),
    -- Roster
    ["R0"] = (function(entry)
        return CLM.L["[Create Roster]: "]
    end),
    ["R1"] = (function(entry)
        return CLM.L["[Delete Roster]: "]
    end),
    ["R2"] = (function(entry)
        return CLM.L["[Rename Roster]: "]
    end),
    ["R3"] = (function(entry)
        return CLM.L["[All Roster Configs]: "]
    end),
    ["R4"] = (function(entry)
        return CLM.L["[Roster Config]: "]
    end),
    ["R5"] = (function(entry)
        return CLM.L["[All Roster Default Slot Values]: "]
    end),
    ["R6"] = (function(entry)
        return CLM.L["[Roster Default Slot Value]: "]
    end),
    ["R7"] = (function(entry)
        return CLM.L["[Roster Item Value Override]: "]
    end),
    ["R8"] = (function(entry)
        return CLM.L["[Roster Item Value Override Single]: "]
    end),
    ["R9"] = (function(entry)
        return CLM.L["[Roster Update Profiles]: "]
    end),
    ["RC"] = (function(entry)
        return CLM.L["[Roster Copy]: "]
    end),
    ["RF"] = (function(entry)
        return CLM.L["[Roster Field Rename]: "]
    end),
    -- Points
    ["DM"] = (function(entry)
        return CLM.L["[Point Award]: "]
    end),
    ["DD"] = (function(entry)
        return CLM.L["[Point Decay]: "]
    end),
    ["DO"] = (function(entry)
        return CLM.L["[Point Award to roster]: "]
    end),
    ["DR"] = (function(entry)
        return CLM.L["[Point Award to raid]: "]
    end),
    ["DT"] = (function(entry)
        return CLM.L["[Point Decay for roster]: "]
    end),
    ["DS"] = (function(entry)
        return CLM.L["[Point Set]: "]
    end),
    -- Loot
    ["IA"] = (function(entry)
        return CLM.L["[Item Award]: "]
    end),
    ["II"] = (function(entry)
        return CLM.L["[Item Award in Raid]: "]
    end),
    -- Raid
    ["AC"] = (function(entry)
        return CLM.L["[Raid Create]: "]
    end),
    ["AS"] = (function(entry)
        return CLM.L["[Raid Start]: "]
    end),
    ["AU"] = (function(entry)
        return CLM.L["[Raid Update]: "]
    end),
    ["AE"] = (function(entry)
        return CLM.L["[Raid Finish]: "]
        end),
    ["IGN"] = (function(entry)
        return CLM.L["[IGNORE]: Ignoring entry"]
    end),
}

local describeFunctions  = {
    -- Default
    ["-"] = (function(entry)
        local description = ""
        for _, field in ipairs(entry:fields()) do
            description = description .. (tostring(entry[field]) or "") .. " "
        end
        return description
    end),
    -- Profile
    ["P0"] = (function(entry)
        return
            UTILS.ColorCodeText(UTILS.getGuidFromInteger(entry:GUID()), "6699ff") ..
            " " ..
            UTILS.ColorCodeText(entry:name(), UTILS.GetClassColor(UTILS.NumberToClass(entry:ingameClass())).hex)
    end),
    ["P1"] = (function(entry)
        local guid = UTILS.getGuidFromInteger(entry:GUID())
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(guid)
        return
            UTILS.ColorCodeText(profile and profile:Name() or guid,
                          profile and UTILS.GetClassColor(profile:Class()).hex or "6699ff")
    end),
    -- Roster
    ["R0"] = (function(entry)
        return
            entry:rosterUid() ..
            " <" .. UTILS.ColorCodeText(entry:name(), "ebb434") .. ">"
    end),
    ["R1"] = (function(entry)
        return
            "<" .. UTILS.ColorCodeText(entry:rosterUid(), "ebb434") ..">"
    end),
    ["R2"] = (function(entry)
        return
            entry:rosterUid() ..
            " <" .. UTILS.ColorCodeText(entry:name(), "ebb434") .. ">"
    end),
    ["R3"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            "<" .. UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434") .. "> " .. CLM.L["Too much data to display"]

    end),
    ["R4"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        local config, value = decodeRosterConfig(entry:config(), entry:value())
        return
            "<" .. UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434") .. "> " ..
            config .. ": " .. value
    end),
    ["R5"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            "<" .. UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434") .. "> " .. CLM.L["Too much data to display"]

    end),
    ["R6"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        local slot, values = decodeSlotValueConfig(entry)
        return
            "<" .. UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434") .. "> " ..
            slot .. ": " .. values
    end),
    ["R7"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        local link, values = decodeItemValueOverride(entry)
        return
            "<" .. UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434") .. "> " ..
            link .. ": " .. values

    end),
    ["R8"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        local link, values = decodeItemValueOverrideSingle(entry)
        return
            "<" .. UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434") .. "> " ..
            link .. ": " .. values
    end),
    ["R9"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            "<" .. UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434") .. "> " ..
            (entry:remove() and CLM.L["Remove"] or CLM.L["Add"]) .. " " .. safeToString(#entry:profiles()) .. CLM.L[" profile(s)"]

    end),
    ["RC"] = (function(entry)
        local source = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:sourceRosterUid())
        local target = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:targetRosterUid())
        return
            "From <" .. UTILS.ColorCodeText(source or entry:sourceRosterUid(), "ebb434") .. "> " ..
            "to <" .. UTILS.ColorCodeText(target or entry:targetRosterUid(), "ebb434") .. ">: " ..
            (entry:config() and CLM.L["[config] "] or "") ..
            (entry:defaults() and CLM.L["[slot defaults] "] or "") ..
            (entry:overrides() and CLM.L["[item values] "] or "") ..
            (entry:profiles() and CLM.L["[profiles] "] or "")

    end),
    ["RF"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            "<" .. UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434") .. "> " ..
            safeToString(CONSTANTS.SLOT_VALUE_TIERS_GUI[entry:tier()]) .. ": " .. safeToString(entry:name())
    end),
    -- Points
    ["DM"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            string.format(CLM.L["Awarded %s points to %s player(s) for %s in <%s>"],
                safeToString(entry:value()), safeToString(#entry:targets()),
                decodeReason(entry:reason()), UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434")
            )
    end),
    ["DD"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            string.format(CLM.L["Decayed %s%% points to %s players in <%s>"],
                safeToString(entry:value()), safeToString(#entry:targets()),
                UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434")
            )
    end),
    ["DO"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            string.format(CLM.L["Awarded %s points to all players for %s in <%s>"],
                safeToString(entry:value()), decodeReason(entry:reason()),
                UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434")
            )
    end),
    ["DR"] = (function(entry)
        local raid = CLM.MODULES.RaidManager:GetRaidByUid(entry:raidUid())
        return
            string.format(CLM.L["Awarded %s points for %s to all players in raid %s"],
                safeToString(entry:value()), decodeReason(entry:reason()),
                (raid and ("(" .. UTILS.ColorCodeText(raid:Name(), "d99212") .. ")") or "")
            )
    end),
    ["DT"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            string.format(CLM.L["Decayed %s%% points to all players %s in <%s>"],
                safeToString(entry:value()), (entry:ignoreNegatives() and CLM.L["excluding negatives "] or ""),
                UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434")
            )
    end),
    ["DS"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            string.format(CLM.L["Set %s points to %s players for %s in <%s>"],
                safeToString(entry:value()), safeToString(#entry:targets()),
                decodeReason(entry:reason()), UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434")
            )
    end),
    -- Loot
    ["IA"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        local guid = UTILS.getGuidFromInteger(entry:profile())
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(guid)
        return
            string.format(CLM.L["%s to %s for %s in <%s>"],
                safeItemIdToLink(entry:item()), (profile and profile:Name() or guid),
                safeToString(entry:value()), UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434")
            )
    end),
    ["II"] = (function(entry)
        local raid = CLM.MODULES.RaidManager:GetRaidByUid(entry:raidUid())
        local guid = UTILS.getGuidFromInteger(entry:profile())
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(guid)
        return
            string.format(CLM.L["%s to %s for %s in <%s>"],
                safeItemIdToLink(entry:item()), (profile and profile:Name() or guid),
                safeToString(entry:value()), UTILS.ColorCodeText(raid and raid:Name() or entry:raidUid(), "ebb434")
            )
    end),
    -- Raid
    ["AC"] = (function(entry)
        local name = CLM.MODULES.RosterManager:GetRosterNameByUid(entry:rosterUid())
        return
            string.format(
                CLM.L["Create raid %s %s in <%s>"],
                UTILS.ColorCodeText(entry:name(), "d99212"), safeToString(entry:uuid()),
                UTILS.ColorCodeText(name or entry:rosterUid(), "ebb434")
            )
    end),
    ["AS"] = (function(entry)
        local raid = CLM.MODULES.RaidManager:GetRaidByUid(entry:raid())
        return
            string.format(CLM.L["Started raid %s"],
                UTILS.ColorCodeText(safeToString(raid and raid:Name() or entry:raid()), "d99212")
            )
    end),
    ["AU"] = (function(entry)
        local raid = CLM.MODULES.RaidManager:GetRaidByUid(entry:raid())
        return
            string.format(CLM.L["Updated raid <%s> %s joined, %s left, %s removed"],
                UTILS.ColorCodeText(raid and raid:Name() or entry:raid(), "d99212"),
                safeToString(#entry:joiners()), safeToString(#entry:leavers()),
                safeToString(#entry:removed())
            )
    end),
    ["AE"] = (function(entry)
        local raid = CLM.MODULES.RaidManager:GetRaidByUid(entry:raid())
        return
            string.format(CLM.L["Finished raid %s"],
                UTILS.ColorCodeText(raid and raid:Name() or entry:raid(), "d99212")
            )
        end),
    ["IGN"] = (function(entry)
        return CLM.L["[IGNORE]: Ignoring entry"]
    end),
}

local function concatenateNameFromList(list)
    local names = ""
    for _,iGUID in ipairs(list) do
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(UTILS.getGuidFromInteger(iGUID))
        if profile then
            names = names .. profile:Name() .. ", "
        end
    end
    return names
end

local extendFunctions  = {
    -- Default
    ["-"] = (function(entry)
        return ""
    end),
    -- Profiles
    -- Points
    ["DM"] = (function(entry)
        return concatenateNameFromList(entry:targets())
    end),
    ["DD"] = (function(entry)
        return concatenateNameFromList(entry:targets())
    end),
    ["DS"] = (function(entry)
        return concatenateNameFromList(entry:targets())
    end),
    ["AU"] = (function(entry)
        local names = ""
        names = names .. concatenateNameFromList(entry:joiners())
        names = names .. concatenateNameFromList(entry:leavers())
        names = names .. concatenateNameFromList(entry:removed())
        return names
    end),
}

local function describeEntry(entry)
    local fn = describeFunctions[entry:class()] or describeFunctions["-"]
    return fn(entry)
end

local function nameEntry(entry)
    local fn = nameFunctions[entry:class()] or nameFunctions["-"]
    return fn(entry)
end

local function extendEntryData(entry)
    local fn = extendFunctions[entry:class()] or extendFunctions["-"]
    return fn(entry)
end

local function getEntryInfo(entry)
    -- Common info
    local name = nameEntry(entry)
    local time = entry:time()
    local type = entry:class()
    local guid = UTILS.getGuidFromInteger(entry:creatorFull())
    local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(guid)
    local author = profile and profile:Name() or guid
    local description = describeEntry(entry)
    local extendedEntryData = extendEntryData(entry)
    return name, time, type, description, extendedEntryData, author
end

--[[
 * Page *
]]--

local SKIPPED_TINT = CreateColor(1, 0.13, 0.13, 0.15)

local Audit = {
    key = "audit",
    order = 5,
    title = CLM.L["Audit"],
    officerOnly = true,
    search = "",
}

local function ShowTooltip(row, rowFrame)
    local tooltip = GameTooltip
    tooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
    tooltip:SetText(row.name ~= "" and row.name or row.values.type)
    tooltip:AddLine(row.values.description, 1, 1, 1, true)
    if row.extended ~= "" then
        tooltip:AddLine(row.extended, 0.8, 0.8, 0.8, true)
    end
    if row.failure then
        tooltip:AddLine(" ")
        tooltip:AddLine(CLM.L["Skipped: this entry could not be applied."], UI.COLOR.BAD:GetRGB())
        tooltip:AddLine(row.failure, 1, 0.38, 0.38, true)
    end
    tooltip:Show()
end

local function RemoveEntry(self, row)
    UI.Confirm(string.format(CLM.L["Remove entry #%s? This writes an undo entry for everyone."], row.values.num), function()
        CLM.MODULES.LedgerManager:Remove(row.entry, true)
        self.list:ClearSelection()
    end)
end

function Audit:Build(content, header)
    local search = UI.CreateSearchBox(header, 180, function(text)
        self.search = strlower(text or "")
        self:Refresh()
    end)
    search:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    if search.Instructions then search.Instructions:SetText(CLM.L["Search"]) end

    local inset = UI.CreateInset(content)
    inset:SetAllPoints()
    self.list = UI.CreateList(inset, {
        columns = {
            { key = "num", title = "#", width = 48, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true,
              color = function() return UI.COLOR.GREY end },
            { key = "time", title = CLM.L["Time"], width = 120, defaultDesc = true,
              text = function(row) return date(CLM.L["%Y/%m/%d %H:%M"], row.values.time) end,
              color = function() return UI.COLOR.GREY end },
            { key = "type", title = CLM.L["Type"], width = 40,
              color = function(row) return row.failure and UI.COLOR.BAD or UI.COLOR.GOLD end },
            { key = "description", title = CLM.L["Description"], width = 0, sortable = false },
            { key = "author", title = CLM.L["By"], width = 90 },
        },
        sortKey = "num",
        sortDesc = true,
        rowTint = function(row) return row.failure and SKIPPED_TINT or nil end,
        onRightClick = function(row, rowFrame)
            UI.ShowContextMenu(rowFrame, "#" .. row.values.num, {
                { text = CLM.L["Remove entry"], color = UI.COLOR.BAD, func = function() RemoveEntry(self, row) end },
            })
        end,
        onEnter = ShowTooltip,
    })
    self.list:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.list:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
end

function Audit:Refresh()
    local failed = CLM.MODULES.LedgerManager:GetFailedEntries()
    local rows, byUuid = {}, {}
    local skipped = 0
    local entries = CLM.MODULES.LedgerManager:GetData()
    for i, entry in ipairs(entries) do
        local ok, name, time, entryType, description, extended, author = pcall(getEntryInfo, entry)
        if not ok then
            -- Unknown entry types may not even have the LogEntry methods
            local hasTime, entryTime = pcall(function() return entry:time() end)
            local hasClass, entryClass = pcall(function() return entry:class() end)
            name, time, entryType, description, extended, author = "", hasTime and entryTime or 0,
                hasClass and entryClass or "?", CLM.L["Can't describe this entry"], "", ""
        end
        local hasUuid, uuid = pcall(function() return entry:uuid() end)
        if not hasUuid then uuid = "row" .. i end
        local failure = failed[uuid]
        if failure then skipped = skipped + 1 end
        local row = {
            id = i,
            entry = entry,
            name = name or "",
            extended = extended or "",
            failure = failure,
            values = { num = i, time = time, type = entryType, description = description or "", author = author or "" },
        }
        byUuid[uuid] = row
        -- An ignore entry marks its target with the ignore entry's number
        if entryType == "IGN" then
            local target = byUuid[entry.ref]
            if target then
                target.values.description = target.values.description .. " " .. UTILS.ColorCodeText("(" .. CLM.L["removed by"] .. " #" .. i .. ")", "44ff44")
            end
        end
        rows[#rows + 1] = row
    end
    local shown = rows
    if self.search ~= "" then
        shown = {}
        for _, row in ipairs(rows) do
            local text = (row.name .. " " .. row.values.description .. " " .. row.extended .. " " .. row.values.author):lower()
            if text:find(self.search, 1, true) then shown[#shown + 1] = row end
        end
    end
    self.list:SetData(shown)

    local footer = string.format(CLM.L["%s of %s entries"], #shown, #rows)
    if skipped > 0 then
        footer = footer .. " · " .. UI.COLOR.BAD:WrapTextInColorCode(string.format(CLM.L["%s skipped"], skipped))
    end
    self.window:SetPageFooter(footer .. " · " .. CLM.L["Right-click an entry: Remove"])
end

CLM.GUI.MainWindow:RegisterPage(Audit)
