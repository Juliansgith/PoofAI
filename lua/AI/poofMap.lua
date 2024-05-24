local NavUtils = import("/lua/sim/navutils.lua")

-- Global variables
bMapSetupRun = false
tMassPoints = {}
tHydroPoints = {}
assignedMassPoints = {}  -- Track which mass points have been assigned

-- Variables against a brain
reftEnemyBase = 'poofEnBase' -- {x, y, z} of the enemy base

function SetupMap(aiBrain)
    if not bMapSetupRun then
        bMapSetupRun = true
        if not NavUtils.IsGenerated() then
            NavUtils.Generate()
        end
    end
    LOG('poofTemp setup')
end

function RecordResourcePoint(sResourceType, x, y, z, size)
    local bAlreadyRecorded = false
    local tResourceTableRef
    if sResourceType == 'Mass' then
        tResourceTableRef = tMassPoints
    elseif sResourceType == 'Hydrocarbon' then
        tResourceTableRef = tHydroPoints
    end

    if tResourceTableRef and next(tResourceTableRef) ~= nil then
        for _, tResource in ipairs(tResourceTableRef) do
            if tResource[1] == x and tResource[3] == z then
                bAlreadyRecorded = true
                break
            end
        end
    end

    if not bAlreadyRecorded then
        table.insert(tResourceTableRef, {x, y, z})
        LOG("RecordResourcePoint: New resource point recorded at (" .. x .. ", " .. z .. ")")
    else
        LOG("RecordResourcePoint: Resource point already recorded at (" .. x .. ", " .. z .. ")")
    end
end

function DetermineEnemyBase(aiBrain)
    local iNearestEnemyBaseDist = 10000
    local tNearestEnemyBase, iCurDist, iEnemyBaseX, iEnemyBaseZ
    local iOurBaseX, iOurBaseZ = aiBrain:GetArmyStartPos()
    local iOurIndex = aiBrain:GetArmyIndex()
    for iBrain, oBrain in ArmyBrains do
        if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) then
            if not ArmyIsCivilian(oBrain:GetArmyIndex()) then
                iEnemyBaseX, iEnemyBaseZ = oBrain:GetArmyStartPos()
                iCurDist = VDist2(iOurBaseX, iOurBaseZ, iEnemyBaseX, iEnemyBaseZ)
                if iCurDist < iNearestEnemyBaseDist then
                    iNearestEnemyBaseDist = iCurDist
                    tNearestEnemyBase = {iEnemyBaseX, GetSurfaceHeight(iEnemyBaseX, iEnemyBaseZ), iEnemyBaseZ}
                end
            end
        end
    end
    aiBrain[reftEnemyBase] = {tNearestEnemyBase[1], tNearestEnemyBase[2], tNearestEnemyBase[3]}
end
