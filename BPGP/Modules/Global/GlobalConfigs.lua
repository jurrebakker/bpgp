-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
-- local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

---@class GlobalConfigs
---@field db table
---@field deList table?
local GlobalConfigs = {}
function GlobalConfigs:Initialize()
    self.db = CLM.MODULES.Database:Personal('global', {
        uiscale = 1.0,
        modifier_combination = CONSTANTS.MODIFIER_COMBINATION.ALT,
        award_modifier_combination = CONSTANTS.MODIFIER_COMBINATION.ALT_SHIFT,
        alerts = true,
        sounds = true,
        pass_on_loot2 = true, -- renamed when the default became "on" (2026-10-17)
        raid_warnings = {
            raid = true,
            auction = true,
            countdown = true,
            loot = true
        },
    })
end

---@param value number 0.5 - 2
function GlobalConfigs:SetUIScale(value)
    value = math.max(0.5, math.min(2, tonumber(value) or 1))
    self.db.uiscale = value
    CLM.MODULES.EventManager:DispatchEvent("CLM_UI_RESIZE", { scale = value })
end

---@param value boolean
function GlobalConfigs:SetPassOnLoot(value)
    self.db.pass_on_loot2 = value and true or false
end

---@return boolean
function GlobalConfigs:GetPassOnLoot()
    return self.db.pass_on_loot2
end

---@param value boolean
function GlobalConfigs:SetSounds(value)
    self.db.sounds = value and true or false
end

---@return boolean
function GlobalConfigs:GetSounds()
    return self.db.sounds
end

---@param value string
function GlobalConfigs:SetModifierCombination(value)
    if value == self:GetAwardModifierCombination() then
        CLM.LOG:Message(CLM.L["The auction click and the award click need different keys."])
        return
    end
    self.db.modifier_combination = CONSTANTS.MODIFIER_COMBINATIONS[value] and value or CONSTANTS.MODIFIER_COMBINATION.ALT
end

---@return string
function GlobalConfigs:GetModifierCombination()
    return self.db.modifier_combination or CONSTANTS.MODIFIER_COMBINATION.ALT
end

---@param value string
function GlobalConfigs:SetAwardModifierCombination(value)
    if value == self:GetModifierCombination() then
        CLM.LOG:Message(CLM.L["The auction click and the award click need different keys."])
        return
    end
    self.db.award_modifier_combination = CONSTANTS.MODIFIER_COMBINATIONS[value] and value or CONSTANTS.MODIFIER_COMBINATION.ALT_SHIFT
end

---@return string
function GlobalConfigs:GetAwardModifierCombination()
    return self.db.award_modifier_combination or CONSTANTS.MODIFIER_COMBINATION.ALT_SHIFT
end

---@param value boolean
function GlobalConfigs:SetRaidWarning(value)
    self.db.raid_warnings.raid = value and true or false
end

---@return boolean
function GlobalConfigs:GetRaidWarning()
    return self.db.raid_warnings.raid
end

---@param value boolean
function GlobalConfigs:SetAuctionWarning(value)
    self.db.raid_warnings.auction = value and true or false
end

---@return boolean
function GlobalConfigs:GetAuctionWarning()
    return self.db.raid_warnings.auction
end

---@param value boolean
function GlobalConfigs:SetCountdownWarning(value)
    self.db.raid_warnings.countdown = value and true or false
end

---@return boolean
function GlobalConfigs:GetCountdownWarning()
    return self.db.raid_warnings.countdown
end

---@param value boolean
function GlobalConfigs:SetLootWarning(value)
    self.db.raid_warnings.loot = value and true or false
end

---@return boolean
function GlobalConfigs:GetLootWarning()
    return self.db.raid_warnings.loot
end

---@return number
function GlobalConfigs:GetUIScale()
    return self.db.uiscale
end

CONSTANTS.MODIFIER_COMBINATION = {
    DISABLED        = "-",
    ALT             = "a",
    SHIFT           = "s",
    CTRL            = "c",
    ALT_SHIFT       = "as",
    ALT_CTRL        = "ac",
    SHIFT_CTRL      = "sc",
    ALT_SHIFT_CTRL  = "asc",
}

CONSTANTS.MODIFIER_COMBINATIONS_SORTED = {
    CONSTANTS.MODIFIER_COMBINATION.DISABLED,
    CONSTANTS.MODIFIER_COMBINATION.SHIFT,
    CONSTANTS.MODIFIER_COMBINATION.CTRL,
    CONSTANTS.MODIFIER_COMBINATION.ALT,
    CONSTANTS.MODIFIER_COMBINATION.ALT_SHIFT,
    CONSTANTS.MODIFIER_COMBINATION.ALT_CTRL,
    CONSTANTS.MODIFIER_COMBINATION.SHIFT_CTRL,
    CONSTANTS.MODIFIER_COMBINATION.ALT_SHIFT_CTRL
}

CONSTANTS.MODIFIER_COMBINATIONS = UTILS.Set(CONSTANTS.MODIFIER_COMBINATIONS_SORTED)

CONSTANTS.MODIFIER_COMBINATIONS_GUI = {
    [CONSTANTS.MODIFIER_COMBINATION.DISABLED] = CLM.L["Disable"],
    [CONSTANTS.MODIFIER_COMBINATION.SHIFT] = CLM.L["Shift"],
    [CONSTANTS.MODIFIER_COMBINATION.CTRL] = CLM.L["Ctrl"],
    [CONSTANTS.MODIFIER_COMBINATION.ALT] = CLM.L["Alt"],
    [CONSTANTS.MODIFIER_COMBINATION.ALT_SHIFT] = CLM.L["Shift + Alt"],
    [CONSTANTS.MODIFIER_COMBINATION.ALT_CTRL] = CLM.L["Ctrl + Alt"],
    [CONSTANTS.MODIFIER_COMBINATION.SHIFT_CTRL] = CLM.L["Shift + Ctrl"],
    [CONSTANTS.MODIFIER_COMBINATION.ALT_SHIFT_CTRL] = CLM.L["Shift + Ctrl + Alt"]
}

CLM.GlobalConfigs = GlobalConfigs