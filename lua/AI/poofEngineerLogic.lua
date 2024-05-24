-- Import necessary modules
Map = import('/mods/PoofAI/lua/AI/poofMap.lua')
Utilities = import('/mods/PoofAI/lua/AI/poofUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local AIUtils = import('/lua/ai/aiutilities.lua')
local Game = import("/lua/game.lua")

resourcePoints = {}
massExtractorsBuilt = 0  -- Track the number of mass extractors built
radarBuilt = false       -- Track if the radar has been built

ForkThread(function()
    WaitSeconds(10)  -- Increase delay to ensure all points are recorded
    InitializeResourcePoints()
end)

function InitializeResourcePoints()
    resourcePoints = {}
    for _, point in ipairs(Map.tMassPoints) do
        table.insert(resourcePoints, {
            x = point[1],
            y = point[2],
            z = point[3],
            status = "available"  -- Initial status of each point
        })
    end
    LOG("Resource points initialized. Total points: " .. tostring(table.getn(resourcePoints)))
    for index, point in ipairs(resourcePoints) do
        LOG("Resource Point " .. index .. ": x=" .. point.x .. ", y=" .. point.y .. ", z=" .. point.z .. ", status=" .. point.status)
    end
end

function AssignTasksToEngineers(oUnit)
    local aiBrain = oUnit:GetAIBrain()
    LOG("Assigning tasks to engineer: " .. oUnit:GetEntityId())

    ForkThread(function()
        while true do
            if oUnit.Dead then
                LOG("Engineer " .. oUnit:GetEntityId() .. " is dead. Exiting task assignment loop.")
                return
            end
            
            if not radarBuilt and massExtractorsBuilt >= 2 then
                LOG("Engineer " .. oUnit:GetEntityId() .. ": Condition met for building radar.")
                BuildRadar(oUnit)
            elseif massExtractorsBuilt < 2 then
                LOG("Engineer " .. oUnit:GetEntityId() .. ": Condition met for building mass extractor.")
                BuildMassExtractor(oUnit)
            else
                LOG("Engineer " .. oUnit:GetEntityId() .. ": Condition met for building energy production.")
                BuildEnergyProduction(oUnit)
            end
            
            WaitSeconds(5)  -- Add a small delay between task checks to avoid overloading
        end
    end)
end

function BuildMassExtractor(oUnit)
    local aiBrain = oUnit:GetAIBrain()
    local tNearestMex, iNearestMexDist = GetNearestAvailableMexLocationAndDistance(oUnit)

    if tNearestMex then
        local position = {tNearestMex[1], 0, tNearestMex[3]}
        LOG("Engineer " .. oUnit:GetEntityId() .. " found closest mass point: X=" .. position[1] .. " Z=" .. position[3])

        for _, point in ipairs(resourcePoints) do
            if point.x == position[1] and point.z == position[3] then
                if point.status == "available" then
                    point.status = "assigned"
                    LOG("Engineer " .. oUnit:GetEntityId() .. " assigned point X=" .. position[1] .. " Z=" .. position[3])
                else
                    LOG("Engineer " .. oUnit:GetEntityId() .. " found point X=" .. position[1] .. " Z=" .. position[3] " but it was not available")
                    return
                end
                break
            end
        end

        local massExtractorBlueprint = Utilities.GetBlueprintThatCanBuildOfCategory(aiBrain, categories.MASSEXTRACTION * categories.TECH1, oUnit)

        if massExtractorBlueprint then
            LOG("Engineer " .. oUnit:GetEntityId() .. " obtained blueprint for Mass Extractor: " .. massExtractorBlueprint)
        else
            LOG("Engineer " .. oUnit:GetEntityId() .. " failed to obtain blueprint for Mass Extractor")
        end

        LOG("Engineer " .. oUnit:GetEntityId() .. " attempting to build Mass Extractor at: X=" .. position[1] .. ", Z=" .. position[3])

        if Utilities.CanBuildAt(aiBrain, massExtractorBlueprint, position) then
            LOG("Engineer " .. oUnit:GetEntityId() .. " can build at the location. Initiating build command.")
            for _, point in ipairs(resourcePoints) do
                if point.x == position[1] and point.z == position[3] then
                    if point.status == "assigned" then
                        Utilities.AttemptToBuild(aiBrain, oUnit, massExtractorBlueprint, position)
                        point.status = "unavailable"
                        massExtractorsBuilt = massExtractorsBuilt + 1
                        LOG("Engineer " .. oUnit:GetEntityId() .. " initiated building for Mass Extractor at: X=" .. position[1] .. ", Z=" .. position[3])
                    else
                        LOG("Engineer " .. oUnit:GetEntityId() .. " point became unavailable. Reassigning tasks.")
                        AssignTasksToEngineers(oUnit)
                    end
                    break
                end
            end
        else
            LOG("Engineer " .. oUnit:GetEntityId() .. " CanBuildAt check failed at: X=" .. position[1] .. ", Z=" .. position[3] .. " - Possible terrain issue or blueprint mismatch.")
            AssignTasksToEngineers(oUnit)
        end
    else
        LOG("Engineer " .. oUnit:GetEntityId() .. " no available mass points found or all are assigned.")
    end
end

function BuildEnergyProduction(oUnit)
    local aiBrain = oUnit:GetAIBrain()
    local currentPos = oUnit:GetPosition()
    local x, y, z = currentPos[1], currentPos[2], currentPos[3]

    if aiBrain:GetEconomyStoredRatio('ENERGY') < 0.5 or aiBrain:GetEconomyIncome('ENERGY') < aiBrain:GetEconomyUsage('ENERGY') then
        local offsetPosition = {x + 20, 0, z + 20}
        local energyProductionBlueprint = Utilities.GetBlueprintThatCanBuildOfCategory(aiBrain, categories.ENERGYPRODUCTION * categories.TECH1, oUnit)
        
        if energyProductionBlueprint then
            LOG("Engineer " .. oUnit:GetEntityId() .. " obtained blueprint for Energy Production: " .. energyProductionBlueprint)
            if Utilities.CanBuildAt(aiBrain, energyProductionBlueprint, offsetPosition) then
                Utilities.AttemptToBuild(aiBrain, oUnit, energyProductionBlueprint, offsetPosition)
                LOG("Engineer " .. oUnit:GetEntityId() .. " building energy production at (" .. offsetPosition[1] .. ", " .. offsetPosition[3] .. ")")
            else
                LOG("Engineer " .. oUnit:GetEntityId() .. " cannot build energy production; position may be blocked or not on navigable terrain.")
            end
        else
            LOG("Engineer " .. oUnit:GetEntityId() .. " failed to obtain blueprint for Energy Production")
        end
    else
        LOG("Engineer " .. oUnit:GetEntityId() .. " current energy conditions do not require building new energy production.")
    end
end

function BuildRadar(oUnit)
    if radarBuilt then
        LOG("Engineer " .. oUnit:GetEntityId() .. " radar already built. Exiting.")
        return
    end

    local aiBrain = oUnit:GetAIBrain()
    local currentPos = oUnit:GetPosition()
    local x, y, z = currentPos[1], currentPos[2], currentPos[3]

    local radarBlueprint = Utilities.GetBlueprintThatCanBuildOfCategory(aiBrain, categories.STRUCTURE * categories.RADAR, oUnit)
    
    if radarBlueprint then
        local radarPosition = {x + 10, 0, z + 10}
        LOG("Engineer " .. oUnit:GetEntityId() .. " obtained blueprint for Radar: " .. radarBlueprint)
        if Utilities.CanBuildAt(aiBrain, radarBlueprint, radarPosition) then
            Utilities.AttemptToBuild(aiBrain, oUnit, radarBlueprint, radarPosition)
            LOG("Engineer " .. oUnit:GetEntityId() .. " building radar at (" .. radarPosition[1] .. ", " .. radarPosition[3] .. ")")
            radarBuilt = true
        else
            LOG("Engineer " .. oUnit:GetEntityId() .. " cannot build radar; position may be blocked or not on navigable terrain.")
        end
    else
        LOG("Engineer " .. oUnit:GetEntityId() .. " failed to obtain blueprint for Radar")
    end
end

function GetNearestAvailableMexLocationAndDistance(oUnit)
    local aiBrain = oUnit:GetAIBrain()
    local sBlueprintToBuild = Utilities.GetBlueprintThatCanBuildOfCategory(aiBrain, categories.STRUCTURE * categories.MASSEXTRACTION, oUnit)
    if sBlueprintToBuild then
        local iNearestMexDist = 10000
        local tNearestMex, iCurDist
        local iPlateauWanted = NavUtils.GetLabel('Hover', oUnit:GetPosition())
        local tBasePosition = oUnit:GetPosition()

        for iMex, tMex in Map.tMassPoints do
            iCurDist = VDist2(tBasePosition[1], tBasePosition[3], tMex[1], tMex[3])
            if iCurDist < iNearestMexDist then
                if NavUtils.GetLabel('Hover', tMex) == iPlateauWanted then
                    local pointAvailable = false
                    for _, point in ipairs(resourcePoints) do
                        if point.x == tMex[1] and point.z == tMex[3] and point.status == "available" then
                            pointAvailable = true
                            break
                        end
                    end
                    if pointAvailable and aiBrain:CanBuildStructureAt(sBlueprintToBuild, tMex) then
                        tNearestMex = {tMex[1], tMex[2], tMex[3]}
                        iNearestMexDist = iCurDist
                    end
                end
            end
        end
        return tNearestMex, iNearestMexDist
    end
end
