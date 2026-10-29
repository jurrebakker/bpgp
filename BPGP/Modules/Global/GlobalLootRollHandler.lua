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
      - you are in a BPGP raid that is in progress and was started less than 12 hours ago
        (an officer may forget to end a raid);
      - you are in a raid group inside a raid instance;
      - that group's leader is an officer of our guild (a pug leader never is).
    Never passed either: quest items, legendaries, stacks, recipes, mounts, toys, cosmetics.
    Both only roll on the item classes we auction: weapons, armor and miscellaneous
    (2026-10-19, R28). Consumables, housing decor, crafting materials and the
    like are left to the player to roll on.

    Need on everything (officers only, off by default, 2026-10-18): the officer who collects the
    loot rolls Need, or Greed / Transmog when Need isn't possible. Same safety rules and the same
    exceptions as passing; it wins over Pass on loot. The officer check runs again on every roll,
    so a player who lost the officer rank stops rolling even with the setting still on.
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

-- Items we never roll on automatically, whichever way
local function IsAutoRollable(rollID)

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

-- Roll type for Need on everything: Need, else Greed, else Transmog (nil when none is allowed)
local function CollectRollType(rollID)
    local _, _, _, _, _, canNeed, canGreed, _, _, _, _, _, canTransmog = GetLootRollItemInfo(rollID)
    if canNeed then return LOOT_ROLL_TYPE_NEED or 1 end
    if canGreed then return LOOT_ROLL_TYPE_GREED or 2 end
    if canTransmog then return LOOT_ROLL_TYPE_TRANSMOG or 4 end
    return nil
end

-- Is it an item class we auction? (false when not cached yet: then we don't roll)
local function IsAuctionedClass(rollID)
    local itemLink = GetLootRollItemLink(rollID)
    if not itemLink or UTILS.IsSecret(itemLink) then return false end
    local classID = select(12, UTILS.GetItemInfo(itemLink))
    return CLM.CONSTANTS.AUCTION_ITEM_CLASSES[classID] or false
end

-- The roll to make, or nil to leave it to the player
local function AutoRollType(rollID)
    local collect = CLM.GlobalConfigs:GetNeedOnEverything()
        and CLM.MODULES.ACL:CheckLevel(CLM.CONSTANTS.ACL.LEVEL.OFFICER)
    local pass = CLM.GlobalConfigs:GetPassOnLoot()
    if not (collect or pass) then return nil end
    if not InOwnRaid() then return nil end
    if not IsAutoRollable(rollID) then return nil end
    if not IsAuctionedClass(rollID) then return nil end
    if collect then return CollectRollType(rollID) end
    return LOOT_ROLL_TYPE_PASS or 0
end

---@class GlobalLootRollHandler
local GlobalLootRollHandler = {}

function GlobalLootRollHandler:Initialize()
    -- Rolls we made ourselves: a bind-on-pickup Need or Greed asks for confirmation
    local autoRolled = {}
    CLM.MODULES.EventManager:RegisterWoWEvent({"START_LOOT_ROLL"}, function(_, _, rollID)
        local ok, rollType = pcall(AutoRollType, rollID)
        if ok and rollType then
            autoRolled[rollID] = rollType
            RollOnLoot(rollID, rollType)
            LOG:Debug("Rolled %s on loot roll %s", tostring(rollType), tostring(rollID))
        end
    end)
    CLM.MODULES.EventManager:RegisterWoWEvent({"CONFIRM_LOOT_ROLL"}, function(_, _, rollID, rollType)
        if autoRolled[rollID] == nil or autoRolled[rollID] ~= rollType then return end
        autoRolled[rollID] = nil
        ConfirmLootRoll(rollID, rollType)
        StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID)
    end)
    CLM.MODULES.EventManager:RegisterWoWEvent({"CANCEL_LOOT_ROLL"}, function(_, _, rollID)
        autoRolled[rollID] = nil
    end)
end

CLM.GlobalLootRollHandler = GlobalLootRollHandler
