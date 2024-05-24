-- pooffactorylogic.lua
local AIUtils = import('/lua/ai/aiutilities.lua')
local Game = import("/lua/game.lua")
local Utilities = import('/mods/PoofAI/lua/AI/poofUtilities.lua')

function GetBlueprintThatCanBuildOfCategory(aiBrain, iCategoryCondition, oFactory)
    return Utilities.GetBlueprintThatCanBuildOfCategory(aiBrain, iCategoryCondition, oFactory)
end

-- Function to determine strategic unit needs
function DetermineUnitNeeds(aiBrain)
    local armyStartPos = aiBrain:GetArmyStartPos()
    local airThreat = aiBrain:GetThreatAtPosition(armyStartPos, 1, true, 'AntiAir')
    local landThreat = aiBrain:GetThreatAtPosition(armyStartPos, 1, true, 'Land')
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
    local engineerCap = 6  -- Set a cap for engineers
    LOG('Current number of engineers: ' .. numEngineers)

    if numEngineers < engineerCap then
        local engineerBlueprint = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.ENGINEER, factory)
        if engineerBlueprint then
            LOG('Building more engineers up to cap.')
            for i = numEngineers + 1, engineerCap do
                aiBrain:BuildUnit(factory, engineerBlueprint, 1)
            end
        else
            LOG('No engineer blueprint available.')
        end
    else
        LOG('Engineer cap reached, assessing other unit needs.')
        local needAir, needLand = DetermineUnitNeeds(aiBrain)
        local unitCategory = needAir and categories.AIR * categories.MOBILE or needLand and categories.LAND * categories.MOBILE or categories.MOBILE
        local blueprintToBuild = GetBlueprintThatCanBuildOfCategory(aiBrain, unitCategory, factory)
        if blueprintToBuild then
            aiBrain:BuildUnit(factory, blueprintToBuild, 1)
            LOG('Building unit of category based on strategic needs: ' .. tostring(unitCategory))
        else
            LOG('No suitable blueprint found for requested unit type.')
        end
    end
end
