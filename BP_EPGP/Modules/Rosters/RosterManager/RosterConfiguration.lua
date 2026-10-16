-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
-- local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

---@class RosterConfiguration
---@field _ table
local RosterConfiguration = {} -- Roster Configuration
---@param i? table
---@return RosterConfiguration
function RosterConfiguration:New(i)
    local o = i or {}

    setmetatable(o, self)
    self.__index = self

    if i then return o end

    o._ = {}
    -- Auction type: Open / Sealed / Vickrey
    o._.auctionType = CONSTANTS.AUCTION_TYPE.SEALED
    -- Item Value mode: Single-Priced / Ascending
    o._.itemValueMode = CONSTANTS.ITEM_VALUE_MODE.SINGLE_PRICED
    -- Auction time seconds
    o._.auctionTime = 30
    -- Anti snipe time seconds (0 = disabled)
    o._.antiSnipe = 0
    -- On time Bonus
    o._.onTimeBonus = false
    -- On Time Bonus Value
    o._.onTimeBonusValue = 0
    -- Round Decimals
    o._.roundDecimals = 10
    -- Minimal bid increment for open auction
    o._.minimalIncrement = 1
    -- Minimum points to be allowed to bid. >=0 covers Allow Negative Bidders
    o._.minimumPoints = 0
    -- Minimum GP used in calculations when player has less
    o._.minGP = 1
    -- Named Buttons Mode
    o._.namedButtons = false
    -- OS
    o._.useOS = true
    -- Always allow bidding base
    o._.baseAlways = false
    -- Always allow all-in bids
    o._.allInAlways = false
    -- Allow equal top bids
    o._.allowEqualMax = false
    -- Allow cancelling and passing bids
    o._.allowCancelPass = false
    -- Round PR Priority
    o._.roundPR = 10
    -- Time for rolling
    o._.rollTime = 20
    -- Multiply auction time lineary
    o._.multiplyTime = false
    -- Base EP / DKP
    o._.basePoints = 0
    -- Base GP
    o._.baseSpent = 0
    -- Always allow bidding 0
    o._.always0 = false

    return o
end

-- ----------------------- --
-- ADD NEW ONLY AT THE END --
-- ----------------------- --
---@return table
function RosterConfiguration:fields()
    return {
        "auctionType",
        "itemValueMode",
        "auctionTime",
        "antiSnipe",
        "onTimeBonus",
        "onTimeBonusValue",
        "roundDecimals",
        "minimalIncrement",
        "minimumPoints",
        "minGP",
        "namedButtons",
        "useOS",
        "roundPR",
        "baseAlways",
        "allInAlways",
        "allowEqualMax",
        "allowCancelPass",
        "rollTime",
        "multiplyTime",
        "basePoints",
        "baseSpent",
        "always0"
    }
end

---@return table
function RosterConfiguration:Storage()
    return self._
end

local function transform_boolean(value) return value and true or false end
local function transform_number(value) return tonumber(value) or 0 end

local TRANSFORMS = {
    auctionType = transform_number,
    itemValueMode = transform_number,
    auctionTime = transform_number,
    antiSnipe = transform_number,
    onTimeBonus = transform_boolean,
    onTimeBonusValue = transform_number,
    roundDecimals = transform_number,
    minimalIncrement = transform_number,
    minimumPoints = transform_number,
    minGP = transform_number,
    namedButtons = transform_boolean,
    useOS = transform_boolean,
    baseAlways = transform_boolean,
    allInAlways = transform_boolean,
    allowEqualMax = transform_boolean,
    allowCancelPass = transform_boolean,
    roundPR = transform_number,
    rollTime = transform_number,
    multiplyTime = transform_boolean,
    basePoints = transform_number,
    baseSpent = transform_number,
    always0 = transform_boolean,
}

---@param data table
function RosterConfiguration:inflate(data)
    for i, key in ipairs(self:fields()) do
        if data[i] ~= nil then self._[key] = data[i] end
    end
end

---@return table
function RosterConfiguration:deflate()
    local result = {}
    for _, key in ipairs(self:fields()) do
        table.insert(result, self._[key])
    end

    return result
end

---@param o RosterConfiguration
function RosterConfiguration:Copy(o)
    for k,v in pairs(o._) do
        self._[k] = v
    end
end

---@param option? string
---@return any
function RosterConfiguration:Get(option)
    if option ~= nil then
        return self._[option]
    end
    return nil
end

---@param option string
---@param value any
function RosterConfiguration:Set(option, value)
    if option == nil then return end
    if self._[option] ~= nil then
        if self:Validate(option, value) then
            self._[option] = TRANSFORMS[option](value)
        end
    end
end

---@param option string
---@param value any
---@return boolean
function RosterConfiguration:Validate(option, value)
    local callback = "_validate_" .. option
    if type(self[callback]) == "function" then
        local r = self[callback](value)
        return r
    end

    return true -- TODO: true or false?
end

local function IsBoolean(value) return type(value) == "boolean" end
local function IsNumeric(value) return type(value) == "number" end
local function IsPositive(value) return value >= 0 end
function RosterConfiguration._validate_auctionType(value) return CONSTANTS.AUCTION_TYPES[value] ~= nil end
function RosterConfiguration._validate_itemValueMode(value) return CONSTANTS.ITEM_VALUE_MODES[value] ~= nil end
function RosterConfiguration._validate_auctionTime(value) value = tonumber(value); return IsNumeric(value) and IsPositive(value) end
function RosterConfiguration._validate_antiSnipe(value) value = tonumber(value); return IsNumeric(value) and IsPositive(value) end
function RosterConfiguration._validate_onTimeBonus(value) return IsBoolean(value) end
function RosterConfiguration._validate_onTimeBonusValue(value) value = tonumber(value); return IsNumeric(value) and IsPositive(value) end
function RosterConfiguration._validate_roundDecimals(value) return CONSTANTS.ALLOWED_ROUNDINGS[value] ~= nil end
function RosterConfiguration._validate_minimalIncrement(value) value = tonumber(value); return IsNumeric(value) and IsPositive(value) end
function RosterConfiguration._validate_minimumPoints(value) return IsNumeric(tonumber(value)) end
function RosterConfiguration._validate_minGP(value) value = tonumber(value); return IsNumeric(value) and IsPositive(value) end
function RosterConfiguration._validate_namedButtons(value) return IsBoolean(value) end
function RosterConfiguration._validate_useOS(value) return IsBoolean(value) end
function RosterConfiguration._validate_baseAlways(value) return IsBoolean(value) end
function RosterConfiguration._validate_allInAlways(value) return IsBoolean(value) end
function RosterConfiguration._validate_allowEqualMax(value) return IsBoolean(value) end
function RosterConfiguration._validate_allowCancelPass(value) return IsBoolean(value) end
function RosterConfiguration._validate_roundPR(value) return CONSTANTS.ALLOWED_ROUNDINGS[value] ~= nil end
function RosterConfiguration._validate_rollTime(value) value = tonumber(value); return IsNumeric(value) and IsPositive(value) end
function RosterConfiguration._validate_multiplyTime(value) return IsBoolean(value) end
function RosterConfiguration._validate_basePoints(value) value = tonumber(value); return IsNumeric(value) and IsPositive(value) end
function RosterConfiguration._validate_baseSpent(value) value = tonumber(value); return IsNumeric(value) and IsPositive(value) end
function RosterConfiguration._validate_always0(value) return IsBoolean(value) end


CLM.MODELS.RosterConfiguration = RosterConfiguration
