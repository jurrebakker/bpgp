-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --
local GuildRoster = GuildRoster or C_GuildInfo.GuildRoster

---@class TrustInfoProvider
---@field cache table
---@field cacheUpdateRequired boolean
local TrustInfoProvider = {}
function TrustInfoProvider:Initialize()
    LOG:Trace("TrustInfoProvider:Initialize()")
    self:WipeAll()
    self:BuildCache()
    self.cacheUpdateRequired = true
    CLM.MODULES.EventManager:RegisterWoWEvent({"PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE"}, (function(...)
        LOG:Debug("Rebuild trust cache after event")
        if not self.cacheUpdateRequired then
            GuildRoster()
            self.cacheUpdateRequired = true
        end
    end))
end

function TrustInfoProvider:BuildCache()
    if self.cacheUpdateRequired then
        self:WipeAll()
        self:BuildRankCache()
        self:BuildGuildCache()
        self.cacheUpdateRequired = false
    end
end

function TrustInfoProvider:BuildRankCache()
    LOG:Trace("TrustInfoProvider:BuildRankCache()")
    for i=1,GuildControlGetNumRanks() do
        local rankInfo = C_GuildInfo.GuildControlGetRankFlags(i)
        self.cache.ranks[i] = {}
        -- 11 View Officer Note / 12 Edit Officer Note. On Midnight both follow "Is Officer".
        self.cache.ranks[i].isOfficer = (rankInfo[11] and rankInfo[12]) and true or false
    end
end

function TrustInfoProvider:BuildGuildCache()
    LOG:Trace("TrustInfoProvider:BuildGuildCache()")
    for i=1,GetNumGuildMembers() do
        local name, rankName, rankIndex, _, _, _, _, _, _, _, _, _, _, _, _, _, GUID = GetGuildRosterInfo(i)
        if name then
            -- https://wowwiki-archive.fandom.com/wiki/API_GetGuildRosterInfo
            -- rankIndex
            -- Number - The number corresponding to the guild's rank.
            -- The Rank Index starts at 0, add 1 to correspond with the index used in GuildControlGetRankName(index)
            rankIndex = rankIndex + 1
            name = UTILS.Disambiguate(name)
            self.cache.guildies[name] = rankIndex
            self.cache.guildieGUIDs[name] = GUID
            if self.cache.ranks[rankIndex] then
                self.cache.ranks[rankIndex].name = rankName
                if self.cache.ranks[rankIndex].isOfficer then
                    self.cache.officers[name] = true
                end
            end
            if rankIndex == 1 then
                self.cache.guildMaster = name
            end
        end
    end
end

---@return table
function TrustInfoProvider:GetInfo()
    self:BuildCache()
    return self.cache
end

---@return table
function TrustInfoProvider:GetRanks()
    self:BuildCache()
    return self.cache.ranks
end

---@return table
function TrustInfoProvider:GetGuildies()
    self:BuildCache()
    return self.cache.guildies
end

---@param name string full name (Name-Realm)
---@return string? GUID
function TrustInfoProvider:GetGuildieGUID(name)
    self:BuildCache()
    return self.cache.guildieGUIDs[name]
end

function TrustInfoProvider:WipeAll()
    LOG:Trace("TrustInfoProvider:WipeAll()")
    self.cache = { guildMaster = "", officers = {}, ranks = {}, guildies = {}, guildieGUIDs = {} }
end


CLM.MODULES.TrustInfoProvider = TrustInfoProvider