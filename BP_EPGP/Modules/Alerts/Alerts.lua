local _, CLM = ...

local eventDispatcher = LibStub("BPEPGP-EventDispatcher")
if not eventDispatcher then return end

---@class CLMAlertFrameTemplate: Frame
---@field Amount FontString
---@field Icon Texture

-- Toasts use Blizzard's loot toast art with our logo; text colours follow the UI roles (ui-redesign.md)
local LOGO = CLM.MEDIA_PATH .. "Icons\\bp-epgp-32.png"
local GREEN, GOLD, GREY, RED = {0.12, 1, 0}, {1, 0.82, 0}, {0.62, 0.62, 0.62}, {1, 0.13, 0.13}

local function Style(self, color)
    if self.Icon then self.Icon:SetTexture(LOGO) end
    self.Amount:SetTextColor(unpack(color))
end

---@param self CLMAlertFrameTemplate
---@param data table
local function PointReceivedAlertFrame_SetUp(self, data)
    local value = tonumber(data.value) or 0
    local valueText = (value ~= nil) and tostring(value) or tostring(data.value)
    local suffix = CLM.UTILS.DecodePointTypeChangeName(data.changeType)
    if data.reason ~= CLM.CONSTANTS.POINT_CHANGE_REASON.DECAY then
        self.Amount:SetText(string.format(CLM.L["%s %s"], valueText, suffix))
        Style(self, data.changeType == CLM.CONSTANTS.POINT_CHANGE_TYPE.SPENT and GOLD or GREEN)
    else
        self.Amount:SetText(string.format(CLM.L["%s %% %s decay"], valueText, suffix))
        Style(self, GREY)
    end
    PlaySound(SOUNDKIT.UI_EPICLOOT_TOAST)
end

local PointReceivedAlertSystem = AlertFrame:AddQueuedAlertFrameSubSystem("BPEPGP_PointReceivedAlertFrameTemplate", PointReceivedAlertFrame_SetUp, 6, math.huge)

---@param self CLMAlertFrameTemplate
---@param data table
local function BidAcceptedAlertFrame_SetUp(self, data)
    local value = tonumber(data.value)
    local valueText = (value ~= nil) and tostring(value) or tostring(data.value)
    self.Amount:SetText(string.format(CLM.L["Bid %s accepted!"], valueText))
    Style(self, GREEN)
end

local BidAcceptedAlertSystem = AlertFrame:AddQueuedAlertFrameSubSystem("BPEPGP_BidAcceptedAlertFrameTemplate", BidAcceptedAlertFrame_SetUp, 6, math.huge)

---@param self CLMAlertFrameTemplate
---@param data table
local function BidDeniedAlertFrame_SetUp(self, data)
    local value = tonumber(data.value)
    local valueText = (value ~= nil) and tostring(value) or tostring(data.value)
    self.Amount:SetText(string.format(CLM.L["Bid %s denied!"], valueText))
    Style(self, RED)
end

local BidDeniedAlertSystem = AlertFrame:AddQueuedAlertFrameSubSystem("BPEPGP_BidDeniedAlertFrameTemplate", BidDeniedAlertFrame_SetUp, 6, math.huge)

eventDispatcher.addEventListener(CLM.CONSTANTS.EVENTS.USER_RECEIVED_POINTS, function(event, data)
    PointReceivedAlertSystem:AddAlert(data)
end)

eventDispatcher.addEventListener(CLM.CONSTANTS.EVENTS.USER_RECEIVED_ITEM, function(event, data)
    LootAlertSystem:AddAlert(data.link or "item:0", 1)
end)

eventDispatcher.addEventListener(CLM.CONSTANTS.EVENTS.USER_BID_ACCEPTED, function(event, data)
    BidAcceptedAlertSystem:AddAlert(data)
end)

eventDispatcher.addEventListener(CLM.CONSTANTS.EVENTS.USER_BID_DENIED, function(event, data)
    BidDeniedAlertSystem:AddAlert(data)
end)
