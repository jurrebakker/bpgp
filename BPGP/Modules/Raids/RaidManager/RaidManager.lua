-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local CHAT_MESSAGE_CHANNEL = "RAID_WARNING"

local whoamiGUID = UTILS.whoamiGUID()

local getGuidFromInteger = UTILS.getGuidFromInteger

local function IsPlayerInPvP()
	local bg = UnitInBattleground("player")
	local arena = IsActiveBattlefieldArena()
	return arena or (bg ~= nil)
end

-- The raid group: the WoW raid roster, or the simulated group in test mode (TestMode:GetSimulatedGroup)
local function GroupIsInRaid()
    if CLM.MODULES.TestMode:GetSimulatedGroup() then return true end
    return IsInRaid()
end

---@param index number
---@return string? name
---@return number? rank 2 = leader, 1 = assistant, 0 = member
local function GroupMemberInfo(index)
    local group = CLM.MODULES.TestMode:GetSimulatedGroup()
    if group then
        local name = group[index]
        if not name then return nil end
        return name, (index == 1) and 2 or 0
    end
    local name, rank = GetRaidRosterInfo(index)
    return name, rank
end

-- In combat on 12.x roster names can be secret values; then the roster can't be read right now
---@return boolean
local function GroupHasSecrets()
    for i=1,MAX_RAID_MEMBERS do
        local name, rank = GroupMemberInfo(i)
        if UTILS.IsSecret(name) or UTILS.IsSecret(rank) then return true end
    end
    return false
end

---@class RaidManager
---@field RaidLeader string
---@field MasterLooter string
---@field IsMasterLootSystem boolean
---@field IsGroupLootSystem boolean
---@field RaidAssistants table
---@field RaidMembers table
---@field _initialized boolean
---@field cache table
---@field isEventHandlingRegistered boolean
---@field rosterUpdatePending boolean?
local RaidManager = {}
function RaidManager:Initialize()
    LOG:Trace("RaidManager:Initialize()")

    self:WipeAll()
    -- self.lastRosterUpdateTime = 0

    self.RaidLeader = ""
    self.MasterLooter = ""
    self.IsMasterLootSystem = false
    self.IsGroupLootSystem = true
    self.RaidAssistants = {}
    self.RaidMembers = {}

    -- Register mutators
    CLM.MODULES.LedgerManager:RegisterEntryType(
        CLM.MODELS.LEDGER.RAID.Create,
        (function(entry)
            LOG:TraceAndCount("mutator(RaidCreate)")
            local raidUid = entry:uuid()
            local name = entry:name()
            local config = CLM.MODELS.RosterConfiguration:New()
            config:inflate(entry:config())
            local rosterUid = entry:rosterUid()

            local roster = CLM.MODULES.RosterManager:GetRosterByUid(rosterUid)
            if not roster then
                LOG:Debug("RaidManager mutator(): Unknown roster uid %s", rosterUid)
                return
            end
            -- Handle existing raid gracefully
            local creator = getGuidFromInteger(entry:creatorFull())
            local raid = CLM.MODELS.Raid:New(raidUid, name, roster, config, creator, entry)
            LOG:Debug("RaidManager mutator(): New raid %s(%s) from %s", name, raidUid, creator)
            self.cache.raids[raidUid] = raid
            self:UpdateProfileCurentRaid(creator, raid)
        end)
    )

    CLM.MODULES.LedgerManager:RegisterEntryType(
        CLM.MODELS.LEDGER.RAID.Update,
        (function(entry)
            LOG:TraceAndCount("mutator(RaidUpdate)")
            local raidUid = entry:raid()
            local joiners = entry:joiners()
            local leavers = entry:leavers()
            local removed = entry:removed()
            local raid = self:GetRaidByUid(raidUid)
            if not raid then
                LOG:Debug("RaidManager mutator(): Unknown raid uid %s", raidUid)
                return
            end
            -- Add Joiners
            for _, iGUID in ipairs(joiners) do
                local GUID = getGuidFromInteger(iGUID)
                local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
                if profile then
                    self:UpdateProfileCurentRaid(GUID, raid)
                end
            end
            -- Remove leavers
            for _, iGUID in ipairs(leavers) do
                local GUID = getGuidFromInteger(iGUID)
                local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
                if profile then
                    self:UpdateProfileCurentRaid(GUID, nil)
                end
            end
            -- Remove removed
            for _, iGUID in ipairs(removed) do
                local GUID = getGuidFromInteger(iGUID)
                local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
                if profile then
                    self:UpdateProfileCurentRaid(GUID, nil)
                end
            end
        end)
    )

    CLM.MODULES.LedgerManager:RegisterEntryType(
        CLM.MODELS.LEDGER.RAID.Start,
        (function(entry)
            LOG:TraceAndCount("mutator(RaidStart)")
            local raidUid = entry:raid()
            local players = entry:players()
            local raid = self:GetRaidByUid(raidUid)
            if not raid then
                LOG:Debug("RaidManager mutator(): Unknown raid uid %s", raidUid)
                return
            end
            -- Add players
            for _,iGUID in ipairs(players) do
                local GUID = getGuidFromInteger(iGUID)
                local profile = CLM.MODULES.ProfileManager:GetProfileByGUID(GUID)
                if profile then
                    self:UpdateProfileCurentRaid(GUID, raid)
                else
                    LOG:Debug("RaidManager mutator(): Missing profile for: %s", GUID)
                end
            end
            raid:Start(entry:time(), getGuidFromInteger(entry:creatorFull()))
        end)
    )

    CLM.MODULES.LedgerManager:RegisterEntryType(
        CLM.MODELS.LEDGER.RAID.End,
        (function(entry)
            LOG:TraceAndCount("mutator(RaidEnd)")
            local raidUid = entry:raid()

            local raid = self:GetRaidByUid(raidUid)
            if not raid then
                LOG:Debug("RaidManager mutator(): Unknown raid uid %s", raidUid)
                return
            end

            raid:End(entry:time())

            local players = raid:Players()
            for _,GUID in ipairs(players) do
                self:UpdateProfileCurentRaid(GUID, nil)
            end
        end)
    )

    CLM.MODULES.LedgerManager:RegisterOnUpdate(function(lag, uncommitted)
        if lag ~= 0 or uncommitted ~= 0 then return end
        self:RegisterEventHandling()
        self:ParseStatus()
    end)

    CLM.MODULES.LedgerManager:RegisterOnRestart(function()
        self:WipeAll()
    end)

    C_Timer.After(20, function()
        self:RegisterEventHandling()
        self:ParseStatus()
    end) -- backup in case of 0 entries

end

function RaidManager:ParseStatus()
    LOG:Trace("RaidManager:ParseStatus()")
    if not self._initialized then
        -- Mark raids as stale
        for _, raid in pairs(self.cache.raids) do
            if raid:IsActive() then
                local referenceTime = raid:StartTime()
                if referenceTime == 0 then
                    referenceTime = raid:CreatedAt()
                end

                if (GetServerTime() - referenceTime) > 86400 then
                    raid:SetStale()
                end
            end
        end

        self:HandleRosterUpdateEvent()

        self._initialized = true
    end
end

---@return boolean
function RaidManager:IsInitialized()
    return self._initialized
end

---@return table
function RaidManager:ListRaids()
    return self.cache.raids
end

---@param raidUid number|string
---@return Raid?
function RaidManager:GetRaidByUid(raidUid)
    return self.cache.raids[raidUid]
end

---@return boolean
function RaidManager:IsInRaid()
    return self.cache.profileRaidInfo[whoamiGUID] and true or false
end

---@return boolean
function RaidManager:IsInActiveRaid()
    return self:IsInRaid() and self:GetRaid():IsActive() or false
end

---@return boolean
function RaidManager:IsInCreatedRaid()
    return self:IsInRaid() and (CONSTANTS.RAID_STATUS.CREATED == self:GetRaid():Status())
end

---@return boolean
function RaidManager:IsInProgressingRaid()
    return self:IsInRaid() and (CONSTANTS.RAID_STATUS.IN_PROGRESS == self:GetRaid():Status())
end

-- handles connection of user with newest ledger raid entity
---@param GUID string
---@param raid Raid?
function RaidManager:UpdateProfileCurentRaid(GUID, raid)
    LOG:Debug("RaidManager:UpdateProfileCurentRaid(%s): %s", GUID, raid and "Add" or "Remove")
    if CLM.MODULES.ProfileManager:GetProfileByGUID(GUID) then
        local current = self.cache.profileRaidInfo[GUID]
        if current and current:IsActive() then
            current:RemovePlayer(GUID)
        end
        if raid then
            self.cache.profileRaidInfo[GUID] = self.cache.raids[raid:UID()]
            raid:AddPlayer(GUID)
        else
            self.cache.profileRaidInfo[GUID] = nil
        end
    end
end

---@param GUID string
---@return Raid?
function RaidManager:GetProfileRaid(GUID)
    return self.cache.profileRaidInfo[GUID]
end

---@param roster Roster
---@param name string
---@param config table
function RaidManager:CreateRaid(roster, name, config)
    LOG:Trace("RaidManager:CreateRaid()")
    if not UTILS.typeof(roster, CLM.MODELS.Roster) then
        LOG:Error("RaidManager:CreateRaid(): Missing valid roster")
        return
    end
    if not UTILS.typeof(config, CLM.MODELS.RosterConfiguration) then
        LOG:Error("RaidManager:CreateRaid(): Missing valid configuration")
        return
    end
    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER) then
        LOG:Message(CLM.L["You are not allowed to create raids."])
        return
    end
    if self:IsInActiveRaid() then
        LOG:Message(CLM.L["You are already in an active raid. Leave or finish it before creating new one."])
        return
    end
    CLM.MODULES.LedgerManager:Submit(CLM.MODELS.LEDGER.RAID.Create:new(roster:UID(), name, config))
end

---@param raid Raid
function RaidManager:StartRaid(raid)
    LOG:Trace("RaidManager:StartRaid()")
    if not UTILS.typeof(raid, CLM.MODELS.Raid) then
        LOG:Message(CLM.L["Missing valid raid"])
        return
    end
    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER) then
        LOG:Message(CLM.L["You are not allowed to start raid."])
        return
    end
    if raid:Status() ~= CONSTANTS.RAID_STATUS.CREATED then
        LOG:Message(CLM.L["You can only start a freshly created raid."])
        return
    end
    if (self:GetRaid() ~= raid) or not GroupIsInRaid() then
        LOG:Message(CLM.L["You are not in the raid."])
        return
    end
    if GroupHasSecrets() then
        LOG:Message(CLM.L["The raid roster can't be read right now (combat). Try again after combat."])
        return
    end

    local players = {}
    for i=1,MAX_RAID_MEMBERS do
        local name = GroupMemberInfo(i)
        if name then
            local profile = CLM.MODULES.ProfileManager:GetProfileByName(UTILS.Disambiguate(name))
            if profile then
                tinsert(players, profile)
            end
        end
    end

    -- Start Raid
    CLM.MODULES.LedgerManager:Submit(CLM.MODELS.LEDGER.RAID.Start:new(raid:UID(), players), true)
    if CLM.GlobalConfigs:GetRaidWarning() and GroupIsInRaid() then
        UTILS.SendChatMessage(string.format(CLM.L["Raid [%s] started"], raid:Name()) , CHAT_MESSAGE_CHANNEL)
    end
    self:HandleRosterUpdateEvent()
    -- On Time Bonus
    local config = raid:Configuration()
    local roster = raid:Roster()
    if roster then
        if not config then
            config = roster.configuration
        end
        local onTimeBonusValue = config:Get("onTimeBonusValue")
        if config:Get("onTimeBonus") and onTimeBonusValue > 0 then
            CLM.MODULES.PointManager:UpdateRaidPoints(raid, onTimeBonusValue, CONSTANTS.POINT_CHANGE_REASON.ON_TIME_BONUS, CONSTANTS.POINT_MANAGER_ACTION.MODIFY, nil, CONSTANTS.POINT_CHANGE_TYPE.POINTS)
        end
    end
end

---@param raid Raid
function RaidManager:EndRaid(raid)
    LOG:Trace("RaidManager:EndRaid()")
    if not UTILS.typeof(raid, CLM.MODELS.Raid) then
        LOG:Message(CLM.L["Missing valid raid"])
        return
    end
    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER) then
        LOG:Message(CLM.L["You are not allowed to start raid."])
        return
    end
    if not raid:Status() then
        LOG:Message(CLM.L["You can only end an active raid."])
        return
    end
    self:HandleRosterUpdateEvent()
    -- End raid
    CLM.MODULES.LedgerManager:Submit(CLM.MODELS.LEDGER.RAID.End:new(raid:UID()), true)

    if CLM.GlobalConfigs:GetRaidWarning() and GroupIsInRaid() then
        UTILS.SendChatMessage(string.format(CLM.L["Raid [%s] ended"], raid:Name()) , CHAT_MESSAGE_CHANNEL)
    end
end

---@param raid Raid
function RaidManager:JoinRaid(raid)
    LOG:Trace("RaidManager:JoinRaid()")
    if not UTILS.typeof(raid, CLM.MODELS.Raid) then
        LOG:Message(CLM.L["Missing valid raid"])
        return
    end
    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER) then
        LOG:Message(CLM.L["You are not allowed to join raid."])
        return
    end
    if not raid:IsActive() then
        LOG:Message(CLM.L["You can only join an active raid."])
        return
    end
    if raid == self:GetRaid() then
        LOG:Message(CLM.L["You can only join different raid than your current one."])
        return
    end
    local myProfile = CLM.MODULES.ProfileManager:GetMyProfile()
    if myProfile == nil then
        error("My profile is nil")
    end
    CLM.MODULES.LedgerManager:Submit(CLM.MODELS.LEDGER.RAID.Update:new(raid:UID(), {}, {CLM.MODULES.ProfileManager:GetMyProfile()}), true)
end

function RaidManager:RegisterEventHandling()
    if self.isEventHandlingRegistered then return end
    CLM.MODULES.EventManager:RegisterWoWBucketEvent({"GROUP_ROSTER_UPDATE", "READY_CHECK"}, 3, (function(...)
        self:HandleRosterUpdateEvent()
    end))
    CLM.MODULES.EventManager:RegisterWoWBucketEvent({"PARTY_LOOT_METHOD_CHANGED","PLAYER_ROLES_ASSIGNED"}, 3, (function(...)
        self:UpdateGameRaidInformation() -- we dont need to check others; im not even sure if we need to do this
    end))
    self.isEventHandlingRegistered = true
end

local reentrance = false
function RaidManager:HandleRosterUpdateEvent()
    LOG:Trace("RaidManager:HandleRosterUpdateEvent()")
    if reentrance then LOG:Debug("Reentrance!") return end
    if not GroupIsInRaid() then return end
    if GroupHasSecrets() then
        -- Retry once the roster is readable again; otherwise everyone would look like a leaver
        if not self.rosterUpdatePending then
            self.rosterUpdatePending = true
            C_Timer.After(5, function()
                self.rosterUpdatePending = nil
                self:HandleRosterUpdateEvent()
            end)
        end
        return
    end
    reentrance = true
    -- Update wow raid information
    self:UpdateGameRaidInformation()
    -- Handle roster update
    if self:IsRaidOwner() and self:IsInProgressingRaid() then
        self:UpdateRaiderList()
    end
    reentrance = false
end

function RaidManager:UpdateGameRaidInformation()
    local lootmethod, _, masterlooterRaidID = UTILS.GetLootMethod()
    LOG:Info("Loot method: %s (id: %s)", lootmethod, masterlooterRaidID)
    self.RaidAssistants = {}
    self.RaidMembers = {}
    self.IsMasterLootSystem = false
    self.IsGroupLootSystem = false
    if UTILS.IsLootMasterLootMethod() and masterlooterRaidID then
        local name = GetRaidRosterInfo(masterlooterRaidID)
        if name then
            name = UTILS.Disambiguate(name)
            self.IsMasterLootSystem = true
            self.MasterLooter = name
            self.RaidAssistants[name] = true -- we add it in case ML is not an assistant
            LOG:Info("Master Looter: %s", name)
        end
    elseif UTILS.IsGroupLootMethod() then
        self.IsGroupLootSystem = true
    end

    for i=1,MAX_RAID_MEMBERS do
        local name, rank = GroupMemberInfo(i)
        if name then
            name = UTILS.Disambiguate(name)
            self.RaidMembers[name] = true
            if rank >= 1 then
                self.RaidAssistants[name] = true
            end
            if rank == 2 then
                self.RaidLeader = name
                LOG:Debug("Raid Leader: %s", self.RaidLeader)
            end
        end
    end
end

function RaidManager:UpdateRaiderList()
    LOG:Trace("RaidManager:UpdateRaiderList()")
    local raid = self:GetRaid()
    if not raid then
        LOG:Debug("Not in raid")
        return
    end
    -- Dont execute this more often than every 1s
    -- if GetServerTime() - self.lastRosterUpdateTime < 1 then return end
    -- self.lastRosterUpdateTime = GetServerTime()

    local current, joiners, leavers = {}, {}, {}
    -- Detect leavers; build current set
    for i=1,MAX_RAID_MEMBERS do
        local name = GroupMemberInfo(i)
        if name then
            name = UTILS.Disambiguate(name)
            current[name] = true
            local profile = CLM.MODULES.ProfileManager:GetProfileByName(name)
            if profile then
                if not raid:IsPlayerInRaid(profile:GUID()) then
                    tinsert(leavers,  profile)
                end
            end
        end
    end

    -- Detect joiners
    for _,profile in ipairs(raid:Profiles()) do
        if not current[profile:Name()] then
            tinsert(joiners, profile)
        end
    end

    LOG:Debug("RaidManager:UpdateRaiderList(): +%d -%d", #joiners, #leavers)
    if (#joiners > 0) or (#leavers > 0) then
        CLM.MODULES.LedgerManager:Submit(CLM.MODELS.LEDGER.RAID.Update:new(raid:UID(), joiners, leavers), true) -- force update
    end
end

---@param name string?
---@return boolean
function RaidManager:IsRaidOwner(name)
    LOG:Trace("RaidManager:IsRaidOwner()")
    name = name or UTILS.whoami()
    local isOwner
    if IsPlayerInPvP() then
        LOG:Debug("Player in PvP")
        return false
    end
    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER, name) then
        isOwner = false
        LOG:Debug("Not Assistant")
    else
        if self.IsMasterLootSystem then
            isOwner = (self.MasterLooter == name)
            LOG:Debug("ML system %s/%s", self.MasterLooter, name)
        else
            isOwner = (self.RaidLeader == name)
            LOG:Debug("Not ML system %s/%s", self.RaidLeader, name)
        end
    end
    if not isOwner then
        LOG:Debug("%s is not raid owner.", name)
    end
    return isOwner
end

---@return boolean
function RaidManager:IsGroupLoot()
    return self.IsGroupLootSystem
end


---@param name string?
---@return boolean
function RaidManager:IsMasterLooter(name)
    return self.IsMasterLootSystem and (self.MasterLooter == (name or UTILS.whoami())) or false
end

--[[
    An auctioneer is an officer who is raid leader or assistant (S9), or (2026-10-18, raid
    feedback) the officer collecting the loot with "Need on everything" on, so the loot can go to
    an officer who isn't an assistant. Other players can't see that setting, so they accept
    auction messages from any officer in their raid group; the officer rank is still checked on
    receive.
]]--
---@param name string?
---@return boolean
function RaidManager:IsAllowedToAuction(name)
    LOG:Trace("RaidManager:IsAllowedToAuction()")
    name = name or UTILS.whoami()

    if not CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER, name) then
        LOG:Debug("Not an officer")
        return false
    end

    local allow = self.RaidAssistants[name]
    if not allow then
        if name == UTILS.whoami() then
            allow = CLM.GlobalConfigs:GetNeedOnEverything() and GroupIsInRaid()
        else
            allow = self.RaidMembers[name]
        end
    end
    allow = allow and true or false
    if not allow then
        LOG:Debug("%s is not allowed to auction.", name)
    end
    return allow
end

---@return Raid?
function RaidManager:GetRaid()
    return self.cache.profileRaidInfo[whoamiGUID]
end

function RaidManager:WipeAll()
    self.cache = {
        current = {
            raid = nil,
            isRaidManager = false,
            raidManager = "",
        },
        raids = {},
        profileRaidInfo = {},
    }
end

CONSTANTS.RAID_STATUS =
{
    CREATED = 0,
    IN_PROGRESS = 1,
    FINISHED = 2,
    STALE = 3
}

CONSTANTS.RAID_STATUS_GUI = {
    [CONSTANTS.RAID_STATUS.CREATED]     = CLM.L["Created"],
    [CONSTANTS.RAID_STATUS.IN_PROGRESS] = CLM.L["In Progress"],
    [CONSTANTS.RAID_STATUS.FINISHED]    = CLM.L["Finished"],
    [CONSTANTS.RAID_STATUS.STALE]       = CLM.L["Stale"]
}

CONSTANTS.RAID_STATUS_ACTIVE = UTILS.Set({ 0, 1 })

CONSTANTS.RAID_STATUSES = UTILS.Set({ 0, 1, 2, 3 })

CLM.MODULES.RaidManager = RaidManager
