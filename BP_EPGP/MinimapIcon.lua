local _, CLM = ...
---@cast CLM CLMNamespace

local addonName = "BP EPGP" -- same as the UI name for config

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
if not ldb then return end

local icon = LibStub("LibDBIcon-1.0", true)
if not icon then return end

local function CreateMinimapDBI()
    CLM.MinimapDBI = ldb:NewDataObject(addonName, {
        type = "data source",
        text = "0",
        icon = CLM.MEDIA_PATH .. "Icons\\bp-epgp-32.png"
    })

    CLM.MinimapDBI.OnClick = function()
        CLM.GUI.Unified:Toggle()
    end

    CLM.MinimapDBI.OnTooltipShow = function(tooltip)
        local info
        tooltip:AddLine(addonName .. " " .. CLM.MODULES.Version:GetString())

        if CLM.MODULES.LedgerManager:IsInitialized() then
            local lag = CLM.MODULES.LedgerManager:Lag()
            local count = CLM.MODULES.LedgerManager:Length()
            local hash = CLM.MODULES.LedgerManager:Hash()
            if lag > 0 then
                info = string.format(CLM.L["%s events (%s pending)"], count, lag)
            else
                info = string.format(CLM.L["%s events (0x%x)"], count, hash)
            end
        else
            info = string.format(CLM.L["Loading..."])
        end

        if CLM.MODULES.LedgerManager:IsInIncoherentState() then
            tooltip:AddLine(CLM.L["Incoherent state"], 0.6, 0.0, 0.0) -- RED
        elseif CLM.MODULES.LedgerManager:IsInSync() then
            tooltip:AddLine(CLM.L["In-Sync"], 0.0, 0.8, 0.0) -- GREEN
        elseif CLM.MODULES.LedgerManager:IsSyncOngoing() then
            tooltip:AddLine(CLM.L["Sync ongoing"], 0.75, 0.75, 0.0) -- YELLOW
        elseif CLM.MODULES.LedgerManager:IsDisabled() then
            tooltip:AddLine(CLM.L["Disabled"], 0.6, 0.0, 0.0) -- RED
        else -- Unknown state
            tooltip:AddLine(CLM.L["Unknown sync state"], 0.4, 0.6, 1) -- BLUE
        end
        tooltip:AddLine(info)
    end

    icon:Register(addonName, CLM.MinimapDBI, BPEPGP_Minimap)
end

---@class Minimap
---@field _initialized boolean
local Minimap = {}

local function CreateConfig(self)
    local options = {
        minimap_toggle = {
            name = CLM.L["Toggle Minimap Icon"],
            desc = CLM.L["Enables / disables minimap Icon"],
            type = "toggle",
            set = function(i, v)
                if v then
                    self:Enable()
                else
                    self:Disable()
                end
            end,
            get = function(i) return self:IsEnabled() end,
            order = 2.5
          },
    }
    CLM.MODULES.ConfigManager:Register(CLM.CONSTANTS.CONFIGS.GROUP.GLOBAL, options)
end

function Minimap:Initialize()
    CreateConfig(self)
    if not BPEPGP_Minimap then BPEPGP_Minimap = {} end

    -- Create Minimap Icon
    CreateMinimapDBI()

    if BPEPGP_Minimap.disable then icon:Hide(addonName) end

    self._initialized = true
end

---@return boolean
function Minimap:IsInitialized()
    return self._initialized
end

function Minimap:Enable()
    BPEPGP_Minimap.disable = false
        icon:Show(addonName)
end

function Minimap:Disable()
    BPEPGP_Minimap.disable = true
    icon:Hide(addonName)
end

---@return boolean
function Minimap:IsEnabled()
    return not BPEPGP_Minimap.disable
end

CLM.MODULES.Minimap = Minimap