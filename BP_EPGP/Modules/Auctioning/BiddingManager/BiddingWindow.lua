-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI
local S = UI.SPACE

--[[
    Bidding window (Phase 9d, ui-redesign.md "Bidding", R9). Every raider sees it during an auction.
      header  "Item 2 of 4 · 14s left" (docked countdown) and YOUR PR
      body    item with item level and slot, Next ›; one row of tier buttons with their GP;
              OS · Pass · Cancel; a status line (accepted / denied); the open bid list
    Clicking another tier replaces your bid. Only an unusable item asks for confirmation.
    The separate timer bar is optional and off by default.
]]--

local WIDTH, HEIGHT = 480, 440
local BAR_FONT_SIZE = 12 -- timer bar font and texture are fixed (ui-overhaul.md)
local ITEM_SIZE = 36

local HIDDEN_BID = UI.COLOR.GREY
local OS_COLOR = CreateColor(1, 0.82, 0.5)

---@class BiddingManagerGUI
---@field window table?
---@field db table
---@field bar BiddingTimerBar?
---@field testBar BiddingTimerBar?
---@field auctionItem AuctionItem?
---@field auctionOrder table
---@field nextItem number
---@field showAfterCombat boolean?
---@field _initialized boolean
local BiddingWindow = { auctionOrder = {}, nextItem = 1 }

local function InitializeDB(self)
    self.db = CLM.MODULES.Database:GUI('bidding', {
        barWidth = 340,
        barHeight = 25,
        -- barLocation
        showBar = false,
        closeOnBid = false,
        advanceOnBid = true,
        hideInCombat = false,
        autoOpen = true,
        ignoreUnusable = false
    })
end

local function Auction()
    return CLM.MODULES.BiddingManager:GetAuctionInfo()
end

--[[
 * Settings (Settings tab, ui-overhaul.md Part 2 "Bidding window") *
]]--

local function Flag(key)
    return function(self) return self.db[key] end,
           function(self, value) self.db[key] = value and true or false end
end
BiddingWindow.GetAutoOpen, BiddingWindow.SetAutoOpen = Flag("autoOpen")
BiddingWindow.GetCloseOnBid, BiddingWindow.SetCloseOnBid = Flag("closeOnBid")
BiddingWindow.GetAdvanceOnBid, BiddingWindow.SetAdvanceOnBid = Flag("advanceOnBid")
BiddingWindow.GetIgnoreUnusable, BiddingWindow.SetIgnoreUnusable = Flag("ignoreUnusable")
BiddingWindow.GetHideInCombat, BiddingWindow.SetHideInCombat = Flag("hideInCombat")
BiddingWindow.GetShowTimerBar, BiddingWindow.SetShowTimerBar = Flag("showBar")

---@return number
function BiddingWindow:GetBarWidth()
    return self.db.barWidth
end

---@param value number
function BiddingWindow:SetBarWidth(value)
    value = math.max(50, math.min(1000, tonumber(value) or 340))
    self.db.barWidth = value
    local bar = self.bar or self.testBar
    if bar then bar:SetWidth(value) end
end

---@return number
function BiddingWindow:GetBarHeight()
    return self.db.barHeight
end

---@param value number
function BiddingWindow:SetBarHeight(value)
    value = math.max(10, math.min(100, tonumber(value) or 25))
    self.db.barHeight = value
    local bar = self.bar or self.testBar
    if bar then bar:SetHeight(value) end
end

--[[
 * Timer bar (optional) *
]]--

local function BarOptions(self, callback)
    return {
        anchor = self.db.barLocation,
        width = self.db.barWidth,
        height = self.db.barHeight,
        fontSize = BAR_FONT_SIZE,
        callback = callback,
    }
end

local function HideTestBar(self)
    if self.testBar then
        self.db.barLocation = { self.testBar:GetPoint() }
        self.testBar:Stop()
    end
    self.testBar = nil
end

-- /bpepgp bar: shows a test bar so it can be moved
function BiddingWindow:ToggleTestBar()
    if CLM.MODULES.BiddingManager:IsAuctionInProgress() then return end
    if self.testBar then
        HideTestBar(self)
    else
        self.testBar = CLM.MODELS.BiddingTimerBar:Test(BarOptions(self))
    end
end

--[[
 * Item order (Next ›) *
]]--

local function IsShownItem(self, item)
    return not self.db.ignoreUnusable or item:GetCanUse() or not Auction():HasUsableItems()
end

-- Index of the next item after `from` that we show (wraps around)
local function NextIndex(self, from)
    local auction = Auction()
    local count = #self.auctionOrder
    if count == 0 then return 1 end
    for step = 1, count do
        local index = ((from - 1 + step) % count) + 1
        local item = auction:GetItemByUID(self.auctionOrder[index])
        if item and IsShownItem(self, item) then return index end
    end
    return ((from) % count) + 1
end

local function ShowIndex(self, index)
    self.nextItem = index
    self.auctionItem = Auction():GetItemByUID(self.auctionOrder[index])
end

function BiddingWindow:BuildBidOrder()
    local auction = Auction()
    self.auctionOrder = {}
    self.auctionItem = nil
    if not auction then return end
    for uid in pairs(auction:GetItems()) do
        self.auctionOrder[#self.auctionOrder + 1] = uid
    end
    table.sort(self.auctionOrder, function(a, b) return tostring(a) < tostring(b) end)
    if #self.auctionOrder > 0 then
        ShowIndex(self, NextIndex(self, #self.auctionOrder))
    end
end

function BiddingWindow:Advance()
    if #self.auctionOrder == 0 then return end
    ShowIndex(self, NextIndex(self, self.nextItem))
    self:Refresh()
end

local function CloseIfDone(self)
    if not self.db.closeOnBid then return end
    for _, item in pairs(Auction():GetItems()) do
        if IsShownItem(self, item) and not item:GetBid() then return end
    end
    self:Hide()
end

--[[
 * Bidding *
]]--

local function SendBid(self, value, bidType)
    local item = self.auctionItem
    if not item then return end
    local function Send()
        if bidType == CONSTANTS.BID_TYPE.PASS then
            CLM.MODULES.BiddingManager:Pass(item)
        elseif bidType == CONSTANTS.BID_TYPE.CANCEL then
            CLM.MODULES.BiddingManager:CancelBid(item)
        else
            CLM.MODULES.BiddingManager:Bid(item, value, bidType)
        end
        if self.db.advanceOnBid then self:Advance() else self:Refresh() end
        CloseIfDone(self)
    end
    local isBid = bidType ~= CONSTANTS.BID_TYPE.PASS and bidType ~= CONSTANTS.BID_TYPE.CANCEL
    if isBid and not item:GetCanUse() then
        UI.Confirm(string.format(CLM.L["Are you sure, you want to bid on an unusable item %s?"], item:GetItemLink()), Send)
    else
        Send()
    end
end

-- Tiers shown as buttons: named (or valued) tiers with a value of 0 or more, Max first
local function VisibleTiers(auction, item)
    local tiers = {}
    local values = item and item:GetValues() or {}
    for _, tier in ipairs(CONSTANTS.SLOT_VALUE_TIERS_ORDERED_REVERSED) do
        local value = tonumber(values[tier]) or 0
        local name = auction:GetFieldName(tier)
        -- Unnamed tier with a value: use the tier's own name instead of hiding the button
        if (not name or name == "") and value > 0 then
            name = CONSTANTS.SLOT_VALUE_TIERS_GUI[tier]
        end
        if name and name ~= "" and value >= 0 then
            tiers[#tiers + 1] = { tier = tier, name = name, value = value }
        end
    end
    -- No named or valued tier (e.g. every value 0): still offer the Base tier, so there is always a bid button
    if #tiers == 0 then
        local base = CONSTANTS.SLOT_VALUE_TIER.BASE
        local value = tonumber(values[base]) or 0
        if value >= 0 then
            local name = auction:GetFieldName(base)
            tiers[1] = { tier = base, name = (name and name ~= "") and name or CONSTANTS.SLOT_VALUE_TIERS_GUI[base], value = value }
        end
    end
    return tiers
end

--[[
 * Building *
]]--

local function BuildHeader(self, window)
    local heading = UI.CreateLabel(window, CLM.L["Bidding"], "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 60, -34)
    self.progressText = UI.CreateLabel(window, "", "GameFontHighlight")
    self.progressText:SetPoint("BOTTOMLEFT", heading, "BOTTOMRIGHT", S.M, 1)
    self.myPR = UI.CreateLabel(window, "", "GameFontNormalHuge", UI.COLOR.GOLD)
    self.myPR:SetPoint("TOPRIGHT", window, "TOPRIGHT", -S.M, -30)
    self.myPRLabel = UI.CreateLabel(window, CLM.L["YOUR PR"], "GameFontNormalSmall")
    self.myPRLabel:SetPoint("RIGHT", self.myPR, "LEFT", -S.S, 0)
end

local function BuildItemRow(self, area)
    self.itemButton = UI.CreateItemButton(area, ITEM_SIZE)
    self.itemButton:SetPoint("TOPLEFT")
    self.nextButton = UI.CreateButton(area, CLM.L["Next"] .. " ›", 80, function() self:Advance() end)
    self.nextButton:SetPoint("TOPRIGHT", 0, -6)
    self.itemLink = UI.CreateLabel(area, "", "GameFontHighlight")
    self.itemLink:SetPoint("TOPLEFT", self.itemButton, "TOPRIGHT", S.S, -2)
    self.itemLink:SetPoint("RIGHT", self.nextButton, "LEFT", -S.S, 0)
    self.itemLink:SetWordWrap(false)
    self.itemInfo = UI.CreateLabel(area, "", "GameFontDisableSmall")
    self.itemInfo:SetPoint("BOTTOMLEFT", self.itemButton, "BOTTOMRIGHT", S.S, 2)
    self.itemInfo:SetPoint("RIGHT", self.nextButton, "LEFT", -S.S, 0)
    self.itemInfo:SetWordWrap(false)
end

local function BuildButtons(self, area)
    self.tierButtons = {}
    for i = 1, #CONSTANTS.SLOT_VALUE_TIERS_ORDERED do
        local button = UI.CreateTierButton(area, function(frame) SendBid(self, frame.value, frame.tier) end)
        button:SetPoint("TOPLEFT", (i - 1) * (74 + 6), -(ITEM_SIZE + S.M))
        self.tierButtons[i] = button
    end
    local y = -(ITEM_SIZE + S.M + 40 + S.S)
    self.osButton = UI.CreateButton(area, CLM.L["OS"], 74, function(frame) SendBid(self, frame.value, CONSTANTS.BID_TYPE.OFF_SPEC) end)
    self.osButton:SetHeight(24)
    self.osButton:SetPoint("TOPLEFT", 0, y)
    self.passButton = UI.CreateButton(area, CLM.L["Pass"], 74, function() SendBid(self, 0, CONSTANTS.BID_TYPE.PASS) end)
    self.passButton:SetHeight(24)
    self.passButton:SetPoint("LEFT", self.osButton, "RIGHT", 6, 0)
    self.cancelButton = UI.CreateButton(area, CLM.L["Cancel"], 74, function() SendBid(self, 0, CONSTANTS.BID_TYPE.CANCEL) end)
    self.cancelButton:SetHeight(24)
    self.cancelButton:SetPoint("LEFT", self.passButton, "RIGHT", 6, 0)
    self.status = UI.CreateLabel(area, "", "GameFontHighlight")
    self.status:SetPoint("TOPLEFT", 0, y - 24 - S.S)
    self.status:SetPoint("RIGHT")
    return y - 24 - S.S - 16 - S.S
end

local function BidLabel(auction, response)
    local bidType = response:Type()
    if bidType == CONSTANTS.BID_TYPE.CANCEL then return CLM.L["Cancel"] end
    if bidType == CONSTANTS.BID_TYPE.PASS then return CLM.L["Pass"] end
    if bidType == CONSTANTS.BID_TYPE.OFF_SPEC then return CLM.L["OS"] .. " " .. tostring(response:Value()) end
    if CONSTANTS.SLOT_VALUE_TIERS[bidType] then
        return auction:GetFieldDisplayName(bidType) .. " " .. tostring(response:Value())
    end
    return (CONSTANTS.BID_TYPE_NAMES[bidType] or "") .. " " .. tostring(response:Value())
end

local function BidColor(response)
    local bidType = response:Type()
    if CONSTANTS.BID_TYPE_HIDDEN[bidType] then return HIDDEN_BID end
    if bidType == CONSTANTS.BID_TYPE.OFF_SPEC then return OS_COLOR end
    return UI.TIER_COLOR[bidType] or UI.COLOR.WHITE
end

local function BuildBidList(self, area, top)
    local inset = UI.CreateInset(area)
    inset:SetPoint("TOPLEFT", 0, top)
    inset:SetPoint("BOTTOMRIGHT")
    self.bidList = UI.CreateList(inset, {
        columns = {
            { key = "name", title = CLM.L["Name"], width = 0, classIcon = true,
              color = function(row) return row.hidden and HIDDEN_BID or UI.GetClassColor(row.classFile) end },
            { key = "score", title = CLM.L["Bid"], width = 110, defaultDesc = true,
              text = function(row) return row.values.bid end,
              color = function(row) return BidColor(row.response) end },
            { key = "pr", title = CLM.L["PR"], width = 56, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true,
              color = function(row) return row.hidden and HIDDEN_BID or UI.COLOR.GOLD end },
            { key = "roll", title = CLM.L["Roll"], width = 44, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true,
              color = function() return UI.COLOR.GREY end },
        },
        sortKey = "score",
        sortDesc = true,
        rowTint = function(row) return row.isMe and CreateColor(0.27, 0.28, 0.93, 0.25) or nil end,
    })
    self.bidList:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.bidList:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
end

local function Build(self)
    local window = UI.CreateWindow({
        name = "BPEPGP_BiddingWindow",
        title = CLM.L["Bidding"],
        width = WIDTH, height = HEIGHT,
        portrait = true,
        dbKey = "biddingwindow",
    })
    self.window = window
    BuildHeader(self, window)
    local top = S.TOP_BAND
    local banner = UI.CreateTestModeBanner(window)
    if banner then
        banner:SetPoint("TOPLEFT", S.S, -top)
        banner:SetPoint("TOPRIGHT", -S.S, -top)
        top = top + 24 + S.XS
    end
    local area = CreateFrame("Frame", nil, window)
    area:SetPoint("TOPLEFT", S.M, -top)
    area:SetPoint("BOTTOMRIGHT", -S.M, S.M)
    BuildItemRow(self, area)
    local listTop = BuildButtons(self, area)
    BuildBidList(self, area, listTop)

    -- Docked countdown
    local elapsed = 0
    window:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        self:UpdateHeader()
    end)
end

--[[
 * Refresh *
]]--

function BiddingWindow:UpdateHeader()
    if not self.window then return end
    local auction = Auction()
    local parts = {}
    if auction and #self.auctionOrder > 0 then
        parts[#parts + 1] = string.format(CLM.L["Item %s of %s"], self.nextItem, #self.auctionOrder)
    end
    if auction and auction:IsInProgress() and auction:GetEndTime() then
        local left = math.max(0, math.ceil(auction:GetEndTime() - GetServerTime()))
        local text = string.format(CLM.L["%ss left"], left)
        parts[#parts + 1] = left <= 5 and UI.COLOR.BAD:WrapTextInColorCode(text) or text
    elseif auction then
        parts[#parts + 1] = CLM.L["Auction finished"]
    end
    self.progressText:SetText(table.concat(parts, " · "))
end

local function RefreshMyPR(self, auction)
    local roster = auction and auction:GetRoster()
    local myGUID = UTILS.whoamiGUID()
    if roster and roster:IsProfileInRoster(myGUID) then
        self.myPR:SetText(tostring(roster:Priority(myGUID)))
        self.myPRLabel:Show()
    else
        self.myPR:SetText("")
        self.myPRLabel:Hide()
    end
end

local function RefreshItem(self)
    local item = self.auctionItem
    self.itemButton:SetItem(item and item:GetItemLink() or nil)
    self.itemLink:SetText(item and item:GetItemLink() or CLM.L["No auction"])
    local info = {}
    if item then
        local link = item:GetItemLink()
        local level = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
        if level then info[#info + 1] = string.format(CLM.L["Item level %s"], level) end
        local _, _, _, equipLoc = UTILS.GetItemInfoInstant(link)
        if equipLoc and _G[equipLoc] then info[#info + 1] = _G[equipLoc] end
        if not item:GetCanUse() then info[#info + 1] = UI.COLOR.BAD:WrapTextInColorCode(CLM.L["Can't use"]) end
        local note = item:GetNote()
        if note and note ~= "" then info[#info + 1] = UI.COLOR.GOLD:WrapTextInColorCode(note) end
    end
    self.itemInfo:SetText(table.concat(info, " · "))
    self.nextButton:SetEnabled(#self.auctionOrder > 1)
end

local function RefreshButtons(self, auction)
    local item = self.auctionItem
    local running = auction and auction:IsInProgress() and item ~= nil
    local myBid = item and item:GetBid()
    local tiers = (auction and item) and VisibleTiers(auction, item) or {}
    for i, button in ipairs(self.tierButtons) do
        local tier = tiers[i]
        button:SetShown(tier ~= nil)
        if tier then
            button.tier, button.value = tier.tier, tier.value
            button:SetTier(tier.name, tier.value, UI.TIER_COLOR[tier.tier])
            button:SetSelected(myBid ~= nil and myBid:Type() == tier.tier)
            button:SetEnabled(running)
        end
    end
    local useOS = auction and auction:GetUseOS()
    self.osButton:SetShown(useOS and true or false)
    self.osButton.value = item and tonumber(item:GetValues()[CONSTANTS.SLOT_VALUE_TIER.BASE]) or 0
    self.osButton:SetEnabled(running)
    self.passButton:SetEnabled(running)
    self.cancelButton:SetEnabled(running and myBid ~= nil)
    if useOS then
        self.passButton:SetPoint("LEFT", self.osButton, "RIGHT", 6, 0)
    else
        self.passButton:SetPoint("LEFT", self.osButton, "LEFT", 0, 0)
    end
end

local function RefreshStatus(self, auction)
    local item = self.auctionItem
    local bid = item and item:GetBid()
    local text, color = CLM.L["No bid yet."], UI.COLOR.GREY
    if bid then
        local label = BidLabel(auction, bid)
        if item:BidAccepted() then
            if bid:Type() == CONSTANTS.BID_TYPE.PASS then
                text, color = CLM.L["You passed."], UI.COLOR.GREY
            elseif bid:Type() == CONSTANTS.BID_TYPE.CANCEL then
                text, color = CLM.L["Your bid is cancelled."], UI.COLOR.GREY
            else
                text, color = string.format(CLM.L["Bid accepted: %s"], label), UI.COLOR.EP
            end
        elseif item:BidDenied() then
            text, color = string.format(CLM.L["Bid denied: %s"], item:GetBidDenyReason() or CLM.L["Unknown"]), UI.COLOR.BAD
        else
            text, color = string.format(CLM.L["Bid sent: %s"], label), UI.COLOR.GOLD
        end
    end
    self.status:SetText(text)
    self.status:SetTextColor(color:GetRGB())
end

local function RefreshBids(self, auction)
    local rows = {}
    local item = self.auctionItem
    if item and auction then
        local roster = auction:GetRoster()
        local me = UTILS.whoami()
        for name, response in pairs(item:GetAllResponses()) do
            local profile = CLM.MODULES.ProfileManager:GetProfileByName(name)
            local pr = (profile and roster) and roster:Priority(profile:GUID()) or 0
            local roll = response:Roll() or 0
            rows[#rows + 1] = {
                id = name,
                response = response,
                isMe = name == me,
                classFile = profile and UTILS.CanonicalClass(profile:ClassInternal()) or nil,
                hidden = CONSTANTS.BID_TYPE_HIDDEN[response:Type()] and true or false,
                values = {
                    name = name,
                    score = CLM.MODULES.AuctionManager:GetBidTypeOrder(response:Type()) * 1e9 + math.floor(pr * 1000) * 1000 + roll,
                    bid = BidLabel(auction, response),
                    pr = pr,
                    roll = roll,
                },
            }
        end
    end
    self.bidList:SetData(rows)
end

function BiddingWindow:Refresh()
    if not self._initialized or not self.window then return end
    local auction = Auction()
    RefreshMyPR(self, auction)
    RefreshItem(self)
    RefreshButtons(self, auction)
    if auction then RefreshStatus(self, auction) else self.status:SetText("") end
    RefreshBids(self, auction)
    self:UpdateHeader()
    if self.bar and self.auctionItem then self.bar:UpdateInfo(self.auctionItem) end
end

-- Kept for BiddingManager: items arrive one by one while their data loads
function BiddingWindow:RefreshItemList()
    self:Refresh()
end

--[[
 * Auction events (called by BiddingManager) *
]]--

function BiddingWindow:StartAuction()
    self:BuildBidOrder()
    HideTestBar(self)
    if self.db.showBar then
        self.bar = CLM.MODELS.BiddingTimerBar:New(self.auctionItem, Auction(), BarOptions(self, function() self:Toggle() end))
    end
    if self.db.autoOpen then
        if self.db.hideInCombat and InCombatLockdown() then
            self.showAfterCombat = true
        else
            self:Show()
        end
    end
    self:Refresh()
end

function BiddingWindow:EndAuction()
    if self.bar then
        self.db.barLocation = { self.bar:GetPoint() }
        self.bar:Stop()
        self.bar = nil
    end
    self:Refresh()
end

function BiddingWindow:AntiSnipe()
    if self.bar then
        self.bar:UpdateTime(Auction():GetAntiSnipe())
    end
    self:UpdateHeader()
end

---@param auctionItem AuctionItem
function BiddingWindow:SetVisibleAuctionItem(auctionItem)
    self.auctionItem = auctionItem
end

--[[
 * Public *
]]--

function BiddingWindow:Initialize()
    LOG:Trace("BiddingWindow:Initialize()")
    InitializeDB(self)
    CLM.MODULES.ConfigManager:RegisterSlash({
        bid = {
            type = "execute",
            name = CLM.L["Bidding"],
            desc = CLM.L["Toggle Bidding window display"],
            handler = self,
            func = "Toggle",
        }
    })
    CLM.MODULES.EventManager:RegisterWoWEvent({"PLAYER_REGEN_DISABLED"}, function()
        if self.db.hideInCombat and self.window and self.window:IsShown() then
            self.showAfterCombat = true
            self.window:Hide()
        end
    end)
    CLM.MODULES.EventManager:RegisterWoWEvent({"PLAYER_REGEN_ENABLED"}, function()
        if not self.showAfterCombat then return end
        self.showAfterCombat = nil
        if CLM.MODULES.BiddingManager:IsAuctionInProgress() then self:Show() end
    end)
    self._initialized = true
end

function BiddingWindow:Show()
    if not self._initialized then return end
    if not self.window then Build(self) end
    self:Refresh()
    self.window:Show()
end

function BiddingWindow:Hide()
    if self.window then self.window:Hide() end
end

function BiddingWindow:Toggle()
    if not self._initialized then return end
    if self.window and self.window:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function BiddingWindow:Reset()
    if self.window then
        self.window:ClearAllPoints()
        self.window:SetPoint("CENTER", 0, 0)
    end
    self.db.barLocation = nil
end

CLM.GUI.BiddingManager = BiddingWindow
