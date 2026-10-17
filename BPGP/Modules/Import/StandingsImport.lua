-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

-- Standings import (release plan Phase 6): officers paste "Name,EP,GP" lines (comma, semicolon
-- or tab separated, e.g. from a spreadsheet) to start BPGP from an existing EPGP list.
-- Only guild members can be imported. Players on the roster but not in the list keep their values.

CONSTANTS.IMPORT_STATUS = {
    UPDATE    = 1, -- on the roster, EP/GP will be set
    ADD       = 2, -- guild member, added to the roster, then EP/GP set
    NOT_GUILD = 3, -- skipped
    DUPLICATE = 4, -- skipped
    INVALID   = 5, -- skipped
}

CONSTANTS.IMPORT_STATUS_GUI = {
    [CONSTANTS.IMPORT_STATUS.UPDATE]    = CLM.L["Update"],
    [CONSTANTS.IMPORT_STATUS.ADD]       = CLM.L["Add to roster"],
    [CONSTANTS.IMPORT_STATUS.NOT_GUILD] = CLM.L["Not in guild"],
    [CONSTANTS.IMPORT_STATUS.DUPLICATE] = CLM.L["Duplicate"],
    [CONSTANTS.IMPORT_STATUS.INVALID]   = CLM.L["Invalid"],
}

---@class StandingsImportRow
---@field line number
---@field name string
---@field ep number?
---@field gp number?
---@field status number
---@field note string
---@field GUID string?
---@field classFile string?

---@param value string?
---@param decimalComma boolean
---@return number?
local function ParseNumber(value, decimalComma)
    value = UTILS.Trim(value or "")
    if decimalComma then value = value:gsub(",", ".") end
    return tonumber(value)
end

---@param line string
---@return string?, string?, string?, boolean
local function SplitLine(line)
    local separator = ","
    if line:find("\t") then
        separator = "\t"
    elseif line:find(";") then
        separator = ";"
    end
    local name, ep, gp = strsplit(separator, line)
    -- With tab or semicolon separators a comma is a decimal comma (European spreadsheets)
    return name, ep, gp, separator ~= ","
end

-- Max level is not required: anyone in the guild can be imported
---@return table<string, table> lower-case name -> { name, GUID, classFile }
local function BuildGuildMap()
    local guild = {}
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, _, _, _, classFile, _, _, _, _, _, GUID = GetGuildRosterInfo(i)
        if name and GUID then
            name = UTILS.Disambiguate(name)
            guild[strlower(name)] = { name = name, GUID = GUID, classFile = classFile }
        end
    end
    return guild
end

---@class StandingsImport
local StandingsImport = {}

---@param text string
---@return StandingsImportRow[]
function StandingsImport:Parse(text)
    local rows = {}
    local roster = CLM.MODULES.RosterManager:GetRoster()
    local guild = BuildGuildMap()
    local seen = {}
    local lineNumber = 0
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        lineNumber = lineNumber + 1
        if UTILS.Trim(line) ~= "" then
            local rawName, rawEP, rawGP, decimalComma = SplitLine(line)
            local name = UTILS.Trim(rawName or "")
            if name ~= "" then
                -- "Name-Realm Name" -> "Name-RealmName" like the game's normalized realm; no realm = ours
                local short, realm = strsplit("-", name, 2)
                name = UTILS.Disambiguate(realm and (short .. "-" .. realm:gsub("[%s']", "")) or short)
            end
            local ep, gp = ParseNumber(rawEP, decimalComma), ParseNumber(rawGP, decimalComma)
            local isHeader = (#rows == 0) and (ep == nil) and (gp == nil) and (rawEP or ""):match("%a")
            if not isHeader then
                local row = { line = lineNumber, name = name, ep = ep, gp = gp, note = "" }
                local member = guild[strlower(name)]
                if name == "" or ep == nil or gp == nil or gp < 0 then
                    row.status = CONSTANTS.IMPORT_STATUS.INVALID
                    row.note = CLM.L["Expected: Name, BP, GP (GP not negative)"]
                elseif not member then
                    row.status = CONSTANTS.IMPORT_STATUS.NOT_GUILD
                elseif seen[member.GUID] then
                    row.status = CONSTANTS.IMPORT_STATUS.DUPLICATE
                    row.note = string.format(CLM.L["Also on line %s"], seen[member.GUID].line)
                    seen[member.GUID].status = CONSTANTS.IMPORT_STATUS.DUPLICATE
                    seen[member.GUID].note = string.format(CLM.L["Also on line %s"], lineNumber)
                else
                    row.name = member.name
                    row.GUID = member.GUID
                    row.classFile = member.classFile
                    if roster and roster:IsProfileInRoster(member.GUID) then
                        row.status = CONSTANTS.IMPORT_STATUS.UPDATE
                    else
                        row.status = CONSTANTS.IMPORT_STATUS.ADD
                    end
                    seen[member.GUID] = row
                end
                rows[#rows + 1] = row
            end
        end
    end
    return rows
end

---@param rows StandingsImportRow[]
---@return number toImport, number toAdd, number skipped
function StandingsImport:Count(rows)
    local toImport, toAdd, skipped = 0, 0, 0
    for _, row in ipairs(rows) do
        if row.status == CONSTANTS.IMPORT_STATUS.UPDATE then
            toImport = toImport + 1
        elseif row.status == CONSTANTS.IMPORT_STATUS.ADD then
            toImport = toImport + 1
            toAdd = toAdd + 1
        else
            skipped = skipped + 1
        end
    end
    return toImport, toAdd, skipped
end

-- Importing over existing points or loot needs an explicit overwrite
---@return boolean
function StandingsImport:RosterHasHistory()
    local roster = CLM.MODULES.RosterManager:GetRoster()
    if not roster then return false end
    return #roster:GetRaidPointHistory() > 0 or #roster:GetRaidLoot() > 0
end

---@param rows StandingsImportRow[]
---@param overwrite boolean
---@return boolean
function StandingsImport:Apply(rows, overwrite)
    LOG:Trace("StandingsImport:Apply()")
    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER) then
        LOG:Message(CLM.L["Only officers can import standings."])
        return false
    end
    local roster = CLM.MODULES.RosterManager:GetRoster()
    if not roster then
        LOG:Message(CLM.L["Set up BPGP first (Standings tab)."])
        return false
    end
    if self:RosterHasHistory() and not overwrite then
        LOG:Message(CLM.L["The roster already has points or loot. Tick overwrite to import anyway."])
        return false
    end

    -- 1. profiles and roster membership for new players
    local newGUIDs = {}
    for _, row in ipairs(rows) do
        if row.status == CONSTANTS.IMPORT_STATUS.ADD then
            if not CLM.MODULES.ProfileManager:GetProfileByGUID(row.GUID) then
                CLM.MODULES.ProfileManager:NewProfile(row.GUID, row.name, row.classFile)
            end
            newGUIDs[#newGUIDs + 1] = row.GUID
        end
    end
    if #newGUIDs > 0 then
        CLM.MODULES.RosterManager:AddProfilesToRoster(roster, newGUIDs)
    end

    -- 2. one SET entry per distinct value, for EP and for GP
    local byEP, byGP = {}, {}
    local count = 0
    for _, row in ipairs(rows) do
        if row.status == CONSTANTS.IMPORT_STATUS.UPDATE or row.status == CONSTANTS.IMPORT_STATUS.ADD then
            byEP[row.ep] = byEP[row.ep] or {}
            tinsert(byEP[row.ep], row.GUID)
            byGP[row.gp] = byGP[row.gp] or {}
            tinsert(byGP[row.gp], row.GUID)
            count = count + 1
        end
    end
    for value, GUIDs in pairs(byEP) do
        CLM.MODULES.PointManager:UpdatePoints(roster, GUIDs, value, CONSTANTS.POINT_CHANGE_REASON.IMPORT,
            CONSTANTS.POINT_MANAGER_ACTION.SET, CLM.L["Import"], CONSTANTS.POINT_CHANGE_TYPE.POINTS)
    end
    for value, GUIDs in pairs(byGP) do
        CLM.MODULES.PointManager:UpdatePoints(roster, GUIDs, value, CONSTANTS.POINT_CHANGE_REASON.IMPORT,
            CONSTANTS.POINT_MANAGER_ACTION.SET, CLM.L["Import"], CONSTANTS.POINT_CHANGE_TYPE.SPENT)
    end
    LOG:Message(CLM.L["Imported standings for %s players (%s added to the roster)."], count, #newGUIDs)
    return true
end

CLM.MODULES.StandingsImport = StandingsImport
