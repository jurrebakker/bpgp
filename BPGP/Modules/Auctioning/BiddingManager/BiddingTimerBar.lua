-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
-- local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI

--[[
    Auction timer bar (optional, off by default: R9).
    Item icon + name, a countdown that turns red for the last 5 seconds and shows "+5s" when
    anti-snipe extends the auction. Click it to toggle the bidding window; drag it to move it.
    Our own code on Modules/UI: replaces LibCandyBar (its licence is "All Rights Reserved").

    BiddingTimerBar:New(item, auction, options) / :Test(options)
    options: anchor = { point, _, relativePoint, x, y } (saved position), width, height, callback
]]--

local DEFAULT_WIDTH = 270
local DEFAULT_HEIGHT = 24
local WARNING_SECONDS = 5
local EXTENDED_SHOWN = 2 -- seconds the "+Ns" note stays

---@class BiddingTimerBar
---@field frame table
---@field bar table
---@field duration number
---@field endTime number
---@field extendedUntil number?
---@field extendedBy number?
---@field callback function
local BiddingTimerBar = {}
BiddingTimerBar.__index = BiddingTimerBar

local function UpdateBar(self)
    local now = GetTime()
    local left = math.max(0, self.endTime - now)
    local fraction = self.duration > 0 and math.min(1, left / self.duration) or 0
    local text = string.format("%ds", math.ceil(left))
    if self.extendedUntil and now < self.extendedUntil then
        text = string.format("+%ds  ", self.extendedBy) .. text
    end
    self.bar:SetValue(fraction)
    self.time:SetText(text)
    local color = left <= WARNING_SECONDS and UI.COLOR.BAD or UI.COLOR.GOLD
    self.bar:SetStatusBarColor(color:GetRGB())
    if left <= 0 then self:Stop() end
end

local function Create(self, item, auction, options)
    local width = tonumber(options.width) or DEFAULT_WIDTH
    local height = tonumber(options.height) or DEFAULT_HEIGHT

    local frame = CreateFrame("Button", nil, UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    if options.anchor and options.anchor[3] then
        frame:SetPoint(options.anchor[3], UIParent, options.anchor[3], options.anchor[4], options.anchor[5])
    else
        frame:SetPoint("CENTER", 0, 185)
    end
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:SetScript("OnClick", function() self.callback() end)
    if CLM.GlobalConfigs and CLM.GlobalConfigs.GetUIScale then frame:SetScale(CLM.GlobalConfigs:GetUIScale()) end

    self.icon = frame:CreateTexture(nil, "ARTWORK")
    self.icon:SetPoint("TOPLEFT")
    self.icon:SetPoint("BOTTOMLEFT")
    self.icon:SetWidth(height)
    self.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    self.bar = UI.CreateProgressBar(frame, width - height, height)
    self.bar:ClearAllPoints()
    self.bar:SetPoint("TOPLEFT", self.icon, "TOPRIGHT")
    self.bar:SetPoint("BOTTOMRIGHT")
    self.label = UI.CreateLabel(self.bar, "", "GameFontHighlightSmall")
    self.label:SetPoint("LEFT", 6, 0)
    self.label:SetWordWrap(false)
    self.time = UI.CreateLabel(self.bar, "", "GameFontHighlightSmall")
    self.time:SetPoint("RIGHT", -6, 0)
    self.time:SetJustifyH("RIGHT")
    self.label:SetPoint("RIGHT", self.time, "LEFT", -6, 0)
    self.bar.Text:Hide() -- label and time replace the bar's centred text

    self.frame = frame
    self.callback = type(options.callback) == "function" and options.callback or function() end
    self.duration = math.max(1, (auction:GetEndTime() or GetServerTime()) - GetServerTime())
    self.endTime = GetTime() + self.duration
    self:UpdateInfo(item)

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        UpdateBar(self)
    end)
    UpdateBar(self)
    frame:Show()
end

---@param item table
---@param auction table
---@param options table
---@return BiddingTimerBar
function BiddingTimerBar:New(item, auction, options)
    local o = setmetatable({}, self)
    Create(o, item, auction, options)
    return o
end

-- A bar with a fake item and 5 minutes on the clock, to position it (/bpgp testbar)
---@param options table
---@return BiddingTimerBar
function BiddingTimerBar:Test(options)
    local item = {
        GetItemLink = function() return "|cffa335ee|Hitem:19019::::::::80:::::::::|h[Thunderfury]|h|r" end,
        GetNote = function() return CLM.L["drag to move"] end
    }
    local auction = {
        GetEndTime = function() return GetServerTime() + 300 end,
    }
    options.callback = function() CLM.LOG:Message(CLM.L["Timer bar: drag it where you want it, then /bpgp testbar again to save."]) end
    return BiddingTimerBar:New(item, auction, options)
end

function BiddingTimerBar:GetPoint()
    return self.frame:GetPoint()
end

---@param item table?
function BiddingTimerBar:UpdateInfo(item)
    if not item or not self.frame then return end
    local link = item:GetItemLink() or ""
    local note = item:GetNote() or ""
    self.label:SetText(note ~= "" and (link .. " (" .. note .. ")") or link)
    local _, _, _, _, icon = UTILS.GetItemInfoInstant(link)
    self.icon:SetTexture(icon or 134400)
end

-- Anti-snipe: the auction got `time` seconds longer
---@param time number
function BiddingTimerBar:UpdateTime(time)
    time = tonumber(time) or 0
    if not self.frame or time <= 0 then return end
    self.endTime = self.endTime + time
    self.duration = math.max(self.duration, self.endTime - GetTime())
    self.extendedBy = time
    self.extendedUntil = GetTime() + EXTENDED_SHOWN
end

---@param width number
function BiddingTimerBar:SetWidth(width)
    if self.frame then self.frame:SetWidth(tonumber(width) or DEFAULT_WIDTH) end
end

---@param height number
function BiddingTimerBar:SetHeight(height)
    if not self.frame then return end
    height = tonumber(height) or DEFAULT_HEIGHT
    self.frame:SetHeight(height)
    self.icon:SetWidth(height)
end

function BiddingTimerBar:Stop()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
end

CLM.MODELS.BiddingTimerBar = BiddingTimerBar
