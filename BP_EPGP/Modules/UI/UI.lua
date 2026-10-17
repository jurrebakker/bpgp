-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
local UTILS     = CLM.UTILS
-- ------------------------------- --

--[[
    Shared UI pieces for the native-Blizzard redesign (docs/features/ui-redesign.md).
    Every window and control is built from Blizzard templates. Template names can change between
    patches, so each one is created with fallbacks: a missing template degrades the look, it never
    stops the addon from loading.
]]--

CLM.UI = CLM.UI or {}
local UI = CLM.UI

-- 4 px grid (design spec "Spacing grid")
UI.SPACE = {
    XS = 4,       -- icon to label, inset inner padding
    S = 8,        -- between controls, frame edge to inset
    M = 12,       -- between control groups, utility window padding
    ROW = 20,     -- list row
    BUTTON = 22,  -- button / dropdown height
    INPUT = 20,   -- input height
    TOP_BAND = 60 -- band under the title on portrait frames
}

UI.COLOR = {
    GOLD     = CreateColor(1, 0.82, 0),
    WHITE    = CreateColor(1, 1, 1),
    GREY     = CreateColor(0.62, 0.62, 0.62),
    EP       = CreateColor(0.12, 1, 0),
    GP       = CreateColor(1, 0.82, 0),
    BAD      = CreateColor(1, 0.13, 0.13),
    TEST     = CreateColor(1, 0.5, 0),
    SELECTED = CreateColor(1, 0.82, 0),
}

-- Bid tier colours follow item qualities (Max orange ... Base white)
UI.TIER_COLOR = {
    x = CreateColor(1, 0.5, 0),
    l = CreateColor(0.64, 0.21, 0.93),
    m = CreateColor(0, 0.44, 0.87),
    s = CreateColor(0.12, 1, 0),
    b = CreateColor(1, 1, 1),
}

local LOGO = CLM.MEDIA_PATH .. "Icons\\bp-epgp-32.png"
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

---@param frameType string
---@param name string?
---@param parent table?
---@param templates string[] tried in order
---@return table frame, string? template the template that worked
local function CreateWithTemplates(frameType, name, parent, templates)
    for _, template in ipairs(templates) do
        local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
        if ok and frame then
            return frame, template
        end
        LOG:Debug("UI: template %s not available", template)
    end
    return CreateFrame(frameType, name, parent), nil
end
UI.CreateWithTemplates = CreateWithTemplates

---@param atlas string
---@return boolean
function UI.HasAtlas(atlas)
    return (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)) ~= nil
end

---@return boolean
function UI.IsTestMode()
    return CLM.MODULES.TestMode and CLM.MODULES.TestMode:IsOn() or false
end

---@param fontString table
---@param color table? ColorMixin
local function SetTextColor(fontString, color)
    if color then fontString:SetTextColor(color:GetRGB()) end
end

---@param parent table
---@param text string?
---@param font string? font object name, default GameFontHighlight
---@param color table? ColorMixin
---@return table FontString
function UI.CreateLabel(parent, text, font, color)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetText(text or "")
    label:SetJustifyH("LEFT")
    SetTextColor(label, color)
    return label
end

--[[
 * Windows *
]]--

---@param frame table
---@param text string
function UI.SetTitle(frame, text)
    if UI.IsTestMode() then
        text = text .. " |cffff8000- " .. CLM.L["TEST MODE"] .. "|r"
    end
    if frame.SetTitle then
        frame:SetTitle(text)
    elseif frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(text)
    elseif frame.TitleText then
        frame.TitleText:SetText(text)
    end
end

---@param frame table
---@return table? texture
local function GetPortrait(frame)
    if frame.GetPortrait then return frame:GetPortrait() end
    if frame.PortraitContainer and frame.PortraitContainer.portrait then return frame.PortraitContainer.portrait end
    return frame.portrait
end

---@param frame table
local function ApplyTestModeLook(frame)
    if frame.NineSlice then
        for _, region in ipairs({ frame.NineSlice:GetRegions() }) do
            if region.SetVertexColor then region:SetVertexColor(UI.COLOR.TEST:GetRGB()) end
        end
    end
    local portrait = GetPortrait(frame)
    if portrait then portrait:SetVertexColor(1, 0.6, 0.3) end
end

---@param frame table
---@param dbKey string
local function SavePosition(frame, dbKey)
    local db = CLM.MODULES.Database:GUI(dbKey)
    local point, _, relativePoint, x, y = frame:GetPoint()
    db.position = { point, relativePoint, x, y }
    if frame.isResizable then
        db.size = { frame:GetWidth(), frame:GetHeight() }
    end
end

---@param frame table
---@param dbKey string
local function RestorePosition(frame, dbKey)
    local db = CLM.MODULES.Database:GUI(dbKey)
    if type(db.position) == "table" and db.position[1] then
        frame:ClearAllPoints()
        frame:SetPoint(db.position[1], UIParent, db.position[2], db.position[3], db.position[4])
    end
    if frame.isResizable and type(db.size) == "table" and db.size[1] then
        frame:SetSize(db.size[1], db.size[2])
    end
end

local function AddResizeGrip(frame, options)
    frame.isResizable = true
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(options.minWidth or options.width, options.minHeight or options.height)
    end
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if options.dbKey then SavePosition(frame, options.dbKey) end
    end)
    frame.ResizeGrip = grip
end

--[[
    Create a window.
    options:
      name       global frame name (BPEPGP_...), needed for Escape-to-close and tabs
      title      title text
      width, height
      portrait   true: PortraitFrameTemplate with the logo (main, auctioning, bidding)
                 false: DefaultPanelFlatTemplate (utility windows)
      dbKey      Database:GUI key to remember position (and size)
      resizable  true: resize grip; minWidth/minHeight (default width/height)
]]--
---@param options table
---@return table frame
function UI.CreateWindow(options)
    local templates = options.portrait
        and { "PortraitFrameTemplate", "ButtonFrameTemplate", "BasicFrameTemplateWithInset" }
        or { "DefaultPanelFlatTemplate", "BasicFrameTemplateWithInset" }
    local frame = CreateWithTemplates("Frame", options.name, UIParent, templates)
    frame:SetSize(options.width, options.height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if options.dbKey then SavePosition(self, options.dbKey) end
    end)

    UI.SetTitle(frame, options.title or "")
    if options.portrait then
        if frame.SetPortraitToAsset then
            frame:SetPortraitToAsset(LOGO)
        else
            local portrait = GetPortrait(frame)
            if portrait then SetPortraitToTexture(portrait, LOGO) end
        end
    end
    if not frame.CloseButton then
        local close = CreateWithTemplates("Button", nil, frame, { "UIPanelCloseButtonDefaultAnchors", "UIPanelCloseButton" })
        close:SetPoint("TOPRIGHT", 0, 0)
        frame.CloseButton = close
    end
    if options.resizable then
        AddResizeGrip(frame, options)
    end
    if options.dbKey then
        RestorePosition(frame, options.dbKey)
    end
    if CLM.GlobalConfigs and CLM.GlobalConfigs.GetUIScale then
        frame:SetScale(CLM.GlobalConfigs:GetUIScale())
    end
    if UI.IsTestMode() then
        ApplyTestModeLook(frame)
    end
    if options.name then
        UTILS.MakeFrameCloseOnEsc(frame, options.name)
    end
    frame:Hide()
    return frame
end

-- Content well
---@param parent table
---@return table
function UI.CreateInset(parent)
    return (CreateWithTemplates("Frame", nil, parent, { "InsetFrameTemplate" }))
end

-- One-line orange banner for test mode; returns nil outside test mode
---@param parent table
---@return table?
function UI.CreateTestModeBanner(parent)
    if not UI.IsTestMode() then return nil end
    local banner = CreateFrame("Frame", nil, parent)
    banner:SetHeight(24)
    local bg = banner:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 0.5, 0, 0.08)
    local line = banner:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(1, 0.5, 0, 0.35)
    local text = UI.CreateLabel(banner, CLM.L["Changes are local. Leaving test mode reloads the UI."], "GameFontNormalSmall", UI.COLOR.TEST)
    text:SetPoint("LEFT", UI.SPACE.S, 0)
    return banner
end

--[[
 * Bottom tabs *
]]--

-- names: tab labels; onSelect(id). The window must have a global name.
---@param frame table
---@param names string[]
---@param onSelect function
function UI.CreateTabs(frame, names, onSelect)
    frame.Tabs = {}
    for i, label in ipairs(names) do
        local tab = CreateWithTemplates("Button", frame:GetName() .. "Tab" .. i, frame,
            { "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate", "UIPanelButtonTemplate" })
        tab:SetID(i)
        tab:SetText(label)
        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
        else
            tab:SetPoint("TOPLEFT", frame.Tabs[i - 1], "TOPRIGHT", 3, 0)
        end
        tab:SetScript("OnClick", function(self)
            UI.SelectTab(frame, self:GetID())
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end)
        if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
        frame.Tabs[i] = tab
    end
    frame.onTabSelected = onSelect
    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(frame, #names) end
end

---@param frame table
---@param id number
function UI.SelectTab(frame, id)
    if PanelTemplates_SetTab then PanelTemplates_SetTab(frame, id) end
    frame.selectedTabId = id
    if frame.onTabSelected then frame.onTabSelected(id) end
end

--[[
 * Buttons *
]]--

-- Primary and secondary buttons share the red template; rank comes from position (primary bottom-right)
---@param parent table
---@param text string
---@param width number?
---@param onClick function?
---@return table
function UI.CreateButton(parent, text, width, onClick)
    local button = CreateWithTemplates("Button", nil, parent, { "UIPanelButtonTemplate" })
    button:SetSize(width or 96, UI.SPACE.BUTTON)
    button:SetText(text)
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

-- Small square button with a game icon (e.g. dice for /roll)
---@param parent table
---@param icon string|number texture path or file id
---@param tooltip string?
---@param onClick function?
---@return table
function UI.CreateIconButton(parent, icon, tooltip, onClick)
    local button = CreateWithTemplates("Button", nil, parent, { "UIPanelSquareButton", "UIPanelButtonTemplate" })
    button:SetSize(24, 24)
    if button.icon then
        button.icon:SetTexture(icon)
        button.icon:SetTexCoord(0, 1, 0, 1)
        button.icon:SetSize(16, 16)
    else
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("CENTER")
        texture:SetSize(16, 16)
        texture:SetTexture(icon)
        button.icon = texture
    end
    if tooltip then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

--[[
    Bid tier button: 74x40, tier name on top, GP below (design 5a).
    :SetTier(name, gp, color) · :SetSelected(bool)
]]--
---@param parent table
---@param onClick function?
---@return table
function UI.CreateTierButton(parent, onClick)
    local button = CreateWithTemplates("Button", nil, parent, { "UIPanelButtonTemplate" })
    button:SetSize(74, 40)
    button:SetText("")
    button.Name = UI.CreateLabel(button, "", "GameFontNormal")
    button.Name:SetPoint("TOP", 0, -6)
    button.Name:SetJustifyH("CENTER")
    button.Cost = UI.CreateLabel(button, "", "GameFontHighlightSmall")
    button.Cost:SetPoint("BOTTOM", 0, 6)
    button.Cost:SetJustifyH("CENTER")
    local selected = button:CreateTexture(nil, "OVERLAY")
    selected:SetPoint("TOPLEFT", -2, 2)
    selected:SetPoint("BOTTOMRIGHT", 2, -2)
    selected:SetTexture(HIGHLIGHT)
    selected:SetBlendMode("ADD")
    selected:SetVertexColor(UI.COLOR.SELECTED:GetRGB())
    selected:Hide()
    button.SelectedTexture = selected

    function button:SetTier(name, gp, color)
        self.Name:SetText(name)
        SetTextColor(self.Name, color or UI.COLOR.GOLD)
        self.Cost:SetText(gp and (tostring(gp) .. " " .. CLM.L["GP"]) or "")
        self.Cost:SetShown(gp ~= nil)
        if gp == nil then
            self.Name:ClearAllPoints()
            self.Name:SetPoint("CENTER")
        end
    end
    function button:SetSelected(isSelected)
        self.SelectedTexture:SetShown(isSelected and true or false)
    end
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

--[[
 * Inputs *
]]--

--[[
    Single-line input (InputBoxTemplate), height 20.
    onChanged(text) runs on every user edit; Enter and Escape drop focus.
]]--
---@param parent table
---@param width number
---@param numeric boolean?
---@param onChanged function?
---@return table
function UI.CreateInput(parent, width, numeric, onChanged)
    local input = CreateWithTemplates("EditBox", nil, parent, { "InputBoxTemplate" })
    input:SetSize(width, UI.SPACE.INPUT)
    input:SetAutoFocus(false)
    input:SetFontObject(numeric and "NumberFontNormal" or "ChatFontNormal")
    if numeric then
        -- SetNumeric allows only digits; EP/GP/decay values may have decimals, so filter instead
        input:SetScript("OnChar", function(self)
            local text = self:GetText()
            local cleaned = text:gsub("[^%d%.%-]", "")
            if cleaned ~= text then self:SetText(cleaned) end
        end)
    end
    input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if onChanged then
        input:SetScript("OnTextChanged", function(self, userInput)
            if userInput then onChanged(self:GetText()) end
        end)
    end
    return input
end

---@param parent table
---@param width number
---@param onChanged function? called with the text on every edit
---@return table
function UI.CreateSearchBox(parent, width, onChanged)
    local box = CreateWithTemplates("EditBox", nil, parent, { "SearchBoxTemplate", "InputBoxTemplate" })
    box:SetSize(width, UI.SPACE.INPUT)
    box:SetAutoFocus(false)
    if onChanged then
        box:HookScript("OnTextChanged", function(self) onChanged(self:GetText()) end)
    end
    return box
end

---@param parent table
---@param label string
---@param onChanged function? called with the new checked state
---@return table
function UI.CreateCheckbox(parent, label, onChanged)
    local check = CreateWithTemplates("CheckButton", nil, parent, { "UICheckButtonTemplate" })
    check:SetSize(24, 24)
    local text = check.text or check.Text
    if not text then
        text = UI.CreateLabel(check, "", "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    end
    text:SetText(label)
    text:SetFontObject("GameFontHighlight")
    check.Label = text
    if onChanged then
        check:SetScript("OnClick", function(self)
            PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            onChanged(self:GetChecked() and true or false)
        end)
    end
    return check
end

--[[
    Dropdown (WowStyle1DropdownTemplate, the 11.x menu system).
    getOptions() returns { {text=, value=}, ... }; getSelected() returns the current value.
    :Refresh() re-reads both.
]]--
---@param parent table
---@param width number
---@param getOptions function
---@param getSelected function
---@param onSelect function
---@return table
function UI.CreateDropdown(parent, width, getOptions, getSelected, onSelect)
    local dropdown = CreateWithTemplates("DropdownButton", nil, parent, { "WowStyle1DropdownTemplate" })
    dropdown:SetSize(width, UI.SPACE.BUTTON)
    if dropdown.SetupMenu then
        dropdown:SetupMenu(function(_, rootDescription)
            for _, option in ipairs(getOptions()) do
                rootDescription:CreateRadio(option.text,
                    function() return getSelected() == option.value end,
                    function() onSelect(option.value) end)
            end
        end)
    end
    function dropdown:Refresh()
        if self.GenerateMenu then self:GenerateMenu() end
    end
    return dropdown
end

--[[
    Context menu (MenuUtil). items: { {text=, func=, color=ColorMixin?, disabled=bool?}, {divider=true}, ... }
]]--
---@param owner table
---@param title string?
---@param items table
function UI.ShowContextMenu(owner, title, items)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        if title then rootDescription:CreateTitle(title) end
        for _, item in ipairs(items) do
            if item.divider then
                rootDescription:CreateDivider()
            else
                local text = item.color and item.color:WrapTextInColorCode(item.text) or item.text
                local button = rootDescription:CreateButton(text, item.func)
                if item.disabled and button.SetEnabled then button:SetEnabled(false) end
            end
        end
    end)
end

-- Thin divider line (Options_HorizontalDivider atlas when available)
---@param parent table
---@return table texture
function UI.CreateDivider(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    if UI.HasAtlas("Options_HorizontalDivider") then
        line:SetAtlas("Options_HorizontalDivider", true)
    else
        line:SetHeight(1)
        line:SetColorTexture(0.35, 0.3, 0.23, 1)
    end
    return line
end

--[[
 * Icons *
]]--

local CLASS_ATLAS = {
    DEATHKNIGHT = "classicon-deathknight", DEMONHUNTER = "classicon-demonhunter", DRUID = "classicon-druid",
    EVOKER = "classicon-evoker", HUNTER = "classicon-hunter", MAGE = "classicon-mage", MONK = "classicon-monk",
    PALADIN = "classicon-paladin", PRIEST = "classicon-priest", ROGUE = "classicon-rogue", SHAMAN = "classicon-shaman",
    WARLOCK = "classicon-warlock", WARRIOR = "classicon-warrior",
}

-- classFile: "WARRIOR", "DEMONHUNTER", ...
---@param texture table
---@param classFile string?
function UI.SetClassIcon(texture, classFile)
    local atlas = classFile and CLASS_ATLAS[classFile]
    if atlas and UI.HasAtlas(atlas) then
        texture:SetAtlas(atlas)
        texture:Show()
    elseif classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classFile]))
        texture:Show()
    else
        texture:Hide()
    end
end

---@param classFile string?
---@return table ColorMixin
function UI.GetClassColor(classFile)
    if classFile and C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFile)
        if color then return color end
    end
    return UI.COLOR.WHITE
end

--[[
    Item button: icon, quality border, item tooltip, optional state border (queue states).
    :SetItem(itemLinkOrId) · :SetState(ColorMixin|nil)
]]--
---@param parent table
---@param size number 36 (queue) or 24 (compact)
---@param onClick function?
---@return table
function UI.CreateItemButton(parent, size, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints()
    button.Icon:SetTexture(134400) -- question mark
    button.IconBorder = button:CreateTexture(nil, "OVERLAY")
    button.IconBorder:SetAllPoints()
    button.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    button.IconBorder:Hide()
    button.StateBorder = button:CreateTexture(nil, "OVERLAY", nil, 1)
    button.StateBorder:SetPoint("CENTER")
    button.StateBorder:SetSize(size * 1.75, size * 1.75)
    button.StateBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.StateBorder:SetBlendMode("ADD")
    button.StateBorder:Hide()
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    function button:SetItem(item)
        self.itemLink = nil
        if not item then
            self.Icon:SetTexture(134400)
            self.IconBorder:Hide()
            return
        end
        local itemObject = type(item) == "number" and Item:CreateFromItemID(item) or Item:CreateFromItemLink(item)
        if itemObject:IsItemEmpty() then return end
        itemObject:ContinueOnItemLoad(function()
            self.itemLink = itemObject:GetItemLink()
            self.Icon:SetTexture(itemObject:GetItemIcon())
            local quality = itemObject:GetItemQuality()
            local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if color and quality >= 2 then
                self.IconBorder:SetVertexColor(color.r, color.g, color.b)
                self.IconBorder:Show()
            else
                self.IconBorder:Hide()
            end
        end)
    end
    function button:SetState(color)
        if color then
            self.StateBorder:SetVertexColor(color:GetRGB())
            self.StateBorder:Show()
        else
            self.StateBorder:Hide()
        end
    end
    button:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

--[[
 * Confirmations *
    Every write asks first (ui-redesign.md R6). One shared StaticPopup; the text says exactly
    what will happen, onAccept runs on Accept.
]]--

local CONFIRM_POPUP = "BPEPGP_CONFIRM"

---@param text string
---@param onAccept function
function UI.Confirm(text, onAccept)
    if not StaticPopupDialogs[CONFIRM_POPUP] then
        StaticPopupDialogs[CONFIRM_POPUP] = {
            text = "%s",
            button1 = YES,
            button2 = NO,
            OnAccept = function(_, data)
                if type(data) == "function" then data() end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Hide(CONFIRM_POPUP)
    StaticPopup_Show(CONFIRM_POPUP, text, nil, onAccept)
end

-- Spinning loading indicator (LoadingSpinnerTemplate); plays while shown
---@param parent table
---@return table
function UI.CreateSpinner(parent)
    local spinner = CreateWithTemplates("Frame", nil, parent, { "LoadingSpinnerTemplate" })
    spinner:SetSize(48, 48)
    spinner:HookScript("OnShow", function(self)
        if self.Anim then self.Anim:Play() end
    end)
    spinner:HookScript("OnHide", function(self)
        if self.Anim then self.Anim:Stop() end
    end)
    return spinner
end

--[[
    Progress / timer bar: StatusBar with the standard bar texture. :SetProgress(fraction, text)
]]--
---@param parent table
---@param width number
---@param height number
---@return table
function UI.CreateProgressBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0.82, 0)
    bar:SetMinMaxValues(0, 1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    border:SetBackdropBorderColor(0.42, 0.35, 0.23, 1)
    bar.Text = UI.CreateLabel(bar, "", "GameFontHighlightSmall")
    bar.Text:SetPoint("CENTER")
    function bar:SetProgress(fraction, text)
        self:SetValue(math.max(0, math.min(1, fraction or 0)))
        self.Text:SetText(text or "")
    end
    return bar
end
