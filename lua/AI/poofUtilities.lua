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
            local selectedBlueprint = tValidBlueprints[math.random(1, iValidBlueprints)]
            LOG("GetBlueprintThatCanBuildOfCategory: Found valid blueprint " .. selectedBlueprint)
            return selectedBlueprint  
        end
    end
    LOG("GetBlueprintThatCanBuildOfCategory: No valid blueprints found for category " .. tostring(iCategoryCondition))
    return nil
end

function CanBuildAt(aiBrain, blueprint, position)
    local positionStr = tostring(position[1]) .. ", " .. tostring(position[2]) .. ", " .. tostring(position[3])
    LOG("CanBuildAt: Checking Blueprint: " .. tostring(blueprint) .. ", Position: " .. positionStr)
    
    -- Add detailed position validation logs
    if not position or type(position) ~= "table" or table.getn(position) ~= 3 then
        LOG("CanBuildAt: Invalid position format - " .. repr(position))
        return false
    end
    
    local canBuild = aiBrain:CanBuildStructureAt(blueprint, position)
    LOG("CanBuildAt: Blueprint: " .. tostring(blueprint) .. ", Position: " .. positionStr .. ", Result: " .. tostring(canBuild))
    return canBuild
end


function AttemptToBuild(aiBrain, unit, blueprintID, position)
    if blueprintID == nil then
        LOG("AttemptToBuild failed: blueprintID is nil")
        return
    end

    local positionValid = type(position) == 'table' and table.getn(position) == 3

    if not positionValid then
        LOG("AttemptToBuild failed: Invalid position format - " .. repr(position))
        return
    end

    local positionStr = table.concat({tostring(position[1]), tostring(position[2]), tostring(position[3])}, ", ")

    if aiBrain:CanBuildStructureAt(blueprintID, position) then
        IssueBuildMobile({unit}, position, blueprintID, {})
        LOG("Building initiated at: " .. positionStr)
    else
        LOG("Cannot build at: " .. positionStr .. " - Location not valid.")
    end
end
