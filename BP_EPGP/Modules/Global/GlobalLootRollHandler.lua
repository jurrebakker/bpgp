-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

--[[
    Pass on loot (Settings → Personal → Loot, on by default): one officer loots the boss items and
    runs the auction, everyone else passes. Re-added on request (2026-10-17) as a single checkbox.

    SAFETY FIRST: a player who pugs someone else's raid must never pass by accident. We only pass
    when ALL of these hold, and when anything can't be verified we don't pass:
      - you are in a BP EPGP raid that is in progress and was started less than 12 hours ago
        (an officer may forget to end a raid);
      - you are in a raid group inside a raid instance;
      - that group's leader is an officer of our guild (a pug leader never is).
    Never passed either: quest items, legendaries, stacks, recipes, mounts, toys, cosmetics.
]]--

local MAX_RAID_AGE = 12 * 3600

-- Leader of the current raid group, or nil when unknown (e.g. names hidden as secret values)
local function GroupLeader()
    for i = 1, GetNumGroupMembers() do
        local name, rank = GetRaidRosterInfo(i)
        if UTILS.IsSecret(name) or UTILS.IsSecret(rank) then return nil end
        if rank == 2 and name then return UTILS.Disambiguate(name) end
    end
    return nil
end

-- Our own guild raid, right now?
local function InOwnRaid()
    if not CLM.MODULES.RaidManager:IsInProgressingRaid() then return false end
    local raid = CLM.MODULES.RaidManager:GetRaid()
    local started = raid and raid:StartTime()
    if not started or (GetServerTime() - started) > MAX_RAID_AGE then return false end
    if not IsInRaid() then return false end
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "raid" then return false end
    local leader = GroupLeader()
    if not leader then return false end
    return CLM.MODULES.ACL:CheckLevel(CLM.CONSTANTS.ACL.LEVEL.OFFICER, leader)
end

local function IsToy(itemId)
    return C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemId) == itemId or false
end

local function ShouldPass(rollID)
    if not CLM.GlobalConfigs:GetPassOnLoot() then return false end
    if not InOwnRaid() then return false end

    local itemLink = GetLootRollItemLink(rollID)
    if not itemLink or UTILS.IsSecret(itemLink) then return false end
    local itemId = UTILS.GetItemIdFromLink(itemLink)
    local _, _, quality, _, _, _, _, stackCount, _, _, _, classID, subclassID = UTILS.GetItemInfo(itemLink)
    if quality == nil then return false end -- not cached yet: don't guess
    if classID == Enum.ItemClass.Questitem then return false end
    if quality >= Enum.ItemQuality.Legendary then return false end
    if (stackCount or 0) > 1 then return false end
    if classID == Enum.ItemClass.Recipe then return false end
    if classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Mount then return false end
    if classID == Enum.ItemClass.Armor and subclassID == Enum.ItemArmorSubclass.Cosmetic then return false end
    if IsToy(itemId) then return false end
    return true
end

---@class GlobalLootRollHandler
local GlobalLootRollHandler = {}

function GlobalLootRollHandler:Initialize()
    CLM.MODULES.EventManager:RegisterWoWEvent({"START_LOOT_ROLL"}, function(_, _, rollID)
        local ok, pass = pcall(ShouldPass, rollID)
        if ok and pass then
            RollOnLoot(rollID, LOOT_ROLL_TYPE_PASS or 0)
            LOG:Debug("Passed on loot roll %s", tostring(rollID))
        end
    end)
end

CLM.GlobalLootRollHandler = GlobalLootRollHandler
