--[[-----------------------------------------------------------------------------
BPEPGPEditBoxNoButton - Ace3 EditBox without the "Okay" button.
The value is stored on every keystroke (option set() is called directly, without the
AceConfigDialog refresh that would steal focus), so a following button click sees it.
Enter still commits through AceConfigDialog as usual.
-------------------------------------------------------------------------------]]
local Type, Version = "BPEPGPEditBoxNoButton", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local function EditBox_OnTextChanged(frame, userInput)
    if not userInput then return end
    local option = frame.obj:GetUserData("option")
    if option and type(option.set) == "function" then
        option.set(nil, frame:GetText())
    end
end

local function Constructor()
    local widget = AceGUI.WidgetRegistry["EditBox"]()
    widget.type = Type
    local baseOnAcquire = widget.OnAcquire
    widget.OnAcquire = function(self)
        baseOnAcquire(self)
        self:DisableButton(true)
    end
    widget.editbox:HookScript("OnTextChanged", EditBox_OnTextChanged)
    return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
