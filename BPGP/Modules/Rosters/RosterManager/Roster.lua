-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local GLOBAL_FAKE_INVENTORY_SLOT = "_GLOBAL"

local SIX_MONTHS_IN_SECONDS = 60 * 60 * 24 * 30 * 6

local function fillSlotsArray(array)
    for key,_ in pairs(CONSTANTS.SLOT_VALUE_TIERS) do
        array[key] = 0
    end
end

local function lazyCreateSlot(self, itemEquipLoc)
    if self.defaultSlotValues[itemEquipLoc] then return end
    self.defaultSlotValues[itemEquipLoc] = {}
    for key,_ in pairs(CONSTANTS.SLOT_VALUE_TIERS) do
        self.defaultSlotValues[itemEquipLoc][key] = self.defaultSlotValues[GLOBAL_FAKE_INVENTORY_SLOT][key]
    end
end

local function lazyCreateItem(self, itemId)
    if self.itemValues[itemId] then return end
    self.itemValues[itemId] = {}
    fillSlotsArray(self.itemValues[itemId])
end

---@class Roster
---@field uid integer
---@field configuration RosterConfiguration
---@field defaultSlotValues table
---@field fieldNames table
---@field inRoster table
---@field itemValues table
---@field pointHistory table
---@field pointInfo table
---@field profileLoot table
---@field profilePointHistory table
---@field raidLoot table
---@field recentRaidLootCache table?
---@field recentRaidLootCacheSeconds number?
---@field recentRaidPointHistoryCache table?
---@field recentRaidPointHistoryCacheSeconds number?
---@field standings table
local Roster = {}
---@param uid integer
---@return Roster
function Roster:New(uid)
    local o = {}

    setmetatable(o, self)
    self.__index = self

    -- CONFIGURATION --
    o.uid  = tonumber(uid)
    o.configuration  = CLM.MODELS.RosterConfiguration:New()
    o.defaultSlotValues = { [GLOBAL_FAKE_INVENTORY_SLOT] = {} }
    fillSlotsArray(o.defaultSlotValues[GLOBAL_FAKE_INVENTORY_SLOT])
    o.fieldNames = {}
    o.itemValues = {}
    -- END CONFIGURATION --

    -- ROSTER STATE --
    o.inRoster = {}             -- Profile is at all in roster
    o.standings = {}            -- Profile standing in roster (dict)
    o.pointInfo = {}            -- Profile point info
    o.pointHistory = {}         -- Point changes in  roster (list)
    o.profilePointHistory = {}  -- Point changes in to players in roster (dict of lists)
    o.raidLoot = {}             -- Loot received in the roster (list). Time descending
    o.profileLoot = {}          -- Loot received by players (dict of lists). Time descending per player
    -- END ROSTER STATE --

    return o
end

---@param GUID string
function Roster:AddProfileByGUID(GUID)
    LOG:Debug("Add profile [%s] to roster [%s]", GUID, self:UID())
    if self:IsProfileInRoster(GUID) then return end
    self.standings[GUID] = 0
    self.profileLoot[GUID] = {}
    self.profilePointHistory[GUID] = {}
    self.inRoster[GUID] = true
    self.pointInfo[GUID] = CLM.MODELS.PointInfo:New()
    self.pointInfo[GUID].spent = self.configuration._.minGP
end

---@param GUID string
function Roster:RemoveProfileByGUID(GUID)
    LOG:Debug("Remove profile [%s] from roster [%s]", GUID, self:UID())
    self.standings[GUID] = nil
    self.profileLoot[GUID] = nil
    self.profilePointHistory[GUID] = nil
    self.inRoster[GUID] = nil
end

---@param GUID string
function Roster:MarkAsConditionallyRemoved(GUID)
    -- Used for backwards compatibility in profiles - marks as removed but doesnt remove any data
    self.inRoster[GUID] = nil
end

---@param GUID string
function Roster:RestoreConditionallyRemoved(GUID)
    -- Used for backwards compatibility in profiles - marks as removed but doesnt remove any data
    self.inRoster[GUID] = true
end

---@param GUID string
---@return boolean
function Roster:IsConditionallyRemoved(GUID)
    return self.standings[GUID] and not self.inRoster[GUID]
end

---@param GUID string
---@return boolean
function Roster:IsProfileInRoster(GUID)
    return (self.inRoster[GUID] ~= nil)
end

---@return number
function Roster:UID()
    return self.uid
end

---@return table
function Roster:Profiles()
    return UTILS.keys(self.inRoster)
end

---@param GUID? string
---@return table|number
function Roster:Standings(GUID)
    if GUID == nil then
        return self.standings or {}
    else
        return self.standings[GUID] or 0
    end
end

---@param GUID string
---@return number
function Roster:GP(GUID)
    local pointInfo = self.pointInfo[GUID]
    if not pointInfo then return -1 end
    -- return mmax(pointInfo.spent, self.configuration._.minGP)
    return pointInfo.spent
end

---@param GUID? string
---@return number
function Roster:Priority(GUID)
    if GUID == nil then
        return 0
    else
        return UTILS.round((self.standings[GUID] or 0) / self:GP(GUID), self.configuration._.roundPR)
    end
end

---@param GUID string
---@return PointInfo
function Roster:GetPointInfoForPlayer(GUID)
    return self.pointInfo[GUID] or CLM.MODELS.PointInfo:New()
end

--[[
 **************************
 * Standings manipulation *
 **************************
]]--

---@param GUID string
---@param value number
---@param timestamp? number
function Roster:UpdateStandings(GUID, value, timestamp)
    LOG:Debug("Roster:UpdateStandings(%s, %s, %s)", GUID, self.uid, value)
    value = UTILS.round(value, self.configuration._.roundDecimals)
    self.standings[GUID] = self:Standings(GUID) + value
    self.pointInfo[GUID]:AddReceived(value)
end

---@param GUID string
---@param value number
function Roster:UpdateSpent(GUID, value)
    LOG:Debug("Roster:UpdateSpent(%s, %s, %s)", GUID, self.uid, value)
    local new = UTILS.round(self.pointInfo[GUID].spent + value, self.configuration._.roundDecimals)
    -- Handle the spent update
    self.pointInfo[GUID].spent = math.max(new, self.configuration._.minGP)
end

---@param GUID string
---@param value number
function Roster:SetStandings(GUID, value)
    self.standings[GUID] = UTILS.round(value, self.configuration._.roundDecimals)
end

---@param GUID string
---@param value number
function Roster:SetSpent(GUID, value)
    self.pointInfo[GUID].spent = UTILS.round(value, self.configuration._.roundDecimals)
end

---@param GUID string
---@param value number
function Roster:DecayStandings(GUID, value)
    local new = UTILS.round(((self:Standings(GUID) * (100 - value)) / 100), self.configuration._.roundDecimals)
    self.pointInfo[GUID]:AddDecayed(self.standings[GUID] - new)
    self.standings[GUID] = new
end

---@param GUID string
---@param value number
function Roster:DecaySpent(GUID, value)
    local new = UTILS.round(((self.pointInfo[GUID].spent * (100 - value)) / 100), self.configuration._.roundDecimals)
    self.pointInfo[GUID].spent = math.max(new, self.configuration._.minGP)
end

---@param GUID string
---@param value number
function Roster:DecayTotal(GUID, value)
    self:DecayStandings(GUID, value)
    self:DecaySpent(GUID, value)
end

--[[
 ***************
 * Slot Values *
 ***************
]]--

---@param itemEquipLoc string
---@param tier string
---@param value number
function Roster:SetDefaultSlotTierValue(itemEquipLoc, tier, value)
    LOG:Debug("Set Default Slot Tier Value: [%s]: [%s] [%s] for roster [%s]", itemEquipLoc, tier, value, self:UID())
    if not itemEquipLoc or not CONSTANTS.INVENTORY_TYPES_SET[itemEquipLoc] then return end
    if not tier or not CONSTANTS.SLOT_VALUE_TIERS[tier] then return end
    lazyCreateSlot(self, itemEquipLoc)

    if itemEquipLoc ~= GLOBAL_FAKE_INVENTORY_SLOT then
        local new = UTILS.ShallowCopy(self:GetDefaultSlotValues(itemEquipLoc))
        new[tier] = value
        local allSame = true
        for key,val in pairs(self:GetDefaultSlotValues(GLOBAL_FAKE_INVENTORY_SLOT)) do
            if val ~= new[key] then
                allSame = false
            end
        end
        if allSame then
            self:ClearDefaultSlotValue(itemEquipLoc)
            return
        end
    end

    self.defaultSlotValues[itemEquipLoc][tier] = tonumber(value) or 0
end

---@param itemEquipLoc? string
---@param tier string
---@return number
function Roster:GetDefaultSlotTierValue(itemEquipLoc, tier)
    if not itemEquipLoc or not CONSTANTS.INVENTORY_TYPES_SET[itemEquipLoc] then
        itemEquipLoc = GLOBAL_FAKE_INVENTORY_SLOT
    end
    if not tier or not CONSTANTS.SLOT_VALUE_TIERS[tier] then return 0 end
    local values = self.defaultSlotValues[itemEquipLoc] or self.defaultSlotValues[GLOBAL_FAKE_INVENTORY_SLOT]
    return values[tier]
end

---@param itemEquipLoc? string
---@return table
function Roster:GetDefaultSlotValues(itemEquipLoc)
    if not itemEquipLoc or not CONSTANTS.INVENTORY_TYPES_SET[itemEquipLoc] then
        itemEquipLoc = GLOBAL_FAKE_INVENTORY_SLOT
    end
    return self.defaultSlotValues[itemEquipLoc] or self.defaultSlotValues[GLOBAL_FAKE_INVENTORY_SLOT]
end

---@param itemEquipLoc string
function Roster:ClearDefaultSlotValue(itemEquipLoc)
    LOG:Debug("Clear Default Slot Value: [%s] for roster [%s]", itemEquipLoc, self:UID())
    self.defaultSlotValues[itemEquipLoc] = nil
end

--[[
 ***************
 * Item Values *
 ***************
]]--

---@return table
function Roster:GetAllItemValues()
    return self.itemValues or {}
end

---@param itemId number
---@param tier string
---@param value number
function Roster:SetItemTierValue(itemId, tier, value)
    LOG:Debug("Set Item Tier Value: [%s]: [%s] [%s] for roster [%s]", itemId, tier, value, self:UID())
    lazyCreateItem(self, itemId)
    self.itemValues[itemId][tier] = tonumber(value) or 0
    self:SetItemValues(itemId, self.itemValues[itemId])
end

---@param itemId number
---@param values table
function Roster:SetItemValues(itemId, values)
    LOG:Debug("Set Item Tier Values: [%s]: for roster [%s]", itemId, self:UID())
    lazyCreateItem(self, itemId)

    local _, _, _, itemEquipLoc = UTILS.GetItemInfoInstant(itemId)

    local allSame = true
    for key,value in pairs(self:GetDefaultSlotValues(itemEquipLoc)) do
        if value ~= values[key] then
            allSame = false
        end
    end
    if allSame then
        self:ClearItemValues(itemId)
    else
        for key,_ in pairs(CONSTANTS.SLOT_VALUE_TIERS) do
            self.itemValues[itemId][key] = values[key] or 0
        end
    end
end

---@param itemId number
function Roster:ClearItemValues(itemId)
    LOG:Debug("Clear Item Value: [%s] for roster [%s]", itemId, self:UID())
    self.itemValues[itemId] = nil
end

local function GetItemValuesProxy(self, itemInfoInput, itemId)
    local itemValues = self.itemValues[itemId]
    if itemValues == nil then
        local _, _, _, itemEquipLoc, _, classID, subclassID = UTILS.GetItemInfoInstant(itemInfoInput)
        local equipLoc = UTILS.WorkaroundEquipLoc(classID, subclassID, itemEquipLoc)
        return self:GetDefaultSlotValues(CLM.IndirectMap.slot[itemId] or equipLoc)
    end
    return itemValues
end

---@param itemId number
---@return table
function Roster:GetItemValues(itemId)
    return GetItemValuesProxy(self, itemId, itemId)
end

---@param itemLink string
---@return table
function Roster:GetItemValuesFromItemLink(itemLink)
    return GetItemValuesProxy(self, itemLink, UTILS.GetItemIdFromLink(itemLink))
end

--[[
 *****************
 * Configuration *
 *****************
]]--

---@param option? string
---@return any
function Roster:GetConfiguration(option)
    return self.configuration:Get(option)
end

local configurationCallbacks = {
    minGP = function(self, value)
        for _, pointInfo in pairs(self.pointInfo) do
            pointInfo.spent = math.max(pointInfo.spent, self.configuration._.minGP)
        end
    end,
    roundDecimals = function(self, value)
        for _, pointInfo in pairs(self.pointInfo) do
            pointInfo:SetRounding(value)
        end
    end
}

---@param option string
---@param value any
function Roster:SetConfiguration(option, value)
    self.configuration:Set(option, value)
    local configurationCb = configurationCallbacks[option]
    if configurationCb then
        configurationCb(self, value)
    end
end

---@param field string
---@return string
function Roster:GetFieldName(field)
    if not CONSTANTS.SLOT_VALUE_TIERS[field] then
        LOG:Debug("Roster:GetFieldName(): Unknown field %s", field)
    end
    return self.fieldNames[field] or ""
end

-- Button name for display. The names are fixed since 2026-10-18 (BiS / Major / Minor); custom
-- names from RosterFieldRename entries are still replayed but no longer shown.
---@param field string
---@return string
function Roster:GetFieldDisplayName(field)
    return CONSTANTS.SLOT_VALUE_TIERS_GUI[field] or ""
end

---@param field string
---@param name string
function Roster:SetFieldName(field, name)
    if not CONSTANTS.SLOT_VALUE_TIERS[field] then
        LOG:Error("Roster:SetFieldName(): Unknown field %s", field)
        return
    end

    self.fieldNames[field] = name
end

--[[
 ********
 * Wipe *
 ********
]]--

function Roster:WipeStandings()
    LOG:Info("Wipe Standings for roster [%s]", self:UID())
    for GUID,_ in pairs(self.standings) do
        self.standings[GUID] = 0
    end
end

function Roster:WipeLoot()
    LOG:Info("Wipe Loot for roster [%s]", self:UID())
    for GUID,_ in pairs(self.standings) do
        self.profileLoot[GUID] = {}
    end
    self.raidLoot = {}
    self.recentRaidLootCache = nil
end

function Roster:WipeHistory()
    LOG:Info("Wipe Standings for roster [%s]", self:UID())
    for GUID,_ in pairs(self.standings) do
        self.profilePointHistory[GUID] = {}
    end
    self.pointHistory = {}
    self.recentRaidPointHistoryCache = nil
end

--[[
 ****************************
 * History (Point and Loot) *
 ****************************
]]--

---@param loot table
---@param profile Profile
function Roster:AddLoot(loot, profile)
    -- History store
    local GUID = profile:GUID()
    self.profileLoot[GUID][#self.profileLoot[GUID]+1] = loot
    self.raidLoot[#self.raidLoot+1] = loot
    self.recentRaidLootCache = nil
    self.pointInfo[GUID]:AddSpent(loot:Value())
end

---@return table
function Roster:GetRaidLoot()
    return self.raidLoot or {}
end

---@param seconds number? timeframe in seconds (default: 6 months)
---@return table
function Roster:GetRecentRaidLoot(seconds)
    seconds = seconds or SIX_MONTHS_IN_SECONDS
    if self.recentRaidLootCache and self.recentRaidLootCacheSeconds == seconds then
        return self.recentRaidLootCache
    end
    local cutoff = time() - seconds
    local result = {}
    for _, loot in ipairs(self.raidLoot or {}) do
        if loot:Timestamp() >= cutoff then
            result[#result+1] = loot
        end
    end
    self.recentRaidLootCache = result
    self.recentRaidLootCacheSeconds = seconds
    return result
end

---@param GUID string
---@return table
function Roster:GetProfileLootByGUID(GUID)
    return self.profileLoot[GUID] or {}
end

---@param history table
---@param profile Profile
function Roster:AddProfilePointHistory(history, profile)
    self.profilePointHistory[profile:GUID()][#self.profilePointHistory[profile:GUID()]+1] = history
end

---@param history table
function Roster:AddRosterPointHistory(history)
    self.pointHistory[#self.pointHistory+1] = history
    self.recentRaidPointHistoryCache = nil
end

---@return table
function Roster:GetRaidPointHistory()
    return self.pointHistory or {}
end

---@param seconds number? timeframe in seconds (default: 6 months)
---@return table
function Roster:GetRecentRaidPointHistory(seconds)
    seconds = seconds or SIX_MONTHS_IN_SECONDS
    if self.recentRaidPointHistoryCache and self.recentRaidPointHistoryCacheSeconds == seconds then
        return self.recentRaidPointHistoryCache
    end
    local cutoff = time() - seconds
    local result = {}
    for _, entry in ipairs(self.pointHistory or {}) do
        if entry:Timestamp() >= cutoff then
            result[#result+1] = entry
        end
    end
    self.recentRaidPointHistoryCache = result
    self.recentRaidPointHistoryCacheSeconds = seconds
    return result
end

---@param GUID string
---@return table
function Roster:GetProfilePointHistoryByGUID(GUID)
    return self.profilePointHistory[GUID] or {}
end

--[[
 *******************
 * Boss kill Bonus *
 *******************
]]--

--[[
 ***********
 * Copying *
 ***********
]]--

---@param s Roster
function Roster:CopyItemValues(s)
    self.itemValues = UTILS.DeepCopy(s.itemValues)
end

---@param s Roster
function Roster:CopyDefaultSlotValues(s)
    self.defaultSlotValues = UTILS.DeepCopy(s.defaultSlotValues)
end

---@param s Roster
function Roster:CopyConfiguration(s)
    self.configuration = CLM.MODELS.RosterConfiguration:New(UTILS.DeepCopy(s.configuration))
    self.fieldNames = UTILS.DeepCopy(s.fieldNames)
end

---@param s Roster
function Roster:CopyProfiles(s)
    for _, GUID in ipairs(s:Profiles()) do
        if not self:IsProfileInRoster(GUID) then
            self:AddProfileByGUID(GUID)
        end
    end
end

CLM.MODELS.Roster = Roster

-- Constants
CONSTANTS.INVENTORY_TYPES = {
    GLOBAL_FAKE_INVENTORY_SLOT,
    "INVTYPE_NON_EQUIP",
    "INVTYPE_HEAD",
    "INVTYPE_NECK",
    "INVTYPE_SHOULDER",
    "INVTYPE_BODY",
    "INVTYPE_CHEST",
    "INVTYPE_WAIST",
    "INVTYPE_LEGS",
    "INVTYPE_FEET",
    "INVTYPE_WRIST",
    "INVTYPE_HAND",
    "INVTYPE_FINGER",
    "INVTYPE_TRINKET",
    "INVTYPE_WEAPON",
    "INVTYPE_SHIELD",
    "INVTYPE_RANGED",
    "INVTYPE_CLOAK",
    "INVTYPE_2HWEAPON",
    "INVTYPE_BAG",
    "INVTYPE_TABARD",
    "INVTYPE_ROBE",
    "INVTYPE_WEAPONMAINHAND",
    "INVTYPE_WEAPONOFFHAND",
    "INVTYPE_HOLDABLE",
    "INVTYPE_AMMO",
    "INVTYPE_THROWN",
    "INVTYPE_RANGEDRIGHT",
    "INVTYPE_QUIVER",
    "INVTYPE_RELIC",
}

CONSTANTS.INVENTORY_TYPES_SET = UTILS.Set(CONSTANTS.INVENTORY_TYPES)

CONSTANTS.INVENTORY_TYPES_SORTED = {
    { type = GLOBAL_FAKE_INVENTORY_SLOT,    name = CLM.L["Global"],            icon = 136522 },
    { type = "INVTYPE_HEAD",                name = CLM.L["Head"],              icon = 136516 },
    { type = "INVTYPE_NECK",                name = CLM.L["Neck"],              icon = 136519 },
    { type = "INVTYPE_SHOULDER",            name = CLM.L["Shoulder"],          icon = 136526 },
    { type = "INVTYPE_BODY",                name = CLM.L["Shirt"],             icon = 136525 },
    { type = "INVTYPE_CLOAK",               name = CLM.L["Back"],              icon = 136525 },
    { type = "INVTYPE_CHEST",               name = CLM.L["Chest"],             icon = 136525 },
    { type = "INVTYPE_ROBE",                name = CLM.L["Chest (robes)"],     icon = 136525 },
    { type = "INVTYPE_TABARD",              name = CLM.L["Tabard"],            icon = 136527 },
    { type = "INVTYPE_WRIST",               name = CLM.L["Wrist"],             icon = 136530 },
    { type = "INVTYPE_HAND",                name = CLM.L["Hands"],             icon = 136515 },
    { type = "INVTYPE_WAIST",               name = CLM.L["Waist"],             icon = 136529 },
    { type = "INVTYPE_LEGS",                name = CLM.L["Legs"],              icon = 136517 },
    { type = "INVTYPE_FEET",                name = CLM.L["Feet"],              icon = 136513 },
    { type = "INVTYPE_FINGER",              name = CLM.L["Finger"],            icon = 136514 },
    { type = "INVTYPE_TRINKET",             name = CLM.L["Trinket"],           icon = 136528 },
    { type = "INVTYPE_WEAPON",              name = CLM.L["One-Hand"],          icon = 136518 },
    { type = "INVTYPE_WEAPONMAINHAND",      name = CLM.L["Main Hand"],         icon = 136518 },
    { type = "INVTYPE_WEAPONOFFHAND",       name = CLM.L["Off Hand"],          icon = 136524 },
    { type = "INVTYPE_HOLDABLE",            name = CLM.L["Held In Off-hand"],  icon = 136524 },
    { type = "INVTYPE_2HWEAPON",            name = CLM.L["Two-Hand"],          icon = 136518 },
    { type = "INVTYPE_SHIELD",              name = CLM.L["Shield"],            icon = 136524 },
    { type = "INVTYPE_RANGED",              name = CLM.L["Ranged"],            icon = 136520 },
    { type = "INVTYPE_RANGEDRIGHT",         name = CLM.L["Ranged (wands)"],    icon = 136520 },
    { type = "INVTYPE_NON_EQUIP",           name = CLM.L["Non-equippable"],    icon = 136511 },
    { type = "INVTYPE_BAG",                 name = CLM.L["Bag"],               icon = 136511 },
    { type = "INVTYPE_AMMO",                name = CLM.L["Ammo"],              icon = 136510 },
    { type = "INVTYPE_THROWN",              name = CLM.L["Thrown"],            icon = 136522 },
    { type = "INVTYPE_QUIVER",              name = CLM.L["Quiver"],            icon = 136522 },
    { type = "INVTYPE_RELIC",               name = CLM.L["Relic"],             icon = 136522 }
}

CONSTANTS.INVENTORY_TYPES_GUI = {
    [GLOBAL_FAKE_INVENTORY_SLOT] = CLM.L["Global"],
    ["INVTYPE_HEAD"] = CLM.L["Head"],
    ["INVTYPE_NECK"] = CLM.L["Neck"],
    ["INVTYPE_SHOULDER"] = CLM.L["Shoulder"],
    ["INVTYPE_BODY"] = CLM.L["Shirt"],
    ["INVTYPE_CLOAK"] = CLM.L["Back"],
    ["INVTYPE_CHEST"] = CLM.L["Chest"],
    ["INVTYPE_ROBE"] = CLM.L["Chest (robes)"],
    ["INVTYPE_TABARD"] = CLM.L["Tabard"],
    ["INVTYPE_WRIST"] = CLM.L["Wrist"],
    ["INVTYPE_HAND"] = CLM.L["Hands"],
    ["INVTYPE_WAIST"] = CLM.L["Waist"],
    ["INVTYPE_LEGS"] = CLM.L["Legs"],
    ["INVTYPE_FEET"] = CLM.L["Feet"],
    ["INVTYPE_FINGER"] = CLM.L["Finger"],
    ["INVTYPE_TRINKET"] = CLM.L["Trinket"],
    ["INVTYPE_WEAPON"] = CLM.L["One-Hand"],
    ["INVTYPE_WEAPONMAINHAND"] = CLM.L["Main Hand"],
    ["INVTYPE_WEAPONOFFHAND"] = CLM.L["Off Hand"],
    ["INVTYPE_HOLDABLE"] = CLM.L["Held In Off-hand"],
    ["INVTYPE_2HWEAPON"] = CLM.L["Two-Hand"],
    ["INVTYPE_SHIELD"] = CLM.L["Shield"],
    ["INVTYPE_RANGED"] = CLM.L["Ranged"],
    ["INVTYPE_RANGEDRIGHT"] = CLM.L["Ranged (wands)"],
    ["INVTYPE_NON_EQUIP"] = CLM.L["Non-equippable"],
    ["INVTYPE_BAG"] = CLM.L["Bag"],
    ["INVTYPE_AMMO"] = CLM.L["Ammo"],
    ["INVTYPE_THROWN"] = CLM.L["Thrown"],
    ["INVTYPE_QUIVER"] = CLM.L["Quiver"],
    ["INVTYPE_RELIC"] = CLM.L["Relic"]
}

CONSTANTS.ALLOWED_ROUNDINGS = UTILS.Set({
    0, 1, 2
})

CONSTANTS.ALLOWED_ROUNDINGS_GUI = {
    [0] = "1",
    [1] = "0.1",
    [2] = "0.01",
}

CONSTANTS.SLOT_VALUE_TIER = {
    BASE   = "b",
    SMALL  = "s",
    MEDIUM = "m",
    LARGE  = "l",
    MAX    = "x"
}

CONSTANTS.SLOT_VALUE_TIERS = UTILS.Set({
    CONSTANTS.SLOT_VALUE_TIER.BASE,
    CONSTANTS.SLOT_VALUE_TIER.SMALL,
    CONSTANTS.SLOT_VALUE_TIER.MEDIUM,
    CONSTANTS.SLOT_VALUE_TIER.LARGE,
    CONSTANTS.SLOT_VALUE_TIER.MAX
})

--[[
    Bid tiers (raid test feedback, 2026-10-18): auctions offer three fixed tiers, BiS > Major > Minor.
    They reuse the Base / Small / Medium keys our guild already filled in, so the GP values in the
    ledger keep their meaning. Large and Max stay valid ledger keys (old entries replay) but are
    never offered, accepted as a bid or shown in the settings.
]]--
CONSTANTS.SLOT_VALUE_TIERS_GUI = {
    ["b"] = CLM.L["Minor"],
    ["s"] = CLM.L["Major"],
    ["m"] = CLM.L["BiS"],
    ["l"] = CLM.L["Large (unused)"],
    ["x"] = CLM.L["Max (unused)"],
}

-- The tiers raiders can bid on, lowest first
CONSTANTS.BID_TIERS_ORDERED = {
    CONSTANTS.SLOT_VALUE_TIER.BASE,
    CONSTANTS.SLOT_VALUE_TIER.SMALL,
    CONSTANTS.SLOT_VALUE_TIER.MEDIUM,
}

CONSTANTS.BID_TIERS_ORDERED_REVERSED = {
    CONSTANTS.SLOT_VALUE_TIER.MEDIUM,
    CONSTANTS.SLOT_VALUE_TIER.SMALL,
    CONSTANTS.SLOT_VALUE_TIER.BASE,
}

CONSTANTS.BID_TIERS = UTILS.Set(CONSTANTS.BID_TIERS_ORDERED)

CONSTANTS.SLOT_VALUE_TIERS_ORDERED = {
    CONSTANTS.SLOT_VALUE_TIER.BASE,
    CONSTANTS.SLOT_VALUE_TIER.SMALL,
    CONSTANTS.SLOT_VALUE_TIER.MEDIUM,
    CONSTANTS.SLOT_VALUE_TIER.LARGE,
    CONSTANTS.SLOT_VALUE_TIER.MAX
}

CONSTANTS.SLOT_VALUE_TIERS_ORDERED_REVERSED = {
    CONSTANTS.SLOT_VALUE_TIER.MAX,
    CONSTANTS.SLOT_VALUE_TIER.LARGE,
    CONSTANTS.SLOT_VALUE_TIER.MEDIUM,
    CONSTANTS.SLOT_VALUE_TIER.SMALL,
    CONSTANTS.SLOT_VALUE_TIER.BASE
}