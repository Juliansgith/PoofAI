-- EngineerLogic.lua
local AIUtils = import('/lua/ai/aiutilities.lua')
local Game = import("/lua/game.lua")
local Utils = import('/lua/utilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local MapData = import('/mods/PoofAI/lua/AI/poofMap.lua')  -- Assuming this contains map-related data and functions

-- Store mass points considered dangerous due to enemy presence
local enemyNearbyMassPoints = {}

function AssignTasksToEngineers(aiBrain)
    local engineers = aiBrain:GetListOfUnits(categories.ENGINEER, false)
    local numEngineers = table.getn(engineers)

    -- Determine the number of engineers for each task
    local numForMassExtraction = math.ceil(numEngineers * 0.30)
    local numForCheckingEnemyExtractors = math.ceil(numEngineers * 0.05)

    -- Check energy status and assign tasks
    local energyStatus = CheckEnergyStatus(aiBrain)
    for i, engineer in ipairs(engineers) do
        if energyStatus then
            BuildEnergyStructures(engineer, aiBrain)
        elseif i <= numForMassExtraction then
            HandleMassExtraction(engineer, aiBrain)
        elseif i <= numForMassExtraction + numForCheckingEnemyExtractors then
            CheckEnemyMassExtractors(engineer, aiBrain)
        else
            -- Assign other tasks such as assisting factories or repairing
            AssignOtherTasks(engineer, aiBrain)
        end
    end
end

function CheckEnergyStatus(aiBrain)
    local currentEnergy = aiBrain:GetEconomyStoredRatio('ENERGY')
    return currentEnergy <= 0.1  -- Check if current stored energy ratio is 10% or less
end

function BuildEnergyStructures(engineer, aiBrain)
    local buildLocation = engineer:GetPosition()  -- Simplified: should ideally find a suitable location
    IssueClearCommands({engineer})  -- Clear any existing commands
    -- Assume blueprint ID for an energy structure, here using a UEF T1 Power Generator as an example
    IssueBuildMobile({engineer}, buildLocation, 'ueb1101')
end

function HandleMassExtraction(engineer, aiBrain)
    local massPoints = MapData.GetMassPoints() -- Function that returns all mass points on the map
    local closestPoint = nil
    local minDist = math.huge
    for _, point in pairs(massPoints) do
        if not enemyNearbyMassPoints[point] then  -- Check if point is not marked as dangerous
            local dist = Utils.VDist2(point[1], point[3], engineer:GetPosition()[1], engineer:GetPosition()[3])
            if dist < minDist then
                closestPoint = point
                minDist = dist
            end
        end
    end

    if closestPoint then
        IssueClearCommands({engineer})  -- Clear any existing commands
        IssueMove({engineer}, closestPoint)  -- Move to the mass point
        -- Assume function to build a mass extractor is something like this:
        IssueBuildMobile({engineer}, closestPoint, 'ueb1103')  -- UEF T1 Mass Extractor blueprint ID
    end
end

function CheckEnemyMassExtractors(engineer, aiBrain)
    -- Similar to HandleMassExtraction but checks for enemy extractors
end

function AssignOtherTasks(engineer, aiBrain)
    -- Logic for assigning non-extraction tasks to engineers
end
