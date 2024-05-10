local BaseGameCreateResourceDeposit = CreateResourceDeposit
local poofMap = import('/mods/PoofAI/lua/AI/poofMap.lua')

CreateResourceDeposit = function(t,x,y,z,size)
    BaseGameCreateResourceDeposit(t,x,y,z,size)
    ForkThread(poofMap.RecordResourcePoint,t,x,y,z,size)
end