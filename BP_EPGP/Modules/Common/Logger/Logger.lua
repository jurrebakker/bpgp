-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

-- Module part
---@class Logger
---@field db table
local Logger = {}
function Logger:Initialize()
    LOG:Trace("Logger:Initialize()")
    self.db = CLM.MODULES.Database:Logger()
end

---@param severity number
function Logger:SetSeverity(severity)
    self.db.severity = severity
    LOG:SetSeverity(self.db.severity)
end

---@param verbosity boolean
function Logger:SetVerbosity(verbosity)
    self.db.verbosity = verbosity
    LOG:SetVerbosity(self.db.verbosity)
end

---@return number
function Logger:GetSeverity()
    return LOG:GetSeverity()
end

---@return boolean
function Logger:GetVerbosity()
    return LOG:GetVerbosity()
end

function Logger:Wipe()
    local db = LOG:GetDatabase() -- luacheck: ignore
    wipe(db)
    collectgarbage()
end

-- Publish API
CLM.MODULES.Logger = Logger
