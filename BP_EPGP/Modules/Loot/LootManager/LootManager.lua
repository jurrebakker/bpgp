-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local CHAT_MESSAGE_CHANNEL = "RAID_WARNING"

local function mutateLootAward(entry, roster)
    local GUID = UTILS.getGuidFromInteger(entry:profile())
    if not roster then
        LOG:Debug("mutateLootAward(): Roster does not exist")
        return
    end
    if roster:IsProfileInRoster(GUID) then
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
        if not profile then
            LOG:Debug("mutateLootAward(): Profile with guid [%s] does not exist", GUID)
            return
        end
        local loot = CLM.MODELS.Loot:New(entry, profile)
        CLM.MODULES.RosterManager:AddLootToRoster(roster, loot, profile)

        -- Force caching loot from server
        UTILS.GetItemInfo(loot:Id())
        CLM.MODULES.EventManager:DispatchEvent(CONSTANTS.EVENTS.USER_RECEIVED_ITEM, { link = loot:String() }, entry:time(), GUID)
    else
        LOG:Debug("mutateLootAward(): Unknown profile guid [%s] in roster [%s]", GUID, roster:UID())
        return
    end
end

---@class LootManager
local LootManager = {}
function LootManager:Initialize()
    LOG:Trace("LootManager:Initialize()")

    CLM.MODULES.LedgerManager:RegisterEntryType(
        CLM.MODELS.LEDGER.LOOT.Award,
        (function(entry)
            LOG:TraceAndCount("mutator(LootAward)")
            local roster = CLM.MODULES.RosterManager:GetRosterByUid(entry:rosterUid())
            if not roster then
                LOG:Debug("PointManager mutator(): Unknown roster uid %s", entry:rosterUid())
                return
            end
            mutateLootAward(entry, roster)
        end))

    CLM.MODULES.LedgerManager:RegisterEntryType(
        CLM.MODELS.LEDGER.LOOT.RaidAward,
        (function(entry)
            LOG:TraceAndCount("mutator(LootRaidAward)")
            local raid = CLM.MODULES.RaidManager:GetRaidByUid(entry:raidUid())
            if not raid then
                LOG:Debug("PointManager mutator(): Unknown raid uid %s", entry:raidUid())
                return
            end
            mutateLootAward(entry, raid:Roster())
        end))
end

---@param raidOrRoster Raid|Roster
---@param name string
---@param itemLink string
---@param itemId number
---@param extra string?
---@param value number
---@param forceInstant boolean?
---@return boolean, string?
function LootManager:AwardItem(raidOrRoster, name, itemLink, itemId, extra, value, forceInstant)
    LOG:Trace("LootManager:AwardItem()")
    local isRaid = true
    if not UTILS.typeof(raidOrRoster, CLM.MODELS.Raid) then
        isRaid = false
        if not UTILS.typeof(raidOrRoster, CLM.MODELS.Roster) then
            LOG:Error("raidOrRoster:AwardItem(): Missing valid raid / roster")
            return false
        end
    end
    local profile = CLM.MODULES.ProfileManager:GetProfileByName(name)
    if not UTILS.typeof(profile, CLM.MODELS.Profile) then
        LOG:Error("LootManager:AwardItem(): Missing valid profile")
        return false
    end
    if type(itemId) ~= "number" then
        LOG:Error("LootManager:AwardItem(): Invalid ItemId")
        return false
    end
    if not UTILS.GetItemInfoInstant(itemId) then
        LOG:Error("LootManager:AwardItem(): Item does not exist")
        return false
    end
    if type(value) ~= "number" then
        LOG:Error("LootManager:AwardItem(): Invalid Value")
        return false
    end
    if type(extra) == "string" then
        extra = string.gsub(extra, "[^-?%d:]+", "")
    elseif extra ~= nil then
        LOG:Error("LootManager:AwardItem(): Invalid extra payload data")
        return false
    end

    local roster = isRaid and raidOrRoster:Roster() or raidOrRoster
    if roster:IsProfileInRoster(profile:GUID()) then
        local entry
        if isRaid then
            entry = CLM.MODELS.LEDGER.LOOT.RaidAward:new(raidOrRoster:UID(), profile, itemId, value, extra)
        else
            entry = CLM.MODELS.LEDGER.LOOT.Award:new(roster:UID(), profile, itemId, value, extra)
        end
        CLM.MODULES.LedgerManager:Submit(entry, forceInstant)
        if CLM.GlobalConfigs:GetLootWarning() then
            local message = string.format(CLM.L["%s awarded to %s for %s %s"], itemLink, name, value, CLM.L["GP"])
            UTILS.SendChatMessage(message, CHAT_MESSAGE_CHANNEL)
        end
        return true, entry:uuid()
    else
        LOG:Error("LootManager:AwardItem(): Unknown profile guid [%s] in roster [%s]", profile:GUID(), roster:UID())
    end
    return false
end

---@param loot Loot
---@param forceInstant boolean?
function LootManager:RevokeItem(loot, forceInstant)
    LOG:Trace("LootManager:RevokeItem()")
    if not UTILS.typeof(loot, CLM.MODELS.Loot) then
        LOG:Error("LootManager:RevokeItem(): Missing valid loot")
        return
    end
    CLM.MODULES.LedgerManager:Remove(loot:Entry(), forceInstant)
end


CLM.MODULES.LootManager = LootManager
