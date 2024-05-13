-- Import necessary modules
Map = import('/mods/PoofAI/lua/AI/poofMap.lua')
Utilities = import('/mods/PoofAI/lua/AI/poofUtilities.lua')

resourcePoints = {}

function InitializeResourcePoints()
    for _, point in ipairs(Map.tMassPoints) do
        table.insert(resourcePoints, {
            x = point[1],
            y = point[2],
            z = point[3],
            status = "available"  -- Initial status of each point
        })
    end
    LOG("Resource points initialized.")
end

-- Call this function after all modules are imported and ready
ForkThread(function()
    WaitSeconds(5)  -- Simulated delay
    InitializeResourcePoints()
end)

function AssignTasksToEngineers(oUnit)
    local aiBrain = oUnit:GetAIBrain()
    local currentPos = oUnit:GetPosition()
    local x, y, z = currentPos[1], currentPos[2], currentPos[3]

    LOG("Engineer Position: x=" .. x .. ", z=" .. z)

    local energyIncome = aiBrain:GetEconomyIncome('ENERGY')
    local massIncome = aiBrain:GetEconomyIncome('MASS')
    local energyUsage = aiBrain:GetEconomyUsage('ENERGY')
    local massUsage = aiBrain:GetEconomyUsage('MASS')
    local energyStoredRatio = aiBrain:GetEconomyStoredRatio('ENERGY')
    local massStoredRatio = aiBrain:GetEconomyStoredRatio('MASS')
    local energyTrend = aiBrain:GetEconomyTrend('ENERGY')
    local massTrend = aiBrain:GetEconomyTrend('MASS')

    LOG("Economic Report: Energy Income=" .. energyIncome .. ", Mass Income=" .. massIncome)

    local closestPoint = nil
    local minDist = math.huge

    -- Check each point's availability and distance
    for index, point in ipairs(resourcePoints) do
        if point.status == "available" then
            local dist = VDist2(x, z, point.x, point.z)
            LOG("Checking Point " .. index .. ": (" .. point.x .. ", " .. point.z .. "), Distance=" .. dist)
            if dist < minDist then
                minDist = dist
                closestPoint = point
                LOG("New Closest Point: (" .. point.x .. ", " .. point.z .. "), Distance=" .. dist)
            end
        end
    end

    -- Try to initiate building at the closest point found
    if closestPoint then
        local position = {closestPoint.x, 0, closestPoint.z}
        LOG("Found Closest Point: X=" .. position[1] .. " Z=" .. position[3])
        local massExtractorBlueprint = Utilities.GetBlueprintThatCanBuildOfCategory(aiBrain, categories.MASSEXTRACTION * categories.TECH1, oUnit)
    if massExtractorBlueprint then
        LOG("Blueprint obtained for Mass Extractor: " .. massExtractorBlueprint)
    else
        LOG("Failed to obtain Blueprint for Mass Extractor")
    end

    LOG("Attempting to Build Mass Extractor at: X=" .. position[1] .. ", Z=" .. position[3])
    if Utilities.CanBuildAt(aiBrain, massExtractorBlueprint, position) then
        LOG("Can build at the location. Initiating build command.")
        Utilities.AttemptToBuild(aiBrain, oUnit, massExtractorBlueprint, position)
        closestPoint.status = "assigned"
        LOG("Building Initiated for Mass Extractor at: X=" .. position[1] .. ", Z=" .. position[3])
    else
        LOG("CanBuildAt Check Failed at: X=" .. position[1] .. ", Z=" .. position[3] .. " - Possible terrain issue or blueprint mismatch.")
    end
else
    LOG("No available mass points found or all are assigned.")
end

    -- Energy Production Building Logic based on economic conditions
    if aiBrain:GetEconomyStoredRatio('ENERGY') < 0.5 or aiBrain:GetEconomyIncome('ENERGY') < aiBrain:GetEconomyUsage('ENERGY') then
        local offsetPosition = {x + 20, 0, z + 20}  -- Slightly further to prevent overlap
        local energyProductionBlueprint = Utilities.GetBlueprintThatCanBuildOfCategory(aiBrain, categories.ENERGYPRODUCTION * categories.TECH1, oUnit)
        if energyProductionBlueprint and Utilities.CanBuildAt(aiBrain, energyProductionBlueprint, offsetPosition) then
            Utilities.AttemptToBuild(aiBrain, oUnit, energyProductionBlueprint, offsetPosition)
            LOG("AssignTasksToEngineers: Building energy production at (" .. offsetPosition[1] .. ", " .. offsetPosition[3] .. ")")
        else
            LOG("AssignTasksToEngineers: Cannot build energy production; position may be blocked or not on navigable terrain.")
        end
    else
        LOG("AssignTasksToEngineers: Current energy conditions do not require building new energy production.")
    end
end