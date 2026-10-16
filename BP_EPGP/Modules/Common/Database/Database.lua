-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local DeepCopy = UTILS.DeepCopy
local assertType = UTILS.assertType

---@class DB
---@field testMode boolean?
local DB = {}

-- You really do not want to modify this
-- vvvvv
local DB_NAME_PERSONAL = 'personal'
local DB_NAME_GUI = 'gui'
local DB_NAME_RAID = 'raid'
local DB_NAME_GUILD = 'guild'
local DB_NAME_LEDGER = 'ledger'
local DB_NAME_LEDGER_TEST = 'ledger_test'
local DB_TEST_MODE = 'testMode'
local DB_NAME_LOGGER = 'logger'
local DB_NAME_GLOBAL = 'global'
-- ^^^^^

local DATABASE_FALLBACK = "unguilded"

local retry_count = 5
local function UpdateSchema(table, schema)
    if type(schema) == "table" then
        for key, value in pairs(schema) do
            if table[key] == nil then
                table[key] = DeepCopy(value)
            end
        end
    elseif type(schema) == "function" then
        schema(table)
    end
end

local function _initialize()
    LOG:Debug("Using database: %s", DB.database_name)

    if type(BPEPGP_DB[DB.database_name]) ~= "table" then
        BPEPGP_DB[DB.database_name] = {}
    end
    if type(BPEPGP_DB[DB.database_name][DB_NAME_PERSONAL]) ~= "table" then
        BPEPGP_DB[DB.database_name][DB_NAME_PERSONAL] = {}
    end
    if type(BPEPGP_DB[DB.database_name][DB_NAME_PERSONAL][DB_NAME_GUI]) ~= "table" then
        BPEPGP_DB[DB.database_name][DB_NAME_PERSONAL][DB_NAME_GUI] = {}
    end
    if type(BPEPGP_DB[DB.database_name][DB_NAME_GUILD]) ~= "table" then
        BPEPGP_DB[DB.database_name][DB_NAME_GUILD] = {}
    end
    if type(BPEPGP_DB[DB.database_name][DB_NAME_RAID]) ~= "table" then
        BPEPGP_DB[DB.database_name][DB_NAME_RAID] = {}
    end
    if type(BPEPGP_DB[DB.database_name][DB_NAME_LEDGER]) ~= "table" then
        BPEPGP_DB[DB.database_name][DB_NAME_LEDGER] = {}
    end
    if type(BPEPGP_DB[DB.database_name][DB_NAME_LEDGER_TEST]) ~= "table" then
        BPEPGP_DB[DB.database_name][DB_NAME_LEDGER_TEST] = {}
    end
    -- Test mode is fixed for the session (also across ForceFallback); switching it reloads the UI (see TestMode)
    if DB.testMode == nil then
        DB.testMode = BPEPGP_DB[DB.database_name][DB_NAME_PERSONAL][DB_TEST_MODE] and true or false
    end
end

-- Retail only: a fixed prefix, so data survives expansion changes
local function _get_prefix()
    return "retail "
end

local function _get_database_name(guildName)
    return string.lower(_get_prefix() .. UnitFactionGroup("player") .. " " .. GetNormalizedRealmName() .. " " .. guildName)
end

function DB:ForceFallback()
    LOG:Debug("Forcing Database into fallback mode")
    DB.database_name = _get_database_name(DATABASE_FALLBACK)
    _initialize()
end

---@return boolean
function DB:Initialize()
    LOG:Trace("DB:Initialize()")
    -- Below API requires delay after loading to work after variables loaded event
    local guildName = GetGuildInfo("player")
    if guildName == nil or guildName == "" then
        if retry_count <= 0 then
            guildName = DATABASE_FALLBACK
        else
            retry_count = retry_count - 1
            LOG:Debug("DB do retry: %d", 5 - retry_count)
            return false
        end
    end

    DB.database_name = _get_database_name(guildName)

    _initialize()

    return true
end

---@return table
function DB:Global()
    return BPEPGP_DB[DB_NAME_GLOBAL]
end

---@return table
function DB:Logger()
    return BPEPGP_DB[DB_NAME_GLOBAL][DB_NAME_LOGGER]
end

---@return table
function DB:Server()
    return BPEPGP_DB[self.database_name]
end

---@param table string
---@param schema table|function|nil
---@return table
function DB:Personal(table, schema)
    assertType(table, 'string')

    if not BPEPGP_DB[self.database_name][DB_NAME_PERSONAL][table] then
        BPEPGP_DB[self.database_name][DB_NAME_PERSONAL][table] = {}
    end

    UpdateSchema(BPEPGP_DB[self.database_name][DB_NAME_PERSONAL][table], schema)

    return BPEPGP_DB[self.database_name][DB_NAME_PERSONAL][table]
end

---@param table string
---@param schema table|function|nil
---@return table
function DB:GUI(table, schema)
    assertType(table, 'string')

    if not BPEPGP_DB[self.database_name][DB_NAME_PERSONAL][DB_NAME_GUI][table] then
        BPEPGP_DB[self.database_name][DB_NAME_PERSONAL][DB_NAME_GUI][table] = {}
    end

    UpdateSchema(BPEPGP_DB[self.database_name][DB_NAME_PERSONAL][DB_NAME_GUI][table], schema)

    return BPEPGP_DB[self.database_name][DB_NAME_PERSONAL][DB_NAME_GUI][table]
end

-- Test mode reads and writes only the test ledger; the live ledger is never touched.
---@return table
function DB:Ledger()
    return BPEPGP_DB[self.database_name][self.testMode and DB_NAME_LEDGER_TEST or DB_NAME_LEDGER]
end

---@param ledger table
function DB:UpdateLedger(ledger)
    BPEPGP_DB[self.database_name][self.testMode and DB_NAME_LEDGER_TEST or DB_NAME_LEDGER] = ledger
end

---@return boolean
function DB:IsTestMode()
    return self.testMode and true or false
end

-- Stored now, used after the next reload
---@param enabled boolean
function DB:SetTestModeOnReload(enabled)
    BPEPGP_DB[self.database_name][DB_NAME_PERSONAL][DB_TEST_MODE] = enabled and true or false
end

-- Replaces the test ledger with an empty one or a copy of the live ledger
---@param copyLive boolean
function DB:ResetTestLedger(copyLive)
    BPEPGP_DB[self.database_name][DB_NAME_LEDGER_TEST] = copyLive and DeepCopy(BPEPGP_DB[self.database_name][DB_NAME_LEDGER]) or {}
end

CLM.MODULES.Database = DB