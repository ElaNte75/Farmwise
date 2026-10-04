local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

function FWR:GetPipelineStageOrder()
    return { "stageSource", "stageRoute", "stageFinal" }
end


function FWR:BuildPipelineResults(itemLink)
    local stageResults = {}
    stageResults.stageSource = self:EvaluateLootSource(itemLink)

    if type(stageResults.stageSource) ~= "table" or not stageResults.stageSource.passed then
        return stageResults, stageResults.stageSource, false
    end

    if stageResults.stageSource.sourceType == "fishing" and self.BuildFishingRouteResult then
        local routeResult, needsRetry = self:BuildFishingRouteResult(stageResults.stageSource)
        stageResults.stageRoute = routeResult
        stageResults.stageFinal = routeResult
        return stageResults, routeResult, needsRetry == true
    end

    if stageResults.stageSource.sourceType == "mining" and self.BuildMiningRouteResult then
        local routeResult, needsRetry = self:BuildMiningRouteResult(stageResults.stageSource)
        stageResults.stageRoute = routeResult
        stageResults.stageFinal = routeResult
        return stageResults, routeResult, needsRetry == true
    end

    if stageResults.stageSource.sourceType == "herbalism" and self.BuildHerbalismRouteResult then
        local routeResult, needsRetry = self:BuildHerbalismRouteResult(stageResults.stageSource)
        stageResults.stageRoute = routeResult
        stageResults.stageFinal = routeResult
        return stageResults, routeResult, needsRetry == true
    end

    if stageResults.stageSource.sourceType == "combat" and self.BuildCombatRouteResult then
        local routeResult, needsRetry = self:BuildCombatRouteResult(stageResults.stageSource)
        stageResults.stageRoute = routeResult
        stageResults.stageFinal = routeResult
        return stageResults, routeResult, needsRetry == true
    end

    stageResults.stageRoute = {
        stage = "rt_unhandled_route",
        passed = false,
        reason = "no_active_route",
        sourceType = stageResults.stageSource.sourceType,
        itemInfo = itemLink,
        itemLink = itemLink,
    }
    stageResults.stageFinal = stageResults.stageRoute
    return stageResults, stageResults.stageRoute, false
end

function FWR:GetFinalPipelineCandidate(stageResults)
    if type(stageResults) ~= "table" then
        return nil
    end
    return stageResults.stageFinal or stageResults.stageRoute or stageResults.stageSource
end

function FWR:CommitPipelineResultToDisplayBasket(stageResults, quantity)
    local finalCandidate = self:GetFinalPipelineCandidate(stageResults)
    if type(finalCandidate) ~= "table" or not finalCandidate.passed then
        return nil
    end

    if self.AddToDisplayBasket then
        self:AddToDisplayBasket(finalCandidate, quantity)
    elseif self.AddOrUpdateDisplayEntry then
        self:AddOrUpdateDisplayEntry(finalCandidate, quantity)
    end

    return finalCandidate
end


function FWR:BuildDisplayPipelineResults(itemLink)
    return self:BuildPipelineResults(itemLink)
end
