local NavUtils = import("/lua/sim/navutils.lua")

--Global variables
bMapSetupRun = false
tMassPoints = {}
tHydroPoints = {}

--Variables against a brain
reftEnemyBase = 'poofEnBase' --{x,y,z} of the enemy base

function SetupMap(aiBrain)
--This makes sure the FAF navigational mesh is generated; the navigational mesh allows you to check if two locations can be pathed to each other (and generate a path to travel between them)
    if not(bMapSetupRun) then
        bMapSetupRun = true
        if not(NavUtils.IsGenerated()) then
            NavUtils.Generate()
        end
    end
    LOG('poofTemp setup')
end

function RecordResourcePoint(sResourceType,x,y,z,size)
    --called by hook into simInit, more reliable method of figuring out if have adaptive map than using markers, as not all mass markers may have mexes generated on an adaptive map
    --Whenever a resource location is created in the map, this is called, and will record the resource location into a table of mex points (tMassPoints) and hydro points (tHydroPoints) for referencing in later code
    local bAlreadyRecorded = false
    local tResourceTableRef
    if sResourceType == 'Mass' then
        tResourceTableRef = tMassPoints
    elseif sResourceType == 'Hydrocarbon' then
        tResourceTableRef = tHydroPoints
    end
    if tResourceTableRef[1] then
        for iEntry, tResource in tResourceTableRef do
            if tResource[1] == x and tResource[3] == z then bAlreadyRecorded = true break end
        end
    end
    if not(bAlreadyRecorded) then
        table.insert(tResourceTableRef, {x,y,z})
    end
end

function GetMassPoints()
    return tMassPoints  -- Simply returns the table of mass points
end

----------General information and functions------

function DetermineEnemyBase(aiBrain)
    --Works out the closest enemy base to aiBrain based on a straight line distance
    local iNearestEnemyBaseDist = 10000
    local tNearestEnemyBase, iCurDist, iEnemyBaseX, iEnemyBaseZ
    local iOurBaseX, iOurBaseZ = aiBrain:GetArmyStartPos()
    local iOurIndex = aiBrain:GetArmyIndex()
    for iBrain, oBrain in ArmyBrains do
        if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) then
            --Is it a civilian?
            if not(ArmyIsCivilian(oBrain:GetArmyIndex())) then
                iEnemyBaseX, iEnemyBaseZ = oBrain:GetArmyStartPos()
                iCurDist = VDist2(iOurBaseX, iOurBaseZ, iEnemyBaseX, iEnemyBaseZ)
                --LOG('Considering enemy brain '..aiBrain.Nickname..'; start positionX='..iEnemyBaseX..';Z='..iEnemyBaseZ..'; iCurDist='..iCurDist..'; Personality='..(ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality or 'nil'))
                if iCurDist < iNearestEnemyBaseDist then
                    iNearestEnemyBaseDist = iCurDist
                    tNearestEnemyBase = {iEnemyBaseX, GetSurfaceHeight(iEnemyBaseX, iEnemyBaseZ), iEnemyBaseZ}
                end
            end
        end
    end
    aiBrain[reftEnemyBase] = {tNearestEnemyBase[1], tNearestEnemyBase[2], tNearestEnemyBase[3]}
end