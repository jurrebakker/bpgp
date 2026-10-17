-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

-- I'm absolutely horrified about using this one
local deformat = LibStub("LibDeformat-3.0")

local typeof = UTILS.typeof

local AuctionInfo = CLM.MODELS.AuctionInfo

local CHAT_MESSAGE_CHANNEL = "RAID_WARNING"

---@class AuctionManager
---@field db table
---@field currentAuction AuctionInfo
---@field pendingAuction AuctionInfo
---@field intervalTicker table
---@field auctionTickerEndTime number
---@field auctionTickerLastCountdownValue number
---@field auctionTimeLeft number
---@field auctionTickerCallbacks table
---@field bidInfoSender BidInfoSender
---@field handlers table
---@field unregisterRolls function?
local AuctionManager = {}

local function InitializeDB(self)
    self.db = CLM.MODULES.Database:Personal('auction', {
        autoTrade = true,
        fillFromCorpse = true,
        fillFromLoot = true,
        lootThreshold = 4,
        removeOnNoBids = false,
        postAllBidsOnAward = false,
        notes = {},
        ignoredClasses = {
            false, false, false, false,
            false, false, false, true,
            false, true,  false, false,
            false, true,  false, false,
            false, false, false, false
        },
        ignoredItems = UTILS.Set({
            22726, -- Splinter of Atiesh
            30183, -- Nether Vortex
            29434, -- Badge of Justice
            23572, -- Primal Nether
            40752, -- Emblem of Heroism
            40753, -- Emblem of Valor
            45038, -- Fragment of Val'anyr
        }),
    })
end

-- Settings (shown in the Settings tab, docs/features/ui-overhaul.md Part 2)

---@param value boolean
function AuctionManager:SetFillFromCorpse(value)
    self.db.fillFromCorpse = value and true or false
end

---@return boolean
function AuctionManager:GetFillFromCorpse()
    return self.db.fillFromCorpse
end

---@param value boolean
function AuctionManager:SetFillFromLoot(value)
    self.db.fillFromLoot = value and true or false
end

---@return boolean
function AuctionManager:GetFillFromLoot()
    return self.db.fillFromLoot
end

---@param value number item quality
function AuctionManager:SetFillRarity(value)
    self.db.lootThreshold = tonumber(value)
end

---@return number
function AuctionManager:GetFillRarity()
    return self.db.lootThreshold or 4
end

---@param value boolean
function AuctionManager:SetRemoveOnNoBids(value)
    self.db.removeOnNoBids = value and true or false
end

---@return boolean
function AuctionManager:GetRemoveOnNoBids()
    return self.db.removeOnNoBids
end

---@param value boolean
function AuctionManager:SetPostAllBidsOnAward(value)
    self.db.postAllBidsOnAward = value and true or false
end

---@return boolean
function AuctionManager:GetPostAllBidsOnAward()
    return self.db.postAllBidsOnAward
end

---@param value boolean
function AuctionManager:SetAutoTrade(value)
    self.db.autoTrade = value and true or false
end

---@return boolean
function AuctionManager:GetAutoTrade()
    return self.db.autoTrade
end

---@param classId number
---@param value boolean
function AuctionManager:SetIgnoredClass(classId, value)
    self.db.ignoredClasses[classId] = value and true or false
end

---@param classId number
---@return boolean
function AuctionManager:GetIgnoredClass(classId)
    return self.db.ignoredClasses[classId] and true or false
end

-- Fixed settings (F): remove on award, and passes/cancels in the bid list, are always on

---@return boolean
function AuctionManager:GetDefaultRemoveOnAward()
    return true
end

---@return boolean
function AuctionManager:GetIncludePasses()
    return true
end

---@return boolean
function AuctionManager:GetIncludeCancels()
    return true
end

-- Filling
local ItemClasses = {}
do
    local ignoredClasses = {
        [8] = true,
        [10] = true,
        [14] = true,
    }
    for _, id in pairs(Enum.ItemClass) do
        if not ignoredClasses[id] then
            ItemClasses[id] = C_Item.GetItemClassInfo(id)
        end
    end
end

-- Item classes that can be ignored when filling the auction list: { [classId] = name }
---@return table
function AuctionManager:GetItemClasses()
    return ItemClasses
end

local function DefaultCallback(_)
    AuctionManager:RefreshGUI()
end

local function PendingAuctionCallback(item)
    if item then
        LOG:Message("%s added to pending auction list.", item:GetItemLink())
    end
end

-- If using custom callback, function, then it is responsible for doing refresh
local function AddItemToAuctionList(self, item, callbackFn)
    callbackFn = callbackFn or DefaultCallback

    local auctionInfo = self.currentAuction
    if not auctionInfo:CanAddItems() then
        auctionInfo = self.pendingAuction
        callbackFn = PendingAuctionCallback
    end

    local auctionItem = auctionInfo:AddItem(item)
    if auctionItem then
        auctionItem:SetNote(self.db.notes[item:GetItemID()])
    end
    callbackFn(auctionItem)
end

local function AutoAddItemInternal(self, item)
    local _, _, _, _, _, _, _, _, _, _, _, classId = UTILS.GetItemInfo(item:GetItemID())
    if (item:GetItemQuality() >= self:GetFillRarity())
    and not (self.db.ignoredClasses[classId])
    and not (self.db.ignoredItems[item:GetItemID()]) then
        AddItemToAuctionList(self, item)
    end
end

local function AutoAddItemProxy(self, item)
    if not item:IsItemEmpty() then
        if item:IsItemDataCached() then
            AutoAddItemInternal(self, item)
        else
            item:ContinueOnItemLoad(function()
                AutoAddItemInternal(self, item)
            end)
        end
    end
end

local function HandleLootMessage(addon, event, message, _, _, _, playerName, ...)
    local self = AuctionManager
    if UTILS.IsSecret(message) or UTILS.IsSecret(playerName) then return end
    if playerName ~= UTILS.whoami() then return end
    if not message then return end
    if not CLM.MODULES.RaidManager:IsInActiveRaid() then return end
    if not self:IsAuctioneer() then return end
    if not self:GetFillFromLoot() then return end
    local itemLink = deformat(message, LOOT_ITEM_SELF_MULTIPLE)
    if not itemLink then
        itemLink = deformat(message, LOOT_ITEM_SELF)
    end
    if not itemLink then return end
    AutoAddItemProxy(self, Item:CreateFromItemLink(itemLink))
end

local function HookAuctionFilling(self)
    CLM.MODULES.Hooks:RegisterModifiedItemLinkClickHandler(function(modifiers, itemLink)
        if CLM.GlobalConfigs:GetModifierCombination() ~= modifiers then return end
        if not CLM.MODULES.RaidManager:IsInRaid() then return end

        if not itemLink then return end
        self:AddItemByLink(itemLink)
        CLM.GUI.AuctionManager:Show()
    end)
end

local alreadyAddedLoot = {}
local function FillLootFromCorpse()
    if not CLM.MODULES.RaidManager:IsInActiveRaid() then return end
    if not AuctionManager:IsAuctioneer() then return end
    if not AuctionManager:GetFillFromCorpse() then return end

    local targetGuid = UnitGUID("target")
    if UTILS.IsSecret(targetGuid) then targetGuid = nil end
    if targetGuid then
        if alreadyAddedLoot[targetGuid] then return end
        alreadyAddedLoot[targetGuid] = true
    end

    local numLootItems = GetNumLootItems()
    for lootIndex = 1, numLootItems do
        local itemLink = GetLootSlotLink(lootIndex)
        if itemLink then
            AutoAddItemProxy(AuctionManager, Item:CreateFromItemLink(itemLink))
        end
    end
end

local function HandleLootOpenedEvent()
    FillLootFromCorpse()
end

-- Comms


-- COMMS

local function SendAuctionStart(self)
    local message = CLM.MODELS.AuctionCommStructure:New(
        CONSTANTS.AUCTION_COMM.TYPE.START_AUCTION,
        CLM.MODELS.AuctionCommStartAuction:NewFromAuctionInfo(self.currentAuction)
    )
    CLM.MODULES.Comms:Send(CLM.COMM_CHANNEL.AUCTION, message, CONSTANTS.COMMS.DISTRIBUTION.RAID)
end

local function SendAuctionEnd()
    local message = CLM.MODELS.AuctionCommStructure:New(CONSTANTS.AUCTION_COMM.TYPE.STOP_AUCTION, {})
    CLM.MODULES.Comms:Send(CLM.COMM_CHANNEL.AUCTION, message, CONSTANTS.COMMS.DISTRIBUTION.RAID)
end

local function SendAntiSnipe()
    local message = CLM.MODELS.AuctionCommStructure:New(CONSTANTS.AUCTION_COMM.TYPE.ANTISNIPE, {})
    CLM.MODULES.Comms:Send(CLM.COMM_CHANNEL.AUCTION, message, CONSTANTS.COMMS.DISTRIBUTION.RAID)
end

local function SendBidAccepted(UID, name)
    local message = CLM.MODELS.AuctionCommStructure:New(
        CONSTANTS.AUCTION_COMM.TYPE.ACCEPT_BID, UID)
    CLM.MODULES.Comms:Send(CLM.COMM_CHANNEL.AUCTION, message, CONSTANTS.COMMS.DISTRIBUTION.WHISPER, name, CONSTANTS.COMMS.PRIORITY.ALERT)
end

local function SendBidDenied(UID, name, reason)
    local message = CLM.MODELS.AuctionCommStructure:New(
        CONSTANTS.AUCTION_COMM.TYPE.DENY_BID,
        CLM.MODELS.AuctionCommDenyBid:New(UID, reason)
    )
    CLM.MODULES.Comms:Send(CLM.COMM_CHANNEL.AUCTION, message, CONSTANTS.COMMS.DISTRIBUTION.WHISPER, name, CONSTANTS.COMMS.PRIORITY.ALERT)
end

local currentAnnounceChannel = 0
local function SendBidInfoInternal(auctionDistributeBidData)
    local message = CLM.MODELS.AuctionCommStructure:New(
        CONSTANTS.AUCTION_COMM.TYPE.DISTRIBUTE_BID, auctionDistributeBidData
    )
    CLM.MODULES.Comms:Send(CLM.COMM_CHANNEL.BIDANNOUNCE .. tostring(currentAnnounceChannel), message, CONSTANTS.COMMS.DISTRIBUTION.RAID, nil, CONSTANTS.COMMS.PRIORITY.NORMAL)
    currentAnnounceChannel = currentAnnounceChannel + 1
    if currentAnnounceChannel == CLM.CONSTANTS.AUCTION_COMM.NUM_ANNOUNCE_CHANNELS - 1 then
        currentAnnounceChannel = 0
    end
end

local function SendBidInfo(self, UID, name, userResponse)
    self.bidInfoSender:Send(UID, name, userResponse)
end

-- Private

local function UpdateAuctionInfo(self, raid)
    for _, auction in ipairs({"currentAuction", "pendingAuction"}) do
        self[auction]:UpdateRaid(raid)
    end
end

local function SetRaidConnection(self)
    if CLM.MODULES.RaidManager:IsInRaid() then
        UpdateAuctionInfo(self, CLM.MODULES.RaidManager:GetRaid())
    end
end



function AuctionManager:Initialize()
    LOG:Trace("AuctionManager:Initialize()")

    InitializeDB(self)

    CLM.MODULES.Comms:Register(CLM.COMM_CHANNEL.BIDDING, (function(rawMessage, distribution, sender)
        local message = CLM.MODELS.BiddingCommStructure:New(rawMessage)
        if CONSTANTS.BIDDING_COMM.TYPES[message:Type()] == nil then return end
        self:HandleIncomingMessage(message, distribution, sender)
    end), CONSTANTS.ACL.LEVEL.PLEBS, true)

    if not CLM.MODULES.ACL:IsTrusted() then return end

    self.handlers = {
        [CONSTANTS.BIDDING_COMM.TYPE.SUBMIT_BID]        = "HandleSubmitBid",
        [CONSTANTS.BIDDING_COMM.TYPE.NOTIFY_CANTUSE]    = "HandleNotifyCantUse",
    }

    self.currentAuction = AuctionInfo:New()
    self.pendingAuction = AuctionInfo:New()

    HookAuctionFilling(self)
    CLM.MODULES.EventManager:RegisterWoWEvent({"LOOT_OPENED"}, HandleLootOpenedEvent)
    CLM.MODULES.EventManager:RegisterWoWEvent({"CHAT_MSG_LOOT"}, HandleLootMessage)

    CLM.MODULES.LedgerManager:RegisterOnUpdate(function(lag, uncommitted)
        if lag ~= 0 or uncommitted ~= 0 then return end
        SetRaidConnection(self)
        self:RefreshGUI()
    end)
end

-- LOCAL AUCTION MANAGEMENT

local function AddItemProxy(self, item, callbackFn)
    if not item:IsItemEmpty() then
        if item:IsItemDataCached() then
        AddItemToAuctionList(self, item, callbackFn)
        else
            item:ContinueOnItemLoad(function() AddItemToAuctionList(self, item, callbackFn) end)
        end
    end
end

---@param itemId number
---@param callbackFn function?
function AuctionManager:AddItemById(itemId, callbackFn)
    if not CLM.MODULES.RaidManager:IsInRaid() then
        LOG:Message(CLM.L["Auctioning requires active raid or roster mode."])
        return
    end
    AddItemProxy(self, Item:CreateFromItemID(itemId), callbackFn)
end

---@param itemLink string
---@param callbackFn function?
function AuctionManager:AddItemByLink(itemLink, callbackFn)
    if not CLM.MODULES.RaidManager:IsInRaid() then
        LOG:Message(CLM.L["Auctioning requires active raid or roster mode."])
        return
    end
    AddItemProxy(self, Item:CreateFromItemLink(itemLink), callbackFn)
end

---@param item AuctionItem
function AuctionManager:MoveItemToPendingList(item)
    if self.currentAuction:IsInProgress() then
        LOG:Warning(CLM.L["Removing items not allowed during auction."])
        return
    end
    self.pendingAuction:AddExistingAuctionItem(item)
    self:RemoveItemFromCurrentAuction(item)
end

local function EndAuction(self)
    local auction = self.currentAuction
    auction:End()
    SendAuctionEnd()
    for _, item in pairs(auction:GetItems()) do
        CLM.MODULES.AuctionHistoryManager:AddAuctionItem(item)
        if self:GetRemoveOnNoBids() then
            if not item:HasValidBids() then
                self:RemoveItemFromCurrentAuction(item)
            end
        end
    end
end

function AuctionManager:StopAuctionManual()
    LOG:Trace("AuctionManager:StopAuctionManual()")
    self.intervalTicker:Cancel()
    if CLM.GlobalConfigs:GetAuctionWarning() then
        UTILS.SendChatMessage(CLM.L["Auction stopped by the Master Looter"], CHAT_MESSAGE_CHANNEL)
    end
    EndAuction(self)
end

local function StopAuctionTimed(self)
    LOG:Trace("AuctionManager:StopAuctionTimed()")
    self.intervalTicker:Cancel()
    if CLM.GlobalConfigs:GetAuctionWarning() then
        UTILS.SendChatMessage(CLM.L["Auction complete"], CHAT_MESSAGE_CHANNEL)
    end
    EndAuction(self)
    self:RefreshGUI()
end

local TICKER_INTERVAL = 0.1

local defaultHandlersTypes = {"init", "ticker", "final"}
local function GenerateIntervalHandlerCallbacks(input)
    local o = input or {}
    for _, handler in ipairs(defaultHandlersTypes) do
        if not o[handler] then o[handler] = (function() end) end
    end
    return o
end

local function NewIntervalHandlers(self, countdown, endTimeValue, callbacks)
    --[[ Prepare ]]
    callbacks.init()
    self.auctionTickerLastCountdownValue = countdown
    self.auctionTickerEndTime = endTimeValue
    --[[ Create Timer ]]
    self.intervalTicker = C_Timer.NewTicker(TICKER_INTERVAL, (function()
        --[[ Tick ]]
        self.auctionTimeLeft = self.auctionTickerEndTime - GetServerTime()
        callbacks.ticker(TICKER_INTERVAL)
        if self.auctionTickerLastCountdownValue > 0 and self.auctionTimeLeft <= self.auctionTickerLastCountdownValue then
            UTILS.SendChatMessage(tostring(math.ceil(self.auctionTimeLeft)), CHAT_MESSAGE_CHANNEL)
            self.auctionTickerLastCountdownValue = self.auctionTickerLastCountdownValue - 1
        end
        --[[ Final ]]
        if self.auctionTimeLeft < 0.1 then
            callbacks.final()
            return
        end
    end))
end

---@param item AuctionItem
function AuctionManager:RemoveItemFromCurrentAuction(item)
    if self.currentAuction:IsInProgress() then
        LOG:Warning(CLM.L["Removing items not allowed during auction."])
        return
    end
    self.currentAuction:RemoveItem(item)
    if self.currentAuction:IsEmpty() then
        self:ClearItemList()
    end
end

function AuctionManager:ClearItemList()
    self.pendingAuction:CopySettings(self.currentAuction)
    self.currentAuction = self.pendingAuction
    self.pendingAuction = AuctionInfo:New()
    CLM.GUI.AuctionManager:SetVisibleAuctionItem(nil)
    self:RefreshGUI()
end

local SENDING_INTERVAL = 1
function AuctionManager:StartAuction()
    LOG:Trace("AuctionManager:StartAuction()")
    local auction = self.currentAuction
    if auction:IsInProgress() then
        LOG:Warning("AuctionManager:StartAuction(): Auction in progress")
        return
    end
    if auction:IsAcceptingRolls() then
        LOG:Warning("AuctionManager:StartAuction(): Accepting rolls currently")
        return
    end
    if not self:IsAuctioneer() then
        LOG:Message(CLM.L["You are not allowed to auction items"])
        return
    end
    -- Auction parameters sanity checks
    if not typeof(auction.raid, CLM.MODELS.Raid) then
        LOG:Warning("AuctionManager:StartAuction(): Invalid raid object")
        return false
    end
    if not CLM.MODULES.RaidManager:IsInProgressingRaid() then
        LOG:Warning("AuctionManager:StartAuction(): Raid not in Progress")
        return false
    end
    if auction:IsEmpty() then
        LOG:Warning("AuctionManager:StartAuction(): Empty auction item list")
        return false
    end
    -- Auction Settings sanity checks
    if auction:GetTime() <= 0 then
        LOG:Warning("AuctionManager:StartAuction(): 0s auction time")
        return false
    end
    if auction:GetTime() < 10 then
        LOG:Warning("AuctionManager:StartAuction(): Very short (below 10s) auction time")
    end
    if CLM.GlobalConfigs:GetAuctionWarning() then
        local numItems = auction:GetItemCount()
        local _, auctionItem = next(auction:GetItems())
        local auctionMessage
        if numItems > 1 then
            auctionMessage = string.format(CLM.L["Auction of %s items."], numItems)
        else
            auctionMessage = string.format(CLM.L["Auction of %s"], auctionItem:GetItemLink())
        end
        UTILS.SendChatMessage(auctionMessage , CHAT_MESSAGE_CHANNEL)
        auctionMessage = ""
        auctionMessage = auctionMessage .. string.format(CLM.L["Auction time: %s."] .. " ", auction:GetTime())
        if auction:GetAntiSnipe() > 0 then
            auctionMessage = auctionMessage .. string.format(CLM.L["Anti-snipe time: %s."], auction:GetAntiSnipe())
        end
        UTILS.SendChatMessage(auctionMessage , CHAT_MESSAGE_CHANNEL)
    end

    -- Store the auctioned values as item overrides
    for id, auctionItem in pairs(auction:GetItems()) do
        CLM.MODULES.RosterManager:SetRosterItemValues(auction.roster, id, auctionItem:GetValues())
    end

    auction:Start()

    SendAuctionStart(self)

    if not self.auctionTickerCallbacks then
        self.auctionTickerCallbacks = GenerateIntervalHandlerCallbacks({
            init = (function()
                self.bidInfoSender = CLM.MODELS.BidInfoSender:New(SENDING_INTERVAL, SendBidInfoInternal)
            end),
            ticker = (function(interval)
                self.bidInfoSender:Tick(interval)
            end),
            final = (function()
                self.bidInfoSender:Flush()
                StopAuctionTimed(self)
            end)
        })
    end

    NewIntervalHandlers(self,
        CLM.GlobalConfigs:GetCountdownWarning() and 5 or 0,
        auction:GetEndTime(), self.auctionTickerCallbacks
    )
end

local function handleIncomingRoll(_, _, message, ...)
    if UTILS.IsSecret(message) then return end
    local auction = CLM.MODULES.AuctionManager:GetCurrentAuctionInfo()
    if not auction:IsAcceptingRolls() then return end

    local who, roll, min, max = string.match(message, "^(.+)%s.*%s.-(%d+).-(%d+)-(%d+)")
    roll, min, max = tonumber(roll), tonumber(min), tonumber(max)

    if not who then
        LOG:Debug("Missing <who>")
        return
    end
    if not roll then
        LOG:Debug("Missing <roll [%s]>", roll)
        return
    end
    if (min ~= 1) or (max ~= 100) then
        LOG:Debug("Missing <min [%s], max [%s]>", min, max)
        return
    end

    if roll < min or roll > max then
        LOG:Debug("Roll not between <min, max>")
        return
    end

    local rollerProfile = CLM.MODULES.ProfileManager:GetProfileByName(UTILS.Disambiguate(who))
    if not rollerProfile then
        LOG:Debug("No profile for %s", who)
        return
    end

    auction:HandleRoll(rollerProfile:Name(), roll)

    AuctionManager:RefreshGUI()
end

function AuctionManager:StartRoll(auctionItem)
    LOG:Trace("AuctionManager:StartRoll()")
    local auction = self.currentAuction
    if auction:IsInProgress() then
        LOG:Warning("AuctionManager:StartRoll(): Auction in progress")
        return
    end
    if auction:IsAcceptingRolls() then
        LOG:Warning("AuctionManager:StartRoll(): Accepting rolls currently")
        return
    end
    if not self:IsAuctioneer() then
        LOG:Message(CLM.L["You are not allowed to auction items"])
        return
    end
    -- Auction parameters sanity checks
    if not typeof(auction.raid, CLM.MODELS.Raid) then
        LOG:Warning("AuctionManager:StartRoll(): Invalid raid object")
        return false
    end
    if not auction:IsItemInAuction(auctionItem) then
        LOG:Error("AuctionManager:StartRoll(): Item not in auction list")
        return false
    end
    local rollTime = auction:GetRollTime()
    local message = string.format(CLM.L["Accepting rolls on %s for %s %s"], auctionItem:GetItemLink(), rollTime, CLM.L["seconds"])
    UTILS.SendChatMessage(message, CHAT_MESSAGE_CHANNEL)

    auction:Roll(auctionItem)

    self.unregisterRolls =  CLM.MODULES.EventManager:RegisterWoWEvent({"CHAT_MSG_SYSTEM"}, handleIncomingRoll)
    NewIntervalHandlers(self,
        CLM.GlobalConfigs:GetCountdownWarning() and 5 or 0,
        GetServerTime() + rollTime,
        GenerateIntervalHandlerCallbacks({
            final = (function()
                self:StopRoll()
                self:RefreshGUI()
            end),
        })
    )

    self:RefreshGUI()
end

function AuctionManager:StopRoll()
    local auction = self.currentAuction
    if not auction:IsAcceptingRolls() then
        LOG:Warning("AuctionManager:StopRoll(): Not accepting rolls currently")
        return
    end

    self.intervalTicker:Cancel()
    self.unregisterRolls()
    self.unregisterRolls = nil

    auction:EndRoll()

    UTILS.SendChatMessage(CLM.L["Rolling complete"], CHAT_MESSAGE_CHANNEL)
end

local function AntiSnipe(self, auction)
    LOG:Trace("AuctionManager:AntiSnipe()")
    local antiSnipe = auction:GetAntiSnipe()
    if auction:IsAntiSnipeAvailable() then
        if self.auctionTimeLeft < antiSnipe then
            auction:AntiSnipe()
            self.auctionTimeLeft = self.auctionTimeLeft + antiSnipe
            self.auctionTickerEndTime = self.auctionTickerEndTime + antiSnipe
            SendAntiSnipe()
            -- Cheeky update the warning countdown, but only if above 3/5s
            if antiSnipe >= 5 then
                self.auctionTickerLastCountdownValue = 5
            elseif antiSnipe >= 3 then
                self.auctionTickerLastCountdownValue = 3
            end
        end
    end
end

---@param message table
---@param distribution string
---@param sender string
function AuctionManager:HandleIncomingMessage(message, distribution, sender)
    LOG:Trace("AuctionManager:HandleIncomingMessage()")
    local mtype = message:Type() or 0
    if self.handlers and self.handlers[mtype] then -- handlers exist only for officers
        self[self.handlers[mtype]](self, message:Data(), sender)
    end
end

---@param data table
---@param sender string
function AuctionManager:HandleSubmitBid(data, sender)
    LOG:Trace("AuctionManager:HandleSubmitBid()")
    if not self:IsAuctionInProgress() then
        LOG:Debug("Received submit bid from %s while no auctions are in progress", sender)
        return
    end
    local response = CLM.MODELS.UserResponse:New(data:Value(), data:Type(), data:Items())
    self:UpdateBid(sender, data:AuctionUID(), response)
end

---@param data table
---@param sender string
function AuctionManager:HandleNotifyCantUse(data, sender)
    LOG:Trace("AuctionManager:HandleNotifyCantUse()")
    if not self:IsAuctionInProgress() then
        LOG:Debug("Received can't use from %s while no auctions are in progress", sender)
        return
    end
    -- self.userResponses.cantUse[sender] = true
end

-- BIDS

local function ValidateBid(auction, uid, item, name, userResponse)
    if not item then
        LOG:Warning("Received bid for not auctioned item from [%s]", name)
        return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.INVALID_ITEM
    end
    local roster = auction:GetRoster()
    -- cancel and pass are always allowed
    if userResponse:Type() == CONSTANTS.BID_TYPE.CANCEL or userResponse:Type() == CONSTANTS.BID_TYPE.PASS then
        return true
    end
    if (not auction:GetUseOS()) and (userResponse:Type() == CONSTANTS.BID_TYPE.OFF_SPEC) then
        return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.OFF_SPEC_NOT_ALLOWED
    end
    local value = userResponse:Value()
    -- sanity check
    local profile = CLM.MODULES.ProfileManager:GetProfileByName(name)
    if not profile then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.NOT_IN_ROSTER end
    local GUID = profile:GUID()
    if not roster:IsProfileInRoster(GUID) then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.NOT_IN_ROSTER end
    -- allow negative bidders
    local current = roster:Standings(GUID)
    local minimumPoints = auction:GetMinimumPoints()
    if current < minimumPoints then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.BELOW_MIN_BIDDER end
    -- tiered: the bid must be one of the item's tier values
    if not item:IsValueAccepted(value) then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.BID_VALUE_INVALID end
    -- accept otherwise
    return true
end

local function ValidateBidLimited(auction, item, name, userResponse)
    if not item then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.INVALID_ITEM end
    local roster = auction:GetRoster()
    -- bid cancelling
    if userResponse:Type() == CONSTANTS.BID_TYPE.CANCEL then
        return true
    end
    -- bid passing
    if userResponse:Type() == CONSTANTS.BID_TYPE.PASS then
        return true
    end
    if (not auction:GetUseOS()) and (userResponse:Type() == CONSTANTS.BID_TYPE.OFF_SPEC) then
        return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.OFF_SPEC_NOT_ALLOWED
    end
    -- sanity check
    local profile = CLM.MODULES.ProfileManager:GetProfileByName(name)
    if not profile then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.NOT_IN_ROSTER end
    local GUID = profile:GUID()
    if not roster:IsProfileInRoster(GUID) then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.NOT_IN_ROSTER end
    -- allow negative bidders
    local current = roster:Standings(GUID)
    local minimumPoints = auction:GetMinimumPoints()
    if current < minimumPoints then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.BELOW_MIN_BIDDER end
    -- accept otherwise
    return true
end

-- Open auction: every bid is shared with the raid
local function AnnounceBid(auction, uid, name, userResponse)
    if not auction:GetItemByUID(uid) then return end
    SendBidInfo(AuctionManager, uid, name, userResponse)
end

---@param name string
---@param uid any
---@param userResponse UserResponse
---@return boolean, number?
function AuctionManager:UpdateBid(name, uid, userResponse)
    LOG:Trace("AuctionManager:UpdateBid()")
    if not self:IsAuctionInProgress() then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.NO_AUCTION_IN_PROGRESS end
    local auction = self.currentAuction
    local item = auction:GetItemByUID(uid)

    local accept, reason = ValidateBid(auction, uid, item, name, userResponse)
    if accept then
        item:SetResponse(name, userResponse)
        AnnounceBid(auction, uid, name, userResponse)
        if not CONSTANTS.BID_TYPE_HIDDEN[userResponse:Type()] then
            AntiSnipe(self, auction)
            SendBidAccepted(uid, name)
        end
    else
        SendBidDenied(uid, name, reason)
    end

    -- TODO update Bids only
    self:RefreshGUI()

    return accept, reason
end

function AuctionManager:UpgradedItems()
    return self.userResponses.upgradedItems
end

local function RevalidateBids(self)
    for _, item in pairs(self.currentAuction:GetItems()) do
        for name, userResponse in pairs(item:GetAllResponses()) do
            local valid, reason = ValidateBidLimited(self.currentAuction, item, name, userResponse)
            if not valid then userResponse:MarkInvalid(reason) end
        end
    end
end

---@param item AuctionItem
---@param name string
---@param price number
function AuctionManager:Award(item, name, price)
    LOG:Trace("AuctionManager:Award()")
    local success, uuid = CLM.MODULES.LootManager:AwardItem(self.currentAuction:GetRaid(), name, item:GetItemLink(), item:GetItemID(), item:GetExtraPayload(), price, true)
    if success then
        CLM.MODULES.AuctionHistoryManager:CorrelateWithLoot(item:GetItemLink(), self.currentAuction:GetEndTime(), uuid)
        if self:GetPostAllBidsOnAward() then
            CLM.MODULES.AuctionHistoryManager:PostByUUID(uuid)
        end
        CLM.MODULES.TradeHelper:Handle(item:GetItemLink(), name)
        RevalidateBids(self)
    end
end

---@param name string?
---@return boolean
function AuctionManager:IsAuctioneer(name)
    LOG:Trace("AuctionManager:IsAuctioneer()")
    name = name or UTILS.whoami()
    return CLM.MODULES.RaidManager:IsAllowedToAuction(name)
end

-- NEW

---@return boolean
function AuctionManager:IsAuctionInProgress()
    return self.currentAuction:IsInProgress()
end

---@return boolean
function AuctionManager:IsAcceptingRolls()
    return self.currentAuction:IsAcceptingRolls()
end

---@return AuctionInfo
function AuctionManager:GetCurrentAuctionInfo()
    return self.currentAuction
end

-- Seconds left in the running auction or /roll phase (0 when nothing runs)
---@return number
function AuctionManager:GetTimeLeft()
    if not (self:IsAuctionInProgress() or self:IsAcceptingRolls()) or not self.auctionTickerEndTime then return 0 end
    return math.max(0, self.auctionTickerEndTime - GetServerTime())
end

-- Sort weight of a bid type: tiers (Max first) above MS, OS, Pass, Cancel
---@param bidType any
---@return number
function AuctionManager:GetBidTypeOrder(bidType)
    if CONSTANTS.SLOT_VALUE_TIERS[bidType] then return CONSTANTS.BID_TYPE_ORDER_DSC[bidType] end
    for name, value in pairs(CONSTANTS.BID_TYPE) do
        if value == bidType and CONSTANTS.BID_TYPE_ORDER_DSC[name] then return CONSTANTS.BID_TYPE_ORDER_DSC[name] end
    end
    return 0
end

--[[
    The winner the auctioning window preselects when an auction ends (ui-redesign.md R10):
    the highest tier, then the highest PR, then the highest roll. Passes, cancels and invalid
    bids never win. `exclude` holds names already awarded this item (items with a count > 1).
]]--
---@param item AuctionItem
---@param exclude table? { [name] = true }
---@return string? name, UserResponse? response
function AuctionManager:GetWinner(item, exclude)
    local roster = self.currentAuction:GetRoster()
    local best, bestName, bestKey
    for name, response in pairs(item:GetAllResponses()) do
        if not CONSTANTS.BID_TYPE_HIDDEN[response:Type()] and not response:IsInvalid() and not (exclude and exclude[name]) then
            local profile = CLM.MODULES.ProfileManager:GetProfileByName(name)
            local pr = (profile and roster) and roster:Priority(profile:GUID()) or 0
            local key = { self:GetBidTypeOrder(response:Type()), pr, response:Roll() or 0 }
            local better = not bestKey
            if bestKey then
                for i = 1, 3 do
                    if key[i] ~= bestKey[i] then better = key[i] > bestKey[i] break end
                end
            end
            if better then best, bestName, bestKey = response, name, key end
        end
    end
    return bestName, best
end

---@param time number
function AuctionManager:SetAuctionTime(time)
    time = tonumber(time) or 0
    if time <= 0 then
        LOG:Warning("Trying to set 0s auction time.")
        return
    end
    self.currentAuction:SetTime(time)
end

---@return number
function AuctionManager:GetAuctionTime()
    return self.currentAuction:GetTime()
end

---@param time number
function AuctionManager:SetAntiSnipe(time)
    time = tonumber(time) or 0
    if time < 0 then
        LOG:Warning("Trying to set negative anti-snipe time.")
        return
    end
    self.currentAuction:SetAntiSnipe(time)
end

---@return number
function AuctionManager:GetAntiSnipe()
    return self.currentAuction:GetAntiSnipe()
end

---@param auctionItem AuctionItem
---@param note string?
function AuctionManager:SetItemNote(auctionItem, note)
    local itemId = auctionItem:GetItemID()
    if note and note:len() > 0 then
        self.db.notes[itemId] = note
    else
        self.db.notes[itemId] = nil
    end
    auctionItem:SetNote(note)
end

function AuctionManager:RefreshGUI()
    CLM.GUI.AuctionManager:Refresh(true)
end

CONSTANTS.AUCTION_COMM = {
    CURRENT_VERSION = 4,
    BID_PASS  = CLM.L["PASS"],
    NUM_ANNOUNCE_CHANNELS = 2,
    TYPE = {
        START_AUCTION = 1,
        STOP_AUCTION = 2,
        ANTISNIPE = 3,
        ACCEPT_BID = 4,
        DENY_BID = 5,
        DISTRIBUTE_BID = 6
    },
    TYPES = UTILS.Set({
        1, -- START AUCTION
        2, -- STOP ACUTION
        3, -- ANTISNIPE
        4, -- ACCEPT BID
        5, -- DENY BID
        6, -- DISTRIBUTE BID
    }),
    DENY_BID_REASON = {
        NOT_IN_ROSTER = 1,
        BELOW_MIN_BIDDER = 2,
        NEGATIVE_STANDING_AFTER = 3,
        BID_VALUE_TOO_LOW = 4,
        BID_VALUE_TOO_HIGH = 5,
        BID_VALUE_INVALID = 6,
        BID_INCREMENT_TOO_LOW = 7,
        NO_AUCTION_IN_PROGRESS = 8,
        CANCELLING_NOT_ALLOWED = 9,
        PASSING_NOT_ALLOWED = 10,
        OFF_SPEC_NOT_ALLOWED = 11,
        INVALID_ITEM = 12,
        SPEC_CHANGE = 13,
    },
    DENY_BID_REASONS = UTILS.Set({
        1, -- NOT_IN_ROSTER
        2, -- BELOW_MIN_BIDDER
        3, -- NEGATIVE_STANDING_AFTER
        4, -- BID_VALUE_TOO_LOW
        5, -- BID_VALUE_TOO_HIGH
        6, -- BID_VALUE_INVALID
        7, -- BID_INCREMENT_TOO_LOW
        8, -- NO_AUCTION_IN_PROGRESS
        9, -- CANCELLING_NOT_ALLOWED
        10,-- PASSING_NOT_ALLOWED
        11,-- OFF_SPEC_NOT_ALLOWED
        12,-- INVALID_ITEM
        13,-- SPEC_CHANGE
    }),
    DENY_BID_REASONS_STRING = {
        [1] = CLM.L["Not in a roster"],
        [2] = CLM.L["Bidding while below minimum standings not allowed"],
        [3] = CLM.L["Bidding over current standings not allowed"],
        [4] = CLM.L["Bid too low"],
        [5] = CLM.L["Bid too high"],
        [6] = CLM.L["Invalid bid value"],
        [7] = CLM.L["Bid increment too low"],
        [8] = CLM.L["No auction in progress"],
        [9] = CLM.L["Bid cancelling not allowed"],
        [10] = CLM.L["Passing after bidding not allowed"],
        [11] = CLM.L["Off-spec bidding not allowed"],
        [12] = CLM.L["Invalid item"],
        [13] = CLM.L["Changing bid from Main-spec to Off-Spec not allowed"]
    }
}

CLM.MODULES.AuctionManager = AuctionManager
