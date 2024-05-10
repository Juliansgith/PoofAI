local poofMap = import('/mods/poofAI/lua/AI/poofMap.lua')
local ACULogic = import('/mods/PoofAI/lua/AI/poofACULogic.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local FactoryLogic = import('/mods/PoofAI/lua/AI/poofFactoryLogic.lua')
local EngineerLogic = import('/mods/PoofAI/lua/AI/poofEngineerLogic.lua')

--Global variables: Order references
subrefiOrderType = 1
subreftOrderPosition = 2 --Location of the order
subrefoOrderUnitTarget = 3 --Unit target if there is one
subrefsOrderBlueprint = 4

refiOrderIssueMove = 1
refiOrderIssueAttack = 3
refiOrderIssueAggressiveMove = 4
refiOrderIssueBuild = 9
refiOrderIssueFactoryBuild = 14


--Variables against a unit
reftoAttackingUnits = 'poofAtckUnt' --table of units told to attack this unit

---------------------OVERVIEW--------------
--When events are generated, they trigger an assessment of what the unit in question should be doing, which is then processed
--For example, when a unit is first built, it has logic assigned to it, which might be to attack an enemy unit
--When a unit is killed, if it was being attacked (per the above) then units with that attack order should have their orders reassessed
--Similalry, this reassessment can be triggered if an engineer finishes building a unit, or via special monitoring for move orders to check if the unit has got near the target location


---------------------EVENTS:----------------
function OnCreate(oUnit)
    --LOG('OnCreate triggered for oUnit='..oUnit.UnitId..', EntityID='..oUnit.EntityId)
    if oUnit:GetFractionComplete() == 1 and oUnit:GetAIBrain().poofAI then
        AssignLogicToUnit(oUnit)
    end
end

function OnConstructed(oEngineer, oUnit)
    --LOG('OnConstructed triggered for oUnit='..oUnit.UnitId..', EntityID='..oUnit.EntityId)
    if oEngineer:GetAIBrain().poofAI then
        AssignLogicToUnit(oEngineer)
    end
    if not(oUnit[subrefiOrderType]) and oUnit:GetAIBrain().poofAI then
        AssignLogicToUnit(oUnit)
    end
end

function OnDamaged(oUnit, instigator)
    if not(oUnit.Dead) and oUnit:GetAIBrain().poofAI then
        HandleDamage(oUnit, instigator)
    end
end

function OnUnitDeath(oUnit)
    --LOG('OnUnitDeath triggered for oUnit='..oUnit.UnitId..', EntityID='..oUnit.EntityId)
    if oUnit[reftoAttackingUnits][1] then
        for iAttacker, oAttacker in oUnit[reftoAttackingUnits] do
            if oAttacker == oUnit then
                --LOG('OnUnitDeath: Will assign logic to the attacker who was trying to attack this unit')
                ForkThread(AssignLogicToUnit, oAttacker)
                table.remove(oUnit[reftoAttackingUnits], iAttacker)                
                break
            end
        end
    end
end

---------Support functions----------------------
function GetBlueprintThatCanBuildOfCategory(aiBrain, iCategoryCondition, oFactory)
    -- Returns nil if can't find any blueprints that can build; will identify all blueprints meeting iCategoryCondition that oFactory can build, and then select a random one of these to build

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



----------Deciding what orders to give to units-----------------

function AssignLogicToUnit(oUnit, iOptionalDelayInSeconds)
    if iOptionalDelayInSeconds then
        WaitSeconds(iOptionalDelayInSeconds)
        if oUnit.Dead then return nil end
    end

    local aiBrain = oUnit:GetAIBrain()

    if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) then
        HandleACU(oUnit)
    elseif EntityCategoryContains(categories.FACTORY, oUnit.UnitId) then
        FactoryLogic.BuildFactoryUnit(oUnit)
    elseif EntityCategoryContains(categories.ENGINEER, oUnit.UnitId) then
        EngineerLogic.AssignTasksToEngineers(aiBrain)  -- Use the new function to assign tasks to engineers
    elseif EntityCategoryContains(categories.LAND * categories.MOBILE * categories.DIRECTFIRE + categories.LAND * categories.MOBILE * categories.INDIRECTFIRE, oUnit.UnitId) then
        AttackNearestVisibleEnemy(oUnit)
    end
end

-------------------------------------------------------------------------

function CheckWhenUnitHasReachedDestination(oUnit, iDistanceWanted)
    -- Assigns logic to unit once it has reached the destination

    --LOG('CheckWhenUnitHasReachedDestination triggered for oUnit='..oUnit.UnitId..', EntityID='..oUnit.EntityId)
    if oUnit[subreftOrderPosition] then
        WaitSeconds(1)
        local iDistToLocation = 10000
        local tCurPosition
        while iDistToLocation > iDistanceWanted do
            WaitSeconds(5)
            tCurPosition = oUnit:GetPosition()
            iDistToLocation = VDist2(oUnit[subreftOrderPosition][1], oUnit[subreftOrderPosition][3], tCurPosition[1], tCurPosition[3])
        end
    else
        WaitSeconds(1)
    end
    AssignLogicToUnit(oUnit)
end

function ProcessACUBuildOrder(oUnit)
    --Considers the initial build order for the ACU - will just alternate for 1 pgen - 1 mex and get 2 land factories
    local aiBrain = oUnit:GetAIBrain()
    local iCurPGens = aiBrain:GetCurrentUnits(categories.STRUCTURE * categories.ENERGYPRODUCTION)
    local iCurFactories = aiBrain:GetCurrentUnits(categories.FACTORY)
    local iCurMexes = aiBrain:GetCurrentUnits(categories.STRUCTURE * categories.MASSEXTRACTION)

    local sBlueprintToBuild
    --LOG('iCurFactories='..iCurFactories..'; iCurMexes='..iCurMexes..'; iCurPGens='..iCurPGens)
    if iCurFactories > 0 and iCurMexes < iCurPGens then
        --Build a mex
        BuildNearestAvailableMex(oUnit)
    else
        if iCurFactories > 0  and iCurPGens < 5 + iCurFactories then
            sBlueprintToBuild = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.STRUCTURE * categories.ENERGYPRODUCTION - categories.HYDROCARBON, oUnit)
        else
            sBlueprintToBuild = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.FACTORY * categories.LAND, oUnit)
        end
        if sBlueprintToBuild then
            BuildNormalBuilding(oUnit, sBlueprintToBuild, oUnit:GetPosition())
        else
            --LOG('Processing ACU build order - no action so will retry assigning logic in 5s')
            ForkThread(AssignLogicToUnit, oUnit, 5)
        end
    end
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

function BuildNormalBuilding(oUnit, sBlueprintToBuild, tSearchLocation)
    --Tries to build sBLueprintToBuild near tSearchLocation (or sends the unit for logic assignment if it cant find anywhere to build)
    local aiBrain = oUnit:GetAIBrain()
    local tBuildLocation = GetBuildLocation(aiBrain, sBlueprintToBuild, tSearchLocation)
    if tBuildLocation then
        IssueTrackedBuild(oUnit, tBuildLocation, sBlueprintToBuild, false)
    else
        --LOG('BuildNormalBuilding - no build location so will retry assigning logic in 5s')
        ForkThread(AssignLogicToUnit, oUnit, 5)
    end
end

function BuildNearestAvailableMex(oUnit)
    --Searches for the nearest available mex that oUnit can path to, and builds a mex there
    local aiBrain = oUnit:GetAIBrain()
    local sBlueprintToBuild = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.STRUCTURE * categories.MASSEXTRACTION, oUnit)
    if sBlueprintToBuild then
        local tNearestMex, iNearestMexDist = GetNearestAvailableMexLocationAndDistance(oUnit)
        if tNearestMex then
            IssueTrackedBuild(oUnit, tNearestMex, sBlueprintToBuild, false)
        end
    end
end

function FactoryLogic.BuildFactoryUnit(oFactory)
    --Decides what unit the factory should build (currently it just builds tanks and LABs)

      --LOG('BuildFactoryUnit triggered for oFactory='..oFactory.UnitId..', EntityID='..oFactory.EntityId)
    local aiBrain = oFactory:GetAIBrain()
    local sBlueprintToBuild = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.DIRECTFIRE * categories.MOBILE, oFactory)
    if sBlueprintToBuild then
        IssueTrackedFactoryBuild(oFactory, sBlueprintToBuild)
    else
        --LOG('BuildFactoryUnit - no unit to build so will retry assigning logic in 10s')
        ForkThread(AssignLogicToUnit, oFactory, 10)
    end
end

-----------Executing unit orders----------------------
function AttackNearestVisibleEnemy(oUnit)
    --Locates the nearest enemy to oUnit and does an attack move towards it
    local oClosestEnemy = GetNearestEnemyUnitAndDistance(oUnit)
    if oClosestEnemy then
        IssueTrackedAttack(oUnit, oClosestEnemy, false)
    else
        AttackEnemyBase(oUnit)
    end
end

function AttackEnemyBase(oUnit)
    --Determine primary enemy base if haven't already, and attack-move towards it
    local aiBrain = oUnit:GetAIBrain()
    if not(aiBrain[poofMap.reftEnemyBase]) then
        poofMap.DetermineEnemyBase(aiBrain)
    end
    IssueTrackedAggressiveMove(oUnit, aiBrain[poofMap.reftEnemyBase], false)
    ForkThread(CheckWhenUnitHasReachedDestination, oUnit, 5)
end

function RunToBase(oUnit)
    --Move back to our base (i.e., start position)
    local aiBrain = oUnit:GetAIBrain()
    local iOurBaseX, iOurBaseZ = aiBrain:GetArmyStartPos()
    IssueTrackedMove(oUnit, {iOurBaseX, GetSurfaceHeight(iOurBaseX, iOurBaseZ), iOurBaseZ}, false)
    ForkThread(CheckWhenUnitHasReachedDestination, oUnit, 5)
end

--------------Supporting functions---------
function GetNearestAvailableMexLocationAndDistance(oUnit)
    --Searches every mex and finds the one nearest to oUnit that oUnit can path to (assuming oUnit is a hover unit)

    local aiBrain = oUnit:GetAIBrain()
    local sBlueprintToBuild = GetBlueprintThatCanBuildOfCategory(aiBrain, categories.STRUCTURE * categories.MASSEXTRACTION, oUnit)
    if sBlueprintToBuild then
        local iNearestMexDist = 10000
        local tNearestMex, iCurDist
        local iPlateauWanted = NavUtils.GetLabel('Hover', oUnit:GetPosition())
        local tBasePosition = oUnit:GetPosition()

        for iMex, tMex in poofMap.tMassPoints do
            iCurDist = VDist2(tBasePosition[1], tBasePosition[3], tMex[1], tMex[3])
            if iCurDist < iNearestMexDist then
                if NavUtils.GetLabel('Hover', tMex) == iPlateauWanted then
                    if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tMex) then
                        tNearestMex = {tMex[1], tMex[2], tMex[3]}
                        iNearestMexDist = iCurDist
                    end
                end
            end
        end
        return tNearestMex, iNearestMexDist
    end
end

function GetNearestEnemyUnitAndDistance(oUnit)
    --Searches for the nearest enemy unit that we have current intel of to oUnit that is on the same plateau

    local aiBrain = oUnit:GetAIBrain()
    local tEnemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE, oUnit:GetPosition(), 500, 'Enemy')
    local oClosestEnemy
    local iClosestEnemyDist = 10000
    if tEnemyUnits[1] then
        local tUnitPosition = oUnit:GetPosition()
        local iPlateauWanted = NavUtils.GetLabel('Hover', tUnitPosition)
        local iCurDist, tCurEnemyPosition
        for iEnemy, oEnemy in tEnemyUnits do
            tCurEnemyPosition = oEnemy:GetPosition()
            iCurDist = VDist2(tUnitPosition[1], tUnitPosition[3], tCurEnemyPosition[1], tCurEnemyPosition[3])
            if iCurDist < iClosestEnemyDist then
                if iPlateauWanted == NavUtils.GetLabel('Hover', oEnemy:GetPosition()) then
                    iClosestEnemyDist = iCurDist
                    oClosestEnemy = oEnemy
                end
            end
        end
    end
    return oClosestEnemy, iClosestEnemyDist
end

------------Order commands and tracking--------------------
function TrackOrder(oUnit, iType, tPosition, oTarget, sBlueprint)
    --Updates tracking of what the unit's current order is
    oUnit[subrefiOrderType] = iType
    oUnit[subreftOrderPosition] = tPosition
    oUnit[subrefoOrderUnitTarget] = oTarget
    oUnit[subrefsOrderBlueprint] = sBlueprint
end
function IssueTrackedClearCommands(oUnit)
    --Clears unit's current orders
    IssueClearCommands({oUnit})
    TrackOrder(oUnit, nil, nil, nil, nil)
end

function IssueTrackedAttack(oUnit, oOrderTarget, bAddToExistingQueue)
    --Attack oOrderTarget
    if not(bAddToExistingQueue) then IssueTrackedClearCommands(oUnit) end
    IssueAttack({oUnit}, oOrderTarget)
    TrackOrder(oUnit, refiOrderIssueAttack, nil, oOrderTarget, nil)
    --Track the unit being attacked
    if not(oOrderTarget[reftoAttackingUnits]) then oOrderTarget[reftoAttackingUnits] = {} end
    table.insert(oOrderTarget[reftoAttackingUnits], oUnit)
end

function IssueTrackedAggressiveMove(oUnit, tOrderPosition, bAddToExistingQueue)
    --Attack-move to tOrderPosition
    if not(bAddToExistingQueue) then IssueTrackedClearCommands(oUnit) end
    IssueAggressiveMove({oUnit}, tOrderPosition)
    oUnit[subreftOrderPosition] = {tOrderPosition[1], tOrderPosition[2], tOrderPosition[3]}
    oUnit[subrefiOrderType] = refiOrderIssueAggressiveMove
    TrackOrder(oUnit, refiOrderIssueAggressiveMove, {tOrderPosition[1], tOrderPosition[2], tOrderPosition[3]}, nil, nil)
end

function IssueTrackedMove(oUnit, tOrderPosition, bAddToExistingQueue)
    --Move to tOrderPosition
    if not(bAddToExistingQueue) then IssueTrackedClearCommands(oUnit) end
    IssueMove({oUnit}, tOrderPosition)
    TrackOrder(oUnit, refiOrderIssueMove, {tOrderPosition[1], tOrderPosition[2], tOrderPosition[3]}, nil, nil)
end

function IssueTrackedFactoryBuild(oUnit, sBPToBuild)
    --Have a factory build sBPToBuild
    IssueBuildFactory({ oUnit }, sBPToBuild, 1)
    TrackOrder(oUnit, refiOrderIssueFactoryBuild, nil, nil, sBPToBuild)
end

function IssueTrackedBuild(oUnit, tOrderPosition, sOrderBlueprint, bAddToExistingQueue)
    --Have an engineer/ACU build sOrderBlueprint at tOrderPosition
    if not(bAddToExistingQueue) then IssueTrackedClearCommands(oUnit) end
    IssueBuildMobile({ oUnit }, tOrderPosition, sOrderBlueprint, {})
    TrackOrder(oUnit, refiOrderIssueBuild, nil, nil, sOrderBlueprint)
end