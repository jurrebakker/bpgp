-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

local EVENT_FILL_AUCTION_WINDOW = "CLM_AUCTION_WINDOW_FILL" -- TODO event

BINDING_HEADER_BPEPGP = "BP EPGP"
_G["BINDING_NAME_BPEPGP_START_AUCTION"] = "Start Auction"
_G["BINDING_NAME_BPEPGP_QUICK_START_AUCTION"] = "Quick Start Auction"
_G["BINDING_NAME_BPEPGP_AWARD_FOR_BASE"] = "Award for Base"
_G["BINDING_NAME_BPEPGP_AWARD_FOR_TIER_SMALL"] = "Award for Tier: Small"
_G["BINDING_NAME_BPEPGP_AWARD_FOR_TIER_MEDIUM"] = "Award for Tier: Medium"
_G["BINDING_NAME_BPEPGP_AWARD_FOR_TIER_LARGE"] = "Award for Tier: Large"
_G["BINDING_NAME_BPEPGP_AWARD_FOR_MAX"] = "Award for Max"
_G["BINDING_NAME_BPEPGP_AWARD_FOR_FREE"] = "Award for Free"
_G["BINDING_NAME_BPEPGP_TOGGLE_AUCTIONING"] = "Toggle Auctioning"
_G["BINDING_NAME_BPEPGP_TOGGLE_AUCTION_HISTORY"] = "Toggle Auction History"
_G["BINDING_NAME_BPEPGP_TOGGLE_BIDDING"] = "Toggle Bidding"
_G["BINDING_NAME_BPEPGP_TOGGLE_LOOT_QUEUE"] = "Toggle Loot Queue"
_G["BINDING_NAME_BPEPGP_TOGGLE_MAIN_UI"] = "Toggle Main UI"

function BPEPGP_Binding_StartAuction() -- luacheck: ignore
    LOG:Trace("BPEPGP_Binding_StartAuction")
    if GameTooltip then
        local _, itemLink = GameTooltip:GetItem()
        if itemLink then
            CLM.MODULES.EventManager:DispatchEvent(EVENT_FILL_AUCTION_WINDOW, {
                link = itemLink,
                start = false
            })
        end
    end
end

function BPEPGP_Binding_QuickStartAuction() -- luacheck: ignore
    LOG:Trace("BPEPGP_Binding_QuickStartAuction")
    if GameTooltip then
        local _, itemLink = GameTooltip:GetItem()
        if itemLink then
            CLM.MODULES.EventManager:DispatchEvent(EVENT_FILL_AUCTION_WINDOW, {
                link = itemLink,
                start = true
            })
        end
    end
end

---@param tier number
local function awardForTierValue(tier)
    if GameTooltip then
        local _, itemLink = GameTooltip:GetItem()
        if itemLink then
            local value = 0
            local raid = CLM.MODULES.RaidManager:GetRaid()
            if raid then
                local itemId = CLM.UTILS.GetItemIdFromLink(itemLink)
                value = raid:Roster():GetItemValues(itemId)[tier]
            end
            CLM.GlobalSlashCommands:Award(itemLink .. "/" .. value)
        end
    end
end

function BPEPGP_Binding_AwardForBase() -- luacheck: ignore
    LOG:Trace("BPEPGP_Binding_AwardForBase")
    awardForTierValue(CONSTANTS.SLOT_VALUE_TIER.BASE)
end

function BPEPGP_Binding_AwardForSmall() -- luacheck: ignore
    LOG:Trace("BPEPGP_Binding_AwardForSmall")
    awardForTierValue(CONSTANTS.SLOT_VALUE_TIER.SMALL)
end

function BPEPGP_Binding_AwardForMedium() -- luacheck: ignore
    LOG:Trace("BPEPGP_Binding_AwardForMedium")
    awardForTierValue(CONSTANTS.SLOT_VALUE_TIER.MEDIUM)
end

function BPEPGP_Binding_AwardForLarge() -- luacheck: ignore
    LOG:Trace("BPEPGP_Binding_AwardForLarge")
    awardForTierValue(CONSTANTS.SLOT_VALUE_TIER.LARGE)
end

function BPEPGP_Binding_AwardForMax() -- luacheck: ignore
    LOG:Trace("BPEPGP_Binding_AwardForMax")
    awardForTierValue(CONSTANTS.SLOT_VALUE_TIER.MAX)
end

function BPEPGP_Binding_AwardForFree() -- luacheck: ignore
    LOG:Trace("BPEPGP_Binding_AwardForFree")
    if GameTooltip then
        local _, itemLink = GameTooltip:GetItem()
        if itemLink then
            CLM.GlobalSlashCommands:Award(itemLink)
        end
    end
end
-- GUI Toggles

function BPEPGP_Binding_ToggleGUI_UnifiedGUI() -- luacheck: ignore
    CLM.GUI.Unified:Toggle()
end
function BPEPGP_Binding_ToggleGUI_LootQueue() -- luacheck: ignore
    CLM.GUI.LootQueue:Toggle()
end
function BPEPGP_Binding_ToggleGUI_AuctionHistory() -- luacheck: ignore
    CLM.GUI.AuctionHistory:Toggle()
end
function BPEPGP_Binding_ToggleGUI_Bidding() -- luacheck: ignore
    CLM.GUI.BiddingManager:Toggle()
end
function BPEPGP_Binding_ToggleGUI_Auctioning() -- luacheck: ignore
    CLM.GUI.AuctionManager:Toggle()
end
