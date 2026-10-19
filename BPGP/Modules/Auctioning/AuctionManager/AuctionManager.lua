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
        removeOnNoBids = false,
        postAllBidsOnAward = false,
        lootDebug = false,
        lootDebugLog = {},
        notes = {},
    })
end

--[[
    Filling the auction list is fixed (raid feedback 2026-10-19): the auctioneer always fills
    from corpses and from their own loot, with Epic or better weapons, armor and miscellaneous
    items (tier tokens, mounts). Everything else, like crafting sparks, is left out.
]]--
local FILL_MIN_QUALITY = Enum.ItemQuality.Epic
local FILL_CLASSES = CLM.CONSTANTS.AUCTION_ITEM_CLASSES

-- Settings (shown in the Settings tab, docs/features/ui-overhaul.md Part 2)

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

--[[
    Loot debug (/bpgp lootdebug): every decision the list filling makes (corpse, chat, Loot Rolls
    history, the "Add from loot rolls" button) is printed to chat and kept in lootDebugLog, which
    is saved with BPGP_DB so it can be read from the SavedVariables file after the raid.
    Raid feedback 2026-10-18: 5 drops, 4 in the list.
]]--
local LOOT_DEBUG_MAX_LINES = 2000

local function LootTrace(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = fmt .. " (format error)" end
    LOG:Debug("[loot] %s", line)
    local db = AuctionManager.db
    if not (db and db.lootDebug) then return end
    LOG:Message("|cff88ccff[loot]|r %s", line)
    local log = db.lootDebugLog
    tinsert(log, date("%Y-%m-%d %H:%M:%S") .. " " .. line)
    while #log > LOOT_DEBUG_MAX_LINES do
        tremove(log, 1)
    end
end

-- Safe text for a value that may be nil or secret
local function Show(value)
    if UTILS.IsSecret(value) then return "<secret>" end
    return tostring(value)
end

-- "4 (Epic)"
local function ShowQuality(quality)
    if quality == nil then return "nil" end
    return string.format("%s (%s)", tostring(quality), tostring(_G["ITEM_QUALITY" .. tostring(quality) .. "_DESC"] or "?"))
end

-- "15 (Miscellaneous)"
local function ShowClass(classId)
    if classId == nil then return "nil" end
    local ok, name = pcall(C_Item.GetItemClassInfo, classId)
    return string.format("%s (%s)", tostring(classId), tostring(ok and name or "?"))
end

-- The filters every auto-added item goes through
local function LogFilterSettings(self)
    LootTrace("filter: quality %s or better", ShowQuality(FILL_MIN_QUALITY))
    local classes = {}
    for classId in pairs(FILL_CLASSES) do
        tinsert(classes, ShowClass(classId))
    end
    table.sort(classes)
    LootTrace("filter: only item classes %s", table.concat(classes, ", "))
    LootTrace("filter: auctioneer %s, active raid %s",
        Show(self:IsAuctioneer()), Show(CLM.MODULES.RaidManager:IsInActiveRaid()))
end

---@param value boolean
function AuctionManager:SetLootDebug(value)
    self.db.lootDebug = value and true or false
    LOG:Message(CLM.L["Loot debug is %s."], self.db.lootDebug and CLM.L["on"] or CLM.L["off"])
    if self.db.lootDebug then LogFilterSettings(self) end
end

---@return boolean
function AuctionManager:GetLootDebug()
    return self.db.lootDebug
end

function AuctionManager:ClearLootDebugLog()
    wipe(self.db.lootDebugLog)
    LOG:Message(CLM.L["Loot debug log cleared."])
end

-- Filling

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
    LootTrace("%s -> %s list, row total now %s", Show(item:GetItemLink()),
        auctionInfo == self.pendingAuction and "PENDING" or "auction",
        auctionItem and Show(auctionItem:GetTotal()) or "nil (not added)")
    callbackFn(auctionItem)
end

--[[
    The same drop can be seen by several sources: the boss corpse, our own "You receive loot" chat
    line and the Loot Rolls history. Each source counts the copies of an item id it added; a source
    only adds a copy when it is ahead of every other source, so each drop lands in the list once
    whichever source sees it first, and a source that misses a drop doesn't stop the others.
    Counts start over on every boss pull.
]]--
local LOOT_SOURCE = { CORPSE = "corpse", CHAT = "chat", HISTORY = "history" }
local lootSourceCounts = {}

local function ResetLootSourceCounts()
    lootSourceCounts = {}
    for _, source in pairs(LOOT_SOURCE) do
        lootSourceCounts[source] = {}
    end
end
ResetLootSourceCounts()

-- Counts one copy of itemId for source; true when it's a new drop that should be added
local function CreditLootSource(source, itemId)
    local counts = lootSourceCounts[source]
    counts[itemId] = (counts[itemId] or 0) + 1
    for other, otherCounts in pairs(lootSourceCounts) do
        if other ~= source and (otherCounts[itemId] or 0) >= counts[itemId] then
            return false
        end
    end
    return true
end

local function AutoAddItemInternal(self, item, source)
    local _, _, _, _, _, _, subType, _, _, _, _, classId, subclassId, bindType = UTILS.GetItemInfo(item:GetItemID())
    local itemLink, quality = Show(item:GetItemLink()), item:GetItemQuality()
    local sourceName = tostring(source or "button")
    LootTrace("%s (%s): quality %s, class %s, subclass %s (%s), bind %s", itemLink, sourceName, ShowQuality(quality),
        ShowClass(classId), Show(subclassId), Show(subType), Show(bindType))
    if not (quality and quality >= FILL_MIN_QUALITY) then
        LootTrace("%s (%s): SKIPPED by the quality filter, %s is below %s", itemLink, sourceName, ShowQuality(quality), ShowQuality(FILL_MIN_QUALITY))
        return
    end
    if not FILL_CLASSES[classId] then
        LootTrace("%s (%s): SKIPPED by the class filter, %s is not a weapon, armor or miscellaneous item", itemLink, sourceName, ShowClass(classId))
        return
    end
    if source and not CreditLootSource(source, item:GetItemID()) then
        LootTrace("%s (%s): SKIPPED, already added from another loot source", itemLink, sourceName)
        return
    end
    LootTrace("%s (%s): passed the filters, adding", itemLink, sourceName)
    AddItemToAuctionList(self, item)
end

local function AutoAddItemProxy(self, item, source)
    if item:IsItemEmpty() then
        LootTrace("%s: SKIPPED, empty item", tostring(source or "button"))
        return
    end
    if item:IsItemDataCached() then
        AutoAddItemInternal(self, item, source)
    else
        LootTrace("%s (%s): waiting for item data", Show(item:GetItemLink()), tostring(source or "button"))
        item:ContinueOnItemLoad(function()
            AutoAddItemInternal(self, item, source)
        end)
    end
end

-- Seconds between bag checks for looted items: loot can take a while to land in the bags
local BAG_CHECK_DELAYS = { 1, 2, 3, 5, 8 }

local function AddWhenTradeable(self, itemLink, attempt)
    attempt = attempt or 1
    C_Timer.After(BAG_CHECK_DELAYS[attempt], function()
        if CLM.MODULES.TradeHelper:IsTradeableInBags(itemLink) then
            AutoAddItemProxy(self, Item:CreateFromItemLink(itemLink), LOOT_SOURCE.CHAT)
        elseif attempt < #BAG_CHECK_DELAYS then
            AddWhenTradeable(self, itemLink, attempt + 1)
        else
            LootTrace("%s (chat): SKIPPED, not found as tradeable in the bags after %d checks", Show(itemLink), attempt)
        end
    end)
end

local function HandleLootMessage(addon, event, message, _, _, _, playerName, ...)
    local self = AuctionManager
    if UTILS.IsSecret(message) or UTILS.IsSecret(playerName) then return end
    if playerName ~= UTILS.whoami() then return end
    if not message then return end
    if not CLM.MODULES.RaidManager:IsInActiveRaid() then return end
    if not self:IsAuctioneer() then return end
    local itemLink = deformat(message, LOOT_ITEM_SELF_MULTIPLE)
    if not itemLink then
        itemLink = deformat(message, LOOT_ITEM_SELF)
    end
    if not itemLink then return end
    LootTrace("%s (chat): looted, checking the bags for it", Show(itemLink))
    -- Only loot that can still go to another player (raid feedback 2026-10-18). Give the
    -- item a moment to land in the bags, then look for it there, a few times.
    AddWhenTradeable(self, itemLink)
end

--[[
    Loot Rolls history (raid feedback 2026-10-18: drops were missing from the list). Every group
    loot roll we win is added; won rolls can always be traded to the rest of the raid, so there is
    no bag check here.
]]--
local processedDrops = {}
local lastDropReasons = {}

local function DropKey(encounterID, lootListID)
    return tostring(encounterID) .. ":" .. tostring(lootListID)
end

-- Item link of a drop we won, or nil and the reason (for the loot debug)
local function WonDropLink(drop)
    if type(drop) ~= "table" then return nil, "no drop info" end
    local winner = drop.winner
    if type(winner) ~= "table" then
        return nil, drop.allPassed and "everyone passed" or "no winner yet"
    end
    if UTILS.IsSecret(winner.isSelf) then return nil, "winner is a secret value" end
    if not winner.isSelf then return nil, "won by " .. Show(winner.playerName) end
    local itemLink = drop.itemHyperlink
    if not itemLink then return nil, "no item link" end
    if UTILS.IsSecret(itemLink) then return nil, "item link is a secret value" end
    return itemLink
end

-- One line about a drop for the loot debug
local function DescribeDrop(drop)
    if type(drop) ~= "table" then return "not a table: " .. Show(drop) end
    local winner = type(drop.winner) == "table" and drop.winner or {}
    return string.format("drop %s %s winner=%s isSelf=%s roll=%s state=%s allPassed=%s rollState=%s",
        Show(drop.lootListID), Show(drop.itemHyperlink), Show(winner.playerName), Show(winner.isSelf),
        Show(winner.roll), Show(winner.state), Show(drop.allPassed), Show(drop.playerRollState))
end

-- Every drop we won in an encounter: { {key = ..., link = ...}, ... }
local function WonDrops(encounterID)
    local won = {}
    if not (C_LootHistory and C_LootHistory.GetSortedDropsForEncounter) then return won end
    local ok, drops = pcall(C_LootHistory.GetSortedDropsForEncounter, encounterID)
    if not ok or type(drops) ~= "table" then return won end
    for _, drop in ipairs(drops) do
        local itemLink = WonDropLink(drop)
        if itemLink then
            tinsert(won, { key = DropKey(encounterID, drop.lootListID), link = itemLink })
        end
    end
    return won
end

-- Drops that were already in the history before this session (e.g. after a /reload) are not new
local function MarkKnownDrops()
    if not (C_LootHistory and C_LootHistory.GetAllEncounterInfos) then return end
    local ok, encounters = pcall(C_LootHistory.GetAllEncounterInfos)
    if not ok or type(encounters) ~= "table" then return end
    for _, encounter in ipairs(encounters) do
        for _, drop in ipairs(WonDrops(encounter.encounterID)) do
            processedDrops[drop.key] = true
        end
    end
end

local function HandleLootHistoryDrop(addon, event, encounterID, lootListID)
    local self = AuctionManager
    if UTILS.IsSecret(encounterID) or UTILS.IsSecret(lootListID) then return end
    local key = DropKey(encounterID, lootListID)
    if processedDrops[key] then return end
    if not (C_LootHistory and C_LootHistory.GetSortedInfoForDrop) then return end
    local ok, drop = pcall(C_LootHistory.GetSortedInfoForDrop, encounterID, lootListID)
    if not ok then
        LootTrace("history %s: GetSortedInfoForDrop failed: %s", key, Show(drop))
        return
    end
    local itemLink, reason = WonDropLink(drop)
    if not itemLink then -- not decided yet, or someone else won it
        if lastDropReasons[key] ~= reason then -- the event fires on every roll; log changes only
            lastDropReasons[key] = reason
            LootTrace("history %s: not added, %s (%s)", key, reason, DescribeDrop(drop))
        end
        return
    end
    processedDrops[key] = true
    if not CLM.MODULES.RaidManager:IsInActiveRaid() then
        LootTrace("history %s: %s SKIPPED, not in an active raid", key, Show(itemLink))
        return
    end
    if not self:IsAuctioneer() then
        LootTrace("history %s: %s SKIPPED, not the auctioneer", key, Show(itemLink))
        return
    end
    AutoAddItemProxy(self, Item:CreateFromItemLink(itemLink), LOOT_SOURCE.HISTORY)
end

-- Count the auction and pending lists' copies per item link
local function CountListedItems(self)
    local listed = {}
    for _, auction in ipairs({ self.currentAuction, self.pendingAuction }) do
        for _, auctionItem in pairs(auction:GetItems()) do
            local itemLink = auctionItem:GetItemLink()
            listed[itemLink] = (listed[itemLink] or 0) + auctionItem:GetTotal()
        end
    end
    return listed
end

-- Add from loot rolls: every drop we won in the last boss's Loot Rolls that isn't listed yet.
-- Returns the number of items added.
---@return number
function AuctionManager:AddFromLootRolls()
    if not CLM.MODULES.RaidManager:IsInRaid() then
        LOG:Message(CLM.L["Auctioning requires active raid or roster mode."])
        return 0
    end
    if not (C_LootHistory and C_LootHistory.GetAllEncounterInfos) then return 0 end
    local ok, encounters = pcall(C_LootHistory.GetAllEncounterInfos)
    if not ok or type(encounters) ~= "table" or #encounters == 0 then
        LOG:Message(CLM.L["No loot rolls found."])
        return 0
    end
    -- The most recent encounter is the one that started last
    local last
    for _, encounter in ipairs(encounters) do
        LootTrace("button: encounter %s %s startTime=%s", Show(encounter.encounterID), Show(encounter.encounterName), Show(encounter.startTime))
        if not last or (encounter.startTime or 0) > (last.startTime or 0) then last = encounter end
    end
    LootTrace("button: using encounter %s %s", Show(last.encounterID), Show(last.encounterName))
    LogFilterSettings(self)
    if self:GetLootDebug() and C_LootHistory.GetSortedDropsForEncounter then
        local okDrops, drops = pcall(C_LootHistory.GetSortedDropsForEncounter, last.encounterID)
        if okDrops and type(drops) == "table" then
            LootTrace("button: %d drop(s) in the Loot Rolls", #drops)
            for _, drop in ipairs(drops) do
                local _, reason = WonDropLink(drop)
                LootTrace("button: %s -> %s", DescribeDrop(drop), reason or "won by us")
            end
        else
            LootTrace("button: GetSortedDropsForEncounter failed: %s", Show(drops))
        end
    end
    local listed = CountListedItems(self)
    for link, count in pairs(listed) do
        LootTrace("button: already listed %dx %s", count, Show(link))
    end
    local added = 0
    for _, drop in ipairs(WonDrops(last.encounterID)) do
        processedDrops[drop.key] = true
        if (listed[drop.link] or 0) > 0 then
            LootTrace("button: %s %s SKIPPED, a copy with this exact link is already listed", drop.key, Show(drop.link))
            listed[drop.link] = listed[drop.link] - 1
        else
            LootTrace("button: %s %s not listed, adding", drop.key, Show(drop.link))
            -- Counts as the history's copy, so a late chat line doesn't add it again
            local counts = lootSourceCounts[LOOT_SOURCE.HISTORY]
            local itemId = UTILS.GetItemIdFromLink(drop.link)
            counts[itemId] = (counts[itemId] or 0) + 1
            AutoAddItemProxy(self, Item:CreateFromItemLink(drop.link))
            added = added + 1
        end
    end
    LOG:Message(CLM.L["Loot rolls of %s: %d won item(s) not in the list yet."], tostring(last.encounterName or "?"), added)
    return added
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

    local targetGuid = UnitGUID("target")
    if UTILS.IsSecret(targetGuid) then targetGuid = nil end
    if targetGuid then
        if alreadyAddedLoot[targetGuid] then
            LootTrace("corpse: already looked at this corpse")
            return
        end
        alreadyAddedLoot[targetGuid] = true
    end

    local numLootItems = GetNumLootItems()
    LootTrace("corpse: %s loot slot(s)", Show(numLootItems))
    for lootIndex = 1, numLootItems do
        local itemLink = GetLootSlotLink(lootIndex)
        if itemLink then
            LootTrace("corpse: slot %d %s", lootIndex, Show(itemLink))
            AutoAddItemProxy(AuctionManager, Item:CreateFromItemLink(itemLink), LOOT_SOURCE.CORPSE)
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
    CLM.MODULES.EventManager:RegisterWoWEvent({"LOOT_HISTORY_UPDATE_DROP"}, HandleLootHistoryDrop)
    CLM.MODULES.EventManager:RegisterWoWEvent({"ENCOUNTER_START"}, function()
        LootTrace("boss pull: loot source counts reset")
        ResetLootSourceCounts()
    end)
    MarkKnownDrops()

    CLM.MODULES.ConfigManager:RegisterSlash({
        lootdebug = {
            type = "input",
            name = "Loot debug",
            desc = "Print every auction list filling decision to chat and keep it in the saved log: on, off or clear",
            set = function(_, value)
                value = UTILS.Trim(strlower(value or ""))
                if value == "clear" then
                    self:ClearLootDebugLog()
                elseif value == "on" or value == "off" then
                    self:SetLootDebug(value == "on")
                else
                    self:SetLootDebug(not self:GetLootDebug())
                end
            end,
        }
    })

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
        LOG:Message(CLM.L["You are not allowed to auction items. Auctioneers are officers who are raid leader or assistant, or who have Need on everything on."])
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
        LOG:Message(CLM.L["You are not allowed to auction items. Auctioneers are officers who are raid leader or assistant, or who have Need on everything on."])
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
    local isTransmog = userResponse:Type() == CONSTANTS.BID_TYPE.TRANSMOG
    if isTransmog and not auction:GetUseTransmog() then
        return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.TRANSMOG_NOT_ALLOWED
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
    -- transmog is free; a tier bid must be BiS / Major / Minor at exactly that tier's value;
    -- anything else must be one of the item's tier values
    local bidType = userResponse:Type()
    if isTransmog then
        if value ~= 0 then return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.BID_VALUE_INVALID end
    elseif CONSTANTS.SLOT_VALUE_TIERS[bidType] then
        local tierValue = tonumber(item:GetValues()[bidType])
        if not CONSTANTS.BID_TIERS[bidType] or not tierValue or tierValue < 0 or tonumber(value) ~= tierValue then
            return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.BID_VALUE_INVALID
        end
    elseif not item:IsValueAccepted(value) then
        return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.BID_VALUE_INVALID
    end
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
    if (not auction:GetUseTransmog()) and (userResponse:Type() == CONSTANTS.BID_TYPE.TRANSMOG) then
        return false, CONSTANTS.AUCTION_COMM.DENY_BID_REASON.TRANSMOG_NOT_ALLOWED
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

-- PR used when ranking a bid: transmog bids ignore PR, so only the roll decides
---@param bidType any
---@param pr number
---@return number
function AuctionManager:GetRankingPR(bidType, pr)
    if CONSTANTS.BID_TYPE_IGNORES_PR[bidType] then return 0 end
    return pr
end

-- Sort weight of a bid type: tiers (BiS first) above MS, OS, Transmog, Pass, Cancel
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
    The winner the Auction tab preselects when an auction ends (ui-redesign.md R10):
    the highest tier, then the highest PR, then the highest roll. OS ranks above Transmog, and
    Transmog ignores PR (highest roll wins). Passes, cancels and invalid bids never win. `exclude` holds names already awarded this item (items with a count > 1).
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
            local key = { self:GetBidTypeOrder(response:Type()), self:GetRankingPR(response:Type(), pr), response:Roll() or 0 }
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
    CURRENT_VERSION = 5,
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
        TRANSMOG_NOT_ALLOWED = 14,
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
        14,-- TRANSMOG_NOT_ALLOWED
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
        [13] = CLM.L["Changing bid from Main-spec to Off-Spec not allowed"],
        [14] = CLM.L["Transmog bidding not allowed"]
    }
}

CLM.MODULES.AuctionManager = AuctionManager
