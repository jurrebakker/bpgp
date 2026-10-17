-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

-- Test mode (docs/features/test-mode.md): BP EPGP runs against a separate world.
--  * ledger: the 'ledger_test' section of BPEPGP_DB (Database:Ledger()); the live ledger is never read or written
--  * comms: prefix BPEPT instead of BPEP (Comms), so only other clients in test mode see the traffic
--  * chat: printed locally with a [TEST] prefix, never sent (UTILS.SendChatMessage)
--  * permissions: unchanged
-- The mode is fixed for a session. Switching stores the choice and reloads the UI, so nothing
-- built from one ledger survives into the other. There is no way to apply test data to live.

local POPUP_SWITCH = "BPEPGP_TEST_MODE_SWITCH"
local POPUP_RESET = "BPEPGP_TEST_MODE_RESET"

local DEFAULT_GROUP_SIZE = 10

---@class TestMode
---@field db table
---@field groupSize number?
local TestMode = {}

---@return boolean
function TestMode:IsOn()
    return CLM.MODULES.Database:IsTestMode()
end

local function CanSwitch()
    if CLM.MODULES.AuctionManager and CLM.MODULES.AuctionManager:IsAuctionInProgress() then
        LOG:Message(CLM.L["Can't switch test mode while an auction is in progress."])
        return false
    end
    return true
end

function TestMode:RequestSwitch()
    if not CanSwitch() then return end
    StaticPopup_Show(POPUP_SWITCH, self:IsOn() and CLM.L["Leave test mode and go back to live data?"] or
        CLM.L["Switch to test mode? You get a separate test ledger; live data is not touched."])
end

---@param copyLive boolean
function TestMode:RequestReset(copyLive)
    if not self:IsOn() then return end
    if not CanSwitch() then return end
    local dialog = StaticPopup_Show(POPUP_RESET, copyLive and CLM.L["Replace all test data with a copy of the live data?"] or
        CLM.L["Wipe all test data and start empty?"])
    if dialog then dialog.data = copyLive end
end

local function Reset(copyLive)
    CLM.MODULES.Database:ResetTestLedger(copyLive)
    -- Test auction history goes with the test ledger
    local history = CLM.MODULES.Database:Personal('auctionHistory2_test')
    history.stack = {}
    ReloadUI()
end

--[[
 * Simulated raid group *
 Test mode only, and only while you're not in a real group: RaidManager reads this list instead of
 the WoW raid roster. You are the raid leader (index 1). The other members are guild members, roster
 members first, so they can bid. Stored in the personal DB so it survives a reload.
]]--

---@return string[]? names, you first
function TestMode:GetSimulatedGroup()
    if not self:IsOn() or IsInGroup() then return nil end
    local names = self.db and self.db.group
    if type(names) ~= "table" or #names == 0 then return nil end
    return names
end

---@param name string
---@return boolean
function TestMode:IsSimulatedPlayer(name)
    local group = self:GetSimulatedGroup()
    if not group then return false end
    for i = 2, #group do
        if group[i] == name then return true end
    end
    return false
end

local function Shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

---@param size number? total group size including you
function TestMode:SimulateGroup(size)
    if not self:IsOn() then return end
    if IsInGroup() then
        LOG:Message(CLM.L["You are in a real group; leave it to use a simulated raid group."])
        return
    end
    size = math.max(2, math.min(40, tonumber(size) or DEFAULT_GROUP_SIZE))
    local me = CLM.UTILS.whoami()
    local roster = CLM.MODULES.RosterManager:GetRoster()
    local maxLevel = GetMaxLevelForPlayerExpansion()
    local onRoster, others = {}, {}
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level, _, _, _, _, _, _, _, _, _, _, _, _, GUID = GetGuildRosterInfo(i)
        if name and GUID and level >= maxLevel then
            name = CLM.UTILS.Disambiguate(name)
            if name ~= me then
                if roster and roster:IsProfileInRoster(GUID) then
                    onRoster[#onRoster + 1] = name
                else
                    others[#others + 1] = name
                end
            end
        end
    end
    local names = { me }
    for _, list in ipairs({ Shuffle(onRoster), Shuffle(others) }) do
        for _, name in ipairs(list) do
            if #names >= size then break end
            names[#names + 1] = name
        end
    end
    self.db.group = names
    LOG:Message(CLM.L["Simulated raid group: you plus %s guild members (%s of them on the roster)."], #names - 1, math.min(#onRoster, #names - 1))
    CLM.MODULES.RaidManager:HandleRosterUpdateEvent()
end

function TestMode:ClearSimulatedGroup()
    if not self.db then return end
    self.db.group = {}
    LOG:Message(CLM.L["Simulated raid group removed."])
end

--[[
 * Simulated bidders *
 Every other member of the current BP EPGP raid places a random bid on each auctioned item:
 a tier, off spec, pass, or nothing. Bids go straight into AuctionManager, like a received bid.
]]--
function TestMode:SimulateBids()
    if not self:IsOn() then return end
    local auctionManager = CLM.MODULES.AuctionManager
    if not auctionManager:IsAuctionInProgress() then
        LOG:Message(CLM.L["No auction in progress."])
        return
    end
    local auction = auctionManager:GetCurrentAuctionInfo()
    local raid = auction:GetRaid()
    if not raid then return end
    local me = CLM.UTILS.whoami()
    local count = 0
    for _, profile in ipairs(raid:Profiles()) do
        local name = profile:Name()
        if name ~= me then
            for uid, item in pairs(auction:GetItems()) do
                local values = item:GetValues()
                local tiers = {}
                for _, tier in ipairs(CLM.CONSTANTS.SLOT_VALUE_TIERS_ORDERED) do
                    if (tonumber(values[tier]) or 0) > 0 then tiers[#tiers + 1] = tier end
                end
                local roll = math.random(100)
                local value, bidType
                if roll <= 15 then
                    -- no response
                elseif roll <= 30 then
                    value, bidType = 0, CLM.CONSTANTS.BID_TYPE.PASS
                elseif roll <= 40 and auction:GetUseOS() then
                    value, bidType = tonumber(values[CLM.CONSTANTS.SLOT_VALUE_TIER.BASE]) or 0, CLM.CONSTANTS.BID_TYPE.OFF_SPEC
                elseif #tiers > 0 then
                    local tier = tiers[math.random(#tiers)]
                    value, bidType = tonumber(values[tier]) or 0, tier
                else
                    -- No tier has a value: bid the Base tier, like the bidding window's fallback button
                    value, bidType = tonumber(values[CLM.CONSTANTS.SLOT_VALUE_TIER.BASE]) or 0, CLM.CONSTANTS.SLOT_VALUE_TIER.BASE
                end
                if bidType then
                    auctionManager:HandleSubmitBid(CLM.MODELS.BiddingCommSubmitBid:New(value, bidType, uid, {}), name)
                    count = count + 1
                end
            end
        end
    end
    LOG:Message(CLM.L["Simulated %s bids."], count)
end

local function RegisterPopups(self)
    StaticPopupDialogs[POPUP_SWITCH] = {
        text = "%s\n\n" .. CLM.L["The UI will reload."],
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            CLM.MODULES.Database:SetTestModeOnReload(not self:IsOn())
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopupDialogs[POPUP_RESET] = {
        text = "%s\n\n" .. CLM.L["The UI will reload."],
        button1 = YES,
        button2 = NO,
        OnAccept = function(_, copyLive)
            Reset(copyLive)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function RegisterOptions(self)
    CLM.MODULES.ConfigManager:RegisterSlash({
        test = {
            type = "execute",
            name = CLM.L["Test mode"],
            desc = CLM.L["Enter or leave test mode"],
            func = function() self:RequestSwitch() end,
        },
        testgroup = {
            type = "input",
            name = CLM.L["Simulate raid group"],
            desc = CLM.L["Test mode: simulate a raid group of this size (0 removes it)."],
            set = function(_, v)
                if (tonumber(v) or 0) <= 0 then
                    self:ClearSimulatedGroup()
                else
                    self:SimulateGroup(v)
                end
            end,
        },
        testbids = {
            type = "execute",
            name = CLM.L["Simulate bids"],
            desc = CLM.L["Test mode: other raid members place random bids on the running auction."],
            func = function() self:SimulateBids() end,
        },
    })
end

function TestMode:Initialize()
    LOG:Trace("TestMode:Initialize()")
    self.db = CLM.MODULES.Database:Personal('testModeData', { group = {} })
    RegisterPopups(self)
    RegisterOptions(self)
    if self:IsOn() then
        LOG:Message("|cffff8000" .. CLM.L["TEST MODE is on."] .. "|r " .. CLM.L["Live data is not used. Type /bpepgp test to leave."])
    end
end

CLM.MODULES.TestMode = TestMode
