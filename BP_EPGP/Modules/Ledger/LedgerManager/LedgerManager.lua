-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local LedgerLib = LibStub("BPEPGP-EventSourcing/LedgerFactory")

local TWO_MONTHS_IN_SECONDS = 60 * 60 * 24 * 30 * 2

local STATUS_SYNCED = "synced"
local STATUS_OUT_OF_SYNC = "out_of_sync"
-- local STATUS_UNKNOWN = "unknown"
local STATUS_UNKNOWN_TYPE = "unknown_type"

-- Sync control (hashes, requests) only from guild members (S5); data only from officers
local function isGuildMember(name)
    return CLM.MODULES.TrustInfoProvider:GetGuildies()[name] ~= nil
end

local function registerReceiveCallback(callback)
    CLM.MODULES.Comms:Register(CLM.COMM_CHANNEL.LEDGER.SYNC, callback, isGuildMember)
    CLM.MODULES.Comms:Register(CLM.COMM_CHANNEL.LEDGER.DATA, callback, CONSTANTS.ACL.LEVEL.OFFICER)
end

--[[
    Officers may send entries. A live push of a single new entry must also come from the
    entry's creator (S7); relayed week data may come from any officer.
]]--
local function authorize(entry, sender, isLiveRemote)
    sender = UTILS.Disambiguate(sender)
    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER, sender) then
        return false
    end
    if isLiveRemote and entry then
        local GUID = CLM.MODULES.TrustInfoProvider:GetGuildieGUID(sender)
        if not GUID then return false end
        local iGUID = UTILS.getIntegerGuid(GUID)
        local creator = entry:creatorFull()
        return iGUID[1] == creator[1] and iGUID[2] == creator[2]
    end
    return true
end

local function createLedger(self, database)
    local ledger = LedgerLib.createLedger(
        database,
        (function(data, distribution, target, callbackFn, callbackArg)
            return CLM.MODULES.Comms:Send(CLM.COMM_CHANNEL.LEDGER.SYNC, data, distribution, target, "NORMAL")
        end), -- send
        registerReceiveCallback, -- registerReceiveHandler
        authorize, -- authorizationHandler
        (function(data, distribution, target, progressCallback)
            return CLM.MODULES.Comms:Send(CLM.COMM_CHANNEL.LEDGER.DATA, data, distribution, target, "NORMAL")
        end), -- sendLargeMessage
        0, 100, LOG)

        ledger.addSyncStateChangedListener(function(_, status)
            self:UpdateSyncState(status)
        end)

        -- Skipped entries (S3): warn once per new batch instead of failing silently
        ledger.addMutatorFailedListener(function()
            if self.failureWarningPending then return end
            self.failureWarningPending = true
            C_Timer.After(5, function()
                self.failureWarningPending = nil
                local count = 0
                for _ in pairs(ledger.getFailedEntries()) do count = count + 1 end
                if count > (self.failuresWarned or 0) then
                    self.failuresWarned = count
                    LOG:Warning(CLM.L["%s ledger entries could not be applied and were skipped. Standings may be incomplete; tell an officer."], count)
                end
            end)
        end)

        -- ledger.setDefaultHandler(function()
        --     self:UpdateSyncState(STATUS_UNKNOWN_TYPE)
        --     LOG:Warning("LedgerManager: Entering incoherent state.")
        -- end)

        return ledger
end

---@class LedgerManager
---@field _initialized boolean
---@field activeDatabase table
---@field activeLedger table
---@field disabled boolean
---@field incoherentState boolean
---@field inSync boolean
---@field lastEntry any
---@field mutatorCallbacks table
---@field onRestartCallbacks table
---@field onUpdateCallbacks table
---@field syncOngoing boolean
---@field recentDataCache table?
---@field recentDataCacheSeconds number?
---@field failureWarningPending boolean?
---@field failuresWarned number?
local LedgerManager = { _initialized = false}
function LedgerManager:Initialize()
    self.activeDatabase = CLM.MODULES.Database:Ledger()
    self.activeLedger = createLedger(self, self.activeDatabase)
    self.mutatorCallbacks = {}
    self.onUpdateCallbacks = {}
    self.onRestartCallbacks = {}
    self._initialized = true

    self:RegisterOnUpdate(function() self.recentDataCache = nil end)
end

---@return boolean
function LedgerManager:IsInitialized()
    return self._initialized
end

function LedgerManager:Enable()
    self.activeLedger.getStateManager():setUpdateInterval(50)
    if CLM.GlobalConfigs:GetDisableSync() then
        LedgerManager:Cutoff()
        LOG:Message("Ledger synchronisation was disabled. Use this at your own risk.")
    else
        self:UpdateSending()
        -- Promotions and demotions take effect without /reload (L2)
        CLM.MODULES.EventManager:RegisterWoWBucketEvent({"GUILD_ROSTER_UPDATE"}, 5, function()
            self:UpdateSending()
        end)
    end
end

-- Officers serve sync data; everyone else only listens
function LedgerManager:UpdateSending()
    if self.disabled then return end
    local isOfficer = CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER)
    local isSending = self.activeLedger.isSendingEnabled()
    if isOfficer and not isSending then
        self.activeLedger.enableSending()
    elseif not isOfficer and isSending then
        self.activeLedger.disableSending()
    end
end

-- This is not reversible until reload
function LedgerManager:Cutoff()
    self.activeLedger.disableSending()
    CLM.MODULES.Comms:Suspend(CLM.COMM_CHANNEL.LEDGER.SYNC)
    CLM.MODULES.Comms:Suspend(CLM.COMM_CHANNEL.LEDGER.DATA)
    self.disabled = true
end

function LedgerManager:DisableAdvertising()
    self.activeLedger.disableSending()
end

---@param class any
---@param mutatorFn function
function LedgerManager:RegisterEntryType(class, mutatorFn)
    if self.mutatorCallbacks[class] then
        LOG:Error("Class %s already exists in Ledger Entries.", class)
        return
    end
    self.mutatorCallbacks[class] = mutatorFn

    self.activeLedger.registerMutator(class, mutatorFn)
end

---@param callback function
function LedgerManager:RegisterOnRestart(callback)
    tinsert(self.onRestartCallbacks, callback)
    self.activeLedger.addStateRestartListener(callback)
end

---@param callback function
function LedgerManager:RegisterOnUpdate(callback)
    tinsert(self.onUpdateCallbacks, callback)
    self.activeLedger.addStateChangedListener(callback)
end

---@return table
function LedgerManager:GetPeerStatus()
    return self.activeLedger.getPeerStatus()
end

function LedgerManager:RequestPeerStatusFromGuild()
    self.activeLedger.requestPeerStatusFromGuild()
end

---@param status string?
function LedgerManager:UpdateSyncState(status)
    self.incoherentState = false
    self.inSync = false
    self.syncOngoing = false
    if self._initialized then
        if status == STATUS_UNKNOWN_TYPE then
            self.incoherentState = true
        elseif status == STATUS_SYNCED then
            self.inSync = true
        elseif status == STATUS_OUT_OF_SYNC then
            self.syncOngoing = true
        end
    end
end

---@return boolean
function LedgerManager:IsInIncoherentState()
    return self.incoherentState
end

---@return boolean
function LedgerManager:IsInSync()
    return self.inSync
end

---@return boolean
function LedgerManager:IsSyncOngoing()
    return self.syncOngoing
end

---@return boolean
function LedgerManager:IsDisabled()
    return self.disabled
end

---@return number
function LedgerManager:Lag()
    return self.activeLedger.getStateManager():lag()
end

---@return number
function LedgerManager:Hash()
    return self.activeLedger.getStateManager():stateHash()
end

---@return number
function LedgerManager:Length()
    return self.activeLedger.getSortedList():length()
end

---@return table
function LedgerManager:GetData()
    return self.activeLedger.getSortedList():entries()
end

---@param seconds number? timeframe in seconds (default & max: 2 months)
---@return table
function LedgerManager:GetRecentData(seconds)
    seconds = math.min(seconds or TWO_MONTHS_IN_SECONDS, TWO_MONTHS_IN_SECONDS)
    if self.recentDataCache and self.recentDataCacheSeconds == seconds then
        return self.recentDataCache
    end
    local now = time()
    local cutoff = now - seconds
    local result = {}
    for _, entry in ipairs(self:GetData()) do
        local entryTime = entry:time()
        if entryTime > now then break end
        if entryTime >= cutoff then
            result[#result+1] = entry
        end
    end
    self.recentDataCache = result
    self.recentDataCacheSeconds = seconds
    return result
end

function LedgerManager:RequestPeerStatusFromRaid()
    self.activeLedger.requestPeerStatusFromRaid()
end

---@param entry any
---@param catchup boolean?
function LedgerManager:Submit(entry, catchup)
    LOG:Trace("LedgerManager:Submit()")
    if not entry then return end
    self.lastEntry = entry
    self.activeLedger.submitEntry(entry, UTILS.whoami())
    if catchup then
        self.activeLedger.catchup()
    end
end

---@param entry any
---@param catchup boolean?
function LedgerManager:Remove(entry, catchup)
    LOG:Trace("LedgerManager:Remove()")
    if not entry then return end
    self.activeLedger.ignoreEntry(entry)
    if catchup then
        self.activeLedger.catchup()
    end
end

function LedgerManager:CancelLastEntry()
    if not self._initialized then return end
    if self.lastEntry then
        self:Remove(self.lastEntry)
        self.lastEntry = nil
    end
end

function LedgerManager:Wipe()
    if not self._initialized then return end
    self:DisableAdvertising()
    local db = CLM.MODULES.Database:Ledger()
    wipe(db)
    collectgarbage()
    self:Enable()
end


CLM.MODULES.LedgerManager = LedgerManager
