-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
-- local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local mergeLists = UTILS.mergeLists
local CanonicalClassToNumber = UTILS.CanonicalClassToNumber
local GetGUIDFromEntry = UTILS.GetGUIDFromEntry

local LogEntry  = LibStub("BPGP-EventSourcing/LogEntry")

---@class ProfileUpdate
---@field g number GUID
---@field n string name
---@field c number class
local ProfileUpdate     = LogEntry:extend("P0")
---@class ProfileRemove
---@field g number GUID
local ProfileRemove     = LogEntry:extend("P1")
-- ------------- --
-- ProfileUpdate --
-- ------------- --
---@param GUID number|string
---@param name? string
---@param class? number|string
---@return ProfileUpdate
function ProfileUpdate:new(GUID, name, class)
    local o = LogEntry.new(self);
    o.g = GetGUIDFromEntry(GUID or 0)
    o.n = (name ~= nil) and tostring(name) or ""
    o.c = CanonicalClassToNumber(class)
    return o
end

---@return number
function ProfileUpdate:GUID()
    return self.g
end

---@return string
function ProfileUpdate:name()
    return self.n
end

---@return number
function ProfileUpdate:ingameClass()
    return self.c
end

local ProfileUpdateFields = mergeLists(LogEntry:fields(), {"g", "n", "c"})
function ProfileUpdate:fields()
    return ProfileUpdateFields
end

-- ------------- --
-- ProfileRemove --
-- ------------- --
---@param GUID number|string
---@return ProfileRemove
function ProfileRemove:new(GUID)
    local o = LogEntry.new(self);
    o.g = GetGUIDFromEntry(GUID or 0)
    return o
end

---@return number
function ProfileRemove:GUID()
    return self.g
end

local ProfileRemoveFields = mergeLists(LogEntry:fields(), {"g"})
function ProfileRemove:fields()
    return ProfileRemoveFields
end

CLM.MODELS.LEDGER.PROFILE = {
    Update  = ProfileUpdate,
    Remove  = ProfileRemove
}