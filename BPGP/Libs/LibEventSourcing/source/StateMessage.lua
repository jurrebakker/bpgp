local Factory, _ = LibStub:NewLibrary("BPGP-EventSourcing/Message/State", 1)
if not Factory then
    return
end


local Message = LibStub("BPGP-EventSourcing/Message")
local Util = LibStub("BPGP-EventSourcing/Util")
local StateMessage = Message:extend('STATE')

function StateMessage:new(stateHash, count, lag)
    local o = Message.new(self)
    Util.assertNumber(stateHash, 'stateHash')
    Util.assertNumber(count, 'count')
    Util.assertNumber(lag, 'lag')
    o.stateHash = stateHash
    o.totalEntryCount = count
    o.lag = lag
    return o
end


function Factory.create(...)
    return StateMessage:new(...)
end

function Factory.type()
    return StateMessage._type
end
