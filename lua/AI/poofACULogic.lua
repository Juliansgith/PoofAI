-- ACULogic.lua
local AIUtils = import('/lua/ai/aiutilities.lua')
local Utils = import('/lua/utilities.lua')
local Game = import('/lua/game.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local MapData = import('/mods/PoofAI/lua/AI/poofMap.lua')


function HandleACU(acu)
    local aiBrain = acu:GetAIBrain()
    LOG("HandleACU: Checking ACU logic for AI brain.")
    if aiBrain:GetCurrentUnits(categories.FACTORY) < 2 then
        LOG("HandleACU: Less than 2 factories. Processing ACU build order.")
        ProcessACUBuildOrder(acu)
    elseif acu:GetHealth() / acu:GetMaxHealth() < 0.7 then
        LOG("HandleACU: ACU health below 70%. Running to base.")
        RunToBase(acu)
    else
        LOG("HandleACU: Managing ACU tasks.")
        ManageACUTasks(acu)
    end
end

function GetBlueprintThatCanBuildOfCategory(aiBrain, iCategoryCondition, oFactory)
    --returns nil if cant find any blueprints that can build; will identify all blueprints meeting iCategoryCondition that oFactory can build, and then select a random one of these to build

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
end

function ProcessACUBuildOrder(acu)
    local aiBrain = acu:GetAIBrain()
    local iCurFactories = aiBrain:GetCurrentUnits(categories.FACTORY)
    local iCurEnergy = aiBrain:GetCurrentUnits(categories.ENERGYPRODUCTION)

    -- First, ensure one factory is built
    if iCurFactories < 1 then
        local factoryBlueprint = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.FACTORY * categories.LAND, acu)
        if factoryBlueprint then
            local location = GetBuildLocation(aiBrain, factoryBlueprint, acu:GetPosition())
            if location then
                BuildNormalBuilding(acu, factoryBlueprint, location)
                LOG("ACU building first factory at: " .. repr(location))
            else
                LOG("Failed to find a suitable location for the factory.")
            end
        else
            LOG("No blueprint found for a factory.")
        end
    -- Then, build two energy structures
    elseif iCurEnergy < 2 then
        local energyBlueprint = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.ENERGYPRODUCTION, acu)
        if energyBlueprint then
            for i = 1, (2 - iCurEnergy) do
                local location = GetBuildLocation(aiBrain, energyBlueprint, acu:GetPosition())
                if location then
                    BuildNormalBuilding(acu, energyBlueprint, location)
                    LOG("ACU building energy structure at: " .. repr(location))
                else
                    LOG("Failed to find a suitable location for energy production.")
                end
            end
        else
            LOG("No blueprint found for energy production.")
        end
    else
        LOG("Initial build order complete. ACU available for other tasks.")
    end
end


function HandleDamage(oUnit, instigator)
    if not oUnit.Dead and oUnit:GetAIBrain().poofAI then
        if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) then
            if oUnit:GetHealth() / oUnit:GetMaxHealth() < 0.7 then
                local aiBrain = oUnit:GetAIBrain()
                local iOurBaseX, iOurBaseZ = aiBrain:GetArmyStartPos()
                if not (oUnit[subreftOrderPosition][1] == iOurBaseX) or not (oUnit[subreftOrderPosition][3] == iOurBaseZ) then
                    RunToBase(oUnit)
                end
            end
        end
    end
end

function RunToBase(acu)
    local aiBrain = acu:GetAIBrain()
    local iOurBaseX, iOurBaseZ = aiBrain:GetArmyStartPos()
    acu:IssueMove({iOurBaseX, GetSurfaceHeight(iOurBaseX, iOurBaseZ), iOurBaseZ})
end

function ManageACUTasks(acu)
    -- Custom logic for managing advanced ACU tasks
end

-- Utility functions specific to ACU operations
function BuildNormalBuilding(acu, blueprint, location)
    local aiBrain = acu:GetAIBrain()
    IssueClearCommands({acu})
    IssueBuildMobile({acu}, location, blueprint, {})
end

function BuildNearestAvailableMex(acu, blueprint)
    local aiBrain = acu:GetAIBrain()
    local tNearestMex, iNearestMexDist = GetNearestAvailableMexLocationAndDistance(acu)
    if tNearestMex then
        IssueClearCommands({acu})
        IssueBuildMobile({acu}, tNearestMex, blueprint, {})
    end
end

function GetNearestAvailableMexLocationAndDistance(acu)
    local aiBrain = acu:GetAIBrain()
    local massPoints = MapData.GetMassPoints()
    local closestPoint = nil
    local minDist = math.huge
    for _, point in pairs(massPoints) do
        local dist = VDist2(point[1], point[3], acu:GetPosition()[1], acu:GetPosition()[3])
        if dist < minDist and aiBrain:CanBuildStructureAt(blueprint, point) then
            closestPoint = point
            minDist = dist
        end
    end
    return closestPoint, minDist
end

function GetBuildLocation(aiBrain, sBlueprintToBuild, tSearchLocation)
    --Searches for somewhere that sBlueprintToBuild can be built around tSearchLocation; doesnt search every possible location but instead searches 170 different locations in ever increasing distances

    --LOG('GetBuildLocation triggered for sBlueprintToBuild='..sBlueprintToBuild..'; tSearchLocation='..repru(tSearchLocation))
    if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tSearchLocation) then return tSearchLocation
    else
        for iAdjust = 4, 52, 4 do
            for iX = -iAdjust, iAdjust, iAdjust do
                for iZ = -iAdjust, iAdjust, iAdjust do
                    if not(iX == 0 and iZ == 0) then
                        local tPotentialBuildLocation = {tSearchLocation[1] + iX, 0, tSearchLocation[3] + iZ}
                        tPotentialBuildLocation[2] = GetSurfaceHeight(tPotentialBuildLocation[1], tPotentialBuildLocation[3])
                        --LOG('Considering tPotentialBuildLocation='..repru(tPotentialBuildLocation)..'; Can build structure here='..tostring(aiBrain:CanBuildStructureAt(sBlueprintToBuild, tPotentialBuildLocation))..'; iX='..iX..'; iZ='..iZ..'; iAdjust='..iAdjust)
                        if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tPotentialBuildLocation) then
                            --LOG('GetBuildLocation found tPotentialBuildLocation='..repru(tPotentialBuildLocation))
                            return tPotentialBuildLocation
                        end
                    end
                end
            end
        end
    end
    --LOG('GetBuildLocation end of code')
end

function BuildNearestAvailableMex(acu)
    -- Implementation to build a mass extractor at nearest location
end

function AttackNearestVisibleEnemy(acu)
    -- Logic to handle combat for the ACU
end
