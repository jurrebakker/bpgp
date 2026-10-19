-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI
local S = UI.SPACE

--[[
    Settings tab (Phase 9c, ui-redesign.md R3, ui-overhaul.md): one tab with sections on the left.
      Personal     your own settings, stored per character (officer parts only for officers)
      Guild        roster settings: ledger entries that sync to everyone; read-only unless officer (D3)
      Gear values  default GP per slot and tier, and the per-item overrides
      Advanced     test mode for everyone; logging and removing the roster for officers
    The Options -> AddOns pages are gone (D2). Which settings exist follows the K/F/D calls in ui-overhaul.md.
]]--

local NAV_WIDTH = 110
local GEAR_INPUT_WIDTH = 44
local GEAR_LABEL_WIDTH = 120

local Settings = {
    key = "settings",
    order = 6,
    title = CLM.L["Settings"],
    forms = {},
}

---@return Roster?
local function GetRoster()
    return CLM.MODULES.RosterManager:GetRoster()
end

local function NoRoster()
    return GetRoster() == nil
end

local function RosterName()
    local roster = GetRoster()
    return roster and CLM.MODULES.RosterManager:GetRosterNameByUid(roster:UID())
end

local function GetRosterOption(option)
    local roster = GetRoster()
    return roster and roster:GetConfiguration(option)
end

local function SetRosterOption(option, value)
    local name = RosterName()
    if name then CLM.MODULES.RosterManager:SetRosterConfiguration(name, option, value) end
end

local function RoundingOptions()
    local options = {}
    for value = 0, 2 do
        options[#options + 1] = { text = CONSTANTS.ALLOWED_ROUNDINGS_GUI[value], value = value }
    end
    return options
end

local function ModifierOptions()
    local options = {}
    for _, value in ipairs(CONSTANTS.MODIFIER_COMBINATIONS_SORTED) do
        options[#options + 1] = { text = CONSTANTS.MODIFIER_COMBINATIONS_GUI[value], value = value }
    end
    return options
end

--[[
 * Personal *
]]--

local function BuildPersonal(self, form)
    local globals = CLM.GlobalConfigs

    form:Header(CLM.L["General"])
    form:Number({ label = CLM.L["UI Scale"], desc = CLM.L["Scales the BPGP windows, from 0.5 to 2. Some windows need to be reopened."],
        get = function() return globals:GetUIScale() end, set = function(v) globals:SetUIScale(v) end })
    form:Toggle({ label = CLM.L["Addon sounds"], desc = CLM.L["Plays a sound when an auction starts or ends."],
        get = function() return globals:GetSounds() end, set = function(v) globals:SetSounds(v) end })
    form:Toggle({ label = CLM.L["Minimap icon"], desc = CLM.L["Shows the minimap icon. /bpgp minimap toggles it too."],
        get = function() return CLM.MODULES.Minimap:IsEnabled() end,
        set = function(v) if v then CLM.MODULES.Minimap:Enable() else CLM.MODULES.Minimap:Disable() end end })

    form:Header(CLM.L["Loot"])
    form:Toggle({ label = CLM.L["Pass on loot"],
        desc = CLM.L["During our own BPGP raids, automatically pass on boss weapons, armor and miscellaneous items (like tier tokens), so the officer who runs the auctions can loot them. You roll on everything else yourself, like consumables and housing decor. Quest items, legendaries, stacks, recipes, mounts, toys and cosmetics are never passed."],
        warning = CLM.L["Only in a BPGP raid started by our officers (less than 12 hours ago), in a raid group led by one of our officers. Outside our own raids (pugs, other guilds, dungeons) you NEVER pass automatically."],
        get = function() return globals:GetPassOnLoot() end, set = function(v) globals:SetPassOnLoot(v) end })
    if self.isOfficer then
        form:Toggle({ label = CLM.L["Need on everything"],
            desc = CLM.L["Officers only. During our own BPGP raids, automatically roll Need on boss weapons, armor and miscellaneous items, or Greed or Transmog when Need isn't possible, so you collect the items for the auction. While it's on you may run auctions in the raid without being assistant. Overrides Pass on loot. Everything else, and quest items, legendaries, stacks, recipes, mounts, toys and cosmetics, are left to you."],
            warning = CLM.L["Same safety rules as Pass on loot: only in our own BPGP raid, led by one of our officers."],
            get = function() return globals:GetNeedOnEverything() end,
            set = function(v)
                -- Raid feedback 3 (2026-10-18): warn when you are not raid leader or assistant
                if v and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
                    UI.Confirm(CLM.L["You are not the raid leader or a raid assistant. With Need on everything on you roll Need on all boss loot in our BPGP raids. Turn it on anyway?"],
                        function()
                            globals:SetNeedOnEverything(true)
                            form:Refresh()
                        end)
                    return
                end
                globals:SetNeedOnEverything(v)
            end })
    end

    local bidding = CLM.GUI.BiddingManager
    form:Header(CLM.L["Bidding window"])
    form:Toggle({ label = CLM.L["Open automatically"], desc = CLM.L["Opens the bidding window when an auction starts and closes it when it ends."],
        get = function() return bidding:GetAutoOpen() end, set = function(v) bidding:SetAutoOpen(v) end })
    form:Toggle({ label = CLM.L["Close on bid"], desc = CLM.L["Closes the bidding window after you have bid on every item."],
        get = function() return bidding:GetCloseOnBid() end, set = function(v) bidding:SetCloseOnBid(v) end })
    form:Toggle({ label = CLM.L["Advance to next item after bid"],
        get = function() return bidding:GetAdvanceOnBid() end, set = function(v) bidding:SetAdvanceOnBid(v) end })
    form:Toggle({ label = CLM.L["Ignore unusable items"], desc = CLM.L["Items your class can't use are left out of the bidding window."],
        get = function() return bidding:GetIgnoreUnusable() end, set = function(v) bidding:SetIgnoreUnusable(v) end })
    form:Toggle({ label = CLM.L["Hide in combat"], desc = CLM.L["Hides the bidding window in combat and shows it again afterwards."],
        get = function() return bidding:GetHideInCombat() end, set = function(v) bidding:SetHideInCombat(v) end })
    form:Toggle({ label = CLM.L["Show timer bar"], desc = CLM.L["A separate countdown bar during auctions. The bidding window already shows the time left."],
        get = function() return bidding:GetShowTimerBar() end, set = function(v) bidding:SetShowTimerBar(v) end })
    form:Number({ label = CLM.L["Timer bar width"], desc = CLM.L["Width of the auction timer bar. /bpgp testbar shows it so you can move it."],
        get = function() return bidding:GetBarWidth() end, set = function(v) bidding:SetBarWidth(v) end })
    form:Number({ label = CLM.L["Timer bar height"],
        get = function() return bidding:GetBarHeight() end, set = function(v) bidding:SetBarHeight(v) end })

    if not self.isOfficer then return end

    form:Header(CLM.L["Raid warnings"])
    form:Toggle({ label = CLM.L["Raid start and end"],
        get = function() return globals:GetRaidWarning() end, set = function(v) globals:SetRaidWarning(v) end })
    form:Toggle({ label = CLM.L["Auction start and end"],
        get = function() return globals:GetAuctionWarning() end, set = function(v) globals:SetAuctionWarning(v) end })
    form:Toggle({ label = CLM.L["Auction end countdown"],
        get = function() return globals:GetCountdownWarning() end, set = function(v) globals:SetCountdownWarning(v) end })
    form:Toggle({ label = CLM.L["Loot awards"],
        get = function() return globals:GetLootWarning() end, set = function(v) globals:SetLootWarning(v) end })

    local auction = CLM.MODULES.AuctionManager
    local history = CLM.MODULES.AuctionHistoryManager
    form:Header(CLM.L["Auctioning"])
    form:Select({ label = CLM.L["Auction click"], desc = CLM.L["Hold these keys and click an item link to add the item to the auction list. Must differ from the award click."],
        options = ModifierOptions, get = function() return globals:GetModifierCombination() end,
        set = function(v) globals:SetModifierCombination(v) end })
    form:Select({ label = CLM.L["Award click"], desc = CLM.L["Hold these keys and click an item link to open the Award window for that item. It doesn't change the GP."],
        options = ModifierOptions, get = function() return globals:GetAwardModifierCombination() end,
        set = function(v) globals:SetAwardModifierCombination(v) end })
    form:Toggle({ label = CLM.L["Remove items without bids"], desc = CLM.L["Removes items nobody bid on from the auction list when the auction ends."],
        get = function() return auction:GetRemoveOnNoBids() end, set = function(v) auction:SetRemoveOnNoBids(v) end })
    form:Toggle({ label = CLM.L["Auto-trade after award"], desc = CLM.L["Opens a trade with the winner when the item is in your bags."],
        get = function() return auction:GetAutoTrade() end, set = function(v) auction:SetAutoTrade(v) end })
    form:Toggle({ label = CLM.L["Post all bids on award"],
        get = function() return auction:GetPostAllBidsOnAward() end, set = function(v) auction:SetPostAllBidsOnAward(v) end })
    form:Select({ label = CLM.L["Post bids to"], desc = CLM.L["Chat channel for \"Post bids\" in the auction history."],
        options = function()
            local options = {}
            for id, channel in ipairs(history:GetPostBidsChannels()) do
                options[#options + 1] = { text = _G[channel] or channel, value = id }
            end
            return options
        end,
        get = function() return history:GetPostBidsChannel() end, set = function(v) history:SetPostBidsChannel(v) end })
end

--[[
 * Guild *
]]--

local function BuildGuild(self, form)
    local readOnly = function() return not self.isOfficer end
    local function Number(label, option, desc)
        form:Number({ label = label, desc = desc, readOnly = readOnly, hidden = NoRoster,
            get = function() return GetRosterOption(option) end, set = function(v) SetRosterOption(option, v) end })
    end
    local function Toggle(label, option, desc)
        form:Toggle({ label = label, desc = desc, readOnly = readOnly, hidden = NoRoster,
            get = function() return GetRosterOption(option) end, set = function(v) SetRosterOption(option, v) end })
    end

    form:Description(function()
        if NoRoster() then return CLM.L["Set up BPGP first (Standings tab)."] end
        local text = self.isOfficer
            and CLM.L["These settings sync to everyone in the guild."]
            or CLM.L["These settings sync to everyone in the guild. Only officers can change them."]
        if CLM.MODULES.RaidManager:IsInActiveRaid() then
            text = text .. " " .. UI.COLOR.GOLD:WrapTextInColorCode(CLM.L["A raid is running: changes apply from the next raid."])
        end
        return text
    end)

    form:Header(CLM.L["BPGP"])
    Number(CLM.L["Starting BP"], "basePoints", CLM.L["BP a player gets when added to the roster."])
    Number(CLM.L["Starting GP"], "baseSpent", CLM.L["GP a player gets when added to the roster."])
    Number(CLM.L["Minimum GP"], "minGP", CLM.L["PR is BP divided by GP, but never by less than this."])
    form:Select({ label = CLM.L["Rounding"], desc = CLM.L["BP and GP are rounded to this."], readOnly = readOnly, hidden = NoRoster,
        options = RoundingOptions, width = 80,
        get = function() return GetRosterOption("roundDecimals") end, set = function(v) SetRosterOption("roundDecimals", v) end })
    form:Select({ label = CLM.L["PR rounding"], readOnly = readOnly, hidden = NoRoster, options = RoundingOptions, width = 80,
        get = function() return GetRosterOption("roundPR") end, set = function(v) SetRosterOption("roundPR", v) end })
    Toggle(CLM.L["On-time bonus"], "onTimeBonus", CLM.L["BP given to everyone in the raid when it starts."])
    Number(CLM.L["On-time bonus BP"], "onTimeBonusValue")

    form:Header(CLM.L["Auction rules"])
    Number(CLM.L["Minimum standing"], "minimumPoints", CLM.L["Minimum BP needed to bid."])
    Toggle(CLM.L["OS"], "useOS", CLM.L["Raiders get an Off-spec button."])
    Toggle(CLM.L["Transmog"], "useTransmog", CLM.L["Raiders get a free Transmog button. It ranks below OS and the highest roll wins, PR doesn't count."])
    Number(CLM.L["Auction length"], "auctionTime", CLM.L["Seconds per auction."])
    Number(CLM.L["Anti-snipe time"], "antiSnipe", CLM.L["Seconds an auction is extended by when someone bids at the end."])
    Toggle(CLM.L["Multiply time"], "multiplyTime", CLM.L["Auction length is multiplied by the number of items."])
    Number(CLM.L["Roll time"], "rollTime", CLM.L["Length of the /roll phase in seconds."])
end

--[[
 * Gear values *
]]--

-- A small numeric cell for the gear grid; applies on Enter or when focus leaves
local function GearInput(parent, get, set, readOnly)
    local input = UI.CreateInput(parent, GEAR_INPUT_WIDTH, true)
    input:SetJustifyH("RIGHT")
    local function Current()
        local value = get()
        return value ~= nil and tostring(value) or ""
    end
    input:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    input:SetScript("OnEscapePressed", function(box) box:SetText(Current()) box:ClearFocus() end)
    input:HookScript("OnEditFocusLost", function(box)
        local value = tonumber(box:GetText())
        if value and box:GetText() ~= Current() then set(value) end
        box:SetText(Current())
    end)
    input.Refresh = function()
        if not input:HasFocus() then input:SetText(Current()) end
        input:SetEnabled(not readOnly())
    end
    return input
end

local function TierHeaderRow(form)
    form:Custom(18, function(frame)
        frame.labels = {}
        for i, tier in ipairs(CONSTANTS.BID_TIERS_ORDERED_REVERSED) do
            local label = UI.CreateLabel(frame, CONSTANTS.SLOT_VALUE_TIERS_GUI[tier], "GameFontNormalSmall", UI.TIER_COLOR[tier])
            label:SetPoint("LEFT", GEAR_LABEL_WIDTH + (i - 1) * (GEAR_INPUT_WIDTH + S.S) + 6, 0)
            label:SetWidth(GEAR_INPUT_WIDTH)
            label:SetJustifyH("RIGHT")
            frame.labels[tier] = label
        end
    end, nil, NoRoster)
end

local function OverrideSignature()
    local roster = GetRoster()
    if not roster then return "" end
    local ids = {}
    for id in pairs(roster:GetAllItemValues()) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end

local function BuildGearValues(self, form)
    local readOnly = function() return not self.isOfficer end
    form:Description(function()
        if NoRoster() then return CLM.L["Set up BPGP first (Standings tab)."] end
        return CLM.L["GP per gear slot for each bid tier (BiS, Major, Minor). A negative value hides that tier's button. OS costs the Minor value."]
    end)

    form:Header(CLM.L["Default slot values"])
    TierHeaderRow(form)
    for _, slot in ipairs(CONSTANTS.INVENTORY_TYPES_SORTED) do
        form:Custom(24, function(frame)
            local icon = frame:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetPoint("LEFT")
            icon:SetTexture(slot.icon)
            local label = UI.CreateLabel(frame, slot.name, "GameFontHighlight")
            label:SetPoint("LEFT", icon, "RIGHT", S.XS, 0)
            frame.inputs = {}
            for i, tier in ipairs(CONSTANTS.BID_TIERS_ORDERED_REVERSED) do
                local input = GearInput(frame,
                    function() local roster = GetRoster() return roster and roster:GetDefaultSlotTierValue(slot.type, tier) end,
                    function(v) CLM.MODULES.RosterManager:SetRosterDefaultSlotTierValue(GetRoster(), slot.type, tier, v) end,
                    readOnly)
                input:SetPoint("LEFT", GEAR_LABEL_WIDTH + (i - 1) * (GEAR_INPUT_WIDTH + S.S) + 6, 0)
                frame.inputs[#frame.inputs + 1] = input
            end
        end, function(frame)
            for _, input in ipairs(frame.inputs) do input.Refresh() end
        end, NoRoster)
    end

    form:Header(CLM.L["Item value overrides"])
    local roster = GetRoster()
    local ids = {}
    if roster then
        for id in pairs(roster:GetAllItemValues()) do ids[#ids + 1] = id end
        table.sort(ids)
    end
    if #ids == 0 then
        form:Description(CLM.L["None yet. Starting an auction stores the item's values here, so you can change them for that item only."])
        return
    end
    TierHeaderRow(form)
    for _, id in ipairs(ids) do
        form:Custom(26, function(frame)
            local item = UI.CreateItemButton(frame, 20)
            item:SetPoint("LEFT")
            item:SetItem(id)
            local name = UI.CreateLabel(frame, "", "GameFontHighlightSmall")
            name:SetPoint("LEFT", item, "RIGHT", S.XS, 0)
            name:SetWidth(GEAR_LABEL_WIDTH - 20 - S.S)
            name:SetWordWrap(false)
            local itemObject = Item:CreateFromItemID(id)
            if not itemObject:IsItemEmpty() then
                itemObject:ContinueOnItemLoad(function() name:SetText(itemObject:GetItemLink()) end)
            end
            frame.inputs = {}
            local last
            for i, tier in ipairs(CONSTANTS.BID_TIERS_ORDERED_REVERSED) do
                local input = GearInput(frame,
                    function() local current = GetRoster() return current and current:GetItemValues(id)[tier] end,
                    function(v) CLM.MODULES.RosterManager:SetRosterItemTierValue(GetRoster(), id, tier, v) end,
                    readOnly)
                input:SetPoint("LEFT", GEAR_LABEL_WIDTH + (i - 1) * (GEAR_INPUT_WIDTH + S.S) + 6, 0)
                frame.inputs[#frame.inputs + 1] = input
                last = input
            end
            if self.isOfficer then
                local remove = UI.CreateButton(frame, CLM.L["Remove"], 70, function()
                    UI.Confirm(string.format(CLM.L["Remove the override for %s? The slot values apply again."], name:GetText() or ("item:" .. id)), function()
                        CLM.MODULES.RosterManager:RemoveRosterItemOverride(GetRoster(), id)
                    end)
                end)
                remove:SetPoint("LEFT", last, "RIGHT", S.M, 0)
            end
        end, function(frame)
            for _, input in ipairs(frame.inputs) do input.Refresh() end
        end, NoRoster)
    end
end

--[[
 * Advanced *
]]--

local function BuildAdvanced(self, form)
    local testMode = CLM.MODULES.TestMode
    local notInTestMode = function() return not testMode:IsOn() end

    form:Header(CLM.L["Test mode"])
    form:Description(CLM.L["Test mode uses a separate ledger and its own sync channel. Only other players in test mode see your test changes, and chat messages are only shown to you. Live data is never changed."])
    form:Button({ label = CLM.L["Test mode"], text = function() return testMode:IsOn() and CLM.L["Leave test mode"] or CLM.L["Enter test mode"] end,
        desc = CLM.L["Switching reloads the UI."], func = function() testMode:RequestSwitch() end })
    form:Button({ label = CLM.L["Reset test data"], text = CLM.L["Reset: empty"], desc = CLM.L["Wipes all test data."],
        hidden = notInTestMode, func = function() testMode:RequestReset(false) end })
    form:Button({ label = "", text = CLM.L["Reset: copy of live"], desc = CLM.L["Replaces all test data with a copy of today's live data."],
        hidden = notInTestMode, func = function() testMode:RequestReset(true) end })
    form:Number({ label = CLM.L["Simulated raid group size"], desc = CLM.L["You plus guild members (roster members first). Used while you're not in a real group."],
        hidden = notInTestMode, get = function() return testMode.groupSize or 10 end,
        set = function(v) testMode.groupSize = math.max(2, math.min(40, v)) end })
    form:Button({ label = "", text = CLM.L["Simulate raid group"], hidden = notInTestMode,
        func = function() testMode:SimulateGroup(testMode.groupSize) end })
    form:Button({ label = "", text = CLM.L["Remove simulated group"], hidden = notInTestMode,
        func = function() testMode:ClearSimulatedGroup() end })

    if not self.isOfficer then return end

    local logger = CLM.MODULES.Logger
    form:Header(CLM.L["Logging"])
    form:Select({ label = CLM.L["Logging level"], desc = CLM.L["How much is written to the log, for bug reports."],
        options = function()
            local options = {}
            for level, name in pairs(LOG.SEVERITY_LEVEL) do options[#options + 1] = { text = name, value = level } end
            table.sort(options, function(a, b) return a.value < b.value end)
            return options
        end,
        get = function() return logger:GetSeverity() end, set = function(v) logger:SetSeverity(v) end })
    form:Toggle({ label = CLM.L["Verbose"], desc = CLM.L["Adds data dumps to log lines."],
        get = function() return logger:GetVerbosity() end, set = function(v) logger:SetVerbosity(v) end })
    form:Button({ label = CLM.L["Log history"], text = CLM.L["Wipe"], func = function()
        UI.Confirm(CLM.L["Wipe the log history?"], function() logger:Wipe() end)
    end })

    form:Header(CLM.L["Danger zone"])
    form:Button({ label = CLM.L["Remove roster"], text = CLM.L["Remove roster"], color = UI.COLOR.BAD, hidden = NoRoster,
        desc = CLM.L["Removes the roster with all standings, for everyone. Use Set up BPGP to start again."],
        func = function()
            UI.Confirm(CLM.L["Remove the roster? All standings are removed for everyone in the guild. This can only be undone from the Audit tab."], function()
                local name = RosterName()
                if name then CLM.MODULES.RosterManager:DeleteRosterByName(name) end
            end)
        end })

    form:Header(CLM.L["About"])
    form:Description(function()
        return string.format(CLM.L["BPGP %s. Based on Core Loot Manager by Lantis and contributors (Apache License 2.0)."],
            CLM.MODULES.Version:GetString())
    end)
end

--[[
 * Page *
]]--

local SECTIONS = {
    { key = "personal", title = CLM.L["Personal"], build = BuildPersonal },
    { key = "guild", title = CLM.L["Guild"], build = BuildGuild },
    { key = "gear", title = CLM.L["Gear values"], build = BuildGearValues },
    { key = "advanced", title = CLM.L["Advanced"], build = BuildAdvanced },
}

local function SelectSection(self, key)
    self.section = key
    for _, section in ipairs(SECTIONS) do
        local selected = section.key == key
        self.navButtons[section.key].Selected:SetShown(selected)
        local form = self.forms[section.key]
        if selected and not form then
            form = UI.CreateForm(self.formArea)
            form.frame:SetAllPoints(self.formArea)
            local ok, err = pcall(section.build, self, form)
            if not ok then LOG:Error("Settings: building %s failed: %s", section.key, tostring(err)) end
            form.signature = section.key == "gear" and OverrideSignature() or nil
            self.forms[section.key] = form
        end
        if form then form.frame:SetShown(selected) end
    end
    self:Refresh()
end

function Settings:Build(content)
    local nav = UI.CreateInset(content)
    nav:SetPoint("TOPLEFT")
    nav:SetPoint("BOTTOMLEFT")
    nav:SetWidth(NAV_WIDTH)
    self.navButtons = {}
    local previous
    for _, section in ipairs(SECTIONS) do
        local button = CreateFrame("Button", nil, nav)
        button:SetHeight(S.BUTTON + 2)
        if previous then
            button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
            button:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -2)
        else
            button:SetPoint("TOPLEFT", S.XS, -S.XS)
            button:SetPoint("TOPRIGHT", -S.XS, -S.XS)
        end
        button.Text = UI.CreateLabel(button, section.title, "GameFontNormal")
        button.Text:SetPoint("LEFT", S.S, 0)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button.Selected = button:CreateTexture(nil, "ARTWORK")
        button.Selected:SetAllPoints()
        button.Selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        button.Selected:SetBlendMode("ADD")
        button.Selected:SetVertexColor(UI.COLOR.SELECTED:GetRGB())
        button.Selected:Hide()
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            SelectSection(self, section.key)
        end)
        self.navButtons[section.key] = button
        previous = button
    end

    local inset = UI.CreateInset(content)
    inset:SetPoint("TOPLEFT", nav, "TOPRIGHT", S.S, 0)
    inset:SetPoint("BOTTOMRIGHT")
    self.formArea = CreateFrame("Frame", nil, inset)
    self.formArea:SetPoint("TOPLEFT", S.M, -S.S)
    self.formArea:SetPoint("BOTTOMRIGHT", -28, S.S) -- room for the scroll bar
    SelectSection(self, "personal")
end

---@param key string? section to show
function Settings:ShowSection(key)
    if self.navButtons and key then SelectSection(self, key) end
end

function Settings:Refresh()
    local form = self.forms[self.section]
    if not form then return end
    -- The override list changes when an auction starts or an override is removed: rebuild it
    if self.section == "gear" and form.signature ~= OverrideSignature() then
        form:Clear()
        BuildGearValues(self, form)
        form.signature = OverrideSignature()
    end
    form:Refresh()
    self.window:SetSubtitle("")
    local footer = ""
    if not self.isOfficer and (self.section == "guild" or self.section == "gear") then
        footer = CLM.L["Read-only: only officers can change guild settings."]
    end
    self.window:SetPageFooter(footer)
end

CLM.GUI.MainWindow:RegisterPage(Settings)
