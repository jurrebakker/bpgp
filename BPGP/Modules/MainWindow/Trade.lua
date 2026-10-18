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
    Trade tab (officers): awarded items still to trade, with the winner. It was its own window
    (9e, R7) until the raid test (2026-10-18) moved it into the main window, right of Auction.
    Right-click: Open trade · Remove. Alt-click opens the trade directly. /bpgp trade opens the tab.
]]--

local Trade = {
    key = "trade",
    order = 1.6, -- right after Auction
    title = CLM.L["Trade"],
    officerOnly = true,
}

local function BuildRows()
    local rows = {}
    for playerName, trackedList in pairs(CLM.MODULES.TradeHelper:GetTracked()) do
        local profile = CLM.MODULES.ProfileManager:GetProfileByName(playerName)
        local classFile = profile and UTILS.CanonicalClass(profile:ClassInternal()) or nil
        for index, itemLink in ipairs(trackedList) do
            rows[#rows + 1] = {
                id = playerName .. "#" .. index,
                player = playerName,
                itemLink = itemLink,
                classFile = classFile,
                values = { item = itemLink, winner = Ambiguate(playerName, "none") },
            }
        end
    end
    return rows
end

local function Remove(row)
    UI.Confirm(string.format(CLM.L["Remove %s for %s from the trade list?"], tostring(row.itemLink), row.values.winner), function()
        CLM.MODULES.TradeHelper:Remove(row.itemLink, row.player)
    end)
end

function Trade:Build(content)
    local inset = UI.CreateInset(content)
    inset:SetAllPoints(content)
    self.list = UI.CreateList(inset, {
        columns = {
            { key = "item", title = CLM.L["Item"], width = 0 },
            { key = "winner", title = CLM.L["Winner"], width = 160, classIcon = true,
              color = function(row) return UI.GetClassColor(row.classFile) end },
        },
        sortKey = "winner",
        onSelectionChanged = function(selection)
            local row = selection[1]
            if row and IsAltKeyDown() then CLM.MODULES.TradeHelper:InitiateTrade(row.player) end
        end,
        onRightClick = function(row, rowFrame)
            UI.ShowContextMenu(rowFrame, row.values.winner, {
                { text = CLM.L["Open trade"], func = function() CLM.MODULES.TradeHelper:InitiateTrade(row.player) end },
                { divider = true },
                { text = CLM.L["Remove"], color = UI.COLOR.BAD, func = function() Remove(row) end },
            })
        end,
        onEnter = function(row, rowFrame)
            if not row.itemLink then return end
            GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(row.itemLink)
            GameTooltip:Show()
        end,
    })
    self.list:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.list:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
end

function Trade:Refresh()
    if not self.list then return end
    local rows = BuildRows()
    self.list:SetData(rows)
    self.window:SetSubtitle(#rows > 0 and string.format(CLM.L["%s to trade"], #rows) or "")
    self.window:SetPageFooter(CLM.L["Alt-click: open trade · right-click: more"])
end

CLM.GUI.MainWindow:RegisterPage(Trade)

--[[
 * CLM.GUI.TradeList: what TradeHelper and /bpgp trade call *
]]--

---@class TradeListGUI
---@field _initialized boolean
local TradeListGUI = {}

function TradeListGUI:Initialize()
    LOG:Trace("TradeListGUI:Initialize()")
    if not CLM.MODULES.ACL:IsTrusted() then return end
    CLM.MODULES.ConfigManager:RegisterSlash({
        trade = {
            type = "execute",
            name = "Trade List",
            desc = CLM.L["Open the Trade tab"],
            handler = self,
            func = "Toggle",
        }
    })
    self._initialized = true
end

-- Open the main window on the Trade tab
function TradeListGUI:Toggle()
    if not self._initialized then return end
    CLM.GUI.MainWindow:Open(Trade.key)
end

---@param visible boolean? only refresh when the tab is shown
function TradeListGUI:Refresh(visible)
    if not (Trade.content and Trade.list) then return end
    if visible and not Trade.content:IsVisible() then return end
    Trade:Refresh()
end

CLM.GUI.TradeList = TradeListGUI
