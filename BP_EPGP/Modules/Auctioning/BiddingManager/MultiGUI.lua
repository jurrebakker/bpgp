-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local ScrollingTable = LibStub("ScrollingTable")
local AceGUI = LibStub("AceGUI-3.0")
---@cast AceGUI AceGUI
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")

local colorGreen = {r = 0.27, g = 0.93, b = 0.27, a = 1.0}
local colorGold = {r = 0.93, g = 0.70, b = 0.13, a = 1.0}
local colorRed = {r = 0.93, g = 0.27, b = 0.2, a = 1.0}
local colorBlue = {r = 0.2, g = 0.2, b = 0.93, a = 1.0}
local colorTurquoise = {r = 0.2, g = 0.93, b = 0.93, a = 1.0}
local colorGrey = {r = 0.62, g = 0.62, b = 0.62, a = 1}

local _, _, _, isElvUI = UTILS.GetAddOnInfo("ElvUI")

local rowMultiplier = 2.7
local rowMultiplierBy2 = rowMultiplier/2
local rowMultiplierBy4 = rowMultiplier/4
local rowMultiplierBy9 = rowMultiplier/9
local ROW_HEIGHT = 25
local BASE_HEIGHT = 115
local BID_ROWS = 7
local BID_ROW_HEIGHT = 18
local BIDS_HEIGHT = ((BID_ROWS + 1) * BID_ROW_HEIGHT) + 5

local BASE_ROW_WIDTH = 170 -- Ace Row Width

local DEFAULT_TEXTURE_NAME = "BP EPGP Default"

local DATA_GROUP_WIDTH = BASE_ROW_WIDTH*(rowMultiplier + 0.15) + (isElvUI and 15 or 0)

local ITEM_REGISTRY     = "bpepgp_bm_gui_opt_item"
local BUTTON_REGISTRY   = "bpepgp_bm_gui_opt_button"

---@class BiddingManagerGUI
---@field top AceGUIFrameWidget
---@field ButtonGroup AceGUISimpleGroupWidget
---@field DataGroup AceGUISimpleGroupWidget
---@field ItemGroup AceGUISimpleGroupWidget
---@field BidList LibSTTable
---@field ItemList LibSTTable
---@field bar BiddingTimerBar?
---@field testBar BiddingTimerBar?
---@field db table
---@field _initialized boolean
---@field auctionItem AuctionItem?
---@field note string?
---@field nextItem number
---@field auctionOrder table
---@field showAfterCombat boolean
---@field ToggleTestBar function
local BiddingManagerGUI = {}

local function InitializeDB(self)
    self.db = CLM.MODULES.Database:GUI('bidding', {
        location = {nil, nil, "CENTER", 0, 0 },
        scale = 1,

        barWidth = 340,
        barHeight = 25,
        barFontSize = 12,

        barTexture = DEFAULT_TEXTURE_NAME,
        -- barLocation
        -- barFontName

        closeOnBid = false,
        advanceOnBid = true,
        hideInCombat = true,
        autoOpen = true,
        includePasses = true,
        includeCancels = false,
        ignoreUnusable = false
    })
end

local function ShowTestBar(self)
    self.testBar = CLM.MODELS.BiddingTimerBar:Test(
        {
            anchor = self.db.barLocation,
            width = self.db.barWidth,
            height = self.db.barHeight,
            texture = self.db.barTexture,
            fontSize = self.db.barFontSize,
            fontName = self.db.barFontName,
        }
    )
end

local function HideTestBar(self)
    if self.testBar then
        self.db.barLocation = { self.testBar:GetPoint() }
        self.testBar:Stop()
    end
    self.testBar = nil
end

local function ToggleTestBar(self)
    if CLM.MODULES.BiddingManager:IsAuctionInProgress() then return end
    if self.testBar then
        HideTestBar(self)
    else
        ShowTestBar(self)
    end
end

local function SetCloseOnBid(self, value)
    self.db.closeOnBid = value and true or false
end

local function GetCloseOnBid(self)
    return self.db.closeOnBid
end

local function SetAutoOpen(self, value)
    self.db.autoOpen = value and true or false
end

local function GetAutoOpen(self)
    return self.db.autoOpen
end

local function SetAdvanceOnBid(self, value)
    self.db.advanceOnBid = value and true or false
end

local function GetAdvanceOnBid(self)
    return self.db.advanceOnBid
end

local function SetIgnoreUnusable(self, value)
    self.db.ignoreUnusable = value and true or false
end

local function GetIgnoreUnusable(self)
    return self.db.ignoreUnusable
end

local function SetHideInCombat(self, value)
    self.db.hideInCombat = value and true or false
end

local function GetHideInCombat(self)
    return self.db.hideInCombat
end

local function SetIncludePasses(self, value)
    self.db.includePasses = value and true or false
end

local function GetIncludePasses(self)
    return self.db.includePasses
end

local function SetIncludeCancels(self, value)
    self.db.includeCancels = value and true or false
end

local function GetIncludeCancels(self)
    return self.db.includeCancels
end

local function CreateConfig(self)
    local options = {
        bidding_header = {
            type = "header",
            name = CLM.L["Bidding"],
            order = 70
        },
        bidding_auto_open = {
            name = CLM.L["Toggle Bidding auto-open"],
            desc = CLM.L["Toggle auto open and auto close on auction start and stop"],
            type = "toggle",
            set = function(i, v) SetAutoOpen(self, v) end,
            get = function(i) return GetAutoOpen(self) end,
            width = "double",
            order = 71
        },
        bidding_gui_close_on_bid = {
            name = CLM.L["Close on bid"],
            desc = CLM.L["Toggle closing bidding UI after submitting bid for all items."],
            type = "toggle",
            set = function(i, v) SetCloseOnBid(self, v) end,
            get = function(i) return GetCloseOnBid(self) end,
            width = "double",
            order = 75
        },
        bidding_gui_ignore_unusable_items = {
            name = CLM.L["Ignore unusable items"],
            desc = CLM.L["Ignores unusable items. They will not be added to bidding window."],
            type = "toggle",
            set = function(i, v) SetIgnoreUnusable(self, v) end,
            get = function(i) return GetIgnoreUnusable(self) end,
            order = 76
        },
        bidding_gui_advance_on_bid = {
            name = CLM.L["Advance to next item after bid"],
            desc = CLM.L["Toggle advancing to next item on the list after bid."],
            type = "toggle",
            set = function(i, v) SetAdvanceOnBid(self, v) end,
            get = function(i) return GetAdvanceOnBid(self) end,
            width = 2,
            order = 76.5
        },
        bidding_gui_bar_width = {
            name = CLM.L["Auction timer bar width"],
            desc = CLM.L["Changes auction timer bar width."],
            type = "range",
            min = 0,
            max = 1000,
            step = 1,
            set = function(i, v)
                v = tonumber(v) or 0
                if v < 0 then v = 0 end
                if v > 1000 then v = 1000 end
                self.db.barWidth = v

                if self.bar then
                    self.bar:SetWidth(self.db.barWidth)
                elseif self.testBar then
                    self.testBar:SetWidth(self.db.barWidth)
                end
            end,
            get = function(i) return self.db.barWidth end,
            order = 77,
            width = 1
        },
        bidding_gui_bar_height = {
            name = CLM.L["Auction timer bar height"],
            desc = CLM.L["Changes auction timer bar height."],
            type = "range",
            min = 0,
            max = 100,
            step = 1,
            set = function(i, v)
                v = tonumber(v) or 0
                if v < 0 then v = 0 end
                if v > 100 then v = 100 end
                self.db.barHeight = v

                if self.bar then
                    self.bar:SetHeight(self.db.barHeight)
                elseif self.testBar then
                    self.testBar:SetHeight(self.db.barHeight)
                end
            end,
            get = function(i) return self.db.barHeight end,
            order = 77.1,
            width = 1
        },
        bidding_gui_bar_font = {
            name = CLM.L["Auction timer bar font"],
            desc = CLM.L["Changes auction timer bar font."],
            type = 'select',
            dialogControl = 'LSM30_Font',
            values = SharedMedia:HashTable("font"),
            set = function(_, key)
                self.db.barFontName = key
                if self.bar then
                    self.bar:SetFontName(SharedMedia:Fetch("font", self.db.barFontName))
                elseif self.testBar then
                    self.testBar:SetFontName(SharedMedia:Fetch("font", self.db.barFontName))
                end
            end,
            get = function() return self.db.barFontName end,
            order = 77.3,
        },
        bidding_gui_bar_font_size = {
            name = CLM.L["Auction timer bar font size"],
            desc = CLM.L["Changes auction timer bar font size."],
            type = "range",
            min = 0,
            max = 64,
            step = 1,
            set = function(i, v)
                v = tonumber(v) or 0
                if v < 0 then v = 0 end
                if v > 64 then v = 64 end
                self.db.barFontSize = v

                if self.bar then
                    self.bar:SetFontSize(self.db.barFontSize)
                elseif self.testBar then
                    self.testBar:SetFontSize(self.db.barFontSize)
                end
            end,
            get = function(i) return self.db.barFontSize end,
            order = 77.2,
            width = 1
        },
        bidding_gui_bar_statusbar = {
            name = CLM.L["Auction timer bar texture"],
            desc = CLM.L["Changes auction timer bar texture."],
            type = 'select',
            dialogControl = 'LSM30_Statusbar',
            values = SharedMedia:HashTable("statusbar"),
            set = function(_, key)
                self.db.barTexture = key
                if self.bar then
                    self.bar:SetTexture(SharedMedia:Fetch("statusbar", self.db.barTexture))
                elseif self.testBar then
                    self.testBar:SetTexture(SharedMedia:Fetch("statusbar", self.db.barTexture))
                end
            end,
            get = function() return self.db.barTexture end,
            order = 77.4,
            width = 1
        },
        bidding_gui_bar_test_bar = {
            name = CLM.L["Toggle test bar"],
            type = "execute",
            func = function()
                ToggleTestBar(self)
            end,
            order = 78,
            width = 1
        },
        bidding_gui_bar_restore_defaults = {
            name = CLM.L["Restore bar defaults"],
            type = "execute",
            func = function()
                local barOptions
                if self.bar then
                    self.bar:Default()
                    barOptions = self.bar:GetOptions()
                elseif self.testBar then
                    self.testBar:Default()
                    barOptions = self.testBar:GetOptions()
                end
                if barOptions then
                    self.db.barWidth = barOptions.width
                    self.db.barHeight = barOptions.height
                    self.db.barTexture = DEFAULT_TEXTURE_NAME
                    self.db.barFontName = barOptions.fontName
                    self.db.barFontSize = barOptions.fontSize
                end
            end,
            order = 78.1,
            width = 1
        },
        bidding_gui_hide_in_combat = {
            name = CLM.L["Hide in combat"],
            desc = CLM.L["Will hide bidding window if you enter combat and show it again when you exit. Will also delay auto opening if needed."],
            type = "toggle",
            set = function(i, v) SetHideInCombat(self, v) end,
            get = function(i) return GetHideInCombat(self) end,
            width = 1,
            order = 76.5
        },
        bidding_gui_include_passes = {
            name = CLM.L["Include passes"],
            desc = CLM.L["Include passes in bid list in open auction mode."],
            type = "toggle",
            set = function(i, v) SetIncludePasses(self, v) end,
            get = function(i) return GetIncludePasses(self) end,
            width = 1,
            order = 71.1
        },
        bidding_gui_include_cancels = {
            name = CLM.L["Include cancels"],
            desc = CLM.L["Include cancels in bid list in open auction mode."],
            type = "toggle",
            set = function(i, v) SetIncludeCancels(self, v) end,
            get = function(i) return GetIncludeCancels(self) end,
            width = 1,
            order = 72.1
        },
    }
    CLM.MODULES.ConfigManager:Register(CLM.CONSTANTS.CONFIGS.GROUP.GLOBAL, options)
end

local function RegisterSlash(self)
    local options = {
        bid = {
            type = "execute",
            name = CLM.L["Bidding"],
            desc = CLM.L["Toggle Bidding window display"],
            handler = self,
            func = "Toggle",
        }
    }
    CLM.MODULES.ConfigManager:RegisterSlash(options)
end

local function StoreLocation(self)
    self.db.location = { self.top:GetPoint() }
    self.db.location[2] = nil
    if self.bar then
        self.db.barLocation = { self.bar:GetPoint() }
        self.db.barLocation[2] = nil
    end
    self.db.scale = self.top.frame:GetScale()
end

local function RestoreLocation(self)
    if self.db.location then
        self.top:ClearAllPoints()
        self.top:SetPoint(self.db.location[3], self.db.location[4], self.db.location[5])
    end
    -- if self.db.scale then
        -- self.top.frame:SetScale(self.db.scale)
    -- end
end

local whoamiGUID = UTILS.whoamiGUID()
local function GetNextAuctionItem(self, startFrom)
    local nextItem = (startFrom or self.nextItem) + 1
    if GetIgnoreUnusable(self) then
        local auction = CLM.MODULES.BiddingManager:GetAuctionInfo()
        while nextItem ~= self.nextItem do
            local nextAuctionItem = auction:GetItemByUID(self.auctionOrder[nextItem])
            if nextAuctionItem and nextAuctionItem:GetCanUse() then break end
            nextItem = nextItem + 1
            if (nextItem > #self.auctionOrder) then nextItem = 1 end
        end
    end
    if (nextItem > #self.auctionOrder) then nextItem = 1 end
    return nextItem
end

local function SetNextVisibleAuctionItem(self)
    self:SetVisibleAuctionItem(CLM.MODULES.BiddingManager:GetAuctionInfo():GetItemByUID(self.auctionOrder[self.nextItem]))
end

local function OverrideNextItem(self, auctionItem)
    local uid
    for _uid, item in pairs(CLM.MODULES.BiddingManager:GetAuctionInfo():GetItems()) do
        if item == auctionItem then
            uid = _uid
        end
    end

    local startFrom
    for i, _uid in ipairs(self.auctionOrder) do
        if _uid == uid then
            startFrom = i
            break
        end
    end
    self.nextItem = GetNextAuctionItem(self, startFrom)
end

function BiddingManagerGUI:Advance() -- skipping unusable + handling toggling during auction when on unusable (or ignore the latter?)
    -- Saturate just in case set
    if (self.nextItem > #self.auctionOrder) then self.nextItem = 1 end
    -- Set the item
    SetNextVisibleAuctionItem(self)
    -- Update Next Auction Item
    self.nextItem = GetNextAuctionItem(self)
    -- Refresh display
    self:Refresh()
end


local function CloseOnBid(self)
    if GetCloseOnBid(self) then
        local auction = CLM.MODULES.BiddingManager:GetAuctionInfo()
        local ok = true
        for _, item in pairs(auction:GetItems()) do
            if GetIgnoreUnusable(self) and item:GetCanUse() or not GetIgnoreUnusable(self) then
                if not item:GetBid() then
                    ok = false
                    break
                end
            end
        end
        if ok then
            self:Toggle()
        end
    end
end

------------------------
--- Options Creation ---
------------------------
local itemOptions = {
    type = "group",
    args = {}
}

local buttonOptions = {
    type = "group",
    args = {}
}

local emptyTierValues = {}
do
    for _, tier in ipairs(CONSTANTS.SLOT_VALUE_TIERS_ORDERED) do
        emptyTierValues[tier] = 0
    end
end

local function GetBidConfirmationPrompt(self)
    if self.auctionItem and not self.auctionItem:GetCanUse() then
        return string.format(CLM.L["Are you sure, you want to bid on an unusable item %s?"], self.auctionItem:GetItemLink())
    end
    return false
end

local numRows
local function GenerateNamedButtonsAuctionOptions(self, auction)
    local options = {}
    local offset = 3
    local row_width = rowMultiplierBy2
    local numButtons = 0
    local usedTiers = CONSTANTS.SLOT_VALUE_TIERS_ORDERED_REVERSED

    local values = self.auctionItem and self.auctionItem:GetValues() or emptyTierValues
    if auction then -- the window is built before the first auction
        for _,tier in ipairs(usedTiers) do
            local value = tonumber(values[tier]) or 0
            local name = auction:GetFieldName(tier)
            -- Unnamed tier with a value: use the tier's own name instead of hiding the button
            if (not name or name == "") and value > 0 then
                name = CONSTANTS.SLOT_VALUE_TIERS_GUI[tier]
            end
            if name and name ~= "" and (value >= 0) then
                options[tier] = {
                    name = name,
                    desc = tostring(value),
                    type = "execute",
                    func = (function()
                        CLM.MODULES.BiddingManager:Bid(self.auctionItem, value, tier)
                        if GetAdvanceOnBid(self) then self:Advance() end
                        CloseOnBid(self)
                    end),
                    width = row_width,
                    order = offset,
                    confirm = (function() return GetBidConfirmationPrompt(self) end),
                }
                offset = offset + 1
                numButtons = numButtons + 1
            end
        end
    end
    -- Off spec: bids the base value as an OS bid
    if auction and auction:GetUseOS() then
        local value = tonumber(values[CONSTANTS.SLOT_VALUE_TIER.BASE]) or 0
        options.os = {
            name = CLM.L["OS"],
            desc = CLM.L["Off spec bid."],
            type = "execute",
            func = (function()
                CLM.MODULES.BiddingManager:Bid(self.auctionItem, value, CONSTANTS.BID_TYPE.OFF_SPEC)
                if GetAdvanceOnBid(self) then self:Advance() end
                CloseOnBid(self)
            end),
            width = row_width,
            order = offset,
            confirm = (function() return GetBidConfirmationPrompt(self) end),
        }
        offset = offset + 1
        numButtons = numButtons + 1
    end
    local isEven = true
    local cancelPassWidth = rowMultiplierBy2
    if (numButtons %2 ~= 0) then
        cancelPassWidth = rowMultiplierBy4
        isEven = false
    end

    options.pass = {
        name = CLM.L["Pass"],
        desc = CLM.L["Notify that you are passing on the item."],
        type = "execute",
        func = (function()
            CLM.MODULES.BiddingManager:Pass(self.auctionItem)
            if GetAdvanceOnBid(self) then self:Advance() end
            CloseOnBid(self)
        end),
        width = cancelPassWidth,
        order = offset
    }
    options.cancel = {
        name = CLM.L["Cancel"],
        desc = CLM.L["Cancel your bid."],
        type = "execute",
        func = (function()
            CLM.MODULES.BiddingManager:CancelBid(self.auctionItem)
            if GetAdvanceOnBid(self) then self:Advance() end
            CloseOnBid(self)
        end),
        width = cancelPassWidth,
        order = offset + 1
    }

    numRows = 0
    if isEven then numRows = 1 end
    numRows = numRows + math.ceil(numButtons/2)

    self.top:SetHeight(BASE_HEIGHT + BIDS_HEIGHT + ((numRows)*ROW_HEIGHT))

    buttonOptions.args = options
end

local function GenerateAuctionOptions(self)
    local icon, itemLink = "Interface\\Icons\\INV_Misc_QuestionMark", "item:0"
    self.note = ""
    local auctionItem = self.auctionItem
    if auctionItem and not auctionItem.item:IsItemEmpty() then
        _, _, _, _, icon = UTILS.GetItemInfoInstant(auctionItem:GetItemID())
        itemLink = auctionItem:GetItemLink()
    end

    local auction = CLM.MODULES.BiddingManager:GetAuctionInfo()

    itemOptions.args = {
        icon = {
            name = "",
            type = "execute",
            image = icon,
            func = (function() end),
            tooltipHyperlink = itemLink,
            width = rowMultiplierBy9,
            order = 1
        },
        item = {
            name = "",
            type = "input",
            get = (function(i) return itemLink or "" end),
            set = (function(i,v) end), -- Intentionally: do not override
            width = 5*rowMultiplierBy9,
            order = 2,
            tooltipHyperlink = itemLink,
        },
        next = {
            name = CLM.L["Next"],
            desc = CLM.L["Next item"],
            type = "execute",
            func = (function()
                self:Advance()
                CloseOnBid(self)
            end),
            width = 3*rowMultiplierBy9,
            order = 4
        },
    }

    GenerateNamedButtonsAuctionOptions(self, auction)
end

local function UpdateOptions(self)
    -- self.top:SetWidth(BASE_WIDTH)
    GenerateAuctionOptions(self)
end

local function CreateOptions(self)
    -- Item Display
    local ItemGroup = AceGUI:Create("SimpleGroup")
    ItemGroup:SetLayout("Flow")
    ItemGroup:SetWidth(DATA_GROUP_WIDTH)
    self.ItemGroup = ItemGroup
    -- Button Display
    local ButtonGroup = AceGUI:Create("SimpleGroup")
    ButtonGroup:SetLayout("Flow")
    ButtonGroup:SetWidth(DATA_GROUP_WIDTH)
    self.ButtonGroup = ButtonGroup
    -- Build options
    UpdateOptions(self)
    -- register
    AceConfigRegistry:RegisterOptionsTable(ITEM_REGISTRY, itemOptions)
    AceConfigDialog:Open(ITEM_REGISTRY, ItemGroup)
    AceConfigRegistry:RegisterOptionsTable(BUTTON_REGISTRY, buttonOptions)
    AceConfigDialog:Open(BUTTON_REGISTRY, ButtonGroup)

    return ItemGroup, ButtonGroup
end
-------------------
--- UI Creation ---
-------------------
local function CreateItemList(self)
    local ItemList = AceGUI:Create("BPEPGPLibScrollingTable")
    self.ItemList = ItemList
    ItemList:SetHeaderless()
    ItemList:SetDisplayRows(8, 32)
    ItemList:SetDisplayCols({
        { name = "",  width = 32, DoCellUpdate = UTILS.LibStItemCellUpdate }, -- Icon
    })
    ItemList:RegisterEvents({
        OnClick = (function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
            if not (row or realrow) then return true end -- Disable sort
            UTILS.LibStSingleSelectClickHandler(table, nil, rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
            local _, selection = next(table:GetSelection())
            local rowData = table:GetRow(selection)
            if rowData then
                local auctionItem = data[realrow].cols[column].item
                OverrideNextItem(self, auctionItem)
                self:SetVisibleAuctionItem(auctionItem)
                self:Refresh()
            end
            return true
        end),
        -- OnEnter handler -> on hover
        OnEnter = (function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            local status = table.DefaultEvents["OnEnter"](rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            local rowData = table:GetRow(realrow)
            if not rowData or not rowData.cols then return status end
            GameTooltip:SetOwner(rowFrame, "ANCHOR_LEFT")
            GameTooltip:SetHyperlink(rowData.cols[column].value or "item:0")
            GameTooltip:Show()
            return status
        end),
        -- OnLeave handler -> on hover out
        OnLeave = (function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            local status = table.DefaultEvents["OnLeave"](rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
            GameTooltip:Hide()
            return status
        end),
    })
    ItemList:EnableSelection(false)
    ItemList:SetTransparent()
    return ItemList
end

local function CreateBidList(self)
    local BidList = AceGUI:Create("BPEPGPLibScrollingTable")
    BidList:SetDisplayRows(BID_ROWS, BID_ROW_HEIGHT)
    local columns = {
        {name = "", width = 18, DoCellUpdate = UTILS.LibStClassCellUpdate },
        {name = CLM.L["Name"],  width = 100,
            comparesort = UTILS.LibStCompareSortWrapper(UTILS.LibStModifierFn), DoCellUpdate = UTILS.LibStNameCellUpdate
        }, -- + (isElvUI and 30 or 0)) },
        {name = CLM.L["Bid"],   width = 100, color = colorGreen,
            sort = ScrollingTable.SORT_DSC,
            sortnext = 4,
            align = "CENTER",
            DoCellUpdate = (function(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
                table.DoCellUpdate(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
                frame.text:SetText(data[realrow].cols[column].text or data[realrow].cols[column].value)
            end)
        },
        {name = CLM.L["Current"],  width = 80, color = colorGold,
            sortnext = 5,
            align = "CENTER"
        },
        {name = CLM.L["Roll"],  width = 40, color = {r = 0.93, g = 0.70, b = 0.13, a = 1.0},
            sortnext = 2,
            align = "CENTER"
        },
        {name = "", width = 18, DoCellUpdate = UTILS.LibStItemCellUpdate },
        {name = "", width = 18, DoCellUpdate = UTILS.LibStItemCellUpdate },
        {name = "", width = 18, DoCellUpdate = UTILS.LibStItemCellUpdate },
        {name = "", width = 18, DoCellUpdate = UTILS.LibStItemCellUpdate },
        {name = "", width = 18, DoCellUpdate = UTILS.LibStItemCellUpdate },
    }
    BidList:SetDisplayCols(columns)
    -- BidList:RegisterEvents({
    --     OnClick = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
    --         UTILS.LibStSingleSelectClickHandler(table, nil, rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
    --         return true
    --     end
    -- })
    -- TODO disable click
    BidList:EnableSelection(false)
    self.BidList = BidList
    return BidList
end

local function CreateDataGroup(self)
    local DataGroup = AceGUI:Create("SimpleGroup")
    DataGroup:SetLayout("Flow")
    DataGroup:SetWidth(DATA_GROUP_WIDTH)

    local ItemGroup, ButtonGroup = CreateOptions(self)
    local BidList = CreateBidList(self)

    DataGroup:AddChild(ItemGroup)
    DataGroup:AddChild(ButtonGroup)
    DataGroup:AddChild(BidList)

    self.DataGroup = DataGroup
    return DataGroup
end

local function UpdateUIStructure(self)
    local itemRows = UTILS.Saturate(numRows + 6, 1, 8)
    self.ItemList:SetDisplayRows(itemRows, 32)
end

local function Create(self)
    LOG:Trace("BiddingManagerGUI:Create()")
    -- Main Frame
    local f = AceGUI:Create("Window")
    self.top = f

    f:SetTitle(CLM.L["Bidding"])
    f:SetLayout("table")
    f:EnableResize(false)
    f:SetHeight(BASE_HEIGHT)
    -- f.frame:SetScript("OnMouseWheel", (function(frame, delta)
    --     if IsControlKeyDown() then
    --         self.db.scale = UTILS.ResizeFrame(frame, (delta > 0), self.db.scale)
    --         RescaleLibCandyBar(self.bar, self.db.scale)
    --     end
    -- end))
    UTILS.MakeFrameCloseOnEsc(f.frame, "BPEPGP_Bidding_GUI")
    -- self.barPreviousPercentageLeft = 1
    -- self.duration = 1

    local ItemList = CreateItemList(self)
    local DataGroup = CreateDataGroup(self)
    local listWidth = ItemList:GetWidth()
    f:SetWidth(DATA_GROUP_WIDTH + listWidth + (isElvUI and 30 or 0))
    f:SetUserData("table", { columns = {listWidth, DATA_GROUP_WIDTH}, alignV =  "top" })

    f:AddChild(ItemList)
    f:AddChild(DataGroup)

    UpdateUIStructure(self)

    -- self:SetInputValue(0)
    -- -- Handle onHide information passing whenever the UI is closed
    -- local oldOnHide = f.frame:GetScript("OnHide")
    -- f.frame:SetScript("OnHide", (function(...)
    --     CLM.MODULES.BiddingManager:NotifyHide()
    --     oldOnHide(...)
    -- end))
    -- Hide by default
    RestoreLocation(self)
    f:Hide()
end

function BiddingManagerGUI:RefreshItemList()
    local auction = CLM.MODULES.BiddingManager:GetAuctionInfo()
    if auction then
        local itemList = {}
        local current = self.auctionItem
        for _, auctionItem in pairs(auction:GetItems()) do
            if GetIgnoreUnusable(self) and auctionItem:GetCanUse() or not GetIgnoreUnusable(self) or not auction:HasUsableItems() then
                local iconColor, note
                if not auctionItem:GetCanUse() then
                    iconColor = colorRed
                    note = CLM.L["Can't use"]
                elseif auctionItem:BidAccepted() then
                    if CONSTANTS.BID_TYPE_REMOVING_BIDS[auctionItem:GetBid():Type()] then
                        iconColor = colorBlue
                        note = CLM.L["Pass"] .. " / " .. CLM.L["Cancel"]
                    else
                        iconColor = colorGreen
                        note = CLM.L["Bid accepted!"]
                    end
                elseif auctionItem:BidDenied() then
                    iconColor = colorGold
                    note = CLM.L["Bid denied!"]
                end
                if current and current:GetItemLink() == auctionItem:GetItemLink() then
                    iconColor = colorTurquoise
                end
                local total = auctionItem:GetTotal()
                local textColor
                if total > 1 then
                    textColor = { r = 0.2, g = 0.8, b = 0.2, a = 1.0 }
                else
                    textColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
                end
                itemList[#itemList+1] = { cols = { {value = auctionItem:GetItemLink(), item = auctionItem, iconColor = iconColor, note = note, overlay = { text = total, color = textColor } }}}
            end
        end
        self.ItemList:SetData(itemList)
    end
end

--------------
--- PUBLIC ---
--------------
function BiddingManagerGUI:Initialize()
    LOG:Trace("BiddingManagerGUI:Initialize()")
    InitializeDB(self)

    CreateConfig(self)

    Create(self)

    RegisterSlash(self)

    self.ToggleTestBar = ToggleTestBar

    CLM.MODULES.EventManager:RegisterWoWEvent({"PLAYER_LOGOUT"}, (function() StoreLocation(self) end))
    CLM.MODULES.EventManager:RegisterWoWEvent({"PLAYER_REGEN_DISABLED"}, (function()
        if GetHideInCombat(self) then
            if self.top:IsVisible() then
                self.showAfterCombat = true
                self:HideDelayed()
            end
        end
    end))
    CLM.MODULES.EventManager:RegisterWoWEvent({"PLAYER_REGEN_ENABLED"}, (function()
        if self.showAfterCombat then
            self.showAfterCombat = nil

            if not CLM.MODULES.BiddingManager:IsAuctionInProgress() then return end
            self:ShowDelayed()
        end
    end))
    self._initialized = true
end

function BiddingManagerGUI:BuildBidOrder()
    local auction = CLM.MODULES.BiddingManager:GetAuctionInfo()

    self.auctionOrder = {}
    self.nextItem = 1

    if not auction then return end

    for uid in pairs(auction:GetItems()) do
        self.auctionOrder[#self.auctionOrder+1] = uid
    end

    self:Advance()
    -- If after advance item is unusable, we advance it one more time if there are usable items to get first usable item
    if auction:HasUsableItems() and not self.auctionItem:GetCanUse() then
        self:Advance()
    end
end

local toggleCb = (function() BiddingManagerGUI:Toggle() end)
function BiddingManagerGUI:StartAuction()
    self:BuildBidOrder()
    -- Hide Test Bar if present
    HideTestBar(self)
    -- Build Bar
    self.bar = CLM.MODELS.BiddingTimerBar:New(
        self.auctionItem,
        CLM.MODULES.BiddingManager:GetAuctionInfo(),
        {
            anchor = self.db.barLocation,
            width = self.db.barWidth,
            height = self.db.barHeight,
            texture = self.db.barTexture,
            fontSize = self.db.barFontSize,
            fontName = self.db.barFontName,
            callback = toggleCb
        }
    )

    if GetAutoOpen(self) then
        if GetHideInCombat(self) and InCombatLockdown() then
            self.showAfterCombat = true
        else
            self:Show()
        end
    end
end

function BiddingManagerGUI:EndAuction()
    StoreLocation(self)

    if self.bar then
        self.bar:Stop()
        self.bar = nil
    end
end

function BiddingManagerGUI:AntiSnipe()
    if self.bar then
        self.bar:UpdateTime(CLM.MODULES.BiddingManager:GetAuctionInfo():GetAntiSnipe())
    end
end

---@param auctionItem AuctionItem
function BiddingManagerGUI:SetVisibleAuctionItem(auctionItem)
    self.auctionItem = auctionItem
end

local function BuildBidRow(name, response, roster, auction)
    local profile = CLM.MODULES.ProfileManager:GetProfileByName(name)
    local class, classColor, current = "", nil, 0
    if profile then
        class = profile:ClassInternal()
        classColor = UTILS.GetClassColor(profile:Class())
        if roster then
            current = roster:Priority(profile:GUID())
        end
    end
    local bidTypeString
    if CONSTANTS.SLOT_VALUE_TIERS[response:Type()] then
        bidTypeString = auction:GetFieldDisplayName(response:Type())
    end
    local bidColor
    if response:Type() == CONSTANTS.BID_TYPE.OFF_SPEC then
        bidColor = colorTurquoise
    end
    local color, desaturate
    if CONSTANTS.BID_TYPE_HIDDEN[response:Type()] then
        color = colorGrey
        desaturate = true
        bidTypeString = response:Type() == CONSTANTS.BID_TYPE.CANCEL and CLM.L["Cancel"] or CLM.L["Pass"]
    end
    local data = {
        {value = class, color = color, desaturate = desaturate},
        {value = name, color = color or classColor},
        {value = response:Value(), text = bidTypeString, bidType = response:Type(), color = color or bidColor},
        {value = current, color = color},
        {value = response:Roll(), color = color},
    }

    local items = response:Items()
    local emptyItems = 5-#items
    for _=1,emptyItems do
        data[#data+1] = {}
    end
    for _, item in ipairs(items) do
        data[#data+1] = {value = item, desaturate = desaturate}
    end

    return {cols = data}
end

function BiddingManagerGUI:RefreshBidList()
    local bidList = {}
    local item = self.auctionItem
    local auction = CLM.MODULES.BiddingManager:GetAuctionInfo()
    if item and auction then
        local roster = auction:GetRoster()
        for name, response in pairs(item:GetAllResponses()) do
            local include = true
            if (response:Type() == CONSTANTS.BID_TYPE.CANCEL and not GetIncludeCancels(self)) or
               (response:Type() == CONSTANTS.BID_TYPE.PASS and not GetIncludePasses(self)) then
                include = false
            end
            if include then
                bidList[#bidList+1] = BuildBidRow(name, response, roster, auction)
            end
        end
    end
    self.BidList:SetData(bidList)
end

local function UpdateBarInfo(self)
    if self.bar then
        self.bar:UpdateInfo(self.auctionItem)
    end
end

local function UpdateCurrentStandings(self)
    local auction = CLM.MODULES.BiddingManager:GetAuctionInfo()
    if not auction then return end
    local roster = CLM.MODULES.BiddingManager:GetAuctionInfo():GetRoster()
    if roster and roster:IsProfileInRoster(whoamiGUID) then
        local value = tostring(roster:Priority(whoamiGUID)) .. " " .. CLM.L["PR"]
        self.top:SetTitle(CLM.L["Bidding"] .. " | " .. CLM.L["Current"] .. ": " .. value)
    end
end

function BiddingManagerGUI:Refresh()
    LOG:Trace("BiddingManagerGUI:Refresh()")
    if not self._initialized then return end

    UpdateOptions(self)
    AceConfigDialog:Open(ITEM_REGISTRY, self.ItemGroup) -- Refresh the config gui panel
    AceConfigDialog:Open(BUTTON_REGISTRY, self.ButtonGroup) -- Refresh the config gui panel
    UpdateUIStructure(self)
    self:RefreshItemList()
    UpdateBarInfo(self)
    UpdateCurrentStandings(self)
    self:RefreshBidList()
end

function BiddingManagerGUI:Toggle()
    LOG:Trace("BiddingManagerGUI:Toggle()")
    if not self._initialized then return end
    if self.top:IsVisible() then
        self:Hide()
    else
        self:Refresh()
        self:Show()
    end
end

function BiddingManagerGUI:Show()
    LOG:Trace("BiddingManagerGUI:Show()")
    if not self._initialized then return end
    if not self.top:IsVisible() then
        self:Refresh()
        self.top:Show()
    end
end

function BiddingManagerGUI:Hide()
    LOG:Trace("BiddingManagerGUI:Hide()")
    if not self._initialized then return end
    if self.top:IsVisible() then
        self.top:Hide()
    end
end

function BiddingManagerGUI:ShowDelayed()
    LOG:Trace("BiddingManagerGUI:ShowDelayed()")
    if not self._initialized then return end
    if not self.top:IsVisible() then
        self:Refresh()
        self.top:Show()
        UTILS.FadeIn(self.top.frame, 0.3)
    end
end

local function HideInternal()
    BiddingManagerGUI.top:Hide()
    BiddingManagerGUI.top.frame:SetAlpha(1)
end

function BiddingManagerGUI:HideDelayed()
    LOG:Trace("BiddingManagerGUI:HideDelayed()")
    if not self._initialized then return end
    if self.top:IsVisible() then
        UTILS.FadeOut(self.top.frame, 0.3, 1, 0, {
            finishedFunc = HideInternal
        })
    end
end

-- function BiddingManagerGUI:HideIfDone()
--     LOG:Trace("BiddingManagerGUI:HideIfDone()")
--     if not self._initialized then return end
--     if self.top:IsVisible() then
--         local auction = CLM.MODULES.BiddingManager:GetAuctionInfo()
--         if auction then

--             self.top:Hide()
--         end
--     end
-- end

function BiddingManagerGUI:RegisterSlash()
    local options = {
        bid = {
            type = "execute",
            name = CLM.L["Bidding"],
            desc = CLM.L["Toggle Bidding window display"],
            handler = self,
            func = "Toggle",
        }
    }
    CLM.MODULES.ConfigManager:RegisterSlash(options)
end

function BiddingManagerGUI:Reset()
    LOG:Trace("BiddingManagerGUI:Reset()")
    self.top:ClearAllPoints()
    self.top:SetPoint("CENTER", 0, 0)
    self.db.location = nil
    self.db.barLocation = nil
end

CLM.GUI.BiddingManager = BiddingManagerGUI
