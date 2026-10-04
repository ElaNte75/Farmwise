local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

function FWR:GetCombatRouteSourceState()
    return nil
end

function FWR:RouteCombatLoot(sourceStage, quantity)
    if self.RouteGenericLoot then
        return self:RouteGenericLoot(sourceStage, quantity, "COMBAT")
    end

    return {
        passed = false,
        reason = "missing_generic_loot_route",
        stage = "rt_combat_route",
        sourceType = sourceStage and sourceStage.sourceType or "combat",
    }, false
end
