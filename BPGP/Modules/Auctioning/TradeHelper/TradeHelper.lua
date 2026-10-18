--[[
    Trade helper: tracks awarded items per winner and puts them in the trade window.
    Lots of thanks to Zh0rax (https://github.com/papa-smurf) for sharing
    all the corner cases of trade handling and solutions to them
]]--

-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local GetContainerNumSlots = GetContainerNumSlots or C_Container.GetContainerNumSlots
local UseContainerItem     = UseContainerItem or C_Container.UseContainerItem

-- Tooltip lines that mean the item can't go to another player (warbound counts as bound)
local boundLines = {}
for _, text in ipairs({ ITEM_SOULBOUND, ITEM_ACCOUNTBOUND, ITEM_BNETACCOUNTBOUND, ITEM_ACCOUNTBOUND_UNTIL_EQUIP }) do
    if type(text) == "string" then boundLines[text] = true end
end

local function ScanTooltip(self)
    local query = string.gsub(BIND_TRADE_TIME_REMAINING, "%%s", ".*")
    local lineWithTimer
    for i = 1, self.fakeTooltip:NumLines() do
        local line = _G["BPGPTradeHelperBagItemCheckerFakeTooltipTextLeft" .. i]
        if line then
            line = line:GetText() or ""
            if UTILS.IsSecret(line) then line = "" end
            if boundLines[line] then
                self.itemInfo.soulbound = true
            end
            if string.find(line, query) then
                lineWithTimer = line
                break
            end
        end
    end
    if lineWithTimer then
        self.itemInfo.tradeTimerExpired = false
    end
end

---@class BagItemChecker
---@field fakeTooltip table
---@field bag number
---@field slot number
---@field itemInfo table
local BagItemChecker = {}
function BagItemChecker:Initialize()
    self.fakeTooltip = CreateFrame("GameTooltip", "BPGPTradeHelperBagItemCheckerFakeTooltip", UIParent, "GameTooltipTemplate")
    self.fakeTooltip:SetOwner(UIParent, "ANCHOR_NONE");
    self:Clear()
end

function BagItemChecker:Clear()
    self.bag = -1
    self.slot = -1

    self.itemInfo = {
        id = -1,
        link = "",
        locked = true,
        soulbound = false,
        tradeTimerExpired = true
    }
end

local function BagItemCheck(self)
    local info = C_Container.GetContainerItemInfo(self.bag, self.slot)
    -- This is a damn fucking n-returns in classic still
    if not info then return end
    self.itemInfo.locked = info.isLocked or false
    self.itemInfo.id = info.itemID or -1
    self.itemInfo.soulbound = false
    self.itemInfo.link = info.hyperlink or ""
    ScanTooltip(self)
end

---@param bag number
---@param slot number
function BagItemChecker:Set(bag, slot)
    self:Clear()

    self.bag = bag
    self.slot = slot

    self.fakeTooltip:ClearLines()
    self.fakeTooltip:SetBagItem(self.bag, self.slot)

    BagItemCheck(self)
end

---@return number
function BagItemChecker:GetItemId()
    return self.itemInfo.id
end

---@return string
function BagItemChecker:GetItemLink()
    return self.itemInfo.link
end

---@return boolean
function BagItemChecker:IsLocked()
    return self.itemInfo.locked
end

---@return boolean
function BagItemChecker:IsSoulbound()
    return self.itemInfo.soulbound
end

---@return boolean
function BagItemChecker:TradeTimerExpired()
    return self.itemInfo.tradeTimerExpired
end

---@return boolean
function BagItemChecker:IsTradeable()
    return not self:TradeTimerExpired() or not self:IsSoulbound()
end

local function ScanBagsForItem(itemLink, tradeableOnly)
    local found = {}
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            BagItemChecker:Set(bag, slot)
            if not BagItemChecker:IsLocked() and (BagItemChecker:GetItemLink() == itemLink) then
                local isTradeable = true
                if tradeableOnly then
                    isTradeable = BagItemChecker:IsTradeable()
                end
                if isTradeable then
                    tinsert(found, {bag = bag, slot = slot} )
                end
            end
        end
    end
    return found
end

local function FindLastTradeTargetItems(self)
    local foundItems = {}
    for _, itemLink in ipairs(self.tracking[self.lastTradeTarget]) do
        if not foundItems[itemLink] then
            local found = ScanBagsForItem(itemLink, true)
            if #found > 0 then
                foundItems[itemLink] = found
            end
        end
    end
    return foundItems
end

----
----
----

local function Clear(self)
    self.lastTradedItems = {}
    self.lastTradeTarget = nil
end

local function HandleTradeShow(self)
    if self.tracking[self.lastTradeTarget] then
        -- Find all items tracked for the requester
        local foundItems = FindLastTradeTargetItems(self)
        -- Add up to 6 to the trade window
        local totalQueued = 0
        for _, itemLink in ipairs(self.tracking[self.lastTradeTarget]) do
            if foundItems[itemLink] and #foundItems[itemLink] > 0 then
                local loc = tremove(foundItems[itemLink])
                C_Timer.After(0.5*totalQueued, function()
                    UseContainerItem(loc.bag, loc.slot)
                end)
                totalQueued = totalQueued + 1
                if totalQueued == 6 then
                    break
                end
            end
        end
    end
end

local function HandleTradeAcceptUpdate(self)
    self.lastTradedItems = {}
    for tradeSlot = 1, 6 do
        local itemLink = GetTradePlayerItemLink(tradeSlot)
        if itemLink then
            tinsert(self.lastTradedItems, itemLink)
        end
    end
end

local function HandleTradeSuccess(self)
    for _, itemLink in ipairs(self.lastTradedItems) do
        self:Remove(itemLink, self.lastTradeTarget)
    end
end


local lootWindowIsOpen = false

---@class TradeHelper
---@field tracking table
---@field lastTradeTarget string?
---@field lastTradedItems table?
local TradeHelper = {}
function TradeHelper:Initialize()
    LOG:Trace("TradeHelper:Initialize()")
    self.tracking = {}
    Clear(self)

    BagItemChecker:Initialize()

    CLM.MODULES.EventManager:RegisterWoWEvent({"TRADE_SHOW"}, (function()
        Clear(self)
        -- NPC Because that's how the engine holds the trade peer
        self.lastTradeTarget = UTILS.GetUnitName("npc")
        if not self.lastTradeTarget then
            pcall(function()
                self.lastTradeTarget = UTILS.Disambiguate(_G.TradeFrameRecipientNameText:GetText())
            end)
        end
        if not self.lastTradeTarget then return end
        HandleTradeShow(self)
    end))
    CLM.MODULES.EventManager:RegisterWoWEvent({"TRADE_ACCEPT_UPDATE"}, (function()
        if not self.lastTradeTarget then return end
        HandleTradeAcceptUpdate(self)
    end))
    CLM.MODULES.EventManager:RegisterWoWEvent({"UI_INFO_MESSAGE"}, (function(_, _, _, message)
        if not self.lastTradeTarget then return end
        if message == ERR_TRADE_COMPLETE then
            HandleTradeSuccess(self)
        end
        self.lastTradeTarget = nil
    end))
    CLM.MODULES.EventManager:RegisterWoWEvent({"LOOT_OPENED"}, (function() lootWindowIsOpen = true end))
    CLM.MODULES.EventManager:RegisterWoWEvent({"LOOT_CLOSED"}, (function() lootWindowIsOpen = false end))
    CLM.MODULES.EventManager:RegisterEvent(CLM.CONSTANTS.EVENTS.GLOBAL_LOOT_REMOVED, function(_, data)
        TradeHelper:Remove(data.id, data.name)
    end)
end

-- Item IDs never tracked for trading (none yet on retail)
local tradeIgnores = UTILS.Set({})
---@param itemLink string
---@return boolean
function TradeHelper:IsIgnored(itemLink)
    return tradeIgnores[UTILS.GetItemIdFromLink(itemLink)]
end

---@param itemLink string|number
---@param player string
function TradeHelper:Track(itemLink, player)
    if self:IsIgnored(itemLink) then return end
    player = UTILS.Disambiguate(player)
    -- Lazy start tracking player
    if not self.tracking[player] then
        self.tracking[player] = {}
    end
    -- Update
    tinsert(self.tracking[player], itemLink)
    --
    CLM.GUI.TradeList:Refresh(true)
end

---@param itemLink string
---@param player string
function TradeHelper:Remove(itemLink, player)
    if self:IsIgnored(itemLink) then return end
    -- Sanity check: If we don't track player then return
    if not self.tracking[player] then
        return
    end
    -- Update
    for id, _itemLink in ipairs(self.tracking[player]) do
        if itemLink == _itemLink then
            tremove(self.tracking[player], id)
            break
        end
    end
    CLM.GUI.TradeList:Refresh(true)
end

---@return table
function TradeHelper:GetTracked()
    return self.tracking
end

-- Players that still have awarded items waiting for a trade, and how many items in total
---@return table players
---@return number items
function TradeHelper:GetPending()
    local players, items = {}, 0
    for player, trackedList in pairs(self.tracking) do
        if #trackedList > 0 then
            tinsert(players, Ambiguate(player, "none"))
            items = items + #trackedList
        end
    end
    table.sort(players)
    return players, items
end

---@param itemLink string
---@param target string
function TradeHelper:Handle(itemLink, target)
    -- Nothing to trade when the auctioneer wins the item themselves
    if UTILS.Disambiguate(target) == UTILS.whoami() then return end
    -- Raid feedback 4 (2026-10-18): ask the winner to open a trade
    UTILS.SendChatMessage(string.format(CLM.L["You won %s. Please open a trade with me to receive it."], tostring(itemLink)), "WHISPER", nil, target)
    if not self:IsIgnored(itemLink) then
        if CLM.MODULES.AuctionManager:GetAutoTrade() then
            self:Track(itemLink, target)
        end
    end
end

-- Is this item in our bags and can it still go to another player (not bound, or bound with
-- a trade timer)? Matches the exact link first, then any copy with the same item id.
---@param itemLink string
---@return boolean
function TradeHelper:IsTradeableInBags(itemLink)
    if #ScanBagsForItem(itemLink, true) > 0 then return true end
    local itemId = UTILS.GetItemIdFromLink(itemLink)
    if itemId == 0 then return false end
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            BagItemChecker:Set(bag, slot)
            if BagItemChecker:GetItemId() == itemId and BagItemChecker:IsTradeable() then
                return true
            end
        end
    end
    return false
end

---@param target string
function TradeHelper:InitiateTrade(target)
    if lootWindowIsOpen then return end
    if TradeFrame:IsShown() then return end
    InitiateTrade(Ambiguate(target, "none"))
end

CLM.MODULES.TradeHelper = TradeHelper
