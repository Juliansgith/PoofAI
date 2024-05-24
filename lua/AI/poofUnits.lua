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
--Similarly, this reassessment can be triggered if an engineer finishes building a unit, or via special monitoring for move orders to check if the unit has got near the target location

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
        ACULogic.HandleDamage(oUnit, instigator)
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

----------Deciding what orders to give to units-----------------
function AssignLogicToUnit(oUnit, iOptionalDelayInSeconds)
    if iOptionalDelayInSeconds then
        WaitSeconds(iOptionalDelayInSeconds)
        if oUnit.Dead then return nil end
    end

    local aiBrain = oUnit:GetAIBrain()
    LOG("Assigning logic to unit: " .. oUnit:GetEntityId())
    if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) then
        LOG("Handling ACU for unit: " .. oUnit:GetEntityId())
        ACULogic.HandleACU(oUnit)
    elseif EntityCategoryContains(categories.FACTORY, oUnit.UnitId) then
        FactoryLogic.BuildFactoryUnit(oUnit)
    elseif EntityCategoryContains(categories.ENGINEER, oUnit.UnitId) then
        EngineerLogic.AssignTasksToEngineers(oUnit) 
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
    local sBlueprintToBuild = Utilities.GetBlueprintThatCanBuildOfCategory(aiBrain, categories.STRUCTURE * categories.MASSEXTRACTION, oUnit)
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
