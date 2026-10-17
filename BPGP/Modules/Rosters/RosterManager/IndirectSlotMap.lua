local _, CLM = ...
---@cast CLM CLMNamespace

-- Items whose equip slot / item level can't be read from the item itself (tier tokens).
-- CLM shipped Wrath/Cata tokens here; retail has none we need yet.
---@class IndirectMap
---@field slot table<number, string> map from itemId to inventory type string
---@field ilvl table<number, number> map from itemId to item level
local IndirectMap = {
    slot = {},
    ilvl = {}
}
CLM.IndirectMap = IndirectMap
