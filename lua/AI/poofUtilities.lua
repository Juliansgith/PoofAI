local AIUtils = import('/lua/ai/aiutilities.lua')
local Game = import("/lua/game.lua")
local Utils = import('/lua/utilities.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')

function GetBlueprintThatCanBuildOfCategory(aiBrain, iCategoryCondition, unit)
    local tBlueprints = EntityCategoryGetUnitList(iCategoryCondition)
    local tValidBlueprints = {}
    local iValidBlueprints = 0

    if unit.CanBuild then
        for _, sBlueprint in tBlueprints do
            if unit:CanBuild(sBlueprint) then
                iValidBlueprints = iValidBlueprints + 1
                tValidBlueprints[iValidBlueprints] = sBlueprint
            end
        end
        if iValidBlueprints > 0 then
            return tValidBlueprints[math.random(1, iValidBlueprints)]  
        end
    end
    return nil
end

function CanBuildAt(aiBrain, blueprint, position)
    return aiBrain:CanBuildStructureAt(blueprint, position)
end

function AttemptToBuild(aiBrain, unit, blueprintID, position)
    if blueprintID == nil then
        LOG("AttemptToBuild failed: blueprintID is nil")
        return
    end

    -- Check if position is correctly formatted as a table with three elements
    local positionValid = type(position) == 'table' and table.getn(position) == 3

    if not positionValid then
        LOG("AttemptToBuild failed: Invalid position format - ", repr(position))
        return
    end

    if aiBrain:CanBuildStructureAt(blueprintID, position) then
        IssueBuildMobile({unit}, position, blueprintID, {})
        LOG("Building initiated at: ", repr(position))
    else
        LOG("Cannot build at: ", repr(position), " - Location not valid.")
    end
end

