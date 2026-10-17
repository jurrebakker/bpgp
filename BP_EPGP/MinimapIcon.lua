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
    if CLM.MODULES.TestMode:IsOn() then
        CLM.MinimapDBI.iconR, CLM.MinimapDBI.iconG, CLM.MinimapDBI.iconB = 1, 0.5, 0
    end

    CLM.MinimapDBI.OnClick = function()
        CLM.GUI.MainWindow:Toggle()
    end

    CLM.MinimapDBI.OnTooltipShow = function(tooltip)
        local info
        tooltip:AddLine(addonName .. " " .. CLM.MODULES.Version:GetString())
        if CLM.MODULES.TestMode:IsOn() then
            tooltip:AddLine(CLM.L["TEST MODE"], 1, 0.5, 0)
        end

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

        -- Same wording and colours as the main window footer
        local state, color = CLM.GUI.MainWindow:GetSyncState()
        tooltip:AddLine(state, color:GetRGB())
        tooltip:AddLine(info, 1, 1, 1)
        tooltip:AddLine(" ")
        tooltip:AddLine(CLM.L["Left-click: open BP EPGP"], 0.62, 0.62, 0.62)
    end

    icon:Register(addonName, CLM.MinimapDBI, BPEPGP_Minimap)
end

---@class Minimap
---@field _initialized boolean
local Minimap = {}

local function RegisterSlash(self)
    CLM.MODULES.ConfigManager:RegisterSlash({
        minimap = {
            type = "execute",
            name = CLM.L["Minimap icon"],
            desc = CLM.L["Show or hide the minimap icon"],
            func = function()
                if self:IsEnabled() then self:Disable() else self:Enable() end
            end,
        }
    })
end

function Minimap:Initialize()
    RegisterSlash(self)
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