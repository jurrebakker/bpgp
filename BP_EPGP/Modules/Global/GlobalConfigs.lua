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
        announce_award_to_guild = true,
        announce_loot_to_raid = false,
        announce_loot_to_raid_owner_only = true,
        announce_loot_to_raid_level = 3,
        wowdkpbot_integration = false,
        modifier_combination = CONSTANTS.MODIFIER_COMBINATION.ALT,
        award_modifier_combination = CONSTANTS.MODIFIER_COMBINATION.ALT_SHIFT,
        chat_commands = false,
        alerts = true,
        sounds = true,
        disable_sync = false,
        suppress_incoming_chat_commands = false,
        suppress_outgoing_chat_commands = false,
        tooltips_display = true,
        raid_warnings = {
            raid = true,
            auction = true,
            countdown = true,
            bids = true,
            loot = true,
            commands = false
        },
        loot_roll = {
            rollOnLoot = CONSTANTS.LOOT_ROLL_TYPE_IGNORE,
            includeLegendary = false,
            includeStacking = false,
            includePatterns = false,
            includeMounts = false,
            includeToys = false,
            includeCosmetics = false,
        }
    })

    local options = {
        clm_logo = {
            name = "",
            type = "description",
            image = CLM.MEDIA_PATH .. "Icons\\bp-epgp-32.png",
            width = 0.25,
            order = 0
        },
        title = {
            type = "description",
            name = (function() return "|cffe6cc80BP EPGP|r " .. CLM.MODULES.Version:GetString() end),
            fontSize = "large",
            descStyle = "inline",
            width = 3,
            order = 0.1
        },
        global_header = {
            type = "header",
            name = CLM.L["Global"],
            order = 1
        },
        global_ui_scale = {
            name = CLM.L["UI Scale"],
            desc = CLM.L["Rescales CLM UI, except Bidding window. You can rescale Bidding window independently by using Ctrl + Mouse Wheel. Some windows may require closing and reopening."],
            type = "range",
            min = 0.5,
            max = 2,
            step = 0.1,
            set = function(i, v)
                if v < 0.5 then v = 0.5 end
                if v > 2 then v = 2 end
                self.db.uiscale = v

                CLM.MODULES.EventManager:DispatchEvent("CLM_UI_RESIZE", {
                    scale = self.db.uiscale
                })

            end,
            get = function(i) return self.db.uiscale end,
            order = 2.1,
            width = 1
        },
        global_sounds = {
            name = CLM.L["Addon sounds"],
            desc = CLM.L["Toggles addon sounds."],
            type = "toggle",
            set = function(i, v) self:SetSounds(v) end,
            get = function(i) return self:GetSounds() end,
            width = 1,
            order = 2.5
        },
        global_wipe_ledger = {
            name = CLM.L["Wipe events"],
            desc = CLM.L["Wipes all events from memory. This will trigger resyncing from other users."],
            type = "execute",
            confirm = true,
            func = function() CLM.MODULES.LedgerManager:Wipe() end,
            order = 4
        },
        global_loot_announcement_header = {
            type = "header",
            name = CLM.L["Announce loot"],
            order = 5
        },
        global_raid_loot_announcement = {
            name = CLM.L["Announce loot from corpse to Raid"],
            desc = CLM.L["Toggles loot announcement to raid"],
            type = "toggle",
            set = function(i, v) self:SetAnnounceLootToRaid(v) end,
            get = function(i) return self:GetAnnounceLootToRaid() end,
            width = "double",
            order = 6
        },
        global_raid_loot_announcement_owner_only = {
            name = CLM.L["Only when ML/RL"],
            desc = CLM.L["When enabled, this will make loot announcement display only if you're Master Looter or Raid Leader (if there is no Master Looter)."],
            type = "toggle",
            set = function(i, v) self:SetAnnounceLootToRaidOwnerOnly(v) end,
            get = function(i) return self:GetAnnounceLootToRaidOwnerOnly() end,
            width = "double",
            order = 7
        },
        global_raid_loot_announcement_level = {
            name = CLM.L["Announcement loot rarity"],
            desc = CLM.L["Select loot rarity for the annoucement to raid."],
            type = "select",
            values = CONSTANTS.ITEM_QUALITY,
            set = function(i, v) self:SetAnnounceLootToRaidLevel(v) end,
            get = function(i) return self:GetAnnounceLootToRaidLevel() end,
            order = 8
        },
        rw_header = {
            type = "header",
            name = CLM.L["Raid Warnings"],
            order = 120
        },
        rw_raid = {
            name = CLM.L["Raid Start/End"],
            desc = CLM.L["Enables announcing raid start and end."],
            type = "toggle",
            set = function(i, v) self:SetRaidWarning(v) end,
            get = function(i) return self:GetRaidWarning() end,
            -- width = "double",
            order = 121
        },
        rw_auction = {
            name = CLM.L["Auction Start/End"],
            desc = CLM.L["Enable announcing auction start and end."],
            type = "toggle",
            set = function(i, v) self:SetAuctionWarning(v) end,
            get = function(i) return self:GetAuctionWarning() end,
            order = 122
        },
        rw_countdown = {
            name = CLM.L["Auction End Countdown"],
            desc = CLM.L["Enables raid-warning countdown for auctions."],
            type = "toggle",
            set = function(i, v) self:SetCountdownWarning(v) end,
            get = function(i) return self:GetCountdownWarning() end,
            order = 124
        },
        rw_loot = {
            name = CLM.L["Loot Awards"],
            desc = CLM.L["Enables announcing loot awards."],
            type = "toggle",
            set = function(i, v) self:SetLootWarning(v) end,
            get = function(i) return self:GetLootWarning() end,
            order = 125
        },
        rw_bids = {
            name = CLM.L["Bids"],
            desc = CLM.L["Enables announcing new highest bid (when applicable)."],
            type = "toggle",
            set = function(i, v) self:SetBidsWarning(v) end,
            get = function(i) return self:GetBidsWarning() end,
            order = 126
        },
        danger_zone_header = {
            type = "header",
            name = CLM.L["Danger Zone - Use at own risk"],
            order = 10000
        },
        danger_zone_disable_sync = {
            type = "toggle",
            name = CLM.L["Disable data synchronisation"],
            desc = CLM.L["Disable data synchronisation. This might lead to unexpected consequences. Use this at your own risk. Requires /reload to apply."],
            set = function(i, v) self:SetDisableSync(v) end,
            get = function(i) return self:GetDisableSync() end,
            width = "full",
            order = 10001
        }
    }
    CLM.MODULES.ConfigManager:Register(CLM.CONSTANTS.CONFIGS.GROUP.GLOBAL, options)
end

---@param value any
function GlobalConfigs:SetRollType(value)
    self.db.loot_roll.rollOnLoot = CONSTANTS.ROLL_TYPE[value] and value or CONSTANTS.LOOT_ROLL_TYPE_IGNORE
end

---@return any
function GlobalConfigs:GetRollType()
    return self.db.loot_roll.rollOnLoot
end


---@param value boolean
function GlobalConfigs:SetLootRollIncludeLegendary(value)
    self.db.loot_roll.includeLegendary = value and true or false
end

---@return boolean
function GlobalConfigs:GetLootRollIncludeLegendary()
    return self.db.loot_roll.includeLegendary
end

---@param value boolean
function GlobalConfigs:SetLootRollIncludeStacking(value)
    self.db.loot_roll.includeStacking = value and true or false
end

---@return boolean
function GlobalConfigs:GetLootRollIncludeStacking()
    return self.db.loot_roll.includeStacking
end

---@param value boolean
function GlobalConfigs:SetLootRollIncludePatterns(value)
    self.db.loot_roll.includePatterns = value and true or false
end

---@return boolean
function GlobalConfigs:GetLootRollIncludePatterns()
    return self.db.loot_roll.includePatterns
end

---@param value boolean
function GlobalConfigs:SetLootRollIncludeMounts(value)
    self.db.loot_roll.includeMounts = value and true or false
end

---@return boolean
function GlobalConfigs:GetLootRollIncludeMounts()
    return self.db.loot_roll.includeMounts
end

---@param value boolean
function GlobalConfigs:SetLootRollIncludeToys(value)
    self.db.loot_roll.includeToys = value and true or false
end

---@return boolean
function GlobalConfigs:GetLootRollIncludeToys()
    return self.db.loot_roll.includeToys
end

---@param value boolean
function GlobalConfigs:SetLootRollIncludeCosmetics(value)
    self.db.loot_roll.includeCosmetics = value and true or false
end

---@return boolean
function GlobalConfigs:GetLootRollIncludeCosmetics()
    return self.db.loot_roll.includeCosmetics
end

---@param value boolean
function GlobalConfigs:SetSounds(value)
    self.db.sounds = value and true or false
end

---@return boolean
function GlobalConfigs:GetSounds()
    return self.db.sounds
end

---@param value boolean
function GlobalConfigs:SetAnnounceAwardToGuild(value)
    self.db.announce_award_to_guild = value and true or false
end

---@return boolean
function GlobalConfigs:GetAnnounceAwardToGuild()
    return self.db.announce_award_to_guild
end

---@param value boolean
function GlobalConfigs:SetAnnounceLootToRaid(value)
    self.db.announce_loot_to_raid = value and true or false
end

---@return boolean
function GlobalConfigs:GetAnnounceLootToRaid()
    return self.db.announce_loot_to_raid
end

---@param value boolean
function GlobalConfigs:SetAnnounceLootToRaidOwnerOnly(value)
    self.db.announce_loot_to_raid_owner_only = value and true or false
end

---@return boolean
function GlobalConfigs:GetAnnounceLootToRaidOwnerOnly()
    return self.db.announce_loot_to_raid_owner_only
end

---@param value number
function GlobalConfigs:SetAnnounceLootToRaidLevel(value)
    self.db.announce_loot_to_raid_level = tonumber(value)
end

---@return number
function GlobalConfigs:GetAnnounceLootToRaidLevel()
    return self.db.announce_loot_to_raid_level or 3
end

---@param value string
function GlobalConfigs:SetModifierCombination(value)
    self.db.modifier_combination = CONSTANTS.MODIFIER_COMBINATIONS[value] and value or CONSTANTS.MODIFIER_COMBINATION.ALT
end

---@return string
function GlobalConfigs:GetModifierCombination()
    return self.db.modifier_combination or CONSTANTS.MODIFIER_COMBINATION.ALT
end

---@param value string
function GlobalConfigs:SetAwardModifierCombination(value)
    self.db.award_modifier_combination = CONSTANTS.MODIFIER_COMBINATIONS[value] and value or CONSTANTS.MODIFIER_COMBINATION.ALT
end

---@return string
function GlobalConfigs:GetAwardModifierCombination()
    return self.db.award_modifier_combination or CONSTANTS.MODIFIER_COMBINATION.ALT
end

---@param value boolean
function GlobalConfigs:SetAllowChatCommands(value)
    self.db.chat_commands = value and true or false
end

---@return boolean
function GlobalConfigs:GetAllowChatCommands()
    return self.db.chat_commands
end

---@param value boolean
function GlobalConfigs:SetSuppressIncomingChatCommands(value)
    self.db.suppress_incoming_chat_commands = value and true or false
end

---@return boolean
function GlobalConfigs:GetSuppressIncomingChatCommands()
    return self.db.suppress_incoming_chat_commands
end

---@param value boolean
function GlobalConfigs:SetSuppressOutgoingChatCommands(value)
    self.db.suppress_outgoing_chat_commands = value and true or false
end

---@return boolean
function GlobalConfigs:GetSuppressOutgoingChatCommands()
    return self.db.suppress_outgoing_chat_commands
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
function GlobalConfigs:SetCommandsWarning(value)
    self.db.raid_warnings.commands = value and true or false
end

---@return boolean
function GlobalConfigs:GetCommandsWarning()
    return self.db.raid_warnings.commands
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

---@param value boolean
function GlobalConfigs:SetBidsWarning(value)
    self.db.raid_warnings.bids = value and true or false
end

---@return boolean
function GlobalConfigs:GetBidsWarning()
    return self.db.raid_warnings.bids
end

---@param v boolean
function GlobalConfigs:SetPriceTooltip(v)
    self.db.tooltips_display = v and true or false
end

---@return boolean
function GlobalConfigs:GetPriceTooltip()
    return self.db.tooltips_display
end

---@return boolean
function GlobalConfigs:GetDisableSync()
    return self.db.disable_sync
end

---@param value boolean
function GlobalConfigs:SetDisableSync(value)
    self.db.disable_sync = value and true or false
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