-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

local AceConfig = LibStub("AceConfig-3.0")

--[[
    Slash commands (/bpgp ...). Settings live in the main window's Settings tab;
    there are no Options -> AddOns pages any more (D2).
]]--

---@class ConfigManager
---@field enabled boolean
---@field slash_options table
local ConfigManager = { enabled = false }

function ConfigManager:Initialize()
    LOG:Trace("ConfigManager:Initialize()")
    self.slash_options = { type = "group", args = {}}
end

function ConfigManager:Enable()
    LOG:Trace("ConfigManager:Enable()")
    self.enabled = true
end

---@param options table
---@return boolean
function ConfigManager:RegisterSlash(options)
    LOG:Trace("ConfigManager:RegisterSlash()")

    if type(options) ~= "table" then
        LOG:Error("ConfigManager:RegisterSlash(): Object is not a table")
        return false
    end

    for option, definition in pairs(options) do
        if self.slash_options.args[option] == nil then
            self.slash_options.args[option] = definition
        else
            LOG:Warning("Option %s already set. Ignoring.", option)
        end
    end

    AceConfig:RegisterOptionsTable("BPGP", self.slash_options, {"bpgp"})
    return true
end

-- Publish API
CLM.MODULES.ConfigManager = ConfigManager
