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

---@class TestMode
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
    local options = {
        test_mode_header = {
            type = "header",
            name = CLM.L["Test mode"],
            order = 9000
        },
        test_mode_info = {
            type = "description",
            name = CLM.L["Test mode uses a separate ledger and its own sync channel. Only other players in test mode see your test changes, and chat messages are only shown to you. Live data is never changed."],
            width = "full",
            order = 9001
        },
        test_mode_switch = {
            name = function() return self:IsOn() and CLM.L["Leave test mode"] or CLM.L["Enter test mode"] end,
            type = "execute",
            func = function() self:RequestSwitch() end,
            width = 1,
            order = 9002
        },
        test_mode_reset_empty = {
            name = CLM.L["Reset: empty"],
            desc = CLM.L["Wipes all test data."],
            type = "execute",
            func = function() self:RequestReset(false) end,
            hidden = function() return not self:IsOn() end,
            width = 1,
            order = 9003
        },
        test_mode_reset_copy = {
            name = CLM.L["Reset: copy of live"],
            desc = CLM.L["Replaces all test data with a copy of today's live data."],
            type = "execute",
            func = function() self:RequestReset(true) end,
            hidden = function() return not self:IsOn() end,
            width = 1,
            order = 9004
        },
    }
    CLM.MODULES.ConfigManager:Register(CLM.CONSTANTS.CONFIGS.GROUP.GLOBAL, options)

    CLM.MODULES.ConfigManager:RegisterSlash({
        test = {
            type = "execute",
            name = CLM.L["Test mode"],
            desc = CLM.L["Enter or leave test mode"],
            func = function() self:RequestSwitch() end,
        }
    })
end

function TestMode:Initialize()
    LOG:Trace("TestMode:Initialize()")
    RegisterPopups(self)
    RegisterOptions(self)
    if self:IsOn() then
        LOG:Message("|cffff8000" .. CLM.L["TEST MODE is on."] .. "|r " .. CLM.L["Live data is not used. Type /bpepgp test to leave."])
    end
end

CLM.MODULES.TestMode = TestMode
