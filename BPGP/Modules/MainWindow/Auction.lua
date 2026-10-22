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
    Auction tab (officers): the auctioning UI lives in the main window (decision R12, 2026-10-17;
    it was a separate window in 9d). Alt-clicking an item or /bpgp auction opens this tab.
      left   item queue (36 px item buttons; the border shows the state)
      right  item + note, three tier GP fields (BiS, Major, Minor), length / anti-snipe / roll / clear / Start-Stop,
             bid list (Name · Bid · PR · Roll · equipped items), Remove on award · Value · Award
      header state and countdown
    States: idle (building the list), running (inputs locked, countdown in the header) and finished
    (the winner is preselected: highest tier, then PR, then roll; Enter in the Value field awards).
    After an award the next item with bids is loaded.
]]--

local QUEUE_WIDTH = 44
local QUEUE_BUTTON = 36
local TIER_INPUT_WIDTH = 56

local STATE_COLOR = {
    idle     = UI.COLOR.GREY,
    running  = CreateColor(0.25, 0.88, 0.82),
    rolling  = UI.COLOR.GOLD,
    finished = UI.COLOR.EP,
}
local QUEUE_STATE = {
    selected = CreateColor(0.25, 0.88, 0.82),
    noBids   = UI.COLOR.BAD,
    hasBids  = UI.COLOR.EP,
}
local INVALID_TINT = CreateColor(1, 0.13, 0.13, 0.15)
local HIDDEN_BID = UI.COLOR.GREY
local OS_COLOR = CreateColor(1, 0.82, 0.5)
local TRANSMOG_COLOR = CreateColor(1, 0.5, 1)

local AuctionWindow = {
    key = "auction",
    order = 1.5, -- right after Standings
    title = CLM.L["Auction"],
    officerOnly = true,
    awarded = {},
}

local function Manager()
    return CLM.MODULES.AuctionManager
end

local function Auction()
    return Manager():GetCurrentAuctionInfo()
end

local function State()
    local auction = Auction()
    if auction:IsInProgress() then return "running" end
    if auction:IsAcceptingRolls() then return "rolling" end
    if auction:IsComplete() then return "finished" end
    return "idle"
end

local function Locked()
    local auction = Auction()
    return auction:IsInProgress() or auction:IsAcceptingRolls()
end

--[[
 * Bid rows *
]]--

local function BidLabel(auction, response)
    local bidType = response:Type()
    if bidType == CONSTANTS.BID_TYPE.CANCEL then return CLM.L["Cancel"] end
    if bidType == CONSTANTS.BID_TYPE.PASS then return CLM.L["Pass"] end
    if bidType == CONSTANTS.BID_TYPE.OFF_SPEC then return CLM.L["OS"] end
    if bidType == CONSTANTS.BID_TYPE.TRANSMOG then return CLM.L["Transmog"] end
    if CONSTANTS.SLOT_VALUE_TIERS[bidType] then
        return auction:GetFieldDisplayName(bidType) .. " " .. tostring(response:Value())
    end
    return (CONSTANTS.BID_TYPE_NAMES[bidType] or "") .. " " .. tostring(response:Value())
end

local function BidColor(response)
    local bidType = response:Type()
    if CONSTANTS.BID_TYPE_HIDDEN[bidType] then return HIDDEN_BID end
    if bidType == CONSTANTS.BID_TYPE.OFF_SPEC then return OS_COLOR end
    if bidType == CONSTANTS.BID_TYPE.TRANSMOG then return TRANSMOG_COLOR end
    return UI.TIER_COLOR[bidType] or UI.COLOR.WHITE
end

local function ItemIcons(items)
    local icons = {}
    for _, item in ipairs(items or {}) do
        local _, _, _, _, icon = UTILS.GetItemInfoInstant(item)
        if icon then icons[#icons + 1] = "|T" .. icon .. ":16:16|t" end
    end
    return table.concat(icons, " ")
end

local function BuildBidRows(item)
    local auction = Auction()
    local roster = auction:GetRoster()
    local rows = {}
    for name, response in pairs(item:GetAllResponses()) do
        local profile = CLM.MODULES.ProfileManager:GetProfileByName(name)
        local pr = (profile and roster) and roster:Priority(profile:GUID()) or 0
        local roll = response:Roll() or 0
        rows[#rows + 1] = {
            id = name,
            response = response,
            classFile = profile and UTILS.CanonicalClass(profile:ClassInternal()) or nil,
            hidden = CONSTANTS.BID_TYPE_HIDDEN[response:Type()] and true or false,
            values = {
                name = name,
                -- tier first, then PR, then roll: the same order the winner is picked in
                score = Manager():GetBidTypeOrder(response:Type()) * 1e9
                    + math.floor(Manager():GetRankingPR(response:Type(), pr) * 1000) * 1000 + roll,
                bid = BidLabel(auction, response),
                pr = pr,
                roll = roll,
                items = ItemIcons(response:Items()),
            },
        }
    end
    return rows
end

--[[
 * Actions *
]]--

local function SelectItem(self, item)
    if self.auctionItem ~= item then
        self.awardPlayer = nil
        self.awardValue = nil
    end
    self.auctionItem = item
    self:Refresh()
end

local function SetWinner(self, name, response)
    self.awardPlayer = name
    self.awardValue = response and UTILS.round(response:Value(), Auction():GetRounding()) or nil
end

-- R10: preselect the winner once the auction has ended, and put the cursor in Value so Enter awards
local function PreselectWinner(self)
    local item = self.auctionItem
    if not item or State() ~= "finished" or self.awardPlayer then return end
    local name, response = Manager():GetWinner(item, self.awarded[item])
    if not name then return end
    SetWinner(self, name, response)
    if self.content and self.content:IsVisible() and self.focusedFor ~= item then
        self.focusedFor = item
        self.valueInput:SetFocus()
        self.valueInput:HighlightText()
    end
end

-- After an award: stay on the item while copies are left, else load the next item that has bids
local function AdvanceAfterAward(self, item)
    if item and Auction():IsItemInAuction(item) and item:GetTotal() > 0 then
        self.focusedFor = nil
        return
    end
    self.auctionItem = nil
    for _, candidate in pairs(Auction():GetItems()) do
        if candidate:HasValidBids() then
            self.auctionItem = candidate
            break
        end
    end
    self.focusedFor = nil
end

local function Award(self)
    local item, name = self.auctionItem, self.awardPlayer
    local value = tonumber(self.valueInput:GetText())
    if not (item and name and value) or Locked() then return end
    value = UTILS.round(value, Auction():GetRounding())
    UI.Confirm(string.format(CLM.L["Award %s to %s for %s GP?"], item:GetItemLink(),
        UI.COLOR.GOLD:WrapTextInColorCode(Ambiguate(name, "none")), tostring(value)), function()
        Manager():Award(item, name, value)
        self.awarded[item] = self.awarded[item] or {}
        self.awarded[item][name] = true
        if self.removeOnAward then
            item:DecrementTotal()
            if item:GetTotal() == 0 then
                Manager():RemoveItemFromCurrentAuction(item)
            end
        end
        self.awardPlayer, self.awardValue = nil, nil
        AdvanceAfterAward(self, item)
        self:Refresh()
    end)
end

local function StartStop(self)
    if Manager():IsAuctionInProgress() then
        Manager():StopAuctionManual()
    else
        wipe(self.awarded)
        self.awardPlayer, self.awardValue, self.focusedFor = nil, nil, nil
        Manager():StartAuction()
    end
    self:Refresh()
end

local function AddItemFromInput(self, text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return end
    local itemId = UTILS.GetItemInfoInstant(text)
    if not itemId then
        LOG:Message(CLM.L["Not an item: %s"], text)
        return
    end
    local callback = function(auctionItem) if auctionItem then SelectItem(self, auctionItem) end end
    if tostring(itemId) == text then
        Manager():AddItemById(itemId, callback)
    else
        Manager():AddItemByLink(text, callback)
    end
end

local function QueueMenu(self, item, owner)
    local disabled = Locked()
    UI.ShowContextMenu(owner, item:GetItemLink(), {
        { text = CLM.L["Move to pending list"], disabled = disabled, func = function()
            Manager():MoveItemToPendingList(item)
            if self.auctionItem == item then self.auctionItem = nil end
            self:Refresh()
        end },
        { text = CLM.L["Remove"], color = UI.COLOR.BAD, disabled = disabled, func = function()
            Manager():RemoveItemFromCurrentAuction(item)
            if self.auctionItem == item then self.auctionItem = nil end
            self:Refresh()
        end },
    })
end

--[[
 * Building *
]]--

local function BuildQueue(self, parent)
    local inset = UI.CreateInset(parent)
    inset:SetPoint("TOPLEFT")
    inset:SetPoint("BOTTOMLEFT")
    inset:SetWidth(QUEUE_WIDTH + S.S)
    local scroll = CreateFrame("ScrollFrame", nil, inset)
    scroll:SetPoint("TOPLEFT", S.XS, -S.XS)
    scroll:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(QUEUE_BUTTON, 1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(frame, delta)
        local offset = frame:GetVerticalScroll() - delta * (QUEUE_BUTTON + S.XS)
        frame:SetVerticalScroll(math.max(0, math.min(offset, frame:GetVerticalScrollRange())))
    end)
    self.queueContent = content
    self.queueButtons = {}
end

local function QueueButton(self, index)
    local button = self.queueButtons[index]
    if button then return button end
    button = UI.CreateItemButton(self.queueContent, QUEUE_BUTTON)
    button:SetPoint("TOP", 0, -(index - 1) * (QUEUE_BUTTON + S.XS) - 2)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.Count = UI.CreateLabel(button, "", "NumberFontNormal")
    button.Count:SetPoint("BOTTOMRIGHT", -2, 2)
    button:SetScript("OnClick", function(frame, mouseButton)
        if not frame.auctionItem then return end
        if mouseButton == "RightButton" then
            QueueMenu(self, frame.auctionItem, frame)
        else
            SelectItem(self, frame.auctionItem)
        end
    end)
    self.queueButtons[index] = button
    return button
end

local function LabeledInput(parent, label, width, color)
    local input = UI.CreateInput(parent, width, true)
    input.Label = UI.CreateLabel(parent, label, "GameFontNormalSmall", color)
    input.Label:SetPoint("BOTTOMLEFT", input, "TOPLEFT", -4, 2)
    return input
end

local function BuildItemRow(self, panel)
    self.itemButton = UI.CreateItemButton(panel, QUEUE_BUTTON)
    self.itemButton:SetPoint("TOPLEFT")
    self.itemLink = UI.CreateLabel(panel, "", "GameFontHighlight")
    self.itemLink:SetPoint("TOPLEFT", self.itemButton, "TOPRIGHT", S.S, 0)
    self.itemLink:SetPoint("RIGHT", panel, "RIGHT", -170, 0)
    self.itemLink:SetWordWrap(false)
    self.noteInput = UI.CreateInput(panel, 190, false)
    self.noteInput:SetPoint("BOTTOMLEFT", self.itemButton, "BOTTOMRIGHT", S.S + 6, 0)
    self.noteInput:SetMaxLetters(40)
    self.noteInput:HookScript("OnEditFocusLost", function(box)
        if self.auctionItem and not Locked() then Manager():SetItemNote(self.auctionItem, box:GetText()) end
    end)
    self.noteHint = UI.CreateLabel(self.noteInput, CLM.L["Note"], "GameFontDisableSmall")
    self.noteHint:SetPoint("LEFT", 2, 0)
    self.noteInput:HookScript("OnTextChanged", function(box) self.noteHint:SetShown(box:GetText() == "" and not box:HasFocus()) end)
    self.noteInput:HookScript("OnEditFocusGained", function() self.noteHint:Hide() end)

    self.addInput = UI.CreateInput(panel, 150, false)
    self.addInput:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -2)
    self.addInput:SetScript("OnEnterPressed", function(box)
        AddItemFromInput(self, box:GetText())
        box:SetText("")
        box:ClearFocus()
    end)
    self.addHint = UI.CreateLabel(self.addInput, CLM.L["Add item: link or ID"], "GameFontDisableSmall")
    self.addHint:SetPoint("LEFT", 2, 0)
    self.addInput:HookScript("OnTextChanged", function(box) self.addHint:SetShown(box:GetText() == "" and not box:HasFocus()) end)
    self.addInput:HookScript("OnEditFocusGained", function() self.addHint:Hide() end)
    self.addInput:HookScript("OnEditFocusLost", function(box) self.addHint:SetShown(box:GetText() == "") end)
    -- Shift-click an item while the field has focus, or drag it onto the field or the item icon
    local function AddDropped(link)
        if not Auction():IsInProgress() then AddItemFromInput(self, link) end
        self.addInput:SetText("")
    end
    UI.AcceptItems(self.addInput, AddDropped)
    UI.AcceptItems(self.itemButton, AddDropped)
end

local function BuildTierRow(self, panel)
    self.tierInputs = {}
    local previous
    for _, tier in ipairs(CONSTANTS.BID_TIERS_ORDERED_REVERSED) do
        local input = LabeledInput(panel, "", TIER_INPUT_WIDTH, UI.TIER_COLOR[tier])
        if previous then
            input:SetPoint("LEFT", previous, "RIGHT", S.M, 0)
        else
            input:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -(QUEUE_BUTTON + S.M + 14))
        end
        input:HookScript("OnEditFocusLost", function(box)
            if self.auctionItem and not Locked() then
                self.auctionItem.values[tier] = tonumber(box:GetText()) or 0
            end
        end)
        input.tier = tier
        self.tierInputs[#self.tierInputs + 1] = input
        previous = input
    end
end

local function BuildControlRow(self, panel)
    local y = -(QUEUE_BUTTON + S.M + 14 + S.INPUT + S.M + 14)
    self.lengthInput = LabeledInput(panel, CLM.L["Length"], 40)
    self.lengthInput:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, y)
    self.lengthInput:HookScript("OnEditFocusLost", function(box) if not Locked() then Manager():SetAuctionTime(box:GetText()) end end)
    self.antiSnipeInput = LabeledInput(panel, CLM.L["Anti-snipe"], 40)
    self.antiSnipeInput:SetPoint("LEFT", self.lengthInput, "RIGHT", S.M + 4, 0)
    self.antiSnipeInput:HookScript("OnEditFocusLost", function(box) if not Locked() then Manager():SetAntiSnipe(box:GetText()) end end)

    self.startButton = UI.CreateButton(panel, CLM.L["Start"], 80, function() StartStop(self) end)
    self.startButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y + 1)
    self.clearButton = UI.CreateButton(panel, CLM.L["Clear list"], 80, function()
        UI.Confirm(CLM.L["Remove all items from the auction list? Pending items move in."], function()
            Manager():ClearItemList()
            self.auctionItem = nil
            self:Refresh()
        end)
    end)
    self.clearButton:SetPoint("RIGHT", self.startButton, "LEFT", -S.S, 0)
    self.rollButton = UI.CreateIconButton(panel, "Interface\\Buttons\\UI-GroupLoot-Dice-Up", CLM.L["Start or stop a /roll phase for this item"], function()
        if Manager():IsAcceptingRolls() then
            Manager():StopRoll()
        elseif self.auctionItem then
            Manager():StartRoll(self.auctionItem)
        end
        self:Refresh()
    end)
    self.rollButton:SetPoint("RIGHT", self.clearButton, "LEFT", -S.S, 0)
    self.lootRollsButton = UI.CreateIconButton(panel, "Interface\\Icons\\INV_Misc_Bag_10", CLM.L["Add from loot rolls: the items you won at the last boss that aren't in the list yet"], function()
        Manager():AddFromLootRolls()
        self:Refresh()
    end)
    self.lootRollsButton:SetPoint("RIGHT", self.rollButton, "LEFT", -S.S, 0)
    if UI.IsTestMode() then
        self.simulateButton = UI.CreateButton(panel, CLM.L["Simulate bids"], 100, function()
            CLM.MODULES.TestMode:SimulateBids()
            self:Refresh()
        end)
        self.simulateButton:SetPoint("RIGHT", self.lootRollsButton, "LEFT", -S.S, 0)
    end
    return y - S.INPUT - S.M
end

local function ShowBidTooltip(row, rowFrame)
    local response = row.response
    GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.values.name)
    if response:IsInvalid() then
        GameTooltip:AddLine(CONSTANTS.AUCTION_COMM.DENY_BID_REASONS_STRING[response:GetInvalidReason()] or CLM.L["Unknown"], UI.COLOR.BAD:GetRGB())
    end
    local items = response:Items() or {}
    if #items > 0 then
        GameTooltip:AddLine(CLM.L["Currently equipped"], 1, 1, 1)
        for _, item in ipairs(items) do
            local _, link = UTILS.GetItemInfo(item)
            if link then GameTooltip:AddLine(link) end
        end
    end
    GameTooltip:Show()
end

local function BuildBidList(self, panel, top)
    local inset = UI.CreateInset(panel)
    inset:SetPoint("TOPLEFT", 0, top)
    inset:SetPoint("BOTTOMRIGHT", 0, S.BUTTON + S.S)
    self.bidList = UI.CreateList(inset, {
        columns = {
            { key = "name", title = CLM.L["Name"], width = 0, classIcon = true,
              color = function(row) return row.hidden and HIDDEN_BID or UI.GetClassColor(row.classFile) end },
            { key = "score", title = CLM.L["Bid"], width = 96, defaultDesc = true,
              text = function(row) return row.values.bid end,
              color = function(row) return BidColor(row.response) end },
            { key = "pr", title = CLM.L["PR"], width = 50, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true,
              color = function(row) return row.hidden and HIDDEN_BID or UI.COLOR.GOLD end },
            { key = "roll", title = CLM.L["Roll"], width = 40, align = "RIGHT", font = "NumberFontNormal", defaultDesc = true,
              color = function() return UI.COLOR.GREY end },
            { key = "items", title = "", width = 80, sortable = false },
        },
        sortKey = "score",
        sortDesc = true,
        rowTint = function(row) return row.response:IsInvalid() and INVALID_TINT or nil end,
        onSelectionChanged = function(selection)
            local row = selection[1]
            if row and not row.hidden then
                SetWinner(self, row.values.name, row.response)
            end
            -- Refresh also puts the highlight back on the winner (clicking the winner again deselects it)
            self:Refresh()
        end,
        onEnter = ShowBidTooltip,
    })
    self.bidList:SetPoint("TOPLEFT", S.XS, -S.XS)
    self.bidList:SetPoint("BOTTOMRIGHT", -S.XS, S.XS)
end

local function BuildAwardRow(self, panel)
    self.awardButton = UI.CreateButton(panel, CLM.L["Award"], 100, function() Award(self) end)
    self.awardButton:SetPoint("BOTTOMRIGHT")
    self.valueInput = UI.CreateInput(panel, 60, true)
    self.valueInput:SetPoint("RIGHT", self.awardButton, "LEFT", -S.M, 0)
    self.valueInput:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
        Award(self)
    end)
    local valueLabel = UI.CreateLabel(panel, CLM.L["Value"], "GameFontNormal")
    valueLabel:SetPoint("RIGHT", self.valueInput, "LEFT", -S.S - 4, 0)
    self.winnerLabel = UI.CreateLabel(panel, "", "GameFontHighlight")
    self.winnerLabel:SetPoint("RIGHT", valueLabel, "LEFT", -S.M, 0)
    self.winnerLabel:SetJustifyH("RIGHT")
    self.removeCheck = UI.CreateCheckbox(panel, CLM.L["Remove on award"], function(checked) self.removeOnAward = checked end)
    self.removeCheck:SetPoint("BOTTOMLEFT", -4, -1)
end

local function BuildHeader(self, header)
    self.stateLabel = UI.CreateLabel(header, "", "GameFontNormal")
    self.stateLabel:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    self.stateLabel:SetJustifyH("RIGHT")
    self.timerBar = UI.CreateProgressBar(header, 140, 14)
    self.timerBar:SetPoint("RIGHT", self.stateLabel, "LEFT", -S.M, 0)
end

function AuctionWindow:Build(content, header)
    self.removeOnAward = Manager():GetDefaultRemoveOnAward()
    BuildHeader(self, header)
    BuildQueue(self, content)
    local panel = CreateFrame("Frame", nil, content)
    panel:SetPoint("TOPLEFT", QUEUE_WIDTH + S.S + S.S, 0)
    panel:SetPoint("BOTTOMRIGHT")
    BuildItemRow(self, panel)
    BuildTierRow(self, panel)
    local listTop = BuildControlRow(self, panel)
    BuildBidList(self, panel, listTop)
    BuildAwardRow(self, panel)

    -- Docked countdown: OnUpdate only runs while the tab is visible
    local elapsed = 0
    content:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        self:UpdateHeader()
    end)
end

--[[
 * Refresh *
]]--

function AuctionWindow:UpdateHeader()
    if not self.stateLabel then return end
    local state = State()
    local auction = Auction()
    local text = ({
        idle = CLM.L["Idle: building the list"],
        running = CLM.L["Auction running"],
        rolling = CLM.L["Accepting rolls"],
        finished = self.awardPlayer and CLM.L["Finished: winner selected"] or CLM.L["Finished"],
    })[state]
    self.stateLabel:SetText(STATE_COLOR[state]:WrapTextInColorCode(text))
    local running = state == "running" or state == "rolling"
    self.timerBar:SetShown(running)
    if running then
        local left = Manager():GetTimeLeft()
        local total = state == "rolling" and auction:GetRollTime() or auction:GetTime()
        self.timerBar:SetProgress(total > 0 and left / total or 0, string.format(CLM.L["%ss left"], math.ceil(left)))
        local color = left < 5 and UI.COLOR.BAD or UI.COLOR.GOLD -- red for the last seconds
        self.timerBar:SetStatusBarColor(color:GetRGB())
    end
end

local function RefreshQueue(self, auction)
    local index = 0
    local finished = auction:IsComplete()
    for _, item in pairs(auction:GetItems()) do
        index = index + 1
        local button = QueueButton(self, index)
        button.auctionItem = item
        button:SetItem(item:GetItemLink())
        local total = item:GetTotal()
        button.Count:SetText(total > 1 and total or "")
        local state
        if item == self.auctionItem then
            state = QUEUE_STATE.selected
        elseif finished then
            state = item:HasValidBids() and QUEUE_STATE.hasBids or QUEUE_STATE.noBids
        end
        button:SetState(state)
        button:Show()
    end
    for i = index + 1, #self.queueButtons do
        self.queueButtons[i].auctionItem = nil
        self.queueButtons[i]:Hide()
    end
    self.queueContent:SetHeight(math.max(index * (QUEUE_BUTTON + S.XS), 1))
end

local function SetInputEnabled(input, enabled)
    input:SetEnabled(enabled)
    if input.Label then input.Label:SetAlpha(enabled and 1 or 0.5) end
end

local function RefreshItem(self, auction)
    local item = self.auctionItem
    local locked = Locked()
    self.itemButton:SetItem(item and item:GetItemLink() or nil)
    self.itemLink:SetText(item and item:GetItemLink() or CLM.L["Alt-click an item, or add one on the right."])
    if not self.noteInput:HasFocus() then self.noteInput:SetText(item and item:GetNote() or "") end
    self.noteHint:SetShown(self.noteInput:GetText() == "" and not self.noteInput:HasFocus())
    SetInputEnabled(self.noteInput, item ~= nil and not locked)
    SetInputEnabled(self.addInput, not auction:IsInProgress())
    for _, input in ipairs(self.tierInputs) do
        input.Label:SetText(CONSTANTS.SLOT_VALUE_TIERS_GUI[input.tier])
        if not input:HasFocus() then
            input:SetText(item and tostring(item.values[input.tier] or 0) or "")
        end
        SetInputEnabled(input, item ~= nil and not locked)
    end
end

local function RefreshControls(self, auction)
    local locked = Locked()
    if not self.lengthInput:HasFocus() then self.lengthInput:SetText(tostring(auction:GetTime() or 0)) end
    if not self.antiSnipeInput:HasFocus() then self.antiSnipeInput:SetText(tostring(auction:GetAntiSnipe() or 0)) end
    SetInputEnabled(self.lengthInput, not locked)
    SetInputEnabled(self.antiSnipeInput, not locked)
    self.startButton:SetText(auction:IsInProgress() and CLM.L["Stop"] or CLM.L["Start"])
    self.startButton:SetEnabled(not auction:IsEmpty() and not auction:IsAcceptingRolls())
    self.clearButton:SetEnabled(not locked and not auction:IsEmpty())
    self.rollButton:SetEnabled(self.auctionItem ~= nil and not auction:IsInProgress())
    if self.simulateButton then self.simulateButton:SetEnabled(auction:IsInProgress()) end
end

local function RefreshAward(self)
    local locked = Locked()
    local item = self.auctionItem
    if not self.valueInput:HasFocus() then
        self.valueInput:SetText(self.awardValue and tostring(self.awardValue) or "")
    end
    SetInputEnabled(self.valueInput, item ~= nil and not locked)
    self.removeCheck:SetChecked(self.removeOnAward)
    self.removeCheck:SetEnabled(not locked)
    local text = CLM.L["Award"]
    if item and item:GetTotal() > 1 then text = text .. string.format(" (%d)", item:GetTotal()) end
    self.awardButton:SetText(text)
    self.awardButton:SetEnabled(item ~= nil and self.awardPlayer ~= nil and not locked)
    if self.awardPlayer then
        local profile = CLM.MODULES.ProfileManager:GetProfileByName(self.awardPlayer)
        local color = profile and UI.GetClassColor(UTILS.CanonicalClass(profile:ClassInternal())) or UI.COLOR.WHITE
        self.winnerLabel:SetText(color:WrapTextInColorCode(Ambiguate(self.awardPlayer, "none")))
    else
        self.winnerLabel:SetText("")
    end
end

---@param visibleOnly boolean? only refresh when the tab is visible
function AuctionWindow:Refresh(visibleOnly)
    if not self.content then return end
    if visibleOnly and not self.content:IsVisible() then return end
    local auction = Auction()
    if self.auctionItem and not auction:IsItemInAuction(self.auctionItem) then
        self.auctionItem = nil
    end
    if not self.auctionItem then
        local _, first = next(auction:GetItems())
        self.auctionItem = first
        self.awardPlayer, self.awardValue = nil, nil
    end
    PreselectWinner(self)
    RefreshQueue(self, auction)
    RefreshItem(self, auction)
    RefreshControls(self, auction)
    self.bidList:SetData(self.auctionItem and BuildBidRows(self.auctionItem) or {})
    -- Highlight the winner, so the preselected (first) player is selected when the next item loads
    self.bidList:SetSelection(self.awardPlayer and { self.awardPlayer } or nil)
    RefreshAward(self)
    self:UpdateHeader()
    if not auction:GetRoster() then
        self.window:SetPageFooter(CLM.L["Set up BPGP first (Standings tab)."])
    else
        self.window:SetPageFooter(CLM.L["Right-click an item in the queue: move to pending or remove · Enter in Value awards"])
    end
end

CLM.GUI.MainWindow:RegisterPage(AuctionWindow)

--[[
 * CLM.GUI.AuctionManager: what AuctionManager calls (alt-click, refreshes, clearing the list) *
]]--

local AuctionGUI = {}

function AuctionGUI:Initialize()
    LOG:Trace("AuctionGUI:Initialize()")
    if not CLM.MODULES.ACL:IsTrusted() then return end
    CLM.MODULES.ConfigManager:RegisterSlash({
        auction = {
            type = "execute",
            name = "Auctioning",
            desc = CLM.L["Open the Auction tab"],
            func = function() self:Show() end,
        }
    })
    self._initialized = true
end

-- Open the main window on the Auction tab
function AuctionGUI:Show()
    if not self._initialized then return end
    CLM.GUI.MainWindow:Open(AuctionWindow.key)
end
AuctionGUI.Toggle = AuctionGUI.Show

---@param visibleOnly boolean?
function AuctionGUI:Refresh(visibleOnly)
    AuctionWindow:Refresh(visibleOnly)
end

---@param auctionItem AuctionItem?
function AuctionGUI:SetVisibleAuctionItem(auctionItem)
    AuctionWindow.auctionItem = auctionItem
    AuctionWindow.awardPlayer, AuctionWindow.awardValue = nil, nil
    AuctionWindow:Refresh(true)
end

CLM.GUI.AuctionManager = AuctionGUI
