local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

local frame = CreateFrame("Frame")
FWR.EventFrame = frame
local function printStatus()
    local status = FWR:GetAdvisorStatus()
    print(string.format(
        "|cffd7be6aFarmWise|r ready - Advisor data: %d zones, %d tracked items. Type /fw advisor to open the Advisor.",
        status.zones,
        status.items
    ))
end

function FWR:SetMainFrameVisibleState(isVisible, forceRefresh)
    self.Settings = self.Settings or {}
    self.Settings.ui = self.Settings.ui or {}
    self.Settings.ui.mainWindowVisible = isVisible == true
    if self.TouchDatabase then
        self:TouchDatabase()
    end
    if self.ApplySettingsVisibilityRules then
        self:ApplySettingsVisibilityRules(forceRefresh == true)
    elseif self.MainFrame then
        if isVisible then
            self.MainFrame:Show()
        else
            self.MainFrame:Hide()
        end
    end
end

function FWR:ToggleMainFrameVisibleState()
    local ui = self.Settings and self.Settings.ui or {}
    local isVisible = ui.mainWindowVisible ~= false
    self:SetMainFrameVisibleState(not isVisible, true)
end

local function handleAddonLoaded(addonName)
    if addonName ~= "FarmWise" then
        return
    end

    FWR:EnsureDatabases()
    FWR:EnsureAdvisorStore()
    FWR:RegisterOptionsCategory()
end

function FWR:ResetSessionForScope()
    local scope = self:GetViewScope()
    self:ResetSessionsInScope(scope)
    print("|cffd7be6aFarmWise|r session reset: " .. self:GetViewScopeLabel(scope) .. ".")
end

function FWR:ResetCurrentSessionView()
    return self:ResetSessionForScope()
end

local function handlePlayerLogin()
    FWR:EnsureDatabases()
    if FWR.EnsureRenderState then
        FWR:EnsureRenderState()
    end
    if FWR.RefreshIdleZoneInfo then
        FWR:RefreshIdleZoneInfo()
    end
    FWR:InitializeMainFrameUI()
    FWR:RegisterOptionsCategory()
    local ui = FWR.Settings and FWR.Settings.ui or {}
    if FWR.Settings and FWR.Settings.ui then
        FWR.Settings.ui.mainWindowVisible = (ui.showMainWindowOnGameLoad ~= false)
    end
    if FWR.ApplySettingsVisibilityRules then
        FWR:ApplySettingsVisibilityRules(true)
    end
    if FWR.CreateLauncherIcon then
        FWR:CreateLauncherIcon()
    end
    printStatus()
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        handleAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        handlePlayerLogin()
    elseif event == "CHAT_MSG_LOOT" then
        FWR:HandleLootChatMessage(...)
    elseif event == "CHAT_MSG_MONEY" then
        if FWR.HandleLootMoneyChatMessage then
            FWR:HandleLootMoneyChatMessage(...)
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if FWR.HandleHerbalismSpellcastStart then
            FWR:HandleHerbalismSpellcastStart(...)
        end
        if FWR.HandleMiningSpellcastStart then
            FWR:HandleMiningSpellcastStart(...)
        end
        if FWR.HandleFishingSpellcastStart then
            FWR:HandleFishingSpellcastStart(...)
        end
        if FWR.HandleSkinningSpellcastStart then
            FWR:HandleSkinningSpellcastStart(...)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if FWR.HandleHerbalismSpellcastSucceeded then
            FWR:HandleHerbalismSpellcastSucceeded(...)
        end
        if FWR.HandleMiningSpellcastSucceeded then
            FWR:HandleMiningSpellcastSucceeded(...)
        end
        if FWR.HandleFishingSpellcastSucceeded then
            FWR:HandleFishingSpellcastSucceeded(...)
        end
        if FWR.HandleSkinningSpellcastSucceeded then
            FWR:HandleSkinningSpellcastSucceeded(...)
        end
        if FWR.HandleProcessingSpellcastSucceeded then
            FWR:HandleProcessingSpellcastSucceeded(...)
        end
    elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        if FWR.HandleTradeSkillItemCraftedResult then
            FWR:HandleTradeSkillItemCraftedResult(...)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            if FWR.HandleHerbalismSpellcastCancelled then
                FWR:HandleHerbalismSpellcastCancelled(..., event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupt" or "failed")
            end
            if FWR.HandleMiningSpellcastCancelled then
                FWR:HandleMiningSpellcastCancelled(..., event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupt" or "failed")
            end
            if FWR.HandleFishingSpellcastCancelled then
                FWR:HandleFishingSpellcastCancelled(..., event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupt" or "failed")
            end
            if FWR.HandleSkinningSpellcastCancelled then
                FWR:HandleSkinningSpellcastCancelled(..., event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupt" or "failed")
            end
        elseif event == "UNIT_SPELLCAST_STOP" then
            if FWR.HandleHerbalismSpellcastCancelled then
                FWR:HandleHerbalismSpellcastCancelled(..., "stop")
            end
            if FWR.HandleMiningSpellcastCancelled then
                FWR:HandleMiningSpellcastCancelled(..., "stop")
            end
            if FWR.HandleFishingSpellcastCancelled then
                FWR:HandleFishingSpellcastCancelled(..., "stop")
            end
            if FWR.HandleSkinningSpellcastCancelled then
                FWR:HandleSkinningSpellcastCancelled(..., "stop")
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            if FWR.HandleHerbalismSpellcastCancelled then
                FWR:HandleHerbalismSpellcastCancelled(..., "channel_stop")
            end
            if FWR.HandleMiningSpellcastCancelled then
                FWR:HandleMiningSpellcastCancelled(..., "channel_stop")
            end
            if FWR.HandleFishingSpellcastCancelled then
                FWR:HandleFishingSpellcastCancelled(..., "channel_stop")
            end
            if FWR.HandleSkinningSpellcastCancelled then
                FWR:HandleSkinningSpellcastCancelled(..., "channel_stop")
            end
        end
    elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
        FWR:SetAuctionHouseOpen(event == "AUCTION_HOUSE_SHOW")
        FWR:RefreshAdvisorPanel()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if FWR.HandleIdleCombatStart then
            FWR:HandleIdleCombatStart(...)
        end
        if FWR.ApplySettingsVisibilityRules then
            FWR:ApplySettingsVisibilityRules(true)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if FWR.HandleIdleCombatEnd then
            FWR:HandleIdleCombatEnd(...)
        end
        if FWR.ApplySettingsVisibilityRules then
            FWR:ApplySettingsVisibilityRules(true)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        if FWR.RefreshIdleZoneInfo then
            FWR:RefreshIdleZoneInfo()
        end
    end
end)

frame:SetScript("OnUpdate", function(_, _)
    if FWR.RefreshHerbalismRouteState then
        FWR:RefreshHerbalismRouteState(GetTime and GetTime() or 0)
    end
    if FWR.RefreshMiningRouteState then
        FWR:RefreshMiningRouteState(GetTime and GetTime() or 0)
    end
    if FWR.RefreshFishingRouteState then
        FWR:RefreshFishingRouteState(GetTime and GetTime() or 0)
    end
    if FWR.RefreshSkinningRouteState then
        FWR:RefreshSkinningRouteState(GetTime and GetTime() or 0)
    end
    if FWR.UpdateIdleSystem then
        FWR:UpdateIdleSystem(FWR:Now())
    end
    FWR:TickSessionReset()
    if FWR.ApplySettingsVisibilityRules then
        local inCombat = false
        if type(InCombatLockdown) == "function" and InCombatLockdown() then
            inCombat = true
        elseif type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player") then
            inCombat = true
        end

        if FWR.__fwrLastObservedCombatState ~= inCombat then
            FWR.__fwrLastObservedCombatState = inCombat
            FWR:ApplySettingsVisibilityRules(true)
        end
    end
end)

-- Module wiring: which module reacts to which engine event.
FWR:Subscribe("lootRecorded", function(entry, quantity)
    FWR:RecordAdvisorItem(entry, quantity)
end)
FWR:Subscribe("activeTimeElapsed", function(seconds)
    FWR:RecordAdvisorTime(seconds)
end)
FWR:Subscribe("lootMoneyRecorded", function(copper)
    FWR:RecordAdvisorGold(copper)
end)
FWR:Subscribe("dataCleared", function()
    FWR:ClearAdvisorData()
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_MONEY")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

SLASH_FARMWISEREFORGED1 = "/fwr"
SLASH_FARMWISEREFORGED2 = "/fw"
SlashCmdList.FARMWISEREFORGED = function(message)
    local command = message and message:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""

    if command == "status" or command == "" then
        printStatus()
        return
    end

    if command == "advisor" or command == "adv" then
        FWR:ToggleAdvisorPanel()
        return
    end

    if command == "sync" then
        FWR:SyncAuctionPrices()
        return
    end

    if command == "ui" or command == "toggle" or command == "show" or command == "hide" then
        if not FWR.MainFrame then
            FWR:InitializeMainFrameUI()
        end
        FWR:ToggleMainFrameVisibleState()
        if FWR.Settings and FWR.Settings.ui and FWR.Settings.ui.mainWindowVisible ~= true and FWR.ControlPanel then
            FWR.ControlPanel:Hide()
        end
        return
    end

    if command == "options" then
        FWR:OpenOptionsCategory()
        return
    end

    print("|cffd7be6aFarmWise|r commands: /fw advisor, /fw sync, /fw ui, /fw options, /fw status")
end
