-- ------------------------------- --
local  _, CLM = ...
---@cast CLM CLMNamespace
-- ------ CLM common cache ------- --
-- local LOG       = CLM.LOG
-- local CONSTANTS = CLM.CONSTANTS
-- local UTILS     = CLM.UTILS
-- ------------------------------- --

local UI = CLM.UI

--[[
    Scrolling list with column headers (design: WowScrollBoxList + MinimalScrollBar, ColumnDisplay look).

    UI.CreateList(parent, options)
      options.columns = {
        { key = "name", title = "Name", width = 0 (fill; at most one), align = "LEFT"|"RIGHT"|"CENTER",
          font = "GameFontHighlight", classIcon = true (shows row.classFile), sortable = true (default),
          text = function(row) -> string (default tostring(row.values[key])),
          color = function(row) -> ColorMixin? },
        ...
      }
      options.rowHeight      default 20
      options.multiSelect    clicks toggle rows, shift-click selects a range
      options.sortKey / options.sortDesc   initial sort
      options.pinned(row) -> true keeps the row on top whatever the sort (e.g. your own row)
      options.rowTint(row) -> ColorMixin? background tint instead of the alternating stripe
      options.onSelectionChanged(selectedRows)
      options.onRightClick(row, rowFrame)
      options.onEnter(row, rowFrame) / options.onLeave(row, rowFrame)

    Rows: { id = unique, values = { key = value }, classFile = "WARRIOR"? }
    Methods: :SetData(rows) · :GetSelection() · :ClearSelection() · :SetSort(key, desc) · :Refresh()
]]--

local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local HEADER_HEIGHT = 20
local SCROLLBAR_SPACE = 14
local CELL_PADDING = 4
local ICON_SIZE = 14

-- Columns before the fill column are anchored from the left, columns after it from the right,
-- so the fill column takes whatever width the list has (it can be resized).
local function LayoutCells(container, cells, columns)
    local fill
    for i, column in ipairs(columns) do
        if not column.width or column.width == 0 then fill = i break end
    end
    local left = 0
    for i = 1, (fill and fill - 1 or #columns) do
        local cell = cells[i]
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", container, "TOPLEFT", left, 0)
        cell:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", left, 0)
        cell:SetWidth(columns[i].width)
        left = left + columns[i].width
    end
    if fill then
        local right = 0
        for i = #columns, fill + 1, -1 do
            local cell = cells[i]
            cell:ClearAllPoints()
            cell:SetPoint("TOPRIGHT", container, "TOPRIGHT", -right, 0)
            cell:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -right, 0)
            cell:SetWidth(columns[i].width)
            right = right + columns[i].width
        end
        local cell = cells[fill]
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", container, "TOPLEFT", left, 0)
        cell:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -right, 0)
    end
end

local function CompareValues(a, b)
    local ta, tb = type(a), type(b)
    if ta == "number" and tb == "number" then return a < b end
    return tostring(a or ""):lower() < tostring(b or ""):lower()
end

local List = {}

function List:SortRows()
    local key, desc = self.sortKey, self.sortDesc
    local rows = self.rows
    local pinned = self.options.pinned
    if key then
        table.sort(rows, function(a, b)
            if pinned then
                local pa, pb = pinned(a) and true or false, pinned(b) and true or false
                if pa ~= pb then return pa end
            end
            local va, vb = a.values[key], b.values[key]
            if va == vb then
                return CompareValues(a.id, b.id)
            end
            if desc then return CompareValues(vb, va) end
            return CompareValues(va, vb)
        end)
    end
    for index, row in ipairs(rows) do
        row._index = index
    end
end

function List:UpdateHeaders()
    for i, header in ipairs(self.headers) do
        local column = self.columns[i]
        header.Arrow:SetShown(self.sortKey == column.key)
        if self.sortKey == column.key then
            -- arrow points down for descending, up for ascending
            header.Arrow:SetRotation(self.sortDesc and 0 or math.pi)
        end
    end
end

function List:Refresh()
    self:SortRows()
    self:UpdateHeaders()
    local provider = CreateDataProvider(self.rows)
    self.ScrollBox:SetDataProvider(provider, ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
end

---@param rows table
function List:SetData(rows)
    self.rows = rows or {}
    local ids = {}
    for _, row in ipairs(self.rows) do ids[row.id] = true end
    for id in pairs(self.selected) do
        if not ids[id] then self.selected[id] = nil end
    end
    self:Refresh()
end

---@param key string
---@param desc boolean
function List:SetSort(key, desc)
    self.sortKey, self.sortDesc = key, desc
    self:Refresh()
end

---@return table rows in display order
function List:GetSelection()
    local result = {}
    for _, row in ipairs(self.rows) do
        if self.selected[row.id] then result[#result + 1] = row end
    end
    return result
end

function List:ClearSelection()
    wipe(self.selected)
    self:UpdateSelectionVisuals()
    self:SelectionChanged()
end

function List:SelectionChanged()
    if self.options.onSelectionChanged then
        self.options.onSelectionChanged(self:GetSelection())
    end
end

function List:UpdateSelectionVisuals()
    self.ScrollBox:ForEachFrame(function(rowFrame)
        if rowFrame.row then
            rowFrame.Selected:SetShown(self.selected[rowFrame.row.id] and true or false)
        end
    end)
end

function List:OnRowClick(rowFrame, button)
    local row = rowFrame.row
    if not row then return end
    if button == "RightButton" then
        if not self.selected[row.id] then
            wipe(self.selected)
            self.selected[row.id] = true
            self:UpdateSelectionVisuals()
            self:SelectionChanged()
        end
        if self.options.onRightClick then self.options.onRightClick(row, rowFrame) end
        return
    end
    if self.options.multiSelect then
        if IsShiftKeyDown() and self.lastClicked and self.lastClicked._index then
            local from, to = self.lastClicked._index, row._index
            if from > to then from, to = to, from end
            for i = from, to do self.selected[self.rows[i].id] = true end
        else
            self.selected[row.id] = not self.selected[row.id] or nil
        end
    else
        local wasSelected = self.selected[row.id]
        wipe(self.selected)
        if not wasSelected then self.selected[row.id] = true end
    end
    self.lastClicked = row
    self:UpdateSelectionVisuals()
    self:SelectionChanged()
end

local function CreateCell(rowFrame, column)
    local cell = CreateFrame("Frame", nil, rowFrame)
    cell.Text = UI.CreateLabel(cell, "", column.font or "GameFontHighlight")
    cell.Text:SetJustifyH(column.align or "LEFT")
    cell.Text:SetWordWrap(false)
    if column.classIcon then
        cell.Icon = cell:CreateTexture(nil, "ARTWORK")
        cell.Icon:SetSize(ICON_SIZE, ICON_SIZE)
        cell.Icon:SetPoint("LEFT", CELL_PADDING, 0)
        cell.Text:SetPoint("LEFT", cell.Icon, "RIGHT", CELL_PADDING, 0)
    else
        cell.Text:SetPoint("LEFT", CELL_PADDING, 0)
    end
    cell.Text:SetPoint("RIGHT", -CELL_PADDING * 2, 0)
    return cell
end

function List:InitRow(rowFrame, row)
    if not rowFrame.cells then
        rowFrame.cells = {}
        for i, column in ipairs(self.columns) do
            rowFrame.cells[i] = CreateCell(rowFrame, column)
        end
        LayoutCells(rowFrame, rowFrame.cells, self.columns)
        rowFrame.Stripe = rowFrame:CreateTexture(nil, "BACKGROUND")
        rowFrame.Stripe:SetAllPoints()
        rowFrame.Stripe:SetColorTexture(1, 1, 1, 0.035)
        rowFrame.Selected = rowFrame:CreateTexture(nil, "ARTWORK")
        rowFrame.Selected:SetAllPoints()
        rowFrame.Selected:SetTexture(HIGHLIGHT)
        rowFrame.Selected:SetBlendMode("ADD")
        rowFrame.Selected:SetVertexColor(UI.COLOR.SELECTED:GetRGB())
        rowFrame:SetHighlightTexture(HIGHLIGHT, "ADD")
        rowFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        rowFrame:SetScript("OnClick", function(frame, button) self:OnRowClick(frame, button) end)
        rowFrame:SetScript("OnEnter", function(frame)
            if self.options.onEnter and frame.row then self.options.onEnter(frame.row, frame) end
        end)
        rowFrame:SetScript("OnLeave", function(frame)
            if self.options.onLeave and frame.row then self.options.onLeave(frame.row, frame) end
            GameTooltip:Hide()
        end)
    end
    rowFrame.row = row
    local tint = self.options.rowTint and self.options.rowTint(row)
    if tint then
        rowFrame.Stripe:SetColorTexture(tint:GetRGBA())
        rowFrame.Stripe:Show()
    else
        rowFrame.Stripe:SetColorTexture(1, 1, 1, 0.035)
        rowFrame.Stripe:SetShown((row._index or 0) % 2 == 0)
    end
    rowFrame.Selected:SetShown(self.selected[row.id] and true or false)
    for i, column in ipairs(self.columns) do
        local cell = rowFrame.cells[i]
        local text
        if column.text then
            text = column.text(row)
        else
            local value = row.values[column.key]
            text = value ~= nil and tostring(value) or ""
        end
        cell.Text:SetText(text)
        local color = column.color and column.color(row)
        cell.Text:SetTextColor((color or UI.COLOR.WHITE):GetRGB())
        if cell.Icon then UI.SetClassIcon(cell.Icon, row.classFile) end
    end
end

local function CreateHeader(list)
    local header = CreateFrame("Frame", nil, list)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -SCROLLBAR_SPACE, 0)
    header:SetHeight(HEADER_HEIGHT)
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    bg:SetGradient("VERTICAL", CreateColor(0.10, 0.08, 0.07, 1), CreateColor(0.18, 0.15, 0.13, 1))
    local line = header:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(0, 0, 0, 1)

    list.headers = {}
    for i, column in ipairs(list.columns) do
        local button = CreateFrame("Button", nil, header)
        button.Text = UI.CreateLabel(button, column.title or "", "GameFontNormalSmall")
        button.Text:SetJustifyH(column.align or "LEFT")
        button.Text:SetPoint("LEFT", column.classIcon and (CELL_PADDING * 2 + ICON_SIZE) or CELL_PADDING, 0)
        button.Text:SetPoint("RIGHT", -CELL_PADDING * 2, 0)
        button.Arrow = button:CreateTexture(nil, "OVERLAY")
        if UI.HasAtlas("auctionhouse-ui-sortarrow") then
            button.Arrow:SetAtlas("auctionhouse-ui-sortarrow")
        else
            button.Arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
        end
        button.Arrow:SetSize(9, 8)
        button.Arrow:SetPoint("RIGHT", -1, 0)
        button.Arrow:Hide()
        button:SetHighlightTexture(HIGHLIGHT, "ADD")
        if column.sortable ~= false then
            button:SetScript("OnClick", function()
                if list.sortKey == column.key then
                    list.sortDesc = not list.sortDesc
                else
                    list.sortKey = column.key
                    list.sortDesc = column.defaultDesc and true or false
                end
                list:Refresh()
            end)
        end
        list.headers[i] = button
    end
    LayoutCells(header, list.headers, list.columns)
    return header
end

---@param parent table
---@param options table
---@return table list
function UI.CreateList(parent, options)
    local list = CreateFrame("Frame", nil, parent)
    for name, method in pairs(List) do list[name] = method end
    list.options = options
    list.columns = options.columns
    list.rows = {}
    list.selected = {}
    list.sortKey = options.sortKey
    list.sortDesc = options.sortDesc

    list.Header = CreateHeader(list)

    local scrollBox = CreateFrame("Frame", nil, list, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", list.Header, "BOTTOMLEFT", 0, -2)
    scrollBox:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -SCROLLBAR_SPACE, 0)
    local scrollBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(options.rowHeight or UI.SPACE.ROW)
    view:SetElementInitializer("Button", function(rowFrame, row) list:InitRow(rowFrame, row) end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    list.ScrollBox = scrollBox
    list.ScrollBar = scrollBar
    list:Refresh()
    return list
end
