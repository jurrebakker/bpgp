-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI
local S = UI.SPACE

--[[
    The main window (Phase 9b, docs/features/ui-redesign.md): one portrait frame with bottom tabs.
    Officers get Standings, History, Raids, Roster and Audit; raiders get Standings, History and Raids (R11).

    Pages register themselves with MainWindow:RegisterPage(page). A page is a table with:
      key, order, title, officerOnly
      Build(page, content, header)   once, the first time the page is shown
      Refresh(page)                  whenever data changed and the page is visible
      OnShow(page)                   optional, when the page becomes visible
    The window gives each page `page.window` (this module), `page.isOfficer`, a content frame and a
    header frame (the space right of the page title, for search boxes and dropdowns).
]]--

local OFFICER_SIZE = { width = 720, height = 480 }
local RAIDER_SIZE  = { width = 520, height = 440 }
local FOOTER_HEIGHT = 18
local HEADING_LEFT = 60 -- clears the portrait

local SYNC_STATE = {
    INCOHERENT = { text = "Incoherent state",   color = UI.COLOR.BAD },
    IN_SYNC    = { text = "In-Sync",            color = UI.COLOR.EP },
    ONGOING    = { text = "Sync ongoing",       color = UI.COLOR.GOLD },
    DISABLED   = { text = "Disabled",           color = UI.COLOR.BAD },
    UNKNOWN    = { text = "Unknown sync state", color = UI.COLOR.GREY },
}

---@class MainWindow
---@field pages table
---@field shownPages table
---@field window table?
---@field isOfficer boolean
---@field currentPage table?
---@field syncing boolean
---@field syncProgress table?
---@field refreshPending boolean
---@field _initialized boolean
local MainWindow = { pages = {} }

---@param page table
function MainWindow:RegisterPage(page)
    self.pages[#self.pages + 1] = page
    table.sort(self.pages, function(a, b) return a.order < b.order end)
end

---@return string text, table color ColorMixin
function MainWindow:GetSyncState()
    local ledger = CLM.MODULES.LedgerManager
    local state = SYNC_STATE.UNKNOWN
    if ledger:IsInIncoherentState() then
        state = SYNC_STATE.INCOHERENT
    elseif ledger:IsInSync() then
        state = SYNC_STATE.IN_SYNC
    elseif ledger:IsSyncOngoing() then
        state = SYNC_STATE.ONGOING
    elseif ledger:IsDisabled() then
        state = SYNC_STATE.DISABLED
    end
    return CLM.L[state.text], state.color
end

local function UpdateFooter(self)
    local window = self.window
    local text, color = self:GetSyncState()
    local events = ""
    if CLM.MODULES.LedgerManager:IsInitialized() then
        events = string.format(CLM.L["%s events"], CLM.MODULES.LedgerManager:Length())
    end
    window.SyncText:SetText(color:WrapTextInColorCode(text) .. "  " .. events)
end

--[[
 * Syncing overlay: replaces the old "BP EPGP is processing" banner *
]]--

local function CreateSyncOverlay(self, area)
    local overlay = CreateFrame("Frame", nil, area)
    overlay:SetAllPoints(area)
    overlay:SetFrameLevel(area:GetFrameLevel() + 20)
    overlay:EnableMouse(true) -- the data underneath is incomplete; don't act on it
    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.82)
    local spinner = UI.CreateSpinner(overlay)
    spinner:SetPoint("CENTER", 0, 36)
    local text = UI.CreateLabel(overlay, CLM.L["BP EPGP is processing..."], "GameFontNormalLarge")
    text:SetPoint("TOP", spinner, "BOTTOM", 0, -S.S)
    text:SetJustifyH("CENTER")
    local bar = UI.CreateProgressBar(overlay, 240, 18)
    bar:SetPoint("TOP", text, "BOTTOM", 0, -S.M)
    local hint = UI.CreateLabel(overlay, CLM.L["Windows will refresh automatically."], "GameFontDisableSmall")
    hint:SetPoint("TOP", bar, "BOTTOM", 0, -S.S)
    hint:SetJustifyH("CENTER")
    overlay.Bar = bar
    overlay:Hide()
    self.window.SyncOverlay = overlay
end

---@param done number
---@param total number
local function ShowSyncing(self, done, total)
    self.syncing = true
    self.syncProgress = { done, total }
    if not self.window then return end
    local overlay = self.window.SyncOverlay
    if total > 0 then
        overlay.Bar:SetProgress(done / total, string.format(CLM.L["%s / %s events"], done, total))
    else
        overlay.Bar:SetProgress(0, "")
    end
    overlay:Show()
    UpdateFooter(self)
end

local function HideSyncing(self)
    self.syncing = false
    if self.window then self.window.SyncOverlay:Hide() end
end

--[[
 * Pages *
]]--

local function ShowPage(self, page)
    for _, other in ipairs(self.shownPages) do
        local shown = other == page
        if other.content then
            other.content:SetShown(shown)
            other.header:SetShown(shown)
        end
    end
    self.currentPage = page
    if not page.content then
        page.content = CreateFrame("Frame", nil, self.window.PageArea)
        page.content:SetAllPoints(self.window.PageArea)
        page.header = CreateFrame("Frame", nil, self.window)
        page.header:SetPoint("TOPLEFT", self.window.Subtitle, "TOPRIGHT", S.M, 6)
        page.header:SetPoint("TOPRIGHT", self.window, "TOPRIGHT", -S.S, -26)
        page.header:SetHeight(S.BUTTON + 4)
        page.window = self
        page.isOfficer = self.isOfficer
        page:Build(page.content, page.header)
    end
    page.content:Show()
    page.header:Show()
    self.window.Heading:SetText(page.title)
    self:SetSubtitle("")
    self:SetPageFooter("")
    CLM.MODULES.Database:GUI("mainwindow").page = page.key
    if page.OnShow then page:OnShow() end
    self:RefreshNow()
end

---@param text string
function MainWindow:SetSubtitle(text)
    if self.window then self.window.Subtitle:SetText(text or "") end
end

---@param text string
function MainWindow:SetPageFooter(text)
    if self.window then self.window.PageFooter:SetText(text or "") end
end

---@param key string
---@return table? page
function MainWindow:GetPage(key)
    for _, page in ipairs(self.shownPages or {}) do
        if page.key == key then return page end
    end
end

---@param key string
function MainWindow:SelectPage(key)
    for index, page in ipairs(self.shownPages) do
        if page.key == key then
            UI.SelectTab(self.window, index)
            return
        end
    end
end

local function Build(self)
    LOG:Trace("MainWindow:Build()")
    self.isOfficer = CLM.MODULES.ACL:CheckLevel(CONSTANTS.ACL.LEVEL.OFFICER)
    local size = self.isOfficer and OFFICER_SIZE or RAIDER_SIZE
    local window = UI.CreateWindow({
        name = "BPEPGP_MainWindow",
        title = CLM.L["BP EPGP"],
        width = size.width, height = size.height,
        portrait = true,
        resizable = true,
        dbKey = "mainwindow",
    })
    -- A saved size from the other view (raider -> officer) may be below the minimum
    window:SetSize(math.max(window:GetWidth(), size.width), math.max(window:GetHeight(), size.height))
    self.window = window

    window.Heading = UI.CreateLabel(window, "", "GameFontNormalLarge")
    window.Heading:SetPoint("TOPLEFT", HEADING_LEFT, -34)
    window.Subtitle = UI.CreateLabel(window, "", "GameFontDisableSmall")
    window.Subtitle:SetPoint("BOTTOMLEFT", window.Heading, "BOTTOMRIGHT", S.S, 1)

    local top = S.TOP_BAND
    local banner = UI.CreateTestModeBanner(window)
    if banner then
        banner:SetPoint("TOPLEFT", S.S, -top)
        banner:SetPoint("TOPRIGHT", -S.S, -top)
        top = top + 24 + S.XS
    end

    local area = CreateFrame("Frame", nil, window)
    area:SetPoint("TOPLEFT", S.S, -top)
    area:SetPoint("BOTTOMRIGHT", -S.S, S.S + FOOTER_HEIGHT)
    window.PageArea = area

    window.PageFooter = UI.CreateLabel(window, "", "GameFontDisableSmall")
    window.PageFooter:SetPoint("BOTTOMLEFT", S.M, S.S)
    window.SyncText = UI.CreateLabel(window, "", "GameFontDisableSmall")
    window.SyncText:SetPoint("BOTTOMRIGHT", -24, S.S) -- clear of the resize grip
    window.SyncText:SetJustifyH("RIGHT")
    window.PageFooter:SetPoint("RIGHT", window.SyncText, "LEFT", -S.M, 0)

    CreateSyncOverlay(self, area)

    self.shownPages = {}
    local names = {}
    for _, page in ipairs(self.pages) do
        if self.isOfficer or not page.officerOnly then
            self.shownPages[#self.shownPages + 1] = page
            names[#names + 1] = page.title
        end
    end
    UI.CreateTabs(window, names, function(id) ShowPage(self, self.shownPages[id]) end)

    window:HookScript("OnShow", function()
        if self.currentPage and self.currentPage.OnShow then self.currentPage:OnShow() end
        self:RefreshNow()
    end)
end

--[[
 * Refreshing *
    Data changes arrive in bursts (a sync applies many entries), so refreshes are coalesced to
    one per frame and only run while the window is visible. Showing the window refreshes it.
]]--

function MainWindow:RefreshNow()
    self.refreshPending = false
    if not (self.window and self.window:IsShown()) then return end
    UpdateFooter(self)
    if self.syncing then return end
    local page = self.currentPage
    if page and page.Refresh then
        local ok, err = pcall(page.Refresh, page)
        if not ok then LOG:Error("MainWindow: refreshing %s failed: %s", tostring(page.key), tostring(err)) end
    end
end

function MainWindow:Refresh()
    if not (self.window and self.window:IsShown()) then return end
    if self.refreshPending then return end
    self.refreshPending = true
    C_Timer.After(0, function() self:RefreshNow() end)
end

local function RegisterSlash(self)
    CLM.MODULES.ConfigManager:RegisterSlash({
        gui = {
            type = "execute",
            name = "Standings",
            desc = CLM.L["Toggle standings window display"],
            handler = self,
            func = "Toggle",
        }
    })
end

function MainWindow:Initialize()
    LOG:Trace("MainWindow:Initialize()")
    self.syncing = false
    RegisterSlash(self)

    CLM.MODULES.LedgerManager:RegisterOnUpdate(function(lag, uncommitted)
        if lag ~= 0 or uncommitted ~= 0 then
            local total = CLM.MODULES.LedgerManager:Length() + uncommitted
            ShowSyncing(self, math.max(total - lag, 0), total)
            return
        end
        HideSyncing(self)
        self:Refresh()
    end)
    CLM.MODULES.LedgerManager:RegisterOnRestart(function()
        if CLM.MODULES.LedgerManager:Length() > 0 then
            ShowSyncing(self, 0, CLM.MODULES.LedgerManager:Length())
        end
    end)
    -- Raid group and guild roster changes (Roster tab, raid counts)
    CLM.MODULES.EventManager:RegisterWoWBucketEvent({"GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE"}, 1, function()
        self:Refresh()
    end)
    CLM.MODULES.EventManager:RegisterEvent("CLM_UI_RESIZE", function(_, data)
        if self.window then self.window:SetScale(data.scale) end
    end)

    self._initialized = true
end

function MainWindow:Toggle()
    LOG:Trace("MainWindow:Toggle()")
    if not self._initialized then return end
    if not self.window then
        Build(self)
        local last = CLM.MODULES.Database:GUI("mainwindow").page
        local index = 1
        for i, page in ipairs(self.shownPages) do
            if page.key == last then index = i end
        end
        self.window:Show()
        UI.SelectTab(self.window, index)
        if self.syncing then ShowSyncing(self, self.syncProgress[1], self.syncProgress[2]) end
        return
    end
    self.window:SetShown(not self.window:IsShown())
end

function MainWindow:Reset()
    LOG:Trace("MainWindow:Reset()")
    if not self.window then return end
    self.window:ClearAllPoints()
    self.window:SetPoint("CENTER", 0, 0)
end

CLM.GUI.MainWindow = MainWindow

-- Addon compartment (BP_EPGP.toc AddonCompartmentFunc)
function BPEPGP_ToggleMainWindow()
    CLM.GUI.MainWindow:Toggle()
end
