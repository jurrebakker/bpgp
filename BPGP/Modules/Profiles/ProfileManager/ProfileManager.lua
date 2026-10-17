-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local whoamiGUID = UTILS.whoamiGUID()

local function notEmptyiGUID(iGUID)
    return iGUID[2] ~= 0
end

---@class ProfileManager
---@field cache table
---@field db table
---@field _initialized boolean
local ProfileManager = {}
function ProfileManager:Initialize()
    LOG:Trace("ProfileManager:Initialize()")

    self.cache = {
        profilesGuidMap = {},
        profiles = {}
    }

    -- Register mutators
    CLM.MODULES.LedgerManager:RegisterEntryType(
        CLM.MODELS.LEDGER.PROFILE.Update,
        (function(entry)
            LOG:TraceAndCount("mutator(ProfileUpdate)")
            local iGUID = entry:GUID()
            if not UTILS.ValidateIntegerGUID(iGUID) then return end
            if not notEmptyiGUID(iGUID) then return end
            local GUID = UTILS.getGuidFromInteger(iGUID)
            local name = entry:name()
            if UTILS.empty(name) then return end

            local class = UTILS.NumberToClass(entry:ingameClass()) or ""
            -- Check if it's an update
            local profileInternal = self.cache.profiles[GUID]
            if profileInternal then
                if UTILS.empty(class) then
                    class = profileInternal:Class()
                end
                profileInternal.class = class
                -- Renam:
                -- Remove old map
                self.cache.profilesGuidMap[strlower(profileInternal.name)] = nil
                -- set new name
                profileInternal.name = name
                self.cache.profilesGuidMap[strlower(name)] = GUID
            else
                -- If profile with this name already exists we need to remove it
                -- before updating guid map
                local oldProfile = self:GetProfileByName(name)
                if oldProfile then
                    self.cache.profiles[oldProfile:GUID()] = nil
                end
                -- New mapping
                local profile = CLM.MODELS.Profile:New(entry, name, class)
                profile:SetGUID(GUID)
                self.cache.profiles[GUID] = profile
                self.cache.profilesGuidMap[strlower(name)] = GUID
                -- Check for conditional restore
                local rosters = CLM.MODULES.RosterManager:GetRosters()
                for _, roster in pairs(rosters) do
                    if roster:IsConditionallyRemoved(GUID) then
                        roster:RestoreConditionallyRemoved(GUID)
                    end
                end
            end
        end))

    CLM.MODULES.LedgerManager:RegisterEntryType(
        CLM.MODELS.LEDGER.PROFILE.Remove,
        (function(entry)
            LOG:TraceAndCount("mutator(ProfileRemove)")
            local GUID = entry:GUID()
            if not UTILS.ValidateIntegerGUID(GUID) then return end
            GUID = UTILS.getGuidFromInteger(GUID)
            local profile = self.cache.profiles[GUID]
            if profile then
                -- Remove
                self.cache.profiles[GUID] = nil
                self.cache.profilesGuidMap[strlower(profile:Name())] = nil
                -- Conditonally remove for backwards compatibility
                local rosters = CLM.MODULES.RosterManager:GetRosters()
                for _, roster in pairs(rosters) do
                    if roster:IsProfileInRoster(GUID) then
                        roster:MarkAsConditionallyRemoved(GUID)
                    end
                end
            end
        end))

    CLM.MODULES.LedgerManager:RegisterOnRestart(function()
        self:WipeAll()
    end)


end

---@param GUID string
---@param name string
---@param class string?
function ProfileManager:NewProfile(GUID, name, class)
    LOG:Trace("ProfileManager:NewProfile()")
    if type(GUID) ~= "string" or GUID == "" then
        LOG:Error("NewProfile(): Empty GUID")
        return
    end
    if type(name) ~= "string" or name == "" then
        LOG:Error("NewProfile(): Empty name")
        return
    end
    local guidProfile = self:GetProfileByGUID(GUID)
    local nameProfile = self:GetProfileByName(name)

    local discard, warning
    if guidProfile then -- profile with this GUID already exists. Is this a rename?
        if nameProfile then -- profile with name and guid exists
            if guidProfile:GUID() == nameProfile:GUID() then -- same profile, same name - do nothing
                discard = true
                LOG:Debug("NewProfile(): guidProfile:GUID() == nameProfile:GUID()")
            else -- 2 different profiles exist. Warning
                discard = true
                LOG:Debug("NewProfile(): guidProfile:GUID() ~= nameProfile:GUID()")
                warning = string.format(CLM.L["Two different profiles exist for target GUID %s (%s:%s) and name %s (%s:%s). Verify and clean up profiles before updating."], GUID, name, guidProfile:GUID(), guidProfile:Name(), nameProfile:GUID(), nameProfile:Name())
            end
        else -- profile with this name does not exist - this is an actual rename
            discard = false
            LOG:Debug("NewProfile(): guidProfile and not nameProfile")
        end
    else -- profile with this GUID does not exist. Is this new profile?
        if nameProfile then -- name is used already by different profile? Warning
            discard = true
            LOG:Debug("NewProfile(): no guidProfile and nameProfile")
            warning = string.format(CLM.L["Profile %s already exists and is used by different GUID %s (%s). "], name, nameProfile:GUID(), nameProfile:Name())
        else -- New profile!
            discard = false
            LOG:Debug("NewProfile(): not guidProfile and not nameProfile")
        end
    end
    if discard then
        if warning then LOG:Warning(warning) end
        LOG:Debug("NewProfile(): discarding request for %s (%s)", name, GUID)
        return
    end

    LOG:Debug("New profile: [%s]: %s", GUID, name)
    CLM.MODULES.LedgerManager:Submit(CLM.MODELS.LEDGER.PROFILE.Update:new(GUID, name, class), true)
end

---@param GUID string
function ProfileManager:RemoveProfile(GUID)
    LOG:Trace("ProfileManager:RemoveProfile()")
    if type(GUID) ~= "string" or GUID == "" then
        LOG:Error("RemoveProfile(): UTILS.empty GUID")
        return
    end
    LOG:Debug("Remove profile: [%s]", GUID)
    CLM.MODULES.LedgerManager:Submit(CLM.MODELS.LEDGER.PROFILE.Remove:new(GUID), true)
end

-- Functionalities

function ProfileManager:WipeAll()
    LOG:Trace("ProfileManager:WipeAll()")
    self.cache = { profilesGuidMap = {}, profiles = {} }
end

---@return Profile?
function ProfileManager:GetMyProfile()
    LOG:Trace("ProfileManager:GetMyProfile()")
    return self:GetProfileByGUID(whoamiGUID)
end

-- Utility

---@param name string
---@return string?
function ProfileManager:GetGUIDFromName(name)
    return self.cache.profilesGuidMap[name]
end

---@return table
function ProfileManager:GetProfiles()
    return self.cache.profiles
end

---@param GUID string
---@return Profile?
function ProfileManager:GetProfileByGUID(GUID)
    return self.cache.profiles[GUID]
end

---@param name string
---@return Profile?
function ProfileManager:GetProfileByName(name)
    return self.cache.profiles[self.cache.profilesGuidMap[strlower(name)]]
end

-- Publis API
CLM.MODULES.ProfileManager = ProfileManager
