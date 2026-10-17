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
    History tab: every EP/GP change, decay and item award on the roster, newest first.
    Header: type dropdown and a player/item search. Officers can remove an entry (undo) by right-click.
]]--

local TYPE = { ALL = "all", EP = "BP", GP = "GP", DECAY = "DEC" }
local TYPE_COLOR = { BP = UI.COLOR.EP, GP = UI.COLOR.GP, DEC = UI.COLOR.GREY }
local ITEM_COLOR = CreateColor(0.64, 0.21, 0.93)

local History = {
    key = "history",
    order = 2,
    title = CLM.L["History"],
    typeFilter = TYPE.ALL,
    search = "",
    requestedItems = {},
}

---@param creator number integer GUID
---@return string name, table color
local function Author(creator)
    local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(UTILS.getGuidFromInteger(creator))
    if not profile then return CLM.L["Unknown"], UI.COLOR.GREY end
    return profile:ShortName(), UI.GetClassColor(UTILS.CanonicalClass(profile:ClassInternal()))
end

---@param profile Profile
---@return table ColorMixin
local function ProfileColor(profile)
    return UI.GetClassColor(UTILS.CanonicalClass(profile:ClassInternal()))
end

-- "Raid (18)", "Roster (42)" or the single player's name
local function TargetText(history, profiles)
    if #profiles == 1 then
        return profiles[1]:ShortName(), ProfileColor(profiles[1])
    end
    local entry = history:Entry()
    local class = entry and entry.class and entry:class()
    local label = CLM.L["Players"]
    if class == "DR" then
        label = CLM.L["Raid"]
    elseif class == "DO" or class == "DT" then
        label = CLM.L["Roster"]
    end
    return string.format("%s (%s)", label, #profiles), UI.COLOR.WHITE
end

---@param loot Loot
---@return string? itemLink nil while the item isn't cached yet
local function LootLink(self, loot)
    local _, itemLink = UTILS.GetItemInfo(loot:String())
    if itemLink then return UTILS.SpoofLink(itemLink, loot:Extra()) end
    local id = loot:Id()
    if id and not self.requestedItems[id] then
        self.requestedItems[id] = true
        local item = Item:CreateFromItemID(id)
        if not item:IsItemEmpty() then
            item:ContinueOnItemLoad(function() self.window:Refresh() end)
        end
    end
end

local function SignedValue(value)
    value = tonumber(value) or 0
    return (value >= 0 and "+" or "") .. tostring(value)
end

local function BuildPointRow(history, index)
    local reason = history:Reason() or 0
    local isDecay = reason == CONSTANTS.POINT_CHANGE_REASON.DECAY
    local kind = isDecay and TYPE.DECAY or (history:Type() == CONSTANTS.POINT_CHANGE_TYPE.SPENT and TYPE.GP or TYPE.EP)
    local profiles = history:Profiles()
    local target, targetColor = TargetText(history, profiles)
    local note = history:Note()
    if note == "" then note = CONSTANTS.POINT_CHANGE_REASONS.ALL[reason] or "" end
    local amount = isDecay
        and string.format("-%s %%", tostring(history:Value()))
        or SignedValue(history:Value())
    if isDecay and history:Type() ~= CONSTANTS.POINT_CHANGE_TYPE.TOTAL then
        amount = amount .. " " .. UTILS.DecodePointTypeChangeName(history:Type())
    end
    local by, byColor = Author(history:Creator())
    local entry = history:Entry()
    local searchText = target .. " " .. note
    for _, profile in ipairs(profiles) do searchText = searchText .. " " .. profile:Name() end
    return {
        id = entry and entry.uuid and ("p" .. entry:uuid()) or ("p" .. index),
        history = history,
        kind = kind,
        targetColor = targetColor,
        byColor = byColor,
        search = searchText:lower(),
        values = { time = history:Timestamp(), type = kind, player = target, amount = amount, note = note, by = by },
    }
end

local function BuildLootRow(self, loot, index)
    local owner = loot:Owner()
    local itemLink = LootLink(self, loot)
    local by, byColor = Author(loot:Creator())
    local entry = loot:Entry()
    local note = itemLink or ("item:" .. tostring(loot:Id()))
    return {
        id = entry and entry.uuid and ("l" .. entry:uuid()) or ("l" .. index),
        loot = loot,
        itemLink = itemLink,
        kind = TYPE.GP,
        targetColor = ProfileColor(owner),
        byColor = byColor,
        search = (owner:Name() .. " " .. note):lower(),
        values = { time = loot:Timestamp(), type = TYPE.GP, player = owner:ShortName(), amount = SignedValue(loot:Value()), note = note, by = by },
    }
end

local function Matches(self, row)
    if self.typeFilter ~= TYPE.ALL and row.kind ~= self.typeFilter then return false end
    if self.search ~= "" and not row.search:find(self.search, 1, true) then return false end
    return true
end

--[[
 * Tooltips *
]]--

local function LootTooltip(row, tooltip)
    local loot = row.loot
    if row.itemLink then
        tooltip:SetHyperlink(row.itemLink)
    else
        tooltip:SetText(row.values.note)
    end
    tooltip:AddLine(" ")
    local raid = CLM.MODULES.RaidManager:GetRaidByUid(loot:RaidUid())
    if raid then tooltip:AddDoubleLine(CLM.L["Raid"], raid:Name(), nil, nil, nil, 1, 1, 1) end
    tooltip:AddDoubleLine(CLM.L["Awarded by"], row.byColor:WrapTextInColorCode(row.values.by))
    local auction = loot:Entry() and CLM.MODULES.AuctionHistoryManager:GetByUUID(loot:Entry():uuid())
    if auction and auction.bids and next(auction.bids) then
        tooltip:AddLine(" ")
        tooltip:AddLine(CLM.L["Bids"])
        local names, rolls = auction.names or {}, auction.rolls or {}
        for bidder, bid in pairs(auction.bids) do
            local text = tostring(bid)
            if rolls[bidder] then text = text .. "/" .. tostring(rolls[bidder]) end
            if names[bidder] then text = text .. " (" .. names[bidder] .. ")" end
            local profile = CLM.MODULES.ProfileManager:GetProfileByName(bidder)
            local name = profile and ProfileColor(profile):WrapTextInColorCode(bidder) or bidder
            tooltip:AddDoubleLine(name, text, nil, nil, nil, 1, 1, 1)
        end
    end
end

local function PointTooltip(row, tooltip)
    local history = row.history
    tooltip:SetText(row.values.note)
    local profiles = history:Profiles()
    tooltip:AddDoubleLine(CLM.L["Affected players:"], tostring(#profiles))
    if #profiles > 0 then
        UTILS.buildPlayerListForTooltip(profiles, tooltip)
    end
    tooltip:AddDoubleLine(CLM.L["Awarded by"], row.byColor:WrapTextInColorCode(row.values.by))
end

local function ShowTooltip(row, rowFrame)
    GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
    if row.loot then LootTooltip(row, GameTooltip) else PointTooltip(row, GameTooltip) end
    GameTooltip:Show()
end

--[[
 * Officer actions *
]]--

local function RemoveEntry(self, row)
    local object = row.loot or row.history
    local entry = object and object:Entry()
    if not entry then return end
    local text = string.format(CLM.L["Remove this entry? %s %s %s (%s). This writes an undo entry for everyone."],
        row.values.type, row.values.amount, row.values.player, row.values.note)
    UI.Confirm(text, function()
        CLM.MODULES.LedgerManager:Remove(entry)
        if row.loot then
            local loot = row.loot
            CLM.MODULES.EventManager:DispatchEvent(CONSTANTS.EVENTS.GLOBAL_LOOT_REMOVED, {
                id = loot:Id(), name = loot:Owner():Name()
            }, loot:Timestamp() + 7200) -- only up to 2 hours after loot is created
        end
        self.list:ClearSelection()
    end)
end

--[[
 * Building *
]]--

local function BuildHeader(self, header)
    local typeDropdown = UI.CreateDropdown(header, 110,
        function()
            return {
                { text = CLM.L["All types"], value = TYPE.ALL },
                { text = CLM.L["BP"], value = TYPE.EP },
                { text = CLM.L["GP"], value = TYPE.GP },
                { text = CLM.L["Decay"], value = TYPE.DECAY },
            }
        end,
        function() return self.typeFilter end,
        function(value) self.typeFilter = value; self:Refresh() end)
    typeDropdown:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    local search = UI.CreateSearchBox(header, 150, function(text)
        self.search = strlower(text or "")
        self:Refresh()
    end)
    search:SetPoint("RIGHT", typeDropdown, "LEFT", -S.M, 0)
    if search.Instructions then search.Instructions:SetText(CLM.L["Player or item"]) end
end

function History:Build(content, header)
    BuildHeader(self, header)
    local inset = UI.CreateInset(content)
    inset:SetAllPoints()
    self.list = UI.CreateList(inset, {
        columns = {
            { key = "time", title = CLM.L["Time"], width = 96, defaultDesc = true,
              text = function(row) return date(CLM.L["%m/%d %H:%M"], row.values.time) end,
              color = function() return UI.COLOR.GREY end },
            { key = "type", title = CLM.L["Type"], width = 40,
              color = function(row) return TYPE_COLOR[row.kind] end },
            { key = "player", title = CLM.L["Player"], width = 110,
              color = function(row) return row.targetColor end },
            { key = "amount", title = CLM.L["Amount"], width = 72, align = "RIGHT", font = "NumberFontNormal", sortable = false,
              color = function(row) return TYPE_COLOR[row.kind] end },
            { key = "note", title = CLM.L["Note / item"], width = 0,
              color = function(row) return row.loot and not row.itemLink and ITEM_COLOR or nil end },
            { key = "by", title = CLM.L["By"], width = 90,
              color = function(row) return row.byColor end },
        },
        sortKey = "time",
        sortDesc = true,
        onRightClick = self.isOfficer and function(row, rowFrame)
            UI.ShowContextMenu(rowFrame, nil, {
                { text = CLM.L["Remove entry"], color = UI.COLOR.BAD, func = function() RemoveEntry(self, row) end },
            })
        end or nil,
        onEnter = ShowTooltip,
    })
    self.list:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.list:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
end

function History:Refresh()
    local roster = CLM.MODULES.RosterManager:GetRoster()
    local rows = {}
    local total = 0
    if roster then
        for index, history in ipairs(roster:GetRaidPointHistory()) do
            local row = BuildPointRow(history, index)
            total = total + 1
            if Matches(self, row) then rows[#rows + 1] = row end
        end
        for index, loot in ipairs(roster:GetRaidLoot()) do
            local ok, row = pcall(BuildLootRow, self, loot, index)
            if ok then
                total = total + 1
                if Matches(self, row) then rows[#rows + 1] = row end
            else
                LOG:Debug("History: skipping loot row: %s", tostring(row))
            end
        end
    end
    self.list:SetData(rows)
    local footer = string.format(CLM.L["%s of %s entries"], #rows, total)
    if self.isOfficer then
        footer = footer .. " · " .. CLM.L["Right-click an entry: Remove"]
    end
    self.window:SetPageFooter(footer)
end

CLM.GUI.MainWindow:RegisterPage(History)
