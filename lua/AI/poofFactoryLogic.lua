-- poofFactoryLogic.lua
-- Import necessary base libraries and utilities
local AIUtils = import('/lua/ai/aiutilities.lua')
local Game = import("/lua/game.lua")


function GetBlueprintThatCanBuildOfCategory(aiBrain, iCategoryCondition, oFactory)
    local tBlueprints = EntityCategoryGetUnitList(iCategoryCondition)
    local tValidBlueprints = {}
    local iValidBlueprints = 0

    if oFactory.CanBuild then
        local Game = import("/lua/game.lua")
        local iArmyIndex = aiBrain:GetArmyIndex()
        for _, sBlueprint in tBlueprints do
            if oFactory:CanBuild(sBlueprint) == true and not(Game.IsRestricted(sBlueprint, iArmyIndex)) then
                iValidBlueprints = iValidBlueprints + 1
                tValidBlueprints[iValidBlueprints] = sBlueprint
            end
        end
        if iValidBlueprints > 0 then
            local iBPToBuild = math.random(1, iValidBlueprints)
            return tValidBlueprints[iBPToBuild]
        end
    end
    return nil
end

-- Function to determine strategic unit needs
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
-- poofFactoryLogic.lua
function BuildFactoryUnit(factory)
    local aiBrain = factory:GetAIBrain()
    local numEngineers = aiBrain:GetCurrentUnits(categories.ENGINEER)
    local engineerCap = 5  -- Set a cap for engineers
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

