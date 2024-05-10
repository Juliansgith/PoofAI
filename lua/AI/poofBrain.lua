local StandardBrain = import("/lua/aibrain.lua").AIBrain
local poofMap = import('/mods/PoofAI/lua/AI/poofMap.lua')
local ACULogic = import('/mods/PoofAI/lua/AI/poofACULogic.lua')
local FactoryLogic = import('/mods/PoofAI/lua/AI/poofFactoryLogic.lua')

NewAIBrain = Class(StandardBrain) {
    -- Initial setup
    OnBeginSession = function(self)
        StandardBrain.OnBeginSession(self)
        self.poofAI = true
        ForkThread(poofMap.SetupMap, self)
    end,

    OnDefeat = function(self)
        StandardBrain.OnDefeat(self)
    end,

    OnCreateAI = function(self, planName)
        StandardBrain.OnCreateAI(self, planName)
        -- Custom initialization can go here
    end,

    -- Example of overriding a method to include custom logic
    OnUnitIdle = function(self, unit)
        -- Check unit type and apply logic
        if unit:GetBlueprint().CategoriesHash.COMMAND then
            ACULogic.HandleACU(self, unit)
        elseif unit:GetBlueprint().CategoriesHash.FACTORY then
            FactoryLogic.BuildFactoryUnit(unit)
        end

        -- Call the base class version if needed
        StandardBrain.OnUnitIdle(self, unit)
    end,
}
