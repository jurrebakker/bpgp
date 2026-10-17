
local Factory, _ = LibStub:NewLibrary("BPGP-EventSourcing/IgnoreEntry", 1)
if not Factory then
    return
end

local LogEntry = LibStub("BPGP-EventSourcing/LogEntry")
local IgnoreEntry = LogEntry:extend('IGN')

function IgnoreEntry:new(entry, creator, counter)
    local o = LogEntry.new(self, creator)
    o.ref = entry:uuid()
    o:setTime(entry:time())
    o:setCounter(counter)
    return o
end

function IgnoreEntry:fields()
    local result = LogEntry:fields()
    table.insert(result, 'ref')
    return result
end

function Factory.create(entry, creator, counter)
    return IgnoreEntry:new(entry, creator, counter)
end

function Factory.class()
    return IgnoreEntry
end
