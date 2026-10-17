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
    Award window (Phase 9e, ui-redesign.md "Award"): award an item outside an auction.
    Item, player, GP with the item's tier values as a hint, Cancel · Award. Opened with the award
    click on an item link, by right-click → Award item in Standings (player filled in, R7), or
    /bpepgp award. Officers only.
]]--

local WIDTH, HEIGHT = 300, 205

---@class AwardGUI
---@field window table?
---@field itemLink string?
---@field awardPlayer string?
---@field _initialized boolean
local AwardGUI = {}

---@return Roster?
local function GetRoster()
    return CLM.MODULES.RosterManager:GetRoster()
end

local function PlayerOptions()
    local roster = GetRoster()
    local options = {}
    if not roster then return options end
    for _, GUID in ipairs(roster:Profiles()) do
        local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
        if profile then
            local color = UI.GetClassColor(UTILS.CanonicalClass(profile:ClassInternal()))
            options[#options + 1] = { text = color:WrapTextInColorCode(profile:ShortName()), value = profile:Name(), sort = profile:Name() }
        end
    end
    table.sort(options, function(a, b) return a.sort < b.sort end)
    return options
end

-- "Base 20 · Small 60 · ... · Max 300" from the slot values or the item's override
local function TierHint(itemLink)
    local roster = GetRoster()
    if not (roster and itemLink) then return "" end
    local values = roster:GetItemValuesFromItemLink(itemLink) or {}
    local parts = {}
    for _, tier in ipairs(CONSTANTS.SLOT_VALUE_TIERS_ORDERED) do
        if values[tier] then
            local name = UTILS.GetRosterConditionalFieldName(tier, roster, "", "")
            parts[#parts + 1] = UI.TIER_COLOR[tier]:WrapTextInColorCode(name .. " " .. tostring(values[tier]))
        end
    end
    return table.concat(parts, " · ")
end

local function SetItem(self, itemLink)
    self.itemLink = itemLink
    self.itemButton:SetItem(itemLink)
    self.itemInput:SetText(itemLink or "")
    self.hint:SetText(TierHint(itemLink))
    self:Refresh()
end

local function SetItemFromText(self, text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then SetItem(self, nil) return end
    local itemId = UTILS.GetItemInfoInstant(text)
    if not itemId then
        LOG:Message(CLM.L["Not an item: %s"], text)
        return
    end
    local item = tostring(itemId) == text and Item:CreateFromItemID(itemId) or Item:CreateFromItemLink(text)
    if item:IsItemEmpty() then return end
    item:ContinueOnItemLoad(function() SetItem(self, item:GetItemLink()) end)
end

local function Award(self)
    local roster = GetRoster()
    local value = tonumber(self.gpInput:GetText())
    if not (roster and self.itemLink and self.awardPlayer and value) then return end
    local itemId, extra = UTILS.GetItemIdFromLink(self.itemLink)
    UI.Confirm(string.format(CLM.L["Award %s to %s for %s GP?"], self.itemLink,
        UI.COLOR.GOLD:WrapTextInColorCode(Ambiguate(self.awardPlayer, "none")), tostring(value)), function()
        -- During a raid on this roster the award belongs to the raid
        local target = roster
        local raid = CLM.MODULES.RaidManager:IsInRaid() and CLM.MODULES.RaidManager:GetRaid()
        if raid and raid:Roster() == roster then target = raid end
        local link, player = self.itemLink, self.awardPlayer
        local success = CLM.MODULES.LootManager:AwardItem(target, player, link, itemId, extra, value)
        if success then
            CLM.MODULES.TradeHelper:Handle(link, player)
            self.window:Hide()
        end
    end)
end

local function Build(self)
    local window = UI.CreateWindow({
        name = "BPEPGP_AwardWindow",
        title = CLM.L["Award"],
        width = WIDTH, height = HEIGHT,
        dbKey = "awardwindow",
    })
    self.window = window
    local top = 32
    local banner = UI.CreateTestModeBanner(window)
    if banner then
        banner:SetPoint("TOPLEFT", S.S, -26)
        banner:SetPoint("TOPRIGHT", -S.S, -26)
        top = top + 24
    end

    self.itemButton = UI.CreateItemButton(window, 36)
    self.itemButton:SetPoint("TOPLEFT", S.M, -top)
    self.itemInput = UI.CreateInput(window, WIDTH - S.M * 2 - 36 - S.S - 6, false)
    self.itemInput:SetPoint("LEFT", self.itemButton, "RIGHT", S.S + 6, 0)
    self.itemInput:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    self.itemInput:HookScript("OnEditFocusLost", function(box)
        if box:GetText() ~= (self.itemLink or "") then SetItemFromText(self, box:GetText()) end
    end)
    -- Shift-click an item (bags, chat, loot) while the field has focus, or drag it onto the field or icon
    UI.AcceptItems(self.itemInput, function(link) SetItemFromText(self, link) end)
    UI.AcceptItems(self.itemButton, function(link) SetItemFromText(self, link) end)

    local playerLabel = UI.CreateLabel(window, CLM.L["Player"], "GameFontNormal")
    playerLabel:SetPoint("TOPLEFT", self.itemButton, "BOTTOMLEFT", 0, -S.M - 4)
    self.playerDropdown = UI.CreateDropdown(window, 180, PlayerOptions,
        function() return self.awardPlayer end,
        function(value) self.awardPlayer = value; self:Refresh() end)
    self.playerDropdown:SetPoint("LEFT", playerLabel, "LEFT", 80, 0)

    local gpLabel = UI.CreateLabel(window, CLM.L["GP"], "GameFontNormal")
    gpLabel:SetPoint("TOPLEFT", playerLabel, "BOTTOMLEFT", 0, -S.M - 4)
    self.gpInput = UI.CreateInput(window, 70, true, function() self:Refresh() end)
    self.gpInput:SetPoint("LEFT", gpLabel, "LEFT", 86, 0)
    self.gpInput:SetScript("OnEnterPressed", function(box) box:ClearFocus() Award(self) end)
    self.hint = UI.CreateLabel(window, "", "GameFontHighlightSmall")
    self.hint:SetPoint("TOPLEFT", gpLabel, "BOTTOMLEFT", 0, -S.S)
    self.hint:SetPoint("RIGHT", window, "RIGHT", -S.M, 0)
    self.hint:SetWordWrap(true)

    self.awardButton = UI.CreateButton(window, CLM.L["Award"], 90, function() Award(self) end)
    self.awardButton:SetPoint("BOTTOMRIGHT", -S.M, S.M)
    local cancel = UI.CreateButton(window, CLM.L["Cancel"], 90, function() window:Hide() end)
    cancel:SetPoint("RIGHT", self.awardButton, "LEFT", -S.S, 0)
end

function AwardGUI:Refresh()
    if not self.window then return end
    self.playerDropdown:Refresh()
    self.awardButton:SetEnabled(self.itemLink ~= nil and self.awardPlayer ~= nil and tonumber(self.gpInput:GetText()) ~= nil)
end

function AwardGUI:Initialize()
    LOG:Trace("AwardGUI:Initialize()")
    if not CLM.MODULES.ACL:IsTrusted() then return end
    CLM.MODULES.ConfigManager:RegisterSlash({
        award = {
            type = "input",
            name = "Award",
            desc = CLM.L["Show Award window"],
            set = function(_, args) self:Show(nil, args) end,
        }
    })
    -- Award click (Settings → Personal) on an item link opens the window with that item
    CLM.MODULES.Hooks:RegisterModifiedItemLinkClickHandler(function(modifiers, itemLink)
        if CLM.GlobalConfigs:GetAwardModifierCombination() ~= modifiers then return end
        if not itemLink then return end
        self:Show(nil, itemLink)
    end)
    self._initialized = true
end

---@param _ any
---@param itemLink string?
function AwardGUI:Show(_, itemLink)
    if not self._initialized then return end
    if not self.window then Build(self) end
    self.gpInput:SetText("")
    if itemLink and itemLink ~= "" then
        SetItemFromText(self, itemLink)
    else
        SetItem(self, nil)
    end
    self.window:Show()
    self:Refresh()
end

-- Standings right-click "Award item" (R7): open with the player filled in; the officer adds the item
---@param name string profile name
function AwardGUI:ShowForPlayer(name)
    if not self._initialized then return end
    self.awardPlayer = name
    self:Show()
end

function AwardGUI:Toggle()
    if self.window and self.window:IsShown() then self.window:Hide() else self:Show() end
end

function AwardGUI:Reset()
    if not self.window then return end
    self.window:ClearAllPoints()
    self.window:SetPoint("CENTER", 0, 0)
end

CLM.GUI.Award = AwardGUI
