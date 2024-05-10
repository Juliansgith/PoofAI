-- ACULogic.lua
function HandleACU(acu)
    local aiBrain = acu:GetAIBrain()
    if aiBrain:GetCurrentUnits(categories.FACTORY) < 2 then
        ProcessACUBuildOrder(acu)
    elseif acu:GetHealth() / acu:GetMaxHealth() < 0.7 then
        RunToBase(acu)
    else
        ManageACUTasks(acu)
    end
end

function ProcessACUBuildOrder(acu)
    local aiBrain = acu:GetAIBrain()
    local iCurFactories = aiBrain:GetCurrentUnits(categories.FACTORY)
    local iCurMexes = aiBrain:GetCurrentUnits(categories.MASSEXTRACTION)
    local iCurPGens = aiBrain:GetCurrentUnits(categories.ENERGYPRODUCTION)

    if iCurFactories < 2 then
        local location = acu:GetPosition()
        BuildNormalBuilding(acu, 'T1LandFactory', location)
    elseif iCurMexes < iCurPGens then
        BuildNearestAvailableMex(acu)
    else
        AttackNearestVisibleEnemy(acu)
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
    -- Implementation to build a structure at specified location
end

function BuildNearestAvailableMex(acu)
    -- Implementation to build a mass extractor at nearest location
end

function AttackNearestVisibleEnemy(acu)
    -- Logic to handle combat for the ACU
end
