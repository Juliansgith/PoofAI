-- poofFactoryLogic.lua
-- Import necessary base libraries and utilities
local AIUtils = import('/lua/ai/aiutilities.lua')

-- Helper function to determine unit needs
function DetermineUnitNeeds(aiBrain)
    local airThreat = aiBrain:GetThreatAtPosition(aiBrain:GetArmyStartPos(), 1, true, 'AntiAir')
    local landThreat = aiBrain:GetThreatAtPosition(aiBrain:GetArmyStartPos(), 1, true, 'Land')
    local needAir = airThreat > landThreat
    local needLand = landThreat > airThreat
    return needAir, needLand
end

-- Generic unit builder that can be used for any builder type
function BuildUnit(builder, unitType)
    local aiBrain = builder:GetAIBrain()
    local blueprintToBuild = AIUtils.AIFindUnitToBuild(builder, unitType)

    if blueprintToBuild then
        aiBrain:BuildUnit(builder, blueprintToBuild, 1)
    else
        WARN('No suitable blueprint found for requested unit type: ' .. tostring(unitType))
    end
end

-- Specific factory unit builder that uses strategic needs and prioritizes engineers
function BuildFactoryUnit(factory)
    local aiBrain = factory:GetAIBrain()
    local numEngineers = aiBrain:GetCurrentUnits(categories.ENGINEER)

    -- Ensure a minimum of 5 engineers at all times
    if numEngineers < 5 then
        local engineerBlueprint = AIUtils.AIFindUnitToBuild(factory, categories.ENGINEER)
        if engineerBlueprint then
            for i = numEngineers + 1, 5 do
                aiBrain:BuildUnit(factory, engineerBlueprint, 1)
            end
        else
            WARN('No engineer blueprint available')
        end
    else
        -- Proceed with normal unit production logic based on strategic needs
        local needAir, needLand = DetermineUnitNeeds(aiBrain)
        local unitCategory = needAir and categories.AIR * categories.MOBILE or needLand and categories.LAND * categories.MOBILE or categories.MOBILE
        BuildUnit(factory, unitCategory)
    end
end
