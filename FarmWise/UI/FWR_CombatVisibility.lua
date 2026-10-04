local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Combat visibility: hides the main window and/or the FarmWise panels (control panel, Advisor)
-- during combat and brings them back afterwards, following the Interface settings.

local panelsHiddenByCombat = {}

local function isPlayerInCombat()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return true
    end

    if type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player") then
        return true
    end

    return false
end

local function collectManagedPanels(self)
    local panels = {}
    if self.ControlPanel then
        panels.controlPanel = self.ControlPanel
    end
    if self.AdvisorPanel then
        panels.advisorPanel = self.AdvisorPanel
    end
    return panels
end

local function applyMainFrameRule(self, ui, inCombat, forceRefresh)
    if not self.MainFrame then
        return
    end

    local shouldShowMainFrame = ui.mainWindowVisible ~= false

    if inCombat and ui.hideMainWindowInCombat == true then
        if self.__fwrMainFrameCombatSnapshot == nil then
            self.__fwrMainFrameCombatSnapshot = self.MainFrame:IsShown() == true
        end
        if self.MainFrame:IsShown() then
            self.MainFrame:Hide()
        end
        return
    end

    local shouldRestore = (self.__fwrMainFrameCombatSnapshot == true)
        or (not inCombat and shouldShowMainFrame == true and forceRefresh == true)
    if shouldShowMainFrame and shouldRestore and not self.MainFrame:IsShown() then
        self.MainFrame:Show()
    elseif shouldShowMainFrame == false and self.MainFrame:IsShown() then
        self.MainFrame:Hide()
    end

    if not inCombat then
        self.__fwrMainFrameCombatSnapshot = nil
    end
end

local function applyPanelsRule(self, ui, inCombat)
    local panels = collectManagedPanels(self)

    if inCombat and ui.hideControlPanelsInCombat == true then
        for key, panel in pairs(panels) do
            if panel:IsShown() then
                panelsHiddenByCombat[key] = true
                panel:Hide()
            end
        end
        return
    end

    if not inCombat then
        if ui.restoreControlPanelsAfterCombat == true then
            for key in pairs(panelsHiddenByCombat) do
                local panel = panels[key]
                if panel and not panel:IsShown() then
                    panel:Show()
                end
            end
        end
        panelsHiddenByCombat = {}
    end
end

function FWR:ApplySettingsVisibilityRules(forceRefresh)
    local ui = self.Settings and self.Settings.ui or {}
    local inCombat = isPlayerInCombat()

    applyMainFrameRule(self, ui, inCombat, forceRefresh)
    applyPanelsRule(self, ui, inCombat)
end
