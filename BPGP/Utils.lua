---@diagnostic disable: param-type-mismatch
local _, CLM = ...
---@cast CLM CLMNamespace

local LOG = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
---@class UTILS
---@field ParseVersionString fun(versionString:string): table
local UTILS = CLM.UTILS

local DumpTable = LibStub("BPGP-EventSourcing/Util").DumpTable

local function capitalize(string)
    string = string or ""
    return string.upper(string.sub(string, 1,1)) .. string.lower(string.sub(string, 2))
end

local numberToClass = {
    [1]  = "Warrior",
    [2]  = "Paladin",
    [3]  = "Hunter",
    [4]  = "Rogue",
    [5]  = "Priest",
    [6]  = "Death Knight",
    [7]  = "Shaman",
    [8]  = "Mage",
    [9]  = "Warlock",
    [10] = "Monk",
    [11] = "Druid",
    [12] = "Demon Hunter",
    [13] = "Evoker"
}
local classOrdered = {
    "Death Knight", "Demon Hunter", "Druid", "Evoker", "Hunter", "Mage", "Monk",
    "Priest", "Rogue", "Shaman", "Paladin", "Warlock", "Warrior"
}

---@return number
function UTILS.GetNumClasses()
    return #classOrdered
end

local classToNumber = {}
for k, v in pairs(numberToClass) do
    classToNumber[v] = k
end

---@param class string
---@return number
function UTILS.ClassToNumber(class)
    return classToNumber[class] or 0
end

---@param number number
---@return string
function UTILS.NumberToClass(number)
    return numberToClass[number] or ""
end

local classToCanonical = {
    ["Warrior"] = "WARRIOR",
    ["Paladin"] = "PALADIN",
    ["Hunter"] = "HUNTER",
    ["Rogue"] = "ROGUE",
    ["Priest"] = "PRIEST",
    ["Death Knight"] = "DEATHKNIGHT",
    ["Shaman"] = "SHAMAN",
    ["Mage"] = "MAGE",
    ["Warlock"] = "WARLOCK",
    ["Monk"] = "MONK",
    ["Druid"] = "DRUID",
    ["Demon Hunter"] = "DEMONHUNTER",
    ["Evoker"] = "EVOKER",
}

---@param class string
---@return string|nil
function UTILS.CanonicalClass(class)
    return classToCanonical[class]
end

local canonicalToNumber = {
    ["WARRIOR"] = 1,
    ["PALADIN"] = 2,
    ["HUNTER"] = 3,
    ["ROGUE"] = 4,
    ["PRIEST"] = 5,
    ["DEATHKNIGHT"] = 6,
    ["SHAMAN"] = 7,
    ["MAGE"] = 8,
    ["WARLOCK"] = 9,
    ["MONK"] = 10,
    ["DRUID"] = 11,
    ["DEMONHUNTER"] = 12,
    ["EVOKER"] = 13,
}

---@param class string
---@return number|nil
function UTILS.CanonicalClassToNumber(class)
    return canonicalToNumber[class]
end

local classColors = {
    ["Druid"]           = { a = 1, r = 1,    g = 0.49, b = 0.04, hex = "FF7D0A" },
    ["Hunter"]          = { a = 1, r = 0.67, g = 0.83, b = 0.45, hex = "ABD473" },
    ["Mage"]            = { a = 1, r = 0.25, g = 0.78, b = 0.92, hex = "40C7EB" },
    ["Priest"]          = { a = 1, r = 1,    g = 1,    b = 1,    hex = "FFFFFF" },
    ["Rogue"]           = { a = 1, r = 1,    g = 0.96, b = 0.41, hex = "FFF569" },
    ["Shaman"]          = { a = 1, r = 0.01, g = 0.44, b = 0.87, hex = "0270DD" },
    ["Paladin"]         = { a = 1, r = 0.96, g = 0.55, b = 0.73, hex = "F58CBA" },
    ["Warlock"]         = { a = 1, r = 0.53, g = 0.53, b = 0.93, hex = "8787ED" },
    ["Warrior"]         = { a = 1, r = 0.78, g = 0.61, b = 0.43, hex = "C79C6E" },
    ["Death Knight"]    = { a = 1, r = 0.77, g = 0.12, b = 0.23, hex = "C41E3A" },
    ["Demon Hunter"]    = { a = 1, r = 0.64, g = 0.19, b = 0.79, hex = "A330C9" },
    ["Monk"]            = { a = 1, r = 0,    g = 1.00, b = 0.60, hex = "00FF98" },
    ["Evoker"]          = { a = 1, r = 0.20, g = 0.58, b = 0.50, hex = "33937F" },
}

---@param className string
---@return table
function UTILS.GetClassColor(className)
    local color = classColors[className]
    return (color or { r = 0.627, g = 0.627, b = 0.627, hex = "9d9d9d" })
end
local GetClassColor = UTILS.GetClassColor

---@param text string
---@param color string
---@return string
function UTILS.ColorCodeText(text, color)
    return string.format("|cff%s%s|r", color, text);
end
local ColorCodeText = UTILS.ColorCodeText

---@param className string
---@return string
function UTILS.ColorCodeAndLocalizeClass(className)
    return ColorCodeText(CLM.L[className], GetClassColor(className).hex);
end

local colorCodedClassList = {}
do
    for _,class in pairs(classOrdered) do
        tinsert(colorCodedClassList, UTILS.ColorCodeAndLocalizeClass(class))
    end
end
---@return table
function UTILS.GetColorCodedClassList()
    return colorCodedClassList
end

---@return table
function UTILS.GetClassList()
    return classOrdered
end

---@param percentage number
---@return string
function UTILS.ColorCodeByPercentage(percentage)
    percentage = tonumber(percentage) or 0
    if percentage < 0 then percentage = 0 end
    if percentage > 100 then percentage = 100 end

    local red, green, blue = 255, 255, 0
    if percentage < 50 then
        green = UTILS.round(5.1*percentage, 0) -- (255 * 2 / 100) * percentage
    elseif percentage > 50 then
        red = UTILS.round(5.1*(100 - percentage), 0) -- (2*255)*(100 - percentage)/100,
    end
    return string.format("|cff%s%s|r", string.format("%02x%02x%02x", red, green, blue), percentage)
end

---@param percentage number
---@return number, number, number, number
function UTILS.GetColorByPercentage(percentage)
    percentage = tonumber(percentage) or 0
    if percentage < 0 then percentage = 0 end
    if percentage > 100 then percentage = 100 end

    local red, green, blue = 1.0, 1.0, 0.0
    if percentage < 50 then
        green = UTILS.round((percentage * 2)/100, 2)
    elseif percentage > 50 then
        red = UTILS.round(2*(100 - percentage)/100, 2)
    end
    return red, green, blue, 1.0
end

---@param s string
---@return string
function UTILS.RemoveColorCode(s)
    return string.sub(s or "", 11, -3)
end

-- formats:
-- s: string  "AARRGGBB"
-- a: string array  = {a = "AA", r = "RR", g = "GG", b = "BB"}
-- i: integer array = {a = AA, r = RR, g = GG, b = BB } from 0 to 255
-- f: float array   = {a = AA, r = RR, g = GG, b = BB } from 0 to 1
---@param itemLink string
---@param format string
---@return string|table
function UTILS.GetColorFromLink(itemLink, format)
    local _, _, a, r, g, b = string.find(itemLink, "|c(%x%x)(%x%x)(%x%x)(%x%x)|.*")
    local color = {
        a = a or "",
        r = r or "",
        g = g or "",
        b = b or ""
    }
    if format == "s" then
        return string.format("%s%s%s%s", color.a, color.r, color.g, color.b)
    else
        if format ~= "s" then
            for k,v in pairs(color) do
                color[k] = tonumber("0x" .. v) or 0
            end
            if format == "f" then
                for k,v in pairs(color) do
                    color[k] = v / 255
                end
            end
        end

        return color
    end
end

---@param itemLink string
---@return number, string
function UTILS.GetItemIdFromLink(itemLink)
    -- local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, Name = string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
    itemLink = itemLink or ""
    -- local _, _, _, _, itemId = string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+).*")
    local _, _, itemId, extra = string.find(itemLink, "item:(%d+)([-?%d:]*)|h")
    return tonumber(itemId) or 0, extra or ""
end

---@param itemLink string
---@param extra string?
---@return string
function UTILS.SpoofLink(itemLink, extra)
    if not extra then return itemLink end
    local _, _, pre, post = string.find(itemLink, "(.*item:%d+)[-?%d:]+(|h.*)")
    if not pre or not post then return itemLink end
    return pre .. extra .. post
end

---@param name string
---@param object table
---@param cli string
function UTILS.UniversalCliMethodExecutor(name, object, cli)
    local values = {strsplit(" ", cli)}
    local method, args, parameters = values[1], {}, ""
    for i=2,#values do
        args[i - 1] = values[i]
        parameters = parameters .. tostring(values[i]) ..  ", "
    end

    if type(object[method]) == "function" then
        LOG:Info("Execute [%s(%s(%s)]", name, method, parameters)
        local result = object[method](object, unpack(args))
        if type(result) == 'table' then
            UTILS.DumpTable(result)
        else
            print(result)
        end

    else
        print("Available methods:")
        for methodName,ref in pairs(object) do
            if type(ref) == "function" then
                print(methodName)
            end
        end
    end
end

---@class StorageQualifiedObject
---@field persistent table
---@field volatile table
local StorageQualifiedObject = {}
---@param storage table?
---@return StorageQualifiedObject
function StorageQualifiedObject:New(storage)
    local o = {}

    setmetatable(o, self)
    self.__index = self

    -- Virtual profile that is not stored
    -- It's not a bug. It's a feature.
    if storage == nil then
        LOG:Warning("Virtual storage qualified object. Is this intended?")
        local s = {}
        o.persistent = s
    else
        o.persistent = storage
    end

    o.volatile = {}

    return o
end

---@param storage table?
---@param o table?
---@return StorageQualifiedObject
function UTILS.NewStorageQualifiedObject(storage, o)
    local sqo = StorageQualifiedObject:New(storage)
    o = o or {}
    setmetatable(sqo, o)
    o.__index = o
    return sqo
end

---@param itemId number
---@return string
function UTILS.GenerateItemLink(itemId)
    return string.format("item:%d:0:0:0:0:0:0:0:0:0:0:0:0", itemId)
end

---@param t table
---@param s table?
---@return table
function UTILS.Set(t, s)
    s = s or {}
    for _,v in pairs(t) do
        if v then
            s[v] = true end
        end
    return s
end

-- http://lua-users.org/wiki/CopyTable
---@param orig any
---@return any
function UTILS.ShallowCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- http://lua-users.org/wiki/CopyTable
---@param orig any
---@param copies table?
---@return any
function UTILS.DeepCopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[UTILS.DeepCopy(orig_key, copies)] = UTILS.DeepCopy(orig_value, copies)
            end
            setmetatable(copy, UTILS.DeepCopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

---@param object any
---@param objectType table
---@return boolean
function UTILS.typeof(object, objectType)
    if not object or not objectType then
        return false
    end
    if type(object) ~= "table" then
        return false
    end
    local mo = getmetatable(object)
    if not mo then
        return false
    end
    return (mo == objectType)
end
local typeof = UTILS.typeof

---@param object any
---@return boolean
function UTILS.empty(object)
    if object == "" or object == nil then
        return true
    end
    return false
end
---@param name string
---@return string
function UTILS.RemoveServer(name)
    name, _ = strsplit("-", name or "")
    return name
end
---@param name string
---@return string
function UTILS.GetServer(name)
    local _, server = strsplit("-", name or "")
    return (server or "")
end
local playerGUID = UnitGUID("player")
local getIntegerGuid, myRealmId

local normalizedRealmName
---@return string
function UTILS.GetNormalizedRealmName()
    normalizedRealmName = normalizedRealmName or GetNormalizedRealmName()
    return normalizedRealmName or ""
end

local _GetNormalizedRealmName = UTILS.GetNormalizedRealmName

---@param GUID string
---@return table
function UTILS.getIntegerGuid(GUID)
    local _, realm, int = strsplit("-", GUID)
    return {tonumber(realm, 10), tonumber(int, 16)}
end
getIntegerGuid = UTILS.getIntegerGuid
myRealmId = unpack(getIntegerGuid(playerGUID), 1)
---@param iGUID table
---@return string
function UTILS.getGuidFromInteger(iGUID)
    return string.format("Player-%d-%08X", iGUID[1], iGUID[2])
end
---@param iGUID any
---@return boolean
function UTILS.ValidateIntegerGUID(iGUID)
    if type(iGUID) ~= "table" then return false end
    for i=1,2 do if type(iGUID[i]) ~= "number" then return false end end
    return true
end
---@param name string
---@return string
function UTILS.Disambiguate(name)
    if string.find(name, "-") == nil then
        name = name .. "-" .. _GetNormalizedRealmName()
    end
    return name
end
---@param e Profile|string|number
---@return table|nil
function UTILS.GetGUIDFromEntry(e)
    if typeof(e, CLM.MODELS.Profile) then
        return getIntegerGuid(e:GUID())
    elseif type(e) == "string" then
        return getIntegerGuid(e)
    elseif type(e) == "number" then
        return {myRealmId, e}
    else
        return nil
    end
end
---@param playerA string
---@param playerB string
---@return boolean
function UTILS.ArePlayersCrossRealm(playerA, playerB)
    return UTILS.GetServer(playerA) ~= UTILS.GetServer(playerB)
end

local GetGUIDFromEntry = UTILS.GetGUIDFromEntry

local Disambiguate = UTILS.Disambiguate
---@param unit string
---@return string
function UTILS.GetUnitName(unit)
    local name = GetUnitName(unit, true)
    return Disambiguate(name or "")
end

do
    local playerFullName
    ---@return string
    function UTILS.whoami()
        if not playerFullName then
            playerFullName = UTILS.GetUnitName("player")
        end
        return playerFullName
    end
end
---@return string
function UTILS.whoamiGUID()
    return playerGUID
end

do
    local playerFaction
    ---@return string
    function UTILS.MyFaction()
        if not playerFaction then
            playerFaction = UnitFactionGroup("player")
        end
        return playerFaction
    end
end

---@param target string
---@return boolean
function UTILS.IsTargetCrossFaction(target)
    local targetFaction = UnitFactionGroup(target)
    if targetFaction == "" or not targetFaction then return false end -- We do not want false positives
    return UnitFactionGroup(target) ~= UTILS.MyFaction()
end

---@param playerList table
---@return table
function UTILS.CreateGUIDList(playerList)
    local playerGUIDList = {}
    local GUID
    -- We expect list of either: GUID in string/integer form or profile
    -- List is expected always
    for _, p in ipairs(playerList) do
        GUID = GetGUIDFromEntry(p)
        if GUID ~= nil then
            playerGUIDList[#playerGUIDList+1] = GUID
        end
    end
    return playerGUIDList
end

---@param t table
function UTILS.DumpTable(t)
    return DumpTable(t)
end

---@param object table
---@param data table
function UTILS.inflate(object, data)
    for i, key in ipairs(object:fields(data.v)) do
        object[key] = data[i]
    end
end

---@param object table
---@param version? number
---@return table
function UTILS.deflate(object, version)
    local result = {}
    for _, key in ipairs(object:fields(version)) do
        tinsert(result, object[key])
    end
    result.v = version
    return result
end

---@param object table
---@return table
function UTILS.keys(object)
    local keyList = {}
    local n = 0

    for k,_ in pairs(object) do
      n = n + 1
      keyList[n] = k
    end
    return keyList
end

---@param handler table
---@param method string
---@return function
function UTILS.method2function(handler, method)
    return (function(...) handler[method](handler, ...) end)
end

---@param t1 table
---@param t2 table
---@param t table?
---@return table
function UTILS.mergeLists(t1, t2, t)
    t = t or {}
    local n = 0
    for _,v in ipairs(t1) do n = n+1; t[n] = v end
    for _,v in ipairs(t2) do n = n+1; t[n] = v end
    return t
end

---@param t1 table
---@param t2 table
---@param t table?
---@return table
function UTILS.mergeDicts(t1, t2, t)
    t = t or {}
    for k,v in pairs(t1) do t[k] = v end
    for k,v in pairs(t2) do t[k] = v end
    return t
end

---@param t table
---@param s table
function UTILS.mergeDictsInline(t, s)
    for k,v in pairs(s) do t[k] = v end
end

---@param string string
---@return string
function UTILS.capitalize(string)
    return capitalize(string)
end

---@param list table?
---@return string
function UTILS.stringifyList(list)
    if not list then return "" end
    local string = ""
    for _,v in ipairs(list) do
        string = string .. tostring(v) .. ", "
    end
    return string:sub(1, -3)
end

---@param dict table?
---@return string
function UTILS.stringifyDict(dict)
    if not dict then return "" end
    local string = ""
    for k,v in pairs(dict) do
        string = string .. tostring(k) .. ": " .. tostring(v) .. ", "
    end
    return string:sub(1, -3)
end

---@param frame Frame
---@param name string
function UTILS.MakeFrameCloseOnEsc(frame, name)
    _G[name] = frame
    tinsert(UISpecialFrames, name)
end

---@return number
function UTILS.GetCutoffTimestamp()
    -- 25 Aug 2019 00:00:00 small bit before Wow Classic release Time
    return 1566684000
end

local function defaultDataProvider(param)
    return param
end

---@param data table
---@param tooltip table
---@param inLine number?
---@param max number?
---@param dataProvider function?
---@param autoWrap boolean?
function UTILS.putListInTooltip(data, tooltip, inLine, max, dataProvider, autoWrap)
    dataProvider = dataProvider or defaultDataProvider
    inLine = inLine or 5
    max = max or 25
    local entriesInLine = 0
    local line = ""
    local separator = ", "
    local numEntries = #data
    local entriesLeft
    local notIncludedEntries = 0
    if numEntries > max then
        notIncludedEntries = numEntries - max
        numEntries = max
    end
    entriesLeft = numEntries

    while (entriesLeft > 0) do
        local currentEntry = data[numEntries - entriesLeft + 1]
        entriesLeft = entriesLeft - 1
        if entriesLeft == 0 then
            separator = ""
        end
        line = line .. dataProvider(currentEntry).. separator
        entriesInLine = entriesInLine + 1
        if entriesInLine >= inLine or entriesLeft == 0 then
            tooltip:AddLine(line, nil, nil, nil, autoWrap and true or false)
            line = ""
            entriesInLine = 0
        end
    end

    if notIncludedEntries > 0 then
        tooltip:AddLine(notIncludedEntries .. CLM.L[" more"], nil, nil, nil, autoWrap and true or false)
    end
end

local function profileListTooltipDataProvider(profile)
    return ColorCodeText(profile:ShortName(), GetClassColor(profile:Class()).hex)
end

local putListInTooltip = UTILS.putListInTooltip
---@param profiles table
---@param tooltip table
function UTILS.buildPlayerListForTooltip(profiles, tooltip)
    return putListInTooltip(profiles, tooltip, 5, 25, profileListTooltipDataProvider, false)
end

---@param unixtimestamp number
---@param offset number?
---@return number
function UTILS.WeekNumber(unixtimestamp, offset)
    offset = offset or 0
    local week = 1 + math.floor((unixtimestamp - offset) / 604800)
    if week < 1 then week = 1 end
    return week
end

---@param week number
---@param offset number?
---@return number
function UTILS.WeekStart(week, offset)
    return ((week * 604800) + (offset or 0))
end

---@param number number
---@param decimals number?
---@return number
function UTILS.round(number, decimals)
    local factor = 10 ^ (decimals or 0)
    return math.floor(number * factor + 0.5) / factor
end

---@param text table
---@return boolean
function UTILS.IsTooltipTextRed(text)
    if text and text:GetText() then
        local r,g,b = text:GetTextColor()
        return math.floor(r*256) >= 255 and math.floor(g*256) == 32 and math.floor(b*256) == 32
    end
    return false
end

---@param text string?
---@return string
function UTILS.Trim(text)
    text = text or ""
    return (string.gsub(text, "^[%s,]*(.-)[%s,]*$", "%1"))
end

-- Convert version string to number for comparision (e.g., "v2.5.4" to "20504")
function UTILS.VersionStringToNumber(s)
    local version = UTILS.ParseVersionString(s)
    return version.major*10000 + version.minor*100 + version.patch
end

function UTILS.OnePassRemove(t, fnKeep)
    local j, n = 1, #t;
    fnKeep = fnKeep or (function(tab, idx)
        return tab[idx] ~= nil
    end)
    for i=1,n do
        if (fnKeep(t, i, j)) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end

    return t;
end

-- https://stackoverflow.com/a/32660766
function UTILS.TableCompare(o1, o2, check_mt)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    if check_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}

    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or UTILS.TableCompare(value1, value2, check_mt) == false then
            return false
        end
        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then return false end
    end
    return true
end

function UTILS.DictNotEmpty(dict)
    return not rawequal(next(dict), nil)
end

local invtypeClassWorkaround = {
    [2] = {
        [3] = "INVTYPE_RANGED", -- Weapon Guns
        [18] = "INVTYPE_RANGED",-- Weapon Crossbow
    },
}

local invtypeEquipLocWorkaround = {
    ["INVTYPE_NON_EQUIP_IGNORE"] = "INVTYPE_NON_EQUIP"
}


function UTILS.WorkaroundEquipLoc(class, subclass, equipLoc)
    local classTable = invtypeClassWorkaround[class] or {}
    local tempEquipLoc = classTable[subclass] or equipLoc
    return invtypeEquipLocWorkaround[tempEquipLoc] or tempEquipLoc
end


function UTILS.assertTypeof(object, objectType)
    if not typeof(object, objectType) then
        error("Unexpected object type", 2)
    end
end

function UTILS.assertType(object, objectType)
    if type(object) ~= objectType then
        error("Unexpected object type", 2)
    end
end

function UTILS.Saturate(value, low, high)
    if value <= low then return low end
    if value >= high then return high end
    return value
end

local defaultCharset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 -_=[];:<>,.?"
function UTILS.randomString(length, customCharset)
    local charset = customCharset or defaultCharset
    local charsetLength = #charset
    local result = ""
    while #result < length do
        local char = math.random(1, charsetLength)
        result = result .. strsub(charset, char, char)
    end
    return result
end

function UTILS.GetAuctionConditionalFieldName(key, auction, prefix, suffix)
    local name
    prefix = prefix or "["
    suffix = suffix or "]"
    if auction then
        name = auction:GetFieldName(key)
        if name == "" then name = nil end
    end
    if not name then
        name = prefix .. CONSTANTS.SLOT_VALUE_TIERS_GUI[key] .. suffix
    end
    return name
end

function UTILS.GetRosterConditionalFieldName(key, roster, prefix, suffix)
    local name
    prefix = prefix or "["
    suffix = suffix or "]"
    if roster then
        name = roster:GetFieldName(key)
        if name == "" then name = nil end
    end
    if not name then
        name = prefix .. CONSTANTS.SLOT_VALUE_TIERS_GUI[key] .. suffix
    end
    return name
end

---@param changeType number
---@return string
function UTILS.DecodePointTypeChangeName(changeType)
    if changeType == CONSTANTS.POINT_CHANGE_TYPE.SPENT then
        return CLM.L["GP"]
    elseif changeType == CONSTANTS.POINT_CHANGE_TYPE.POINTS then
        return CLM.L["BP"]
    end
    return CLM.L["BP/GP"]
end

--------------------------
--- Midnight restrictions ---
--------------------------
-- Secret values (12.x): opaque values the addon may not compare, index or parse
---@param value any
---@return boolean
function UTILS.IsSecret(value)
    return (issecretvalue ~= nil) and issecretvalue(value) and true or false
end

-- Chat lockdown (12.x): chat can't be sent, e.g. during encounters
---@return boolean
function UTILS.InChatLockdown()
    return (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) and true or false
end

-- Addon messages are blocked during encounters too; queue instead of losing them
---@return boolean
function UTILS.InAddonMessageLockdown()
    return UTILS.InChatLockdown() or (IsEncounterInProgress and IsEncounterInProgress()) or false
end

-- Runs flushFn every second until it returns true (queue empty)
---@param flushFn function
---@return function start
function UTILS.NewRetryQueue(flushFn)
    local ticker
    return function()
        if ticker then return end
        ticker = C_Timer.NewTicker(1, function()
            if flushFn() then
                ticker:Cancel()
                ticker = nil
            end
        end)
    end
end

local SendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
local CHAT_QUEUE_MAX_AGE = 30 -- seconds; older messages (e.g. countdowns) are no longer useful
local raidChannels = UTILS.Set({"RAID", "RAID_WARNING"})
local chatQueue = {}

local function SendChatNow(message, channel, target)
    if raidChannels[channel] and not IsInRaid() then return end
    SendChat("[BPGP] " .. tostring(message), channel, nil, target)
end

local startChatQueue = UTILS.NewRetryQueue(function()
    if UTILS.InChatLockdown() then return false end
    local now = GetTime()
    for _, queued in ipairs(chatQueue) do
        if now - queued.time <= CHAT_QUEUE_MAX_AGE then
            SendChatNow(queued.message, queued.channel, queued.target)
        end
    end
    wipe(chatQueue)
    return true
end)

function UTILS.SendChatMessage(message, channel, _, target)
    if CLM.MODULES.Database:IsTestMode() then
        -- Test mode never sends chat; show what would have been sent
        CLM.LOG:Message("|cffff8000[TEST]|r %s%s: %s", tostring(channel), target and (" " .. tostring(target)) or "", tostring(message))
        return
    end
    if UTILS.InChatLockdown() then
        tinsert(chatQueue, { message = message, channel = channel, target = target, time = GetTime() })
        startChatQueue()
        return
    end
    SendChatNow(message, channel, target)
end

------------------------
--- Retail API wrappers ---
------------------------
local GetItemInfo = C_Item.GetItemInfo
function UTILS.GetItemInfo(...)
    return GetItemInfo(...)
end

local GetItemInfoInstant = C_Item.GetItemInfoInstant
function UTILS.GetItemInfoInstant(...)
    return GetItemInfoInstant(...)
end

local GetItemQualityByID = C_Item.GetItemQualityByID
function UTILS.GetItemQualityByID(...)
    return (GetItemQualityByID(...) or 0)
end

local GetAddOnInfo = C_AddOns.GetAddOnInfo
function UTILS.GetAddOnInfo(...)
    return GetAddOnInfo(...)
end

local GetContainerNumSlots = C_Container.GetContainerNumSlots
function UTILS.GetContainerNumSlots(...)
    return GetContainerNumSlots(...)
end

local UseContainerItem = C_Container.UseContainerItem
function UTILS.UseContainerItem(...)
    return UseContainerItem(...)
end

local GetLootMethod = C_PartyInfo.GetLootMethod
function UTILS.GetLootMethod()
    return GetLootMethod()
end

local lootMasterMethods = UTILS.Set({"master"})
local groupLootMethods = UTILS.Set({"group"})

if Enum.LootMethod then
    UTILS.Set({Enum.LootMethod.Masterlooter}, lootMasterMethods)
    UTILS.Set({Enum.LootMethod.Group}, groupLootMethods)
end

function UTILS.IsLootMasterLootMethod()
    return lootMasterMethods[UTILS.GetLootMethod()]
end

function UTILS.IsGroupLootMethod()
    return groupLootMethods[UTILS.GetLootMethod()]
end
-----------------
--- CONSTANTS ---
-----------------

CONSTANTS.ITEM_QUALITY = {
    [0] = ColorCodeText(CLM.L["Poor"], "9d9d9d"),
    [1] = ColorCodeText(CLM.L["Common"], "ffffff"),
    [2] = ColorCodeText(CLM.L["Uncommon"], "1eff00"),
    [3] = ColorCodeText(CLM.L["Rare"], "0070dd"),
    [4] = ColorCodeText(CLM.L["Epic"], "a335ee"),
    [5] = ColorCodeText(CLM.L["Legendary"], "ff8000"),
}
CONSTANTS.LOOT_ROLL_TYPE_ANY = -2
CONSTANTS.LOOT_ROLL_TYPE_IGNORE = -1
CONSTANTS.LOOT_ROLL_TYPE_TRANSMOG = 4
CONSTANTS.ROLL_TYPE = {
    [CONSTANTS.LOOT_ROLL_TYPE_ANY]      = ColorCodeText(CLM.L["Any"], "ff8000"),
    [CONSTANTS.LOOT_ROLL_TYPE_IGNORE]   = ColorCodeText(CLM.L["Do Nothing"], "9d9d9d"),
    [LOOT_ROLL_TYPE_PASS]               = PASS,
    [LOOT_ROLL_TYPE_NEED]               = ColorCodeText(NEED, "1eff00"),
    [LOOT_ROLL_TYPE_GREED]              = ColorCodeText(GREED , "ffd100"),
}
CONSTANTS.ROLL_TYPE[LOOT_ROLL_TYPE_DISENCHANT] = ColorCodeText(ROLL_DISENCHANT, "0070dd")
CONSTANTS.ROLL_TYPE[CONSTANTS.LOOT_ROLL_TYPE_TRANSMOG] = ColorCodeText(TRANSMOGRIFICATION or "Transmogrification", "a335ee")

CONSTANTS.REGEXP_FLOAT = "^-?%d+%.?%d*$"
CONSTANTS.REGEXP_FLOAT_POSITIVE = "^%d+%.?%d*$"
