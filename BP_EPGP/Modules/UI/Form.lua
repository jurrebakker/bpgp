-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
-- local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI
local S = UI.SPACE

--[[
    Settings form: a scrolling column of "label + control" rows (ui-redesign.md "Settings rows").

    local form = UI.CreateForm(parent)
    form:Header(text)
    form:Description(text)
    form:Toggle{ label=, desc=, warning=, get=, set=, readOnly=function?, hidden=function? }
        (every row: desc is the tooltip text, warning an extra line in red)
    form:Number{ label=, desc=, get=, set=, width=, readOnly= }      applied on Enter or when focus leaves
    form:Text{ label=, desc=, get=, set=, width=, maxLetters=, readOnly= }
    form:Select{ label=, desc=, options=function -> {{text=, value=}}, get=, set=, width=, readOnly= }
    form:Button{ label=, text=, desc=, func=, width=, color=ColorMixin?, readOnly= }
    form:Custom(height, function(frame) ... end, refresh?)  a free-form block (e.g. a grid)
    form:Layout()   positions the rows (call after adding rows, and when `hidden` may have changed)
    form:Refresh()  re-reads every getter and the read-only state
    form:Clear()    hides all rows so the form can be rebuilt

    readOnly() disables the control (shown, not hidden: D3). Rows never write without the user
    changing a control, and setters get plain Lua values (boolean, number, string).
]]--

local LABEL_WIDTH = 200
local ROW_HEIGHT = 26
local HEADER_HEIGHT = 30

local Form = {}

local function ShowTooltip(owner, title, desc, warning)
    if not desc and not warning then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    if desc then GameTooltip:AddLine(desc, 1, 1, 1, true) end
    if warning then GameTooltip:AddLine(warning, 1, 0.13, 0.13, true) end
    GameTooltip:Show()
end

function Form:AddRow(height, definition)
    local row = CreateFrame("Frame", nil, self.content)
    row:SetHeight(height)
    row.definition = definition or {}
    row.height = height
    self.rows[#self.rows + 1] = row
    return row
end

-- Label on the left with the description as tooltip
local function AddLabel(row, definition)
    local hit = CreateFrame("Frame", nil, row)
    hit:SetPoint("TOPLEFT")
    hit:SetPoint("BOTTOMLEFT")
    hit:SetWidth(LABEL_WIDTH - S.S)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self) ShowTooltip(self, definition.label, definition.desc, definition.warning) end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.Label = UI.CreateLabel(hit, definition.label or "", "GameFontNormal")
    row.Label:SetPoint("LEFT")
    row.Label:SetPoint("RIGHT")
    row.Label:SetWordWrap(false)
end

local function IsReadOnly(definition)
    return definition.readOnly and definition.readOnly() or false
end

local function SetRowEnabled(row, enabled)
    if row.Control and row.Control.SetEnabled then row.Control:SetEnabled(enabled) end
    if row.Label then
        if enabled then row.Label:SetFontObject("GameFontNormal") else row.Label:SetFontObject("GameFontDisable") end
    end
end

---@param text string
function Form:Header(text)
    local row = self:AddRow(HEADER_HEIGHT)
    row.isHeader = true
    local label = UI.CreateLabel(row, text, "GameFontNormalLarge")
    label:SetPoint("BOTTOMLEFT", 0, S.XS + 2)
    local line = UI.CreateDivider(row)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    return row
end

---@param text string|function
function Form:Description(text)
    local row = self:AddRow(ROW_HEIGHT)
    local label = UI.CreateLabel(row, "", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 0, -S.XS)
    label:SetPoint("RIGHT")
    label:SetWordWrap(true)
    label:SetJustifyV("TOP")
    row.Refresh = function()
        label:SetText(type(text) == "function" and text() or text)
    end
    -- Wrapped text: the height is only known once the row has its width (in Layout)
    row.Measure = function()
        return math.max(ROW_HEIGHT, math.ceil(label:GetStringHeight()) + S.S)
    end
    row.Refresh()
    return row
end

---@param definition table
function Form:Toggle(definition)
    local row = self:AddRow(ROW_HEIGHT, definition)
    AddLabel(row, definition)
    local check = UI.CreateCheckbox(row, "", function(checked)
        definition.set(checked)
        self:Refresh()
    end)
    check:SetPoint("LEFT", LABEL_WIDTH - 4, 0)
    row.Control = check
    row.Refresh = function()
        check:SetChecked(definition.get() and true or false)
        SetRowEnabled(row, not IsReadOnly(definition))
    end
    return row
end

local function AddInput(self, definition, numeric)
    local row = self:AddRow(ROW_HEIGHT, definition)
    AddLabel(row, definition)
    local input = UI.CreateInput(row, definition.width or (numeric and 70 or 160), numeric)
    input:SetPoint("LEFT", LABEL_WIDTH + 6, 0)
    if definition.maxLetters then input:SetMaxLetters(definition.maxLetters) end
    local function Current()
        local value = definition.get()
        return value ~= nil and tostring(value) or ""
    end
    local function Apply()
        local text = input:GetText()
        if text == Current() then return end
        if numeric then
            local value = tonumber(text)
            if value then definition.set(value) end
        else
            definition.set(text)
        end
        input:SetText(Current())
    end
    input:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    input:HookScript("OnEditFocusLost", Apply)
    input:SetScript("OnEscapePressed", function(box)
        box:SetText(Current())
        box:ClearFocus()
    end)
    row.Control = input
    row.Refresh = function()
        if not input:HasFocus() then input:SetText(Current()) end
        SetRowEnabled(row, not IsReadOnly(definition))
    end
    return row
end

---@param definition table
function Form:Number(definition)
    return AddInput(self, definition, true)
end

---@param definition table
function Form:Text(definition)
    return AddInput(self, definition, false)
end

---@param definition table
function Form:Select(definition)
    local row = self:AddRow(ROW_HEIGHT, definition)
    AddLabel(row, definition)
    local dropdown = UI.CreateDropdown(row, definition.width or 160, definition.options, definition.get, function(value)
        definition.set(value)
        self:Refresh()
    end)
    dropdown:SetPoint("LEFT", LABEL_WIDTH, 0)
    row.Control = dropdown
    row.Refresh = function()
        dropdown:Refresh()
        SetRowEnabled(row, not IsReadOnly(definition))
    end
    return row
end

---@param definition table
function Form:Button(definition)
    local row = self:AddRow(ROW_HEIGHT, definition)
    AddLabel(row, definition)
    -- text may be a function (e.g. "Enter test mode" / "Leave test mode"); Refresh sets it
    local text = definition.text or definition.label
    local button = UI.CreateButton(row, type(text) == "function" and text() or text, definition.width or 160, function() definition.func() end)
    button:SetPoint("LEFT", LABEL_WIDTH, 0)
    if definition.color then
        button:GetFontString():SetTextColor(definition.color:GetRGB())
    end
    if definition.desc then
        button:SetScript("OnEnter", function(self) ShowTooltip(self, definition.label or definition.text, definition.desc) end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    row.Control = button
    row.Refresh = function()
        if type(definition.text) == "function" then button:SetText(definition.text()) end
        SetRowEnabled(row, not IsReadOnly(definition))
    end
    return row
end

---@param height number
---@param build function(frame)
---@param refresh function? (frame)
---@param hidden function?
function Form:Custom(height, build, refresh, hidden)
    local row = self:AddRow(height, { hidden = hidden })
    build(row)
    row.Refresh = refresh and function() refresh(row) end or nil
    return row
end

function Form:Layout()
    local y = 0
    for _, row in ipairs(self.rows) do
        local hidden = row.definition.hidden and row.definition.hidden() or row.removed
        row:SetShown(not hidden)
        if not hidden then
            if row.isHeader and y < 0 then y = y - S.S end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
            row:SetPoint("RIGHT", self.content, "RIGHT", -S.S, 0)
            if row.Measure then row.height = row.Measure() end
            row:SetHeight(row.height)
            y = y - row.height - (row.isHeader and S.XS or 0)
        end
    end
    self.content:SetHeight(math.max(-y + S.S, 1))
end

function Form:Refresh()
    for _, row in ipairs(self.rows) do
        if row.Refresh and not row.removed then row.Refresh() end
    end
    self:Layout()
end

-- Hide every row; the caller adds new ones (frames are not reused)
function Form:Clear()
    for _, row in ipairs(self.rows) do
        row.removed = true
        row:Hide()
    end
    self.rows = {}
end

---@param parent table
---@return table form
function UI.CreateForm(parent)
    local scroll = UI.CreateWithTemplates("ScrollFrame", nil, parent, { "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" })
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnSizeChanged", function(self, width) content:SetWidth(math.max(width, 1)) end)
    -- Not every template version wires up the mouse wheel; do it here so it always scrolls
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = self:GetVerticalScroll() - delta * ROW_HEIGHT * 3
        self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
    end)

    local form = { frame = scroll, content = content, rows = {} }
    for name, method in pairs(Form) do form[name] = method end
    return form
end
