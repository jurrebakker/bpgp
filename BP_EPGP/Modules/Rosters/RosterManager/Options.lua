-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local CBTYPE = {
    GETTER          = "get",
    SETTER          = "set",
    EXECUTOR        = "execute",
    HIDER           = "hide",
    CONFIRMATION    = "confirm"
}

---@class RosterManagerOptions
---@field copy_source_name string?
---@field externalOptions table
---@field handlers table
---@field readOnly boolean
---@field rosterName string
local RosterManagerOptions = { externalOptions = {} }

local function GetRosterOption(name, option)
    local roster = CLM.MODULES.RosterManager:GetRosterByName(name)
    if roster == nil then return nil end
    return roster:GetConfiguration(option)
end

local function SetRosterOption(name, option, value)
    CLM.MODULES.RosterManager:SetRosterConfiguration(name, option, value)
end

---@return nil
function RosterManagerOptions:Initialize()
    self.rosterName = CLM.MODULES.RosterManager:GenerateName()
    self.readOnly = not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.MANAGER)
    self.handlers = {
        general_name_get = (function(name)
            return name
        end),
        general_name_set = (function(old, new)
            CLM.MODULES.RosterManager:RenameRoster(old, new)
        end),
        general_remove_execute = (function(name)
            CLM.MODULES.RosterManager:DeleteRosterByName(name)
        end),
        general_fill_profiles_execute = (function(name)
            local profiles = CLM.MODULES.ProfileManager:GetProfiles()
            local profileList = {}
            for GUID, _ in pairs(profiles) do
                table.insert(profileList, GUID)
            end
            local roster = CLM.MODULES.RosterManager:GetRosterByName(name)
            CLM.MODULES.RosterManager:AddProfilesToRoster(roster, profileList)
        end),
        general_copy_execute = (function(name)
            if self.copy_source_name == nil then return end
            CLM.MODULES.RosterManager:Copy(self.copy_source_name, name, true, true, true, false)
        end),
        general_copy_source_get = (function(name)
            return self.copy_source_name
        end),
        general_copy_source_set = (function(name, value)
            self.copy_source_name = value
        end),
        -- Bonuses
        general_on_time_bonus_get = (function(name)
            return GetRosterOption(name, "onTimeBonus")
        end),
        general_on_time_bonus_set = (function(name, value)
            SetRosterOption(name, "onTimeBonus", value)
        end),
        general_on_time_bonus_value_get = (function(name)
            return tostring(GetRosterOption(name, "onTimeBonusValue"))
        end),
        general_on_time_bonus_value_set = (function(name, value)
            SetRosterOption(name, "onTimeBonusValue", value)
        end),
        general_named_buttons_toggle_set = (function(name, value)
            SetRosterOption(name, "namedButtons", value)
        end),
        general_named_buttons_toggle_get = (function(name)
            return GetRosterOption(name, "namedButtons")
        end),
        -- Caps
        general_round_decimals_get = (function(name)
            return GetRosterOption(name, "roundDecimals")
        end),
        general_round_decimals_set = (function(name, value)
            SetRosterOption(name, "roundDecimals", value)
        end),
        general_round_pr_get = (function(name)
            return GetRosterOption(name, "roundPR")
        end),
        general_round_pr_set = (function(name, value)
            SetRosterOption(name, "roundPR", value)
        end),
        general_min_gp_get = (function(name)
            return tostring(GetRosterOption(name, "minGP"))
        end),
        general_min_gp_set = (function(name, value)
            SetRosterOption(name, "minGP", value)
        end),
        -- Auction
        auction_auction_type_get = (function(name)
            return GetRosterOption(name, "auctionType")
        end),
        auction_auction_type_set = (function(name, value)
            SetRosterOption(name, "auctionType", value)
        end),
        auction_item_value_mode_get = (function(name)
            return GetRosterOption(name, "itemValueMode")
        end),
        auction_item_value_mode_set = (function(name, value)
            SetRosterOption(name, "itemValueMode", value)
        end),
        auction_cancelpass_get = (function(name)
            return GetRosterOption(name, "allowCancelPass")
        end),
        auction_cancelpass_set = (function(name, value)
            SetRosterOption(name, "allowCancelPass", value)
        end),
        auction_use_os_get = (function(name)
            return GetRosterOption(name, "useOS")
        end),
        auction_use_os_set = (function(name, value)
            SetRosterOption(name, "useOS", value)
        end),
        auction_auction_time_get = (function(name)
            return tostring(GetRosterOption(name, "auctionTime"))
        end),
        auction_auction_time_set = (function(name, value)
            SetRosterOption(name, "auctionTime", value)
        end),
        auction_antisnipe_time_get = (function(name)
            return tostring(GetRosterOption(name, "antiSnipe"))
        end),
        auction_antisnipe_time_set = (function(name, value)
            SetRosterOption(name, "antiSnipe", value)
        end),
        auction_linear_time_multiply_get = (function(name)
            return GetRosterOption(name, "multiplyTime")
        end),
        auction_linear_time_multiply_set = (function(name, value)
            SetRosterOption(name, "multiplyTime", value)
        end),
        auction_roll_time_get = (function(name)
            return tostring(GetRosterOption(name, "rollTime"))
        end),
        auction_roll_time_set = (function(name, value)
            SetRosterOption(name, "rollTime", value)
        end),
        auction_minimum_points_get = (function(name)
            return tostring(GetRosterOption(name, "minimumPoints"))
        end),
        auction_minimum_points_set = (function(name, value)
            SetRosterOption(name, "minimumPoints", value)
        end),
        general_starting_points_get = (function(name)
            return tostring(GetRosterOption(name, "basePoints"))
        end),
        general_starting_points_set = (function(name, value)
            SetRosterOption(name, "basePoints", value)
        end),
        general_starting_spent_get = (function(name)
            return tostring(GetRosterOption(name, "baseSpent"))
        end),
        general_starting_spent_set = (function(name, value)
            SetRosterOption(name, "baseSpent", value)
        end),
    }

    self:UpdateOptions()

    CLM.MODULES.LedgerManager:RegisterOnUpdate(function(lag, uncommitted)
        if lag ~= 0 or uncommitted ~= 0 then return end
        self:UpdateOptions()
        CLM.MODULES.ConfigManager:UpdateOptions(CONSTANTS.CONFIGS.GROUP.ROSTER)
    end)
end

local CONFIRMATION_GROUPS = UTILS.Set({"general", "auction"})
---@param cbtype string
---@param info table
---@return any
function RosterManagerOptions:_Handle(cbtype, info, ...)
    -- Assumes This is the handler of each of the subgroups but not the main group
    local roster_name = info[1]
    local group = info[2]
    local node_name
    if #info >= 2 then
        node_name = group
        for i=3,#info do
            node_name = node_name .. "_" .. info[i]
        end
    else
        node_name = info[#info]
    end
    node_name = node_name .. "_".. cbtype

    -- print(node_name)
    -- Execute handler
    if type(self.handlers[node_name]) == "function" then
        return self.handlers[node_name](roster_name, ...)
    end

    if cbtype == CBTYPE.HIDER then
        return false
    end

    if cbtype == CBTYPE.CONFIRMATION then
        if CLM.MODULES.RaidManager:IsInActiveRaid() then
            local raid = CLM.MODULES.RaidManager:GetRaid()
            if not raid then return false end
            if raid:Roster() == CLM.MODULES.RosterManager:GetRosterByName(roster_name) and CONFIRMATION_GROUPS[group] then
                return CLM.L["You are changing roster settings during active raid. You can continue without any issues however the settings will not get applied until you start a new one."]
            end
        end

        return false
    end

    return nil
end

---@param info table
---@return any
function RosterManagerOptions:Getter(info, ...)
   return self:_Handle(CBTYPE.GETTER, info, ...)
end

---@param info table
function RosterManagerOptions:Setter(info, ...)
    if self.readOnly then return end
    self:_Handle(CBTYPE.SETTER, info, ...)
end

---@param info table
function RosterManagerOptions:Handler(info, ...)
    self:_Handle(CBTYPE.EXECUTOR, info, ...)
end

---@param info table
function RosterManagerOptions:Hider(info, ...)
    self:_Handle(CBTYPE.HIDER, info, ...)
end

---@param info table
---@return any
function RosterManagerOptions:Confirmation(info, ...)
    return self:_Handle(CBTYPE.CONFIRMATION, info, ...)
end

local valuesWithDesc = {
    {
        type = CONSTANTS.SLOT_VALUE_TIER.BASE,
        desc = CLM.L["Base value for Static-Priced auction.\nMinimum value for Ascending and Tiered auction.\n\nSet to same value as other tier or negative to ignore."]
    },
    {
        type = CONSTANTS.SLOT_VALUE_TIER.SMALL,
        desc = CLM.L["Small value for Tiered auction.\n\nSet to same value as other tier or negative to ignore."]
    },
    {
        type = CONSTANTS.SLOT_VALUE_TIER.MEDIUM,
        desc = CLM.L["Medium value for Tiered auction.\n\nSet to same value as other tier or negative to ignore."]
    },
    {
        type = CONSTANTS.SLOT_VALUE_TIER.LARGE,
        desc = CLM.L["Large value for Tiered auction.\n\nSet to same value as other tier or negative to ignore."]
    },
    {
        type = CONSTANTS.SLOT_VALUE_TIER.MAX,
        desc = CLM.L["Maximum value for Ascending and Tiered auction.\n\nSet to same value as other tier or negative to ignore."]
    }
}

local function default_slot_values(self, roster)
    local args = {}
    local order = 0
    local prefix
    for _, slot in ipairs(CONSTANTS.INVENTORY_TYPES_SORTED) do
        prefix = slot.type:lower()
        args[prefix .. "_header"] = {
            type = "header",
            order = order,
            name = slot.name
        }
        order = order + 1
        args[prefix .. "_icon"] = {
            name = "",
            type = "description",
            image = slot.icon,
            order = order,
            width = 0.5
        }
        order = order + 1
        for _, ivalues in ipairs(valuesWithDesc) do
            args[prefix .. "_" .. ivalues.type] = {
                type = "input",
                order = order,
                desc = ivalues.desc,
                width = 0.5,
                get = (function(i)
                    return tostring(roster:GetDefaultSlotTierValue(slot.type, ivalues.type))
                end),
                set = (function(i, v)
                    if self.readOnly then return end
                    CLM.MODULES.RosterManager:SetRosterDefaultSlotTierValue(roster, slot.type, ivalues.type, tonumber(v))
                end),
                -- name = (CONSTANTS.SLOT_VALUE_TIERS_GUI[ivalues.type] or ""),
                name = UTILS.GetRosterConditionalFieldName(ivalues.type, roster),
                pattern = CONSTANTS.REGEXP_FLOAT,
            }
            order = order + 1
        end
    end
    return args
end

local function item_value_overrides(self, roster)
    local items = roster:GetAllItemValues()
    local args = {}
    local order = 1
    for id,_ in pairs(items) do
        local _, _, _, _, icon = UTILS.GetItemInfoInstant(id)
        local shortItemLink = "item:" .. tostring(id)
        if icon then
            local sid = tostring(id)
            local prefix = "i" .. sid
            args[prefix .. "icon"] = {
                    name = "",
                    image = icon,
                    order = order,
                    width = 0.35,
                    type = "execute",
                    func = (function() end),
                    tooltipHyperlink = shortItemLink,
                }
            order = order + 1
            for _, ivalues in ipairs(valuesWithDesc) do
                args[prefix .. "_" .. ivalues.type] = {
                    type = "input",
                    order = order,
                    -- desc = ivalues.desc,
                    width = 0.5,
                    set = (function(i, v)
                        if self.readOnly then return end
                        CLM.MODULES.RosterManager:SetRosterItemTierValue(roster, id, ivalues.type, tonumber(v))
                    end),
                    get = (function(i)
                        local values = roster:GetItemValues(id)
                        return tostring(values[ivalues.type])
                    end),
                    -- name = (CONSTANTS.SLOT_VALUE_TIERS_GUI[ivalues.type] or ""),
                    name = UTILS.GetRosterConditionalFieldName(ivalues.type, roster),
                    pattern = CONSTANTS.REGEXP_FLOAT,
                }
                order = order + 1
            end
            args[prefix .. "remove"] = {
                name = "x",
                desc = CLM.L["Remove override"],
                -- image = icon,
                order = order,
                width = 0.30,
                type = "execute",
                func = (function() CLM.MODULES.RosterManager:RemoveRosterItemOverride(roster, id) end)
            }
            order = order + 6
        end
    end
    return args
end

function RosterManagerOptions:GenerateRosterOptions(name)
    local roster = CLM.MODULES.RosterManager:GetRosterByName(name)
    if not roster then
        LOG:Debug("RosterManagerOptions:GenerateRosterOptions(): Unknown roster %s", tostring(name))
        return
    end
    local isManager = CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.MANAGER)

    local disableManage = (function() return not isManager end)


    local options = {
        type = "group",
        name = name,
        handler = self,
        set = "Setter",
        get = "Getter",
        confirm = "Confirmation",
        -- hidden = "Hider",
        func = "Handler",
        childGroups = "select",
        order = roster:UID(),
        args = {
            general = {
                name = CLM.L["General settings"],
                type = "group",
                order = 1,
                args = {
                    name = {
                        name = CLM.L["Name"],
                        desc = CLM.L["Change roster name."],
                        type = "input",
                        width = 1,
                        order = 0
                    },
                    round_decimals = {
                        name = CLM.L["Rounding"],
                        desc = CLM.L["Round to selected number of decimals"],
                        type = "select",
                        -- style = "radio",
                        width = 1,
                        disabled = disableManage,
                        order = 2,
                        values = CONSTANTS.ALLOWED_ROUNDINGS_GUI
                    },
                    copy_header = {
                        name = CLM.L["Copy settings"],
                        type = "header",
                        order = 97,
                        width = "full"
                    },
                    copy = {
                        name = CLM.L["Copy settings"],
                        desc = CLM.L["Copy settings from selected roster."],
                        type = "execute",
                        confirm = true,
                        disabled = disableManage,
                        order = 98
                    },
                    copy_source = {
                        name = CLM.L["Copy source"],
                        desc = CLM.L["Copy settings from selected roster."],
                        type = "select",
                        values = (function()
                            local v = {}
                            local r = CLM.MODULES.RosterManager:GetRosters()
                            for n, _r in pairs(r) do
                                v[n] = n
                            end
                            return v
                        end),
                        disabled = disableManage,
                        order = 99
                    },
                    remove_header = {
                        name = CLM.L["Remove roster"],
                        type = "header",
                        order = 100,
                        width = "full"
                    },
                    remove = {
                        name = CLM.L["Remove"],
                        desc = CLM.L["Removes current roster."],
                        type = "execute",
                        confirm = true,
                        disabled = disableManage,
                        order = 101
                    },
                    --
                    bonuses_header = {
                        name = CLM.L["Bonuses"],
                        type = "header",
                        order = 4,
                        width = "full"
                    },
                    on_time_bonus = {
                        name = CLM.L["On Time Bonus"],
                        type = "toggle",
                        order = 6,
                        disabled = disableManage,
                        width = 1
                    },
                    on_time_bonus_value = {
                        name = CLM.L["On Time Bonus Value"],
                        type = "input",
                        order = 9,
                        pattern = CONSTANTS.REGEXP_FLOAT_POSITIVE,
                        disabled = disableManage,
                        width = 1
                    },
                    starting_points_header = {
                        name = CLM.L["Starting points"],
                        type = "header",
                        order = 21,
                        width = "full"
                    },
                    starting_points = {
                        name = function() return string.format(CLM.L["Starting %s"], CLM.L["EP"]) end,
                        desc = function() return string.format(CLM.L["%s to be awarded to player when joining roster."], CLM.L["EP"]) end,
                        type = "input",
                        disabled = disableManage,
                        order = 22,
                        pattern = CONSTANTS.REGEXP_FLOAT_POSITIVE,
                    },
                    starting_spent = {
                        name = function() return string.format(CLM.L["Starting %s"], CLM.L["GP"]) end,
                        desc = function() return string.format(CLM.L["%s to be awarded to player when joining roster."], CLM.L["GP"]) end,
                        type = "input",
                        disabled = disableManage,
                        order = 23,
                        pattern = CONSTANTS.REGEXP_FLOAT_POSITIVE,
                    },
                    named_buttons_header = {
                        name = CLM.L["Button Names"],
                        type = "header",
                        order = 28,
                        width = "full"
                    },
                    epgp_header = {
                        name = CLM.L["EPGP"],
                        type = "header",
                        order = 36,
                        width = "full",
                    },
                    min_gp = {
                        name = CLM.L["Minimum GP"],
                        desc = CLM.L["Minimum GP used in calculations when player has less GP than this value."],
                        type = "input",
                        disabled = disableManage,
                        pattern = CONSTANTS.REGEXP_FLOAT_POSITIVE,
                        order = 37,
                    },
                    round_pr = {
                        name = CLM.L["PR Rounding"],
                        desc = CLM.L["Round PR to selected number of decimals"],
                        type = "select",
                        width = 1,
                        disabled = disableManage,
                        order = 38,
                        values = CONSTANTS.ALLOWED_ROUNDINGS_GUI
                    },
                },
            },
            auction = {
                name = CLM.L["Auction settings"],
                type = "group",
                order = 2,
                args = {
                    item_value_mode = {
                        name = CLM.L["Item value mode"],
                        desc = CLM.L["|cff00ee44Single-Priced:|r Static value mode. Only bidding Base value is supported.\n\n|cff00ee44Ascending:|r Ranged value mode. Allows bidding any value in |cff44ee00<base, max>|r.\n\n|cff00ee44Tiered:|r Ranged value mode. Allows bidding only specific values. Up to 5 tiers are configurable in |cff44ee00<base, small, medium, large, max>|r."],
                        type = "select",
                        disabled = disableManage,
                        order = 5,
                        values = CONSTANTS.ITEM_VALUE_MODES_GUI
                    },
                    bidding_header = {
                        name = CLM.L["Bidding"],
                        type = "header",
                        order = 10,
                        width = "full"
                    },
                    minimum_points = {
                        name = CLM.L["Minimum standing"],
                        desc = CLM.L["Minimum standing required to be allowed to bid."],
                        type = "input",
                        disabled = disableManage,
                        pattern = CONSTANTS.REGEXP_FLOAT,
                        width = 1,
                        order = 11
                    },
                    use_os = {
                        name = CLM.L["OS"],
                        desc = CLM.L["Enable OS bids"],
                        type = "toggle",
                        disabled = disableManage,
                        width = 1,
                        order = 12
                    },
                    cancelpass = {
                        name = CLM.L["Always allow cancel/pass"],
                        desc = CLM.L["Enable to always allow cancelling or passing bids. Affects Open-Ascending Auction."],
                        type = "toggle",
                        disabled = disableManage,
                        width = 2,
                        order = 12.1
                    },
                    time_header = {
                        name = CLM.L["Time"],
                        type = "header",
                        order = 13,
                        width = "full"
                    },
                    auction_time = {
                        name = CLM.L["Auction length"],
                        desc = CLM.L["Auction length in seconds."],
                        type = "input",
                        disabled = disableManage,
                        pattern = CONSTANTS.REGEXP_FLOAT_POSITIVE,
                        width = 1,
                        order = 14
                    },
                    antisnipe_time = {
                        name = CLM.L["Anti-snipe time"],
                        desc = CLM.L["Time in seconds by which auction will be extended if bid is received during last 10 seconds."],
                        type = "input",
                        disabled = disableManage,
                        pattern = CONSTANTS.REGEXP_FLOAT_POSITIVE,
                        width = 1,
                        order = 15
                    },
                    linear_time_multiply = {
                        name = CLM.L["Multiply time"],
                        desc = CLM.L["Multiply auction time by the number of items to increase auction time lineary."],
                        type = "toggle",
                        disabled = disableManage,
                        width = 1,
                        order = 16
                    },
                    roll_time = {
                        name = CLM.L["Roll"] .. " " .. CLM.L["Time"],
                        desc = CLM.L["Roll"] .. " " .. CLM.L["Time"],
                        type = "input",
                        disabled = disableManage,
                        pattern = CONSTANTS.REGEXP_FLOAT_POSITIVE,
                        width = 1,
                        order = 20
                    },
                },
            },
            default_slot_values = {
                name = CLM.L["Default slot values"],
                type = "group",
                order = 3,
                args = default_slot_values(self, roster)
            },
            item_value_overrides = {
                name = CLM.L["Item value overrides"],
                type = "group",
                order = 5,
                args = item_value_overrides(self, roster)
            },
        }
    }
    options.args.auction.args.auction_type = {
        name = CLM.L["Auction type"],
        desc = CLM.L["|cff00ee44Open:|r English Auction with highest bidder announcement. Highest bidder wins. Two players can not bid same value. Additionally always allows bidding base to accomodate for Swedish Auction flavor.\n\n|cff00ee44Anonymous Open:|r Same as Open but highest bidder name is not disclosed.\n\n|cff00ee44Sealed:|r Bids are not announced. Highest bidder wins.\n\n|cff00ee44Vickrey:|r Same as sealed but winner pays with second-highest bid."],
        type = "select",
        disabled = disableManage,
        order = 4,
        values = CONSTANTS.AUCTION_TYPES_GUI
    }
    -- Button names
    options.args.general.args.named_buttons_toggle = {
        name = CLM.L["Use named buttons"],
        desc = CLM.L["Will display names of the buttons instead of values in bidding UI"],
        type = "toggle",
        order = 29,
        disabled = disableManage,
        width = 1
    }
    local order = 30
    for _, tier in ipairs(CONSTANTS.SLOT_VALUE_TIERS_ORDERED) do
        options.args.general.args["named_button_tier_" .. tostring(tier)] = {
            -- name = CONSTANTS.SLOT_VALUE_TIERS_GUI[tier],
            name = UTILS.GetRosterConditionalFieldName(tier, roster),
            type = "input",
            set = (function(i, v) CLM.MODULES.RosterManager:SetFieldName(roster, tier, v) end),
            get = (function(i) return roster:GetFieldName(tier) end),
            order = order,
            disabled = disableManage,
            width = 1
        }
        order = order + 1
    end
    return options
end

function RosterManagerOptions:UpdateOptions()
    local options = {
        new = { -- Global options -> Create New Roster
            name = CLM.L["Create"],
            desc = CLM.L["Creates new roster with default configuration"],
            type = "execute",
            func = function() CLM.MODULES.RosterManager:NewRoster(self.rosterName); self.rosterName = CLM.MODULES.RosterManager:GenerateName() end,
            disabled = (function() return not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.MANAGER) end),
            order = 1
        },
        roster_name = {
            name = CLM.L["Roster name"],
            desc = CLM.L["Roster Name"],
            type = "input",
            set = (function(i, v) self.rosterName = v end),
            get = (function(i) return self.rosterName end),
            disabled = (function() return not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.MANAGER) end),
            order = 2,
        },
    }
    for _, name in pairs(CLM.MODULES.RosterManager:GetRostersUidMap()) do
        options[name] = self:GenerateRosterOptions(name)
    end
    CLM.MODULES.ConfigManager:Register(CONSTANTS.CONFIGS.GROUP.ROSTER, options, true)
end

CLM.OPTIONS.RosterManager = RosterManagerOptions
