-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --
---@class ACL
---@field guildMaster boolean
local ACL = {}
function ACL:Initialize()
    LOG:Trace("ACL:Initialize()")
    self.guildMaster = IsGuildLeader()
end

---@param name string?
---@return boolean
function ACL:IsTrusted(name)
    return self:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER, name) or false
end

---@param level number?
---@param name string?
---@return boolean
function ACL:CheckLevel(level, name)
    LOG:Trace("ACL:CheckLevel()")
    local info = CLM.MODULES.TrustInfoProvider:GetInfo()
    -- By default block everything except for GM if level not provided
    level = level or CONSTANTS.ACL.LEVEL.GUILD_MASTER
    -- Request is for self
    if name == nil then
        if self.guildMaster then
            return true
        end
        name = UTILS.whoami()
    end
    local isGuildMaster = (info.guildMaster == name) or false
    if level >= CONSTANTS.ACL.LEVEL.GUILD_MASTER then
        return isGuildMaster
    end
    if level >= CONSTANTS.ACL.LEVEL.OFFICER then
        return isGuildMaster or (info.officers[name] or false)
    end
    return true
end

---@diagnostic disable-next-line: missing-fields
CONSTANTS.ACL = {}
-- Officer = a guild rank with "Is Officer" (rank permission flags 11/12, view/edit officer note).
-- See docs/decisions.md, S1/S2.
CONSTANTS.ACL.LEVEL = {
    PLEBS = 0,
    OFFICER = 1,
    GUILD_MASTER = 2
}

CONSTANTS.ACL.LEVELS = UTILS.Set({
    CONSTANTS.ACL.LEVEL.PLEBS,
    CONSTANTS.ACL.LEVEL.OFFICER,
    CONSTANTS.ACL.LEVEL.GUILD_MASTER
})

CLM.MODULES.ACL = ACL
