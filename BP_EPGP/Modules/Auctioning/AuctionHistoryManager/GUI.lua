-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI
local S = UI.SPACE

--[[
    Auction history window (Phase 9e, ui-redesign.md "Auction history"). Officers only.
    Finished auctions, newest first. Click an entry to show its bids under it.
    Right-click: Post bids · Remove auction · Remove older than 7 days · Remove all.
]]--

local WIDTH, HEIGHT = 265, 400
local SEVEN_DAYS = 7 * 24 * 3600

---@class AuctionHistoryGUI
---@field window table?
---@field expanded table
---@field _initialized boolean
local AuctionHistoryGUI = { expanded = {} }

local function Manager()
    return CLM.MODULES.AuctionHistoryManager
end

local function BidderColor(name)
    local profile = CLM.MODULES.ProfileManager:GetProfileByName(name)
    return profile and UI.GetClassColor(UTILS.CanonicalClass(profile:ClassInternal())) or UI.COLOR.WHITE
end

local function BuildRows(self)
    local rows = {}
    for seq, auction in ipairs(Manager():GetHistory()) do
        local key = tostring(auction.time) .. ":" .. tostring(auction.id)
        rows[#rows + 1] = {
            id = "a" .. key,
            seq = seq,
            key = key,
            auction = auction,
            values = { order = #rows, item = auction.link or ("item:" .. tostring(auction.id)), time = auction.time or 0 },
        }
        if self.expanded[key] then
            local bids = {}
            for bidder, bid in pairs(auction.bids or {}) do
                bids[#bids + 1] = { name = bidder, bid = bid }
            end
            table.sort(bids, function(a, b)
                if a.bid ~= b.bid then return (tonumber(a.bid) or 0) > (tonumber(b.bid) or 0) end
                return a.name < b.name
            end)
            if #bids == 0 then
                rows[#rows + 1] = { id = "b" .. key, isBid = true, values = { order = #rows, item = "    " .. CLM.L["No bids"], time = 0 } }
            end
            for _, entry in ipairs(bids) do
                local text = BidderColor(entry.name):WrapTextInColorCode(Ambiguate(entry.name, "none"))
                local bid = tostring(entry.bid)
                local names, rolls = auction.names or {}, auction.rolls or {}
                if names[entry.name] then bid = names[entry.name] .. " " .. bid end
                if rolls[entry.name] then bid = bid .. " / " .. tostring(rolls[entry.name]) end
                rows[#rows + 1] = {
                    id = "b" .. key .. entry.name,
                    isBid = true,
                    values = { order = #rows, item = "    " .. text .. "  " .. bid, time = 0 },
                }
            end
        end
    end
    return rows
end

local function ShowMenu(self, row, owner)
    UI.ShowContextMenu(owner, row.auction.link, {
        { text = CLM.L["Post bids"], func = function() Manager():PostById(row.seq) end },
        { divider = true },
        { text = CLM.L["Remove auction"], color = UI.COLOR.BAD, func = function()
            UI.Confirm(string.format(CLM.L["Remove the auction of %s from the history?"], row.auction.link or ""), function()
                Manager():Remove(row.seq)
            end)
        end },
        { text = CLM.L["Remove older than 7 days"], color = UI.COLOR.BAD, func = function()
            UI.Confirm(CLM.L["Remove every auction older than 7 days from the history?"], function()
                Manager():RemoveOld(SEVEN_DAYS)
            end)
        end },
        { text = CLM.L["Remove all..."], color = UI.COLOR.BAD, func = function()
            UI.Confirm(CLM.L["Remove the whole auction history?"], function() Manager():Wipe() end)
        end },
    })
end

local function Build(self)
    local window = UI.CreateWindow({
        name = "BPEPGP_AuctionHistoryWindow",
        title = CLM.L["Auction History"],
        width = WIDTH, height = HEIGHT,
        dbKey = "auctionhistorywindow",
    })
    self.window = window
    local inset = UI.CreateInset(window)
    inset:SetPoint("TOPLEFT", S.S, -28)
    inset:SetPoint("BOTTOMRIGHT", -S.S, S.S + 16)
    self.footer = UI.CreateLabel(window, "", "GameFontDisableSmall")
    self.footer:SetPoint("BOTTOMLEFT", S.M, S.S)
    self.list = UI.CreateList(inset, {
        columns = {
            { key = "item", title = CLM.L["Item"], width = 0, sortable = false },
            { key = "time", title = CLM.L["Time"], width = 70, sortable = false,
              text = function(row) return row.isBid and "" or date(CLM.L["%m/%d %H:%M"], row.values.time) end,
              color = function() return UI.COLOR.GREY end },
        },
        sortKey = "order",
        onSelectionChanged = function(selection)
            local row = selection[1]
            if row and not row.isBid then
                self.expanded[row.key] = not self.expanded[row.key] or nil
                self.list:ClearSelection()
                self:Refresh()
            end
        end,
        onRightClick = function(row, rowFrame)
            if not row.isBid then ShowMenu(self, row, rowFrame) end
        end,
        onEnter = function(row, rowFrame)
            if row.isBid then return end
            GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(row.auction.link or ("item:" .. tostring(row.auction.id)))
            GameTooltip:Show()
        end,
    })
    self.list:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.list:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
    window:HookScript("OnShow", function() self:Refresh() end)
end

---@param visible boolean? only refresh when the window is shown
function AuctionHistoryGUI:Refresh(visible)
    if not self._initialized or not self.window then return end
    if visible and not self.window:IsShown() then return end
    self.list:SetData(BuildRows(self))
    self.footer:SetText(string.format(CLM.L["%s auctions · click to show bids"], #Manager():GetHistory()))
end

function AuctionHistoryGUI:Initialize()
    LOG:Trace("AuctionHistoryGUI:Initialize()")
    if not CLM.MODULES.ACL:IsTrusted() then return end
    CLM.MODULES.ConfigManager:RegisterSlash({
        auction_history = {
            type = "execute",
            name = "Auction History",
            desc = CLM.L["Toggle Auction History window display"],
            handler = self,
            func = "Toggle",
        }
    })
    self._initialized = true
end

function AuctionHistoryGUI:Toggle()
    if not self._initialized then return end
    if not self.window then Build(self) end
    self.window:SetShown(not self.window:IsShown())
end

function AuctionHistoryGUI:Reset()
    if not self.window then return end
    self.window:ClearAllPoints()
    self.window:SetPoint("CENTER", 0, 0)
end

CLM.GUI.AuctionHistory = AuctionHistoryGUI
