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
    Trade list window (Phase 9e, ui-redesign.md "Trade list", R7: stays its own window). Officers only.
    Awarded items still to trade, with the winner. Right-click: Open trade · Remove.
    Alt-click opens the trade directly.
]]--

local WIDTH, HEIGHT = 350, 230

---@class TradeListGUI
---@field window table?
---@field _initialized boolean
local TradeListGUI = {}

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

local function Build(self)
    local window = UI.CreateWindow({
        name = "BPEPGP_TradeListWindow",
        title = CLM.L["Trade List"],
        width = WIDTH, height = HEIGHT,
        dbKey = "tradelistwindow",
    })
    self.window = window
    local inset = UI.CreateInset(window)
    inset:SetPoint("TOPLEFT", S.S, -28)
    inset:SetPoint("BOTTOMRIGHT", -S.S, S.S + 16)
    local footer = UI.CreateLabel(window, CLM.L["Alt-click: open trade · right-click: more"], "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", S.M, S.S)
    self.list = UI.CreateList(inset, {
        columns = {
            { key = "item", title = CLM.L["Item"], width = 0 },
            { key = "winner", title = CLM.L["Winner"], width = 110, classIcon = true,
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
    window:HookScript("OnShow", function() self:Refresh() end)
end

---@param visible boolean? only refresh when the window is shown
function TradeListGUI:Refresh(visible)
    if not self._initialized or not self.window then return end
    if visible and not self.window:IsShown() then return end
    self.list:SetData(BuildRows())
end

function TradeListGUI:Initialize()
    LOG:Trace("TradeListGUI:Initialize()")
    if not CLM.MODULES.ACL:IsTrusted() then return end
    CLM.MODULES.ConfigManager:RegisterSlash({
        trade = {
            type = "execute",
            name = "Trade List",
            desc = CLM.L["Toggle Trade List window display"],
            handler = self,
            func = "Toggle",
        }
    })
    self._initialized = true
end

function TradeListGUI:Toggle()
    if not self._initialized then return end
    if not self.window then Build(self) end
    self.window:SetShown(not self.window:IsShown())
end

function TradeListGUI:Reset()
    if not self.window then return end
    self.window:ClearAllPoints()
    self.window:SetPoint("CENTER", 0, 0)
end

CLM.GUI.TradeList = TradeListGUI
