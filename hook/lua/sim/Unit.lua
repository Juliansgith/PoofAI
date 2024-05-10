local poofUnits = import('/mods/PoofAI/lua/AI/poofUnits.lua')

do --Per Balthazaar - encasing the code in do .... end means that you dont have to worry about using unique variables
    local poofOldUnit = Unit
    Unit = Class(poofOldUnit) {
        OnCreate = function(self)
            poofOldUnit.OnCreate(self)
            ForkThread(poofUnits.OnCreate, self)
        end,
        OnStopBuild = function(self, unit)
            if unit and not(unit.Dead) and unit.GetFractionComplete and unit:GetFractionComplete() == 1 then
                ForkThread(poofUnits.OnConstructed, self, unit)
            end
            return poofOldUnit.OnStopBuild(self, unit)
        end,
        OnDamage = function(self, instigator, amount, vector, damageType)
            poofOldUnit.OnDamage(self, instigator, amount, vector, damageType)
            poofUnits.OnDamaged(self, instigator) --Want this after just incase our code messes things up
        end,
        OnKilled = function(self, instigator, type, overkillRatio) --NOTE: For some reason this doesnt run a lot of the time; onkilledunit is more reliable
            poofUnits.OnUnitDeath(self)
            poofOldUnit.OnKilled(self, instigator, type, overkillRatio)
        end,
        OnReclaimed = function(self, reclaimer)
            poofUnits.OnUnitDeath(self)
            poofOldUnit.OnReclaimed(self, reclaimer)
        end,
        OnDecayed = function(self)
            --LOG('OnDecayed: Time='..GetGameTimeSeconds()..'; self.UnitId='..(self.UnitId or 'nil'))
            poofUnits.OnUnitDeath(self)
            poofOldUnit.OnDecayed(self)
        end,
        OnKilledUnit = function(self, unitKilled, massKilled)
            poofUnits.OnUnitDeath(unitKilled)
            poofOldUnit.OnKilledUnit(self, unitKilled, massKilled)
        end,
        OnDestroy = function(self)
            --LOG('OnDestroy: Time='..GetGameTimeSeconds()..'; self.UnitId='..(self.UnitId or 'nil'))
            poofUnits.OnUnitDeath(self)
            poofOldUnit.OnDestroy(self)
        end,
    }
end