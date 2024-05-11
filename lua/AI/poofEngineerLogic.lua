-- EngineerLogic.lua
local AIUtils = import('/lua/ai/aiutilities.lua')
local Game = import("/lua/game.lua")
local Utils = import('/lua/utilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local MapData = import('/mods/PoofAI/lua/AI/poofMap.lua')  -- Import module that contains map-related data and functions

-- Store mass points considered dangerous due to enemy presence
local enemyNearbyMassPoints = {}

-- Get a blueprint that can build specific categories, ensuring that the selected blueprint is not restricted
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
            return tValidBlueprints[math.random(1, iValidBlueprints)]  -- Randomly select a blueprint to build
        end
    end
    return nil
end
-- Assign tasks to engineers based on current needs and priorities
function AssignTasksToEngineers(oUnit)
    local aiBrain = oUnit:GetAIBrain()
    LOG("Assigning tasks to engineer: " .. oUnit:GetEntityId())

    -- Retrieve a list of engineers
    local engineers = aiBrain:GetListOfUnits(categories.ENGINEER, false)
    for _, engineer in engineers do
        if not engineer:IsCommandActive() then  -- Check if the engineer has no active commands before assigning tasks
            HandleMassExtraction(engineer, aiBrain)
        end
    end
end

-- Check the current energy status to prioritize energy production if necessary
function CheckEnergyStatus(aiBrain)
    local currentEnergy = aiBrain:GetEconomyStoredRatio('ENERGY')
    return currentEnergy <= 0.1
end

-- Build energy structures if the energy status is low
function BuildEnergyStructures(engineer, aiBrain)
    local buildLocation = engineer:GetPosition()  -- Simplified: should ideally find a suitable location
    IssueClearCommands({engineer})  -- Clear any existing commands
    local blueprintId = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.ENERGYPRODUCTION, engineer)
    if blueprintId then
        LOG('Attempting to build energy structure: Blueprint ID ' .. blueprintId)
        local success = IssueBuildMobile({engineer}, buildLocation, blueprintId)
        if success then
            LOG('Build command issued successfully.')
        else
            LOG('Failed to issue build command.')
        end
    else
        LOG('No valid blueprint found for energy structures.')
    end
end

function HandleMassExtraction(engineer, aiBrain)
    local massPoints = MapData.GetMassPoints()  -- Ensure this is correctly implemented to retrieve mass points
    local closestPoint = nil
    local minDist = math.huge
    local engineerPos = engineer:GetPosition()

    for _, point in pairs(massPoints) do
        local dist = VDist2(engineerPos[1], engineerPos[3], point[1], point[3])
        if dist < minDist then
            closestPoint = {point[1], GetTerrainHeight(point[1], point[3]), point[3]}
            minDist = dist
        end
    end

    if closestPoint then
        local blueprintId = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.MASSEXTRACTION, engineer)
        if blueprintId then
            LOG('Sending engineer to build at closest mass point: ' .. repr(closestPoint))
            IssueClearCommands({engineer})
            local success = IssueBuildMobile({engineer}, closestPoint, blueprintId)
            if success then
                LOG('Build command issued successfully at ' .. tostring(closestPoint))
            else
                LOG('Failed to issue build command at ' .. tostring(closestPoint))
            end
        else
            LOG('No valid blueprint found for mass extraction.')
        end
    else
        LOG('No mass points available or suitable for building.')
    end
end




-- Optional function to check and disrupt enemy mass extraction
function CheckEnemyMassExtractors(engineer, aiBrain)
    -- This function would contain logic similar to HandleMassExtraction but targeting enemy controlled areas
end

-- Assign other maintenance or assist tasks to engineers not assigned to critical building tasks
function AssignOtherTasks(engineer, aiBrain)
    -- This function could assign engineers to assist with factory production or perform repairs
end
