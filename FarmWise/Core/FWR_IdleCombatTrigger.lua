local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

local DEFAULT_COMBAT_GRACE_SECONDS = 30

local function getCombatGraceSeconds()
    local defaults = FWR.DEFAULTS or {}
    local idleDefaults = defaults.idleSystem or {}
    local configured = tonumber(idleDefaults.combatGraceSeconds)
    if configured and configured > 0 then
        return configured
    end
    return DEFAULT_COMBAT_GRACE_SECONDS
end

function FWR:HandleIdleCombatStart()
    if self.ApplyIdleElapsed then
        self:ApplyIdleElapsed(self:Now())
    end

    local state = self:EnsureIdleSystemState()
    local canTakeOwnership = self.CanActivateIdleTrigger and self:CanActivateIdleTrigger("combat", self:Now()) or true

    state.inCombat = true
    state.graceDeadline = nil
    state.graceContextKey = nil
    state.activeTriggerOwner = "combat"
    state.mode = "COMBAT"

    if self.ClearHerbalismRouteState then
        self:ClearHerbalismRouteState(true)
    end
    if self.ClearMiningRouteState then
        self:ClearMiningRouteState(true)
    end
    if self.ClearSkinningRouteState then
        self:ClearSkinningRouteState(true)
    end

    if self.AppendDebugTrace then
        self:AppendDebugTrace("COMBAT", "combat started", {
            "canTakeOwnership=" .. tostring(canTakeOwnership),
            "activeOwner=" .. tostring(state.activeTriggerOwner),
            "contextKey=" .. tostring(state.current and state.current.key or "-"),
        })
    end

    if self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end
end

function FWR:HandleIdleCombatEnd()
    if self.ApplyIdleElapsed then
        self:ApplyIdleElapsed(self:Now())
    end

    local state = self:EnsureIdleSystemState()
    state.inCombat = false
    local now = self:Now()
    state.graceDeadline = now + getCombatGraceSeconds()
    state.graceContextKey = state.current and state.current.key or nil
    if state.activeTriggerOwner == "combat" then
        state.activeTriggerOwner = nil
    end
    state.mode = "GRACE"

    if self.AppendDebugTrace then
        self:AppendDebugTrace("COMBAT", "combat ended", {
            "graceDeadline=" .. tostring(state.graceDeadline),
            "activeOwner=" .. tostring(state.activeTriggerOwner),
            "contextKey=" .. tostring(state.current and state.current.key or "-"),
        })
    end

    if self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end
end
