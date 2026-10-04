FarmWiseDB = FarmWiseDB or {}

local ADDON_NAME = ... or "FarmWise"
local ADDON_DISPLAY_NAME = "FarmWise"


------------------------------------------------
-- WINDOW SIZE
------------------------------------------------
local WINDOW_WIDTH = 410
local WINDOW_HEIGHT = 220
local BASE_VISIBLE_ROWS = 5
local MAX_VISIBLE_ROWS = 15
local MIN_VISIBLE_ROWS = 6
local DATA_ROW_HEIGHT = 16
local FRAME_SIDE_PADDING = 5
local DIVIDER_ALPHA = 0.15
local IDLE_THRESHOLD_SECONDS = 120
local REFRESH_INTERVAL_SECONDS = 1
local UTILITY_ROW_HEIGHT = 22
local MENU_BUTTON_WIDTH = 44
local FOOTER_TEXT_RIGHT_RESERVED = 94
local OPTIONS_PANEL_WIDTH = 250
local STATS_MIN_TIME_SECONDS = 15 * 60
local UTILITY_BUTTON_GAP = 6
local UTILITY_BUTTON_SIDE_PADDING = 4
local STATS_FOOTER_HEIGHT = 16
local ADVISOR_VISIBLE_RESULTS = 2
local ADVISOR_ROW_HEIGHT = 58
local ADVISOR_ROW_SPACING = 8
local ADVISOR_ROW_PITCH = ADVISOR_ROW_HEIGHT + ADVISOR_ROW_SPACING

local frame = CreateFrame("Frame", "FarmWiseFrame", UIParent)
frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

local IsFrameLocked
local SaveCurrentFramePosition
local RestoreSavedFramePosition


frame:SetScript("OnDragStart", function(self)
    if IsFrameLocked() then
        return
    end
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveCurrentFramePosition()
    RestoreSavedFramePosition()
end)

frame.lines = {}
frame.measureFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.measureFS:Hide()
frame.measureFSNumeric = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
frame.measureFSNumeric:Hide()

local currentZone = ""
local ZoneRuntimeDB = {}
local refreshElapsed = 0
local flashElapsed = 0
local utilityWasOpenBeforeCombat = false
local optionsWasOpenBeforeCombat = false
local statsWasOpenBeforeCombat = false
local statsExactItemID = nil
local statsExactQuality = nil
local statsAutoFilledText = nil
local statsPendingSmartBackspace = nil
local farmAdvisorMode = "SELECT"
local FARM_ADVISOR_MODE_SELECT = "SELECT"
local FARM_ADVISOR_MODE_ITEM = "ITEM"
local FARM_ADVISOR_MODE_GOLD = "GOLD"
local statsInternalTextUpdate = false
local utilityButtonEnabled = true
local frameWasShownBeforeCombat = false
local windowHiddenByCombat = false
local mailboxOpen = false
local tradeOpen = false
local auctionHouseOpen = false

FarmWise = FarmWise or {}

local ApplyBottomLayout

local DEFAULT_SETTINGS = {
    idleMinutes = 2,
    hideOptionsInCombat = true,
    showWindowOnLogin = true,
    hideWindowInCombat = false,
    visibleRows = BASE_VISIBLE_ROWS,
    frameLocked = false,
    minimapAngle = 315,
    backgroundTransparency = 50,
    ahFreshnessMinutes = 30,
    framePosX = nil,
    framePosY = nil,
}

local function GetSettings()
    FarmWiseDB._settings = FarmWiseDB._settings or {}
    local s = FarmWiseDB._settings
    if s.idleMinutes == nil then s.idleMinutes = DEFAULT_SETTINGS.idleMinutes end
    if s.hideOptionsInCombat == nil then s.hideOptionsInCombat = DEFAULT_SETTINGS.hideOptionsInCombat end
    if s.showWindowOnLogin == nil then s.showWindowOnLogin = DEFAULT_SETTINGS.showWindowOnLogin end
    if s.hideWindowInCombat == nil then s.hideWindowInCombat = DEFAULT_SETTINGS.hideWindowInCombat end
    if s.visibleRows == nil then s.visibleRows = DEFAULT_SETTINGS.visibleRows end
    if s.frameLocked == nil then s.frameLocked = DEFAULT_SETTINGS.frameLocked end
    if s.minimapAngle == nil then s.minimapAngle = DEFAULT_SETTINGS.minimapAngle end
    if s.backgroundTransparency == nil then s.backgroundTransparency = DEFAULT_SETTINGS.backgroundTransparency end
    if s.ahFreshnessMinutes == nil then s.ahFreshnessMinutes = DEFAULT_SETTINGS.ahFreshnessMinutes or 30 end
    return s
end

local function GetAHFreshnessMinutes()
    local value = tonumber(GetSettings().ahFreshnessMinutes) or DEFAULT_SETTINGS.ahFreshnessMinutes or 30
    if value ~= 15 and value ~= 30 and value ~= 60 then
        value = DEFAULT_SETTINGS.ahFreshnessMinutes or 30
    end
    return value
end

local function SetAHFreshnessMinutes(value)
    value = tonumber(value)
    if value ~= 15 and value ~= 30 and value ~= 60 then
        value = DEFAULT_SETTINGS.ahFreshnessMinutes
    end
    GetSettings().ahFreshnessMinutes = value
end

local function GetVisibleRows()
    local rows = tonumber(GetSettings().visibleRows) or BASE_VISIBLE_ROWS
    if rows < MIN_VISIBLE_ROWS then rows = MIN_VISIBLE_ROWS end
    if rows > MAX_VISIBLE_ROWS then rows = MAX_VISIBLE_ROWS end
    return rows
end

local function SetVisibleRows(value)
    local s = GetSettings()
    value = tonumber(value) or BASE_VISIBLE_ROWS
    if value < MIN_VISIBLE_ROWS then value = MIN_VISIBLE_ROWS end
    if value > MAX_VISIBLE_ROWS then value = MAX_VISIBLE_ROWS end
    s.visibleRows = value
end

IsFrameLocked = function()
    return GetSettings().frameLocked == true
end

local function SetFrameLocked(locked)
    GetSettings().frameLocked = locked and true or false
end

local function SetIdleMinutes(value)
    local s = GetSettings()
    value = tonumber(value) or DEFAULT_SETTINGS.idleMinutes
    if value < 1 then value = 1 end
    if value > 10 then value = 10 end
    s.idleMinutes = value
end

local function GetIdleThresholdSeconds()
    return (GetSettings().idleMinutes or DEFAULT_SETTINGS.idleMinutes) * 60
end

local function GetBackgroundTransparency()
    local value = tonumber(GetSettings().backgroundTransparency) or DEFAULT_SETTINGS.backgroundTransparency
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end
    return value
end

local function SetBackgroundTransparency(value)
    local s = GetSettings()
    value = tonumber(value) or DEFAULT_SETTINGS.backgroundTransparency
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end
    s.backgroundTransparency = value
end

local function GetBackgroundAlpha()
    return 1 - (GetBackgroundTransparency() / 100)
end

function SaveCurrentFramePosition()
    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    if left and bottom then
        local s = GetSettings()
        s.framePosX = left
        s.framePosY = bottom
    end
end

function RestoreSavedFramePosition()
    local s = GetSettings()
    local x = tonumber(s.framePosX)
    local y = tonumber(s.framePosY)

    frame:ClearAllPoints()
    if x and y then
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
        frame:SetPoint("CENTER")
    end
end

RestoreSavedFramePosition()

------------------------------------------------
-- Background
------------------------------------------------
frame.bg = frame:CreateTexture(nil, "BACKGROUND")
frame.bg:SetAllPoints()
frame.bg:SetColorTexture(0, 0, 0, GetBackgroundAlpha())

------------------------------------------------
-- Title
------------------------------------------------
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
frame.title:SetTextColor(1,0.82,0)
frame.title:SetText(ADDON_DISPLAY_NAME)

frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 6, 0)
frame.subtitle:SetTextColor(1,0.82,0)
frame.subtitle:SetText("(Farm smarter, zone by zone)")

frame.idleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.idleLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -10)
frame.idleLabel:SetTextColor(1, 0.15, 0.15)
frame.idleLabel:SetText("IDLE")
frame.idleLabel:Hide()

local function FormatGoldCompact(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local c = math.floor(copper % 100)
    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, c)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, c)
    else
        return string.format("%dc", c)
    end
end

FarmWise.IsAuctionHouseOpen = function()
    return auctionHouseOpen == true
end

FarmWise.SetAHScanButtonText = function(textValue)
    if frame and frame.utilityAHScanButton then
        frame.utilityAHScanButton:SetText(textValue or "AH Sync")
    end
end

FarmWise.GetAHSyncAgeSeconds = function()
    FarmWiseDB = FarmWiseDB or {}
    FarmWiseDB._ah = FarmWiseDB._ah or {}
    local lastSync = FarmWiseDB._ah.lastSyncTime
    if not lastSync then
        return nil
    end
    return math.max(0, time() - lastSync)
end

FarmWise.GetAuctionDataStore = function()
    FarmWiseDB = FarmWiseDB or {}
    FarmWiseDB._ah = FarmWiseDB._ah or { items = {}, lastSyncTime = nil, lastSyncCount = 0, lastTooltipMessage = nil }
    FarmWiseDB._ah.items = FarmWiseDB._ah.items or {}
    return FarmWiseDB._ah
end


FarmWise.ShowInfoSidePanel = function(titleText, subtitleText, bodyText)
    if frame.resetPanel then
        frame.resetPanel:Show()
    end
    if frame.optionsPanel then frame.optionsPanel:Hide() end
    if frame.statsPanel then frame.statsPanel:Hide() end
    if frame.resetPanelBg then frame.resetPanelBg:Show() end
    if frame.resetSelectionFrame then frame.resetSelectionFrame:Hide() end
    if frame.resetHelp then
        frame.resetHelp:SetText(subtitleText or "Information")
    end
    frame.resetTitle:SetText(titleText or "Information")
    if frame.resetBody then
        local body = bodyText or ""
        body = body:gsub("Steps:\n", "Steps:\n\n")
        frame.resetBody:SetText(body)
        frame.resetBody:Show()
    end
    if frame.resetWarning then frame.resetWarning:Hide() end
    if frame.resetFooterDivider then frame.resetFooterDivider:Show() end
    if frame.resetFooter then frame.resetFooter:Show() end
    if frame.resetConfirmButton then frame.resetConfirmButton:Hide() end
    if frame.resetBackButton then frame.resetBackButton:Hide() end
    if frame.confirmAllButton then frame.confirmAllButton:Hide() end
    if frame.confirmZoneButton then frame.confirmZoneButton:Hide() end
    if frame.confirmCancelButton then
        frame.confirmCancelButton:Show()
        frame.confirmCancelButton:SetText("OK")
    end
end

FarmWise.HideInfoSidePanel = function()
    if frame and frame.resetPanel and frame.resetPanel:IsShown() and resetPendingMode == nil then
        ToggleResetPanel(false)
    end
end

local FormatAHSyncAgeText

local function UpdateAHFreshnessIndicator()
    if not frame or not frame.ahFreshnessText then
        return
    end

    local ageSeconds = FarmWise.GetAHSyncAgeSeconds and FarmWise.GetAHSyncAgeSeconds() or nil
    if not ageSeconds then
        frame.ahFreshnessText:SetText("AH Sync Age: --")
        frame.ahFreshnessText:SetTextColor(0.65, 0.65, 0.65)
        frame.ahFreshnessText:Show()
        return
    end

    local thresholdSeconds = GetAHFreshnessMinutes() * 60
    local warningSeconds = thresholdSeconds + (10 * 60)

    if ageSeconds <= thresholdSeconds then
        frame.ahFreshnessText:SetTextColor(0.15, 0.85, 0.15)
    elseif ageSeconds <= warningSeconds then
        frame.ahFreshnessText:SetTextColor(1, 0.82, 0)
    else
        frame.ahFreshnessText:SetTextColor(1, 0.15, 0.15)
    end

    frame.ahFreshnessText:SetText(FormatAHSyncAgeText(ageSeconds))
    frame.ahFreshnessText:Show()
end

FarmWise.UpdateAHFreshnessIndicator = UpdateAHFreshnessIndicator

local function GetCurrentWindowHeight()
    local extraRows = GetVisibleRows() - BASE_VISIBLE_ROWS
    -- The original window height leaves room for about 6.5 visible data rows.
    -- Subtract 24px so the viewport matches the configured row count exactly.
    local baseHeight = WINDOW_HEIGHT - 24
    local height = baseHeight + (math.max(0, extraRows) * DATA_ROW_HEIGHT)
    if frame.utilityBar and frame.utilityBar:IsShown() then
        height = height + UTILITY_ROW_HEIGHT
    end
    return height
end

local function ResizeFramePreserveBottom()
    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    frame:SetSize(WINDOW_WIDTH, GetCurrentWindowHeight())
    ApplyBottomLayout()
    if left and bottom then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        SaveCurrentFramePosition()
    end
end

local function GetSidePanelWidth()
    if frame.optionsPanel and frame.optionsPanel:IsShown() then
        return frame.optionsPanel:GetWidth()
    end

    if frame.statsPanel and frame.statsPanel:IsShown() then
        return frame.statsPanel:GetWidth()
    end

    if frame.resetPanel and frame.resetPanel:IsShown() then
        return frame.resetPanel:GetWidth()
    end

    return 0
end

local function GetEffectiveFrameWidth()
    return WINDOW_WIDTH + GetSidePanelWidth()
end

ApplyBottomLayout = function()
    local extraBottom = 0
    if frame.utilityBar and frame.utilityBar:IsShown() then
        extraBottom = UTILITY_ROW_HEIGHT
    end

    frame.footerDivider:ClearAllPoints()
    frame.footerDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FRAME_SIDE_PADDING, 25 + extraBottom)
    frame.footerDivider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FRAME_SIDE_PADDING - 18, 25 + extraBottom)

    frame.footerFrame:ClearAllPoints()
    frame.footerFrame:SetPoint("TOPLEFT", frame.footerDivider, "BOTTOMLEFT", 0, -2)

    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", frame.divider, "BOTTOMLEFT", 0, -24)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.footerDivider, "TOPRIGHT", 0, 6)

    frame.utilityDivider:ClearAllPoints()
    frame.utilityDivider:SetPoint("TOPLEFT", frame.footerFrame, "BOTTOMLEFT", 0, -2)
    frame.utilityDivider:SetPoint("TOPRIGHT", frame.footerFrame, "BOTTOMRIGHT", 0, -2)

    frame.utilityBar:ClearAllPoints()
    frame.utilityBar:SetPoint("TOPLEFT", frame.utilityDivider, "BOTTOMLEFT", 0, -2)

    if frame.optionsPanel then
        frame.optionsPanel:SetHeight(GetCurrentWindowHeight())
        frame.optionsPanel:ClearAllPoints()
        frame.optionsPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    end

    if frame.statsPanel then
        frame.statsPanel:SetHeight(GetCurrentWindowHeight())
        frame.statsPanel:ClearAllPoints()
        frame.statsPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    end

    if frame.resetPanel then
        frame.resetPanel:SetHeight(GetCurrentWindowHeight())
        frame.resetPanel:ClearAllPoints()
        frame.resetPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    end
end


------------------------------------------------
-- Session header & divider
------------------------------------------------
frame.session = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
frame.session:SetPoint("TOPLEFT",frame.title,"BOTTOMLEFT",0,-6)
frame.session:SetTextColor(1,1,1)
frame.session:SetJustifyH("LEFT")

frame.divider = frame:CreateTexture(nil,"OVERLAY")
frame.divider:SetHeight(1)
frame.divider:SetColorTexture(1,1,1,DIVIDER_ALPHA)
frame.divider:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_SIDE_PADDING, -57)
frame.divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -FRAME_SIDE_PADDING - 18, -57)

frame.ahFreshnessText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.ahFreshnessText:SetPoint("BOTTOMRIGHT", frame.divider, "TOPRIGHT", -2, 3)
frame.ahFreshnessText:SetJustifyH("RIGHT")
frame.ahFreshnessText:SetText("")
frame.ahFreshnessText:Hide()

------------------------------------------------
-- Footer
------------------------------------------------
frame.footerDivider = frame:CreateTexture(nil, "OVERLAY")
frame.footerDivider:SetHeight(1)
frame.footerDivider:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.footerDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FRAME_SIDE_PADDING, 25)
frame.footerDivider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FRAME_SIDE_PADDING - 18, 25)

frame.footerFrame = CreateFrame("Frame", nil, frame)
frame.footerFrame:SetHeight(16)
frame.footerFrame:SetWidth(WINDOW_WIDTH - (FRAME_SIDE_PADDING * 2) - 18)
frame.footerFrame:SetPoint("TOPLEFT", frame.footerDivider, "BOTTOMLEFT", 0, -2)

frame.footerText = frame.footerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.footerText:SetPoint("LEFT", frame.footerFrame, "LEFT", 0, 0)
frame.footerText:SetPoint("RIGHT", frame.footerFrame, "RIGHT", -FOOTER_TEXT_RIGHT_RESERVED, 0)
frame.footerText:SetJustifyH("LEFT")
frame.footerText:SetMaxLines(1)
frame.footerText:SetWordWrap(false)
frame.footerText:SetNonSpaceWrap(false)
frame.footerText:SetTextColor(1, 0.82, 0)

frame.toolsButton = CreateFrame("Button", nil, frame.footerFrame, "UIPanelButtonTemplate")
frame.toolsButton:SetSize(MENU_BUTTON_WIDTH, 16)
frame.toolsButton:SetPoint("RIGHT", frame.footerFrame, "RIGHT", 0, 0)
frame.toolsButton:SetText("Menu")
frame.toolsButton:SetNormalFontObject("GameFontNormalSmall")
frame.toolsButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.toolsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Show utility buttons", 1, 0.82, 0)
    GameTooltip:AddLine("Toggle the extra utility footer.", 1, 1, 1, true)
    GameTooltip:Show()
end)
frame.toolsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)


frame.lockButton = CreateFrame("Button", nil, frame.footerFrame, "UIPanelButtonTemplate")
frame.lockButton:SetSize(42, 16)
frame.lockButton:SetPoint("RIGHT", frame.toolsButton, "LEFT", -4, 0)
frame.lockButton:SetNormalFontObject("GameFontNormalSmall")
frame.lockButton:SetHighlightFontObject("GameFontHighlightSmall")

local function RefreshLockButton()
    if frame.utilityLockButton then
        if IsFrameLocked() then
            frame.utilityLockButton:SetText("Unlock")
        else
            frame.utilityLockButton:SetText("Lock")
        end
    end
end

frame.lockButton:SetScript("OnClick", function()
    SetFrameLocked(not IsFrameLocked())
    RefreshLockButton()
end)
frame.lockButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if IsFrameLocked() then
        GameTooltip:SetText("Unlock window", 1, 0.82, 0)
        GameTooltip:AddLine("Allow dragging the main FarmWise frame.", 1, 1, 1, true)
    else
        GameTooltip:SetText("Lock window", 1, 0.82, 0)
        GameTooltip:AddLine("Prevent accidental movement of the main FarmWise frame.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
frame.lockButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
RefreshLockButton()
frame.lockButton:SetSize(1, 1)
frame.lockButton:Hide()

frame.lockButton:SetScript("OnClick", function()
    SetFrameLocked(not IsFrameLocked())
    RefreshLockButton()
end)
frame.lockButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if IsFrameLocked() then
        GameTooltip:SetText("Unlock window", 1, 0.82, 0)
        GameTooltip:AddLine("Allow dragging the main FarmWise frame.", 1, 1, 1, true)
    else
        GameTooltip:SetText("Lock window", 1, 0.82, 0)
        GameTooltip:AddLine("Prevent accidental movement of the main FarmWise frame.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
frame.lockButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
RefreshLockButton()

frame.utilityDivider = frame:CreateTexture(nil, "OVERLAY")
frame.utilityDivider:SetHeight(1)
frame.utilityDivider:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.utilityDivider:SetPoint("TOPLEFT", frame.footerFrame, "BOTTOMLEFT", 0, -2)
frame.utilityDivider:SetPoint("TOPRIGHT", frame.footerFrame, "BOTTOMRIGHT", 0, -2)
frame.utilityDivider:Hide()

frame.utilityBar = CreateFrame("Frame", nil, frame)
frame.utilityBar:SetHeight(16)
frame.utilityBar:SetWidth(WINDOW_WIDTH - (FRAME_SIDE_PADDING * 2) - 18)
frame.utilityBar:SetPoint("TOPLEFT", frame.utilityDivider, "BOTTOMLEFT", 0, -2)
frame.utilityBar:Hide()

frame.utilityBarBg = frame.utilityBar:CreateTexture(nil, "BACKGROUND")
frame.utilityBarBg:SetAllPoints()
frame.utilityBarBg:SetColorTexture(0.08, 0.08, 0.08, 0.35)

frame.utilityButtons = {}

local UTILITY_BUTTON_NUDGE = {
    reset = 0,
    options = 0,
    advisor = 0,
    ahsync = 0,
    lock = 0,
}

frame.utilityResetButton = CreateFrame("Button", nil, frame.utilityBar, "UIPanelButtonTemplate")
frame.utilityResetButton:SetSize(72, 16)
frame.utilityResetButton:SetText("Reset")
frame.utilityResetButton:SetNormalFontObject("GameFontNormalSmall")
frame.utilityResetButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.utilityResetButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Reset tracked data", 1, 0.82, 0)
    GameTooltip:AddLine("Choose to clear only the current zone or the full database.", 1, 1, 1, true)
    GameTooltip:Show()
end)
frame.utilityResetButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
frame.utilityResetButton.layoutKey = "reset"
table.insert(frame.utilityButtons, frame.utilityResetButton)

frame.utilityOptionsButton = CreateFrame("Button", nil, frame.utilityBar, "UIPanelButtonTemplate")
frame.utilityOptionsButton:SetSize(50, 16)
frame.utilityOptionsButton:SetText("Options")
frame.utilityOptionsButton:SetNormalFontObject("GameFontNormalSmall")
frame.utilityOptionsButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.utilityOptionsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Tracker options", 1, 0.82, 0)
    GameTooltip:AddLine("Open the settings panel for idle timer and UI behavior.", 1, 1, 1, true)
    GameTooltip:Show()
end)
frame.utilityOptionsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
frame.utilityOptionsButton.layoutKey = "options"
table.insert(frame.utilityButtons, frame.utilityOptionsButton)

frame.utilityStatsButton = CreateFrame("Button", nil, frame.utilityBar, "UIPanelButtonTemplate")
frame.utilityStatsButton:SetSize(74, 16)
frame.utilityStatsButton:SetText("Advisor")
frame.utilityStatsButton:SetNormalFontObject("GameFontNormalSmall")
frame.utilityStatsButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.utilityStatsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Advisor", 1, 0.82, 0)
    GameTooltip:AddLine("Choose item farming or gold farming analysis for your tracked zones.", 1, 1, 1, true)
    GameTooltip:Show()
end)
frame.utilityStatsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
frame.utilityStatsButton.layoutKey = "advisor"
table.insert(frame.utilityButtons, frame.utilityStatsButton)

frame.utilityAHScanButton = CreateFrame("Button", nil, frame.utilityBar, "UIPanelButtonTemplate")
frame.utilityAHScanButton:SetSize(56, 16)
frame.utilityAHScanButton:SetText("AH Sync")
frame.utilityAHScanButton:SetNormalFontObject("GameFontNormalSmall")
frame.utilityAHScanButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.utilityAHScanButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Action House Synchronization", 1, 0.82, 0)
    if Auctionator and Auctionator.API and Auctionator.API.v1 then
        GameTooltip:AddLine("Import Auctionator prices for items FarmWise already tracks.", 1, 1, 1, true)
        local ahStore = FarmWise.GetAuctionDataStore and FarmWise.GetAuctionDataStore() or nil
        if ahStore and ahStore.lastSyncCount and ahStore.lastSyncTotal then
            GameTooltip:AddLine(string.format("Tracked item prices: %d/%d", ahStore.lastSyncCount or 0, ahStore.lastSyncTotal or 0), 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine("Run Auctionator Full Scan first for the best results.", 1, 0.82, 0, true)
    else
        GameTooltip:AddLine("Auctionator is required. Install and enable Auctionator to synchronize FarmWise prices.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
frame.utilityAHScanButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
frame.utilityAHScanButton.layoutKey = "ahsync"
table.insert(frame.utilityButtons, frame.utilityAHScanButton)

frame.utilityLockButton = CreateFrame("Button", nil, frame.utilityBar, "UIPanelButtonTemplate")
frame.utilityLockButton:SetSize(84, 16)
frame.utilityLockButton:SetNormalFontObject("GameFontNormalSmall")
frame.utilityLockButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.utilityLockButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if IsFrameLocked() then
        GameTooltip:SetText("Unlock frame", 1, 0.82, 0)
        GameTooltip:AddLine("Allow dragging the main FarmWise frame.", 1, 1, 1, true)
    else
        GameTooltip:SetText("Lock frame", 1, 0.82, 0)
        GameTooltip:AddLine("Prevent accidental movement of the main FarmWise frame.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
frame.utilityLockButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
frame.utilityLockButton.layoutKey = "lock"
table.insert(frame.utilityButtons, frame.utilityLockButton)
RefreshLockButton()

local function LayoutUtilityButtons()
    if not frame.utilityButtons then
        return
    end

    local count = #frame.utilityButtons
    if count == 0 then
        return
    end

    local totalWidth = frame.utilityBar:GetWidth()
    local totalGapWidth = (count - 1) * UTILITY_BUTTON_GAP
    local availableButtonWidth = totalWidth - (UTILITY_BUTTON_SIDE_PADDING * 2) - totalGapWidth
    local baseButtonWidth = math.floor(availableButtonWidth / count)
    local remainder = availableButtonWidth - (baseButtonWidth * count)
    local offsetX = UTILITY_BUTTON_SIDE_PADDING

    for index, button in ipairs(frame.utilityButtons) do
        local buttonWidth = baseButtonWidth
        if index <= remainder then
            buttonWidth = buttonWidth + 1
        end

        local nudgeX = 0
        if button.layoutKey and UTILITY_BUTTON_NUDGE[button.layoutKey] then
            nudgeX = UTILITY_BUTTON_NUDGE[button.layoutKey]
        end

        button:ClearAllPoints()
        button:SetSize(buttonWidth, 16)
        button:SetPoint("LEFT", frame.utilityBar, "LEFT", offsetX + nudgeX, 0)
        offsetX = offsetX + buttonWidth + UTILITY_BUTTON_GAP
    end
end

LayoutUtilityButtons()

frame.optionsPanel = CreateFrame("Frame", nil, frame)
frame.optionsPanel:SetSize(OPTIONS_PANEL_WIDTH, WINDOW_HEIGHT)
frame.optionsPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
frame.optionsPanel:Hide()

frame.optionsPanelBg = frame.optionsPanel:CreateTexture(nil, "BACKGROUND")
frame.optionsPanelBg:SetAllPoints()
frame.optionsPanelBg:SetColorTexture(0, 0, 0, 0.42)

frame.optionsDividerLeft = frame.optionsPanel:CreateTexture(nil, "OVERLAY")
frame.optionsDividerLeft:SetWidth(1)
frame.optionsDividerLeft:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.optionsDividerLeft:SetPoint("TOPLEFT", frame.optionsPanel, "TOPLEFT", 0, 0)
frame.optionsDividerLeft:SetPoint("BOTTOMLEFT", frame.optionsPanel, "BOTTOMLEFT", 0, 0)

frame.optionsTitle = frame.optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.optionsTitle:SetPoint("TOPLEFT", frame.optionsPanel, "TOPLEFT", 12, -10)
frame.optionsTitle:SetTextColor(1, 0.82, 0)
frame.optionsTitle:SetText("Options")

frame.optionsDivider = frame.optionsPanel:CreateTexture(nil, "OVERLAY")
frame.optionsDivider:SetHeight(1)
frame.optionsDivider:SetColorTexture(1,1,1,DIVIDER_ALPHA)
frame.optionsDivider:SetPoint("TOPLEFT", frame.optionsPanel, "TOPLEFT", 10, -34)
frame.optionsDivider:SetPoint("TOPRIGHT", frame.optionsPanel, "TOPRIGHT", -12, -34)

frame.optionsScroll = CreateFrame("ScrollFrame", nil, frame.optionsPanel, "UIPanelScrollFrameTemplate")
frame.optionsScroll:SetPoint("TOPLEFT", frame.optionsDivider, "BOTTOMLEFT", 0, -8)
frame.optionsScroll:SetPoint("BOTTOMRIGHT", frame.optionsPanel, "BOTTOMRIGHT", -28, 10)
frame.optionsScroll:EnableMouseWheel(true)

frame.optionsContent = CreateFrame("Frame", nil, frame.optionsScroll)
frame.optionsContent:SetSize(OPTIONS_PANEL_WIDTH - 40, 180)
frame.optionsScroll:SetScrollChild(frame.optionsContent)
frame.optionsScroll:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll() or 0
    local step = 24
    local maxScroll = math.max(0, (self:GetScrollChild():GetHeight() or 0) - self:GetHeight())
    local newValue = current - (delta * step)
    if newValue < 0 then newValue = 0 end
    if newValue > maxScroll then newValue = maxScroll end
    self:SetVerticalScroll(newValue)
end)

local OPTIONS_ROW_HEIGHT = 22
local OPTIONS_ROW_SPACING = 10
local OPTIONS_CONTROL_RIGHT = -2
local OPTION_BUTTON_WIDTH = 40
local OPTION_BUTTON_GAP = 6
local OPTIONS_LABEL_GAP = 14
local OPTIONS_CONTROL_COLUMN_WIDTH = 90
local OPTIONS_PANEL_EXTRA_WIDTH = 40

local optionsRows = {}

local function CreateOptionsRow(parent, previous, labelText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(OPTIONS_PANEL_WIDTH - 48, OPTIONS_ROW_HEIGHT)
    if previous then
        row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -OPTIONS_ROW_SPACING)
    else
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    end

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetTextColor(1, 0.82, 0)
    label:SetJustifyH("LEFT")
    label:SetMaxLines(1)
    label:SetWordWrap(false)
    label:SetNonSpaceWrap(false)
    label:SetText(labelText .. ":")

    row.label = label
    table.insert(optionsRows, row)
    return row
end

local function CreateYesNoControls(parent)
    local noButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    noButton:SetSize(OPTION_BUTTON_WIDTH, 18)
    noButton:SetPoint("RIGHT", parent, "RIGHT", OPTIONS_CONTROL_RIGHT - OPTION_BUTTON_WIDTH - OPTION_BUTTON_GAP, 0)
    noButton:SetText("No")
    noButton:SetNormalFontObject("GameFontNormalSmall")
    noButton:SetHighlightFontObject("GameFontHighlightSmall")

    local yesButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    yesButton:SetSize(OPTION_BUTTON_WIDTH, 18)
    yesButton:SetPoint("LEFT", noButton, "RIGHT", OPTION_BUTTON_GAP, 0)
    yesButton:SetText("Yes")
    yesButton:SetNormalFontObject("GameFontNormalSmall")
    yesButton:SetHighlightFontObject("GameFontHighlightSmall")

    parent.yesButton = yesButton
    parent.noButton = noButton

    return yesButton, noButton
end

frame.optionsLoginRow = CreateOptionsRow(frame.optionsContent, nil, "Show Window on Login")
frame.optionsLoginYes, frame.optionsLoginNo = CreateYesNoControls(frame.optionsLoginRow)

frame.optionsWindowCombatRow = CreateOptionsRow(frame.optionsContent, frame.optionsLoginRow, "Hide Window in Combat")
frame.optionsWindowCombatYes, frame.optionsWindowCombatNo = CreateYesNoControls(frame.optionsWindowCombatRow)

frame.optionsCombatRow = CreateOptionsRow(frame.optionsContent, frame.optionsWindowCombatRow, "Hide Options in Combat")
frame.optionsCombatYes, frame.optionsCombatNo = CreateYesNoControls(frame.optionsCombatRow)

frame.optionsRowsRow = CreateOptionsRow(frame.optionsContent, frame.optionsCombatRow, "Set Visible Rows (6-15)")
frame.optionsRowsInput = CreateFrame("EditBox", nil, frame.optionsRowsRow, "InputBoxTemplate")
frame.optionsRowsInput:SetSize(32, 20)
frame.optionsRowsInput:SetPoint("RIGHT", frame.optionsRowsRow, "RIGHT", OPTIONS_CONTROL_RIGHT - OPTION_BUTTON_WIDTH - OPTION_BUTTON_GAP - 8, 0)
frame.optionsRowsInput:SetAutoFocus(false)
frame.optionsRowsInput:SetNumeric(true)
frame.optionsRowsInput:SetMaxLetters(2)
frame.optionsRowsInput:SetJustifyH("CENTER")
frame.optionsRowsInput:SetTextInsets(0, 0, 0, 0)

frame.optionsRowsSet = CreateFrame("Button", nil, frame.optionsRowsRow, "UIPanelButtonTemplate")
frame.optionsRowsSet:SetSize(OPTION_BUTTON_WIDTH, 18)
frame.optionsRowsSet:SetPoint("RIGHT", frame.optionsRowsRow, "RIGHT", OPTIONS_CONTROL_RIGHT, 0)
frame.optionsRowsSet:SetText("Set")
frame.optionsRowsSet:SetNormalFontObject("GameFontNormalSmall")
frame.optionsRowsSet:SetHighlightFontObject("GameFontHighlightSmall")

frame.optionsIdleRow = CreateOptionsRow(frame.optionsContent, frame.optionsRowsRow, "Set Idle Timer (1-10)")
frame.optionsIdleInput = CreateFrame("EditBox", nil, frame.optionsIdleRow, "InputBoxTemplate")
frame.optionsIdleInput:SetSize(32, 20)
frame.optionsIdleInput:SetPoint("RIGHT", frame.optionsIdleRow, "RIGHT", OPTIONS_CONTROL_RIGHT - OPTION_BUTTON_WIDTH - OPTION_BUTTON_GAP - 8, 0)
frame.optionsIdleInput:SetAutoFocus(false)
frame.optionsIdleInput:SetNumeric(true)
frame.optionsIdleInput:SetMaxLetters(2)
frame.optionsIdleInput:SetJustifyH("CENTER")
frame.optionsIdleInput:SetTextInsets(0, 0, 0, 0)

frame.optionsIdleSet = CreateFrame("Button", nil, frame.optionsIdleRow, "UIPanelButtonTemplate")
frame.optionsIdleSet:SetSize(OPTION_BUTTON_WIDTH, 18)
frame.optionsIdleSet:SetPoint("RIGHT", frame.optionsIdleRow, "RIGHT", OPTIONS_CONTROL_RIGHT, 0)
frame.optionsIdleSet:SetText("Set")
frame.optionsIdleSet:SetNormalFontObject("GameFontNormalSmall")
frame.optionsIdleSet:SetHighlightFontObject("GameFontHighlightSmall")

frame.optionsBackgroundRow = CreateOptionsRow(frame.optionsContent, frame.optionsIdleRow, "Set Transparency (0-100)")
frame.optionsBackgroundInput = CreateFrame("EditBox", nil, frame.optionsBackgroundRow, "InputBoxTemplate")
frame.optionsBackgroundInput:SetSize(32, 20)
frame.optionsBackgroundInput:SetPoint("RIGHT", frame.optionsBackgroundRow, "RIGHT", OPTIONS_CONTROL_RIGHT - OPTION_BUTTON_WIDTH - OPTION_BUTTON_GAP - 8, 0)
frame.optionsBackgroundInput:SetAutoFocus(false)
frame.optionsBackgroundInput:SetNumeric(true)
frame.optionsBackgroundInput:SetMaxLetters(3)
frame.optionsBackgroundInput:SetJustifyH("CENTER")
frame.optionsBackgroundInput:SetTextInsets(0, 0, 0, 0)

frame.optionsBackgroundSet = CreateFrame("Button", nil, frame.optionsBackgroundRow, "UIPanelButtonTemplate")
frame.optionsBackgroundSet:SetSize(OPTION_BUTTON_WIDTH, 18)
frame.optionsBackgroundSet:SetPoint("RIGHT", frame.optionsBackgroundRow, "RIGHT", OPTIONS_CONTROL_RIGHT, 0)
frame.optionsBackgroundSet:SetText("Set")
frame.optionsBackgroundSet:SetNormalFontObject("GameFontNormalSmall")
frame.optionsBackgroundSet:SetHighlightFontObject("GameFontHighlightSmall")

frame.optionsAHFreshnessRow = CreateOptionsRow(frame.optionsContent, frame.optionsBackgroundRow, "Set AH Sync Time (15/30/60)")
frame.optionsAHFreshnessInput = CreateFrame("EditBox", nil, frame.optionsAHFreshnessRow, "InputBoxTemplate")
frame.optionsAHFreshnessInput:SetSize(32, 20)
frame.optionsAHFreshnessInput:SetPoint("RIGHT", frame.optionsAHFreshnessRow, "RIGHT", OPTIONS_CONTROL_RIGHT - OPTION_BUTTON_WIDTH - OPTION_BUTTON_GAP - 8, 0)
frame.optionsAHFreshnessInput:SetAutoFocus(false)
frame.optionsAHFreshnessInput:SetNumeric(true)
frame.optionsAHFreshnessInput:SetMaxLetters(2)
frame.optionsAHFreshnessInput:SetJustifyH("CENTER")
frame.optionsAHFreshnessInput:SetTextInsets(0, 0, 0, 0)

frame.optionsAHFreshnessSet = CreateFrame("Button", nil, frame.optionsAHFreshnessRow, "UIPanelButtonTemplate")
frame.optionsAHFreshnessSet:SetSize(OPTION_BUTTON_WIDTH, 18)
frame.optionsAHFreshnessSet:SetPoint("RIGHT", frame.optionsAHFreshnessRow, "RIGHT", OPTIONS_CONTROL_RIGHT, 0)
frame.optionsAHFreshnessSet:SetText("Set")
frame.optionsAHFreshnessSet:SetNormalFontObject("GameFontNormalSmall")
frame.optionsAHFreshnessSet:SetHighlightFontObject("GameFontHighlightSmall")


local function LayoutOptionsPanel()
    local maxLabelWidth = 0

    for _, row in ipairs(optionsRows) do
        frame.measureFS:SetText(row.label:GetText() or "")
        maxLabelWidth = math.max(maxLabelWidth, frame.measureFS:GetStringWidth())
    end

    local contentWidth = math.ceil(maxLabelWidth + OPTIONS_LABEL_GAP + OPTIONS_CONTROL_COLUMN_WIDTH)
    local panelWidth = contentWidth + OPTIONS_PANEL_EXTRA_WIDTH
    local controlRightOffset = -2

    frame.optionsPanel:SetWidth(panelWidth)
    frame.optionsContent:SetWidth(contentWidth)

    for _, row in ipairs(optionsRows) do
        row:SetWidth(contentWidth)
        row.label:SetWidth(maxLabelWidth)
    end

    for _, row in ipairs(optionsRows) do
        if row.yesButton and row.noButton then
            row.noButton:ClearAllPoints()
            row.noButton:SetPoint("RIGHT", row, "RIGHT", controlRightOffset - OPTION_BUTTON_WIDTH - OPTION_BUTTON_GAP, 0)

            row.yesButton:ClearAllPoints()
            row.yesButton:SetPoint("LEFT", row.noButton, "RIGHT", OPTION_BUTTON_GAP, 0)
        end
    end

    frame.optionsRowsSet:ClearAllPoints()
    frame.optionsRowsSet:SetPoint("RIGHT", frame.optionsRowsRow, "RIGHT", controlRightOffset, 0)
    frame.optionsRowsInput:ClearAllPoints()
    frame.optionsRowsInput:SetPoint("RIGHT", frame.optionsRowsSet, "LEFT", -6, 0)

    frame.optionsIdleSet:ClearAllPoints()
    frame.optionsIdleSet:SetPoint("RIGHT", frame.optionsIdleRow, "RIGHT", controlRightOffset, 0)
    frame.optionsIdleInput:ClearAllPoints()
    frame.optionsIdleInput:SetPoint("RIGHT", frame.optionsIdleSet, "LEFT", -6, 0)

    frame.optionsBackgroundSet:ClearAllPoints()
    frame.optionsBackgroundSet:SetPoint("RIGHT", frame.optionsBackgroundRow, "RIGHT", controlRightOffset, 0)
    frame.optionsBackgroundInput:ClearAllPoints()
    frame.optionsBackgroundInput:SetPoint("RIGHT", frame.optionsBackgroundSet, "LEFT", -6, 0)

    frame.optionsAHFreshnessSet:ClearAllPoints()
    frame.optionsAHFreshnessSet:SetPoint("RIGHT", frame.optionsAHFreshnessRow, "RIGHT", controlRightOffset, 0)
    frame.optionsAHFreshnessInput:ClearAllPoints()
    frame.optionsAHFreshnessInput:SetPoint("RIGHT", frame.optionsAHFreshnessSet, "LEFT", -6, 0)
end

frame.optionsContent:SetHeight(252)
LayoutOptionsPanel()

local STATS_PANEL_WIDTH = frame.optionsPanel:GetWidth()

frame.statsPanel = CreateFrame("Frame", nil, frame)
frame.statsPanel:SetSize(STATS_PANEL_WIDTH, WINDOW_HEIGHT)
frame.statsPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
frame.statsPanel:Hide()

frame.statsPanelBg = frame.statsPanel:CreateTexture(nil, "BACKGROUND")
frame.statsPanelBg:SetAllPoints()
frame.statsPanelBg:SetColorTexture(0, 0, 0, 0.42)

frame.statsDividerLeft = frame.statsPanel:CreateTexture(nil, "OVERLAY")
frame.statsDividerLeft:SetWidth(1)
frame.statsDividerLeft:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.statsDividerLeft:SetPoint("TOPLEFT", frame.statsPanel, "TOPLEFT", 0, 0)
frame.statsDividerLeft:SetPoint("BOTTOMLEFT", frame.statsPanel, "BOTTOMLEFT", 0, 0)

frame.statsTitle = frame.statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.statsTitle:SetPoint("TOPLEFT", frame.statsPanel, "TOPLEFT", 12, -10)
frame.statsTitle:SetTextColor(1, 0.82, 0)
frame.statsTitle:SetText("Advisor")

frame.statsDivider = frame.statsPanel:CreateTexture(nil, "OVERLAY")
frame.statsDivider:SetHeight(1)
frame.statsDivider:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)

frame.statsHelp = frame.statsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.statsHelp:SetPoint("TOPLEFT", frame.statsTitle, "BOTTOMLEFT", 2, -2)
frame.statsHelp:SetPoint("RIGHT", frame.statsPanel, "RIGHT", -12, 0)
frame.statsHelp:SetJustifyH("LEFT")
frame.statsHelp:SetText("Choose what you want to analyze.")

frame.statsDivider:SetPoint("TOPLEFT", frame.statsHelp, "BOTTOMLEFT", -2, -4)
frame.statsDivider:SetPoint("TOPRIGHT", frame.statsPanel, "TOPRIGHT", -12, 0)

frame.statsSelectionFrame = CreateFrame("Frame", nil, frame.statsPanel)
frame.statsSelectionFrame:SetPoint("TOPLEFT", frame.statsDivider, "BOTTOMLEFT", 0, -2)
frame.statsSelectionFrame:SetPoint("BOTTOMRIGHT", frame.statsPanel, "BOTTOMRIGHT", -16, 38)

frame.statsItemModeButton = CreateFrame("Button", nil, frame.statsSelectionFrame, "UIPanelButtonTemplate")
frame.statsItemModeButton:SetSize(180, 24)
frame.statsItemModeButton:SetPoint("TOP", frame.statsSelectionFrame, "TOP", 0, -10)
frame.statsItemModeButton:SetText("Item Farming / Hour")
frame.statsItemModeButton:SetNormalFontObject("GameFontNormalSmall")
frame.statsItemModeButton:SetHighlightFontObject("GameFontHighlightSmall")

frame.statsItemModeDescription = frame.statsSelectionFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.statsItemModeDescription:SetPoint("TOP", frame.statsItemModeButton, "BOTTOM", 0, -6)
frame.statsItemModeDescription:SetPoint("LEFT", frame.statsSelectionFrame, "LEFT", 18, 0)
frame.statsItemModeDescription:SetPoint("RIGHT", frame.statsSelectionFrame, "RIGHT", -18, 0)
frame.statsItemModeDescription:SetJustifyH("CENTER")
frame.statsItemModeDescription:SetText("Find the strongest zones for one tracked item based on hourly item yield.")

frame.statsSelectionSeparator = frame.statsSelectionFrame:CreateTexture(nil, "OVERLAY")
frame.statsSelectionSeparator:SetHeight(1)
frame.statsSelectionSeparator:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.statsSelectionSeparator:SetPoint("TOPLEFT", frame.statsItemModeDescription, "BOTTOMLEFT", 18, -14)
frame.statsSelectionSeparator:SetPoint("TOPRIGHT", frame.statsItemModeDescription, "BOTTOMRIGHT", -18, -14)

frame.statsGoldModeButton = CreateFrame("Button", nil, frame.statsSelectionFrame, "UIPanelButtonTemplate")
frame.statsGoldModeButton:SetSize(180, 24)
frame.statsGoldModeButton:SetPoint("TOP", frame.statsSelectionSeparator, "BOTTOM", 0, -18)
frame.statsGoldModeButton:SetText("Gold Farming / Hour")
frame.statsGoldModeButton:SetNormalFontObject("GameFontNormalSmall")
frame.statsGoldModeButton:SetHighlightFontObject("GameFontHighlightSmall")

frame.statsGoldModeDescription = frame.statsSelectionFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.statsGoldModeDescription:SetPoint("TOP", frame.statsGoldModeButton, "BOTTOM", 0, -6)
frame.statsGoldModeDescription:SetPoint("LEFT", frame.statsSelectionFrame, "LEFT", 18, 0)
frame.statsGoldModeDescription:SetPoint("RIGHT", frame.statsSelectionFrame, "RIGHT", -18, 0)
frame.statsGoldModeDescription:SetJustifyH("CENTER")
frame.statsGoldModeDescription:SetText("Estimate zone value per hour from Auctionator prices and tracked item counts.")

frame.statsInput = CreateFrame("EditBox", nil, frame.statsPanel, "InputBoxTemplate")
frame.statsInput:SetSize(STATS_PANEL_WIDTH - 104, 20)
frame.statsInput:SetPoint("TOPLEFT", frame.statsDivider, "BOTTOMLEFT", 2, -8)
frame.statsInput:SetAutoFocus(false)
frame.statsInput:SetTextInsets(6, 6, 0, 0)
frame.statsInput:SetMaxLetters(120)
frame.statsInput.Instructions = frame.statsInput:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.statsInput.Instructions:SetPoint("LEFT", frame.statsInput, "LEFT", 6, 0)
frame.statsInput.Instructions:SetText("Enter item name")
frame.statsInput.Instructions:Show()

frame.statsInput:SetWidth(STATS_PANEL_WIDTH - 104)
frame.statsClearButton = CreateFrame("Button", nil, frame.statsPanel, "UIPanelButtonTemplate")
frame.statsClearButton:SetSize(42, 20)
frame.statsClearButton:SetPoint("LEFT", frame.statsInput, "RIGHT", 6, 0)
frame.statsClearButton:SetText("Clear")
frame.statsClearButton:SetNormalFontObject("GameFontNormalSmall")
frame.statsClearButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.statsClearButton:SetScript("OnClick", function()
    statsPendingSmartBackspace = nil
    statsExactItemID = nil
    statsExactQuality = nil
    statsAutoFilledText = nil
    statsInternalTextUpdate = true
    frame.statsInput:SetText("")
    frame.statsInput:SetCursorPosition(0)
    statsInternalTextUpdate = false
    if frame.statsInput.Instructions then
        frame.statsInput.Instructions:Show()
    end
end)
frame.statsClearButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Clear search", 1, 0.82, 0)
    GameTooltip:AddLine("Remove the current item query.", 1, 1, 1, true)
    GameTooltip:Show()
end)
frame.statsClearButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

frame.statsFooterDivider = frame.statsPanel:CreateTexture(nil, "OVERLAY")
frame.statsFooterDivider:SetHeight(1)
frame.statsFooterDivider:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.statsFooterDivider:SetPoint("BOTTOMLEFT", frame.statsPanel, "BOTTOMLEFT", 10, 25)
frame.statsFooterDivider:SetPoint("BOTTOMRIGHT", frame.statsPanel, "BOTTOMRIGHT", -30, 25)

frame.statsFooter = CreateFrame("Frame", nil, frame.statsPanel)
frame.statsFooter:SetHeight(STATS_FOOTER_HEIGHT)
frame.statsFooter:SetPoint("TOPLEFT", frame.statsFooterDivider, "BOTTOMLEFT", 0, -2)
frame.statsFooter:SetPoint("TOPRIGHT", frame.statsFooterDivider, "BOTTOMRIGHT", 0, -2)

frame.statsBackButton = CreateFrame("Button", nil, frame.statsFooter, "UIPanelButtonTemplate")
frame.statsBackButton:SetSize(48, 18)
frame.statsBackButton:SetPoint("RIGHT", frame.statsFooter, "RIGHT", 0, 0)
frame.statsBackButton:SetText("Back")
frame.statsBackButton:SetNormalFontObject("GameFontNormalSmall")
frame.statsBackButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.statsBackButton:Hide()

frame.statsScroll = CreateFrame("ScrollFrame", nil, frame.statsPanel, "UIPanelScrollFrameTemplate")
frame.statsScroll:SetPoint("TOPLEFT", frame.statsInput, "BOTTOMLEFT", -2, -10)
frame.statsScroll:SetPoint("BOTTOMRIGHT", frame.statsFooterDivider, "TOPRIGHT", 0, 6)
frame.statsScroll:EnableMouseWheel(true)

frame.statsContent = CreateFrame("Frame", nil, frame.statsScroll)
frame.statsContent:SetSize(STATS_PANEL_WIDTH - 40, 180)
frame.statsScroll:SetScrollChild(frame.statsContent)

local function GetStatsScrollMax()
    return math.max(0, (frame.statsScroll:GetScrollChild():GetHeight() or 0) - frame.statsScroll:GetHeight())
end

local function SetStatsScrollValue(value)
    local maxScroll = GetStatsScrollMax()
    value = tonumber(value) or 0
    if value < 0 then value = 0 end
    if value > maxScroll then value = maxScroll end
    frame.statsScroll:SetVerticalScroll(value)
end

local function StepStatsScrollByRow(delta)
    local current = frame.statsScroll:GetVerticalScroll() or 0
    local direction = 0
    if delta > 0 then
        direction = -1
    elseif delta < 0 then
        direction = 1
    end
    if direction == 0 then
        return
    end

    local snappedCurrent = math.floor((current / ADVISOR_ROW_PITCH) + 0.5) * ADVISOR_ROW_PITCH
    local target = snappedCurrent + (direction * ADVISOR_ROW_PITCH)
    SetStatsScrollValue(target)
end

frame.statsScroll:SetScript("OnMouseWheel", function(self, delta)
    StepStatsScrollByRow(delta)
end)

local function SetStatsScrollAnchorToInput()
    frame.statsScroll:ClearAllPoints()
    frame.statsScroll:SetPoint("TOPLEFT", frame.statsInput, "BOTTOMLEFT", -2, -10)
    frame.statsScroll:SetPoint("BOTTOMRIGHT", frame.statsFooterDivider, "TOPRIGHT", 0, 6)
end

local function SetStatsScrollAnchorToDivider()
    frame.statsScroll:ClearAllPoints()
    frame.statsScroll:SetPoint("TOPLEFT", frame.statsDivider, "BOTTOMLEFT", 0, -10)
    frame.statsScroll:SetPoint("BOTTOMRIGHT", frame.statsFooterDivider, "TOPRIGHT", 0, 6)
end

frame.statsHint = frame.statsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.statsHint:SetPoint("TOPLEFT", frame.statsContent, "TOPLEFT", 0, 0)
frame.statsHint:SetPoint("RIGHT", frame.statsContent, "RIGHT", -8, 0)
frame.statsHint:SetJustifyH("LEFT")
frame.statsHint:SetJustifyV("TOP")
frame.statsHint:SetText("")
frame.statsHint:Hide()

frame.statsRows = {}
for i = 1, 10 do
    local row = CreateFrame("Frame", nil, frame.statsContent)
    row:SetSize(STATS_PANEL_WIDTH - 48, ADVISOR_ROW_HEIGHT)
    if i == 1 then
        row:SetPoint("TOPLEFT", frame.statsContent, "TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", frame.statsRows[i - 1], "BOTTOMLEFT", 0, -ADVISOR_ROW_SPACING)
    end

    row.zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.zoneText:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.zoneText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.zoneText:SetJustifyH("LEFT")
    row.zoneText:SetTextColor(1, 0.82, 0)

    row.statsText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.statsText:SetPoint("TOPLEFT", row.zoneText, "BOTTOMLEFT", 0, -2)
    row.statsText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.statsText:SetJustifyH("LEFT")
    row.statsText:SetJustifyV("TOP")
    row.statsText:SetSpacing(1)
    row.statsText:SetTextColor(1, 1, 1)

    row.divider = row:CreateTexture(nil, "ARTWORK")
    row.divider:SetHeight(1)
    row.divider:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
    row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 0)

    row:Hide()
    table.insert(frame.statsRows, row)
end

frame.statsContent:SetHeight(190)

frame.resetPanel = CreateFrame("Frame", nil, frame)
frame.resetPanel:SetSize(STATS_PANEL_WIDTH, WINDOW_HEIGHT)
frame.resetPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
frame.resetPanel:Hide()

frame.resetPanelBg = frame.resetPanel:CreateTexture(nil, "BACKGROUND")
frame.resetPanelBg:SetAllPoints()
frame.resetPanelBg:SetColorTexture(0, 0, 0, 0.42)

local function ApplyBackgroundTransparency()
    local alpha = GetBackgroundAlpha()
    if frame.bg then
        frame.bg:SetColorTexture(0, 0, 0, alpha)
    end
    if frame.utilityBarBg then
        frame.utilityBarBg:SetColorTexture(0.08, 0.08, 0.08, alpha)
    end
    if frame.optionsPanelBg then
        frame.optionsPanelBg:SetColorTexture(0, 0, 0, alpha)
    end
    if frame.statsPanelBg then
        frame.statsPanelBg:SetColorTexture(0, 0, 0, alpha)
    end
    if frame.resetPanelBg then
        frame.resetPanelBg:SetColorTexture(0, 0, 0, alpha)
    end
end

ApplyBackgroundTransparency()

frame.resetDividerLeft = frame.resetPanel:CreateTexture(nil, "OVERLAY")
frame.resetDividerLeft:SetWidth(1)
frame.resetDividerLeft:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.resetDividerLeft:SetPoint("TOPLEFT", frame.resetPanel, "TOPLEFT", 0, 0)
frame.resetDividerLeft:SetPoint("BOTTOMLEFT", frame.resetPanel, "BOTTOMLEFT", 0, 0)

frame.resetTitle = frame.resetPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.resetTitle:SetPoint("TOPLEFT", frame.resetPanel, "TOPLEFT", 12, -10)
frame.resetTitle:SetTextColor(1, 0.82, 0)
frame.resetTitle:SetText("Reset Data")

frame.resetHelp = frame.resetPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.resetHelp:SetPoint("TOPLEFT", frame.resetTitle, "BOTTOMLEFT", 2, -2)
frame.resetHelp:SetPoint("RIGHT", frame.resetPanel, "RIGHT", -12, 0)
frame.resetHelp:SetJustifyH("LEFT")
frame.resetHelp:SetText("Choose what data to delete.")

frame.resetDivider = frame.resetPanel:CreateTexture(nil, "OVERLAY")
frame.resetDivider:SetHeight(1)
frame.resetDivider:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.resetDivider:SetPoint("TOPLEFT", frame.resetHelp, "BOTTOMLEFT", -2, -4)
frame.resetDivider:SetPoint("TOPRIGHT", frame.resetPanel, "TOPRIGHT", -12, 0)

frame.resetBody = frame.resetPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.resetBody:SetPoint("TOPLEFT", frame.resetDivider, "BOTTOMLEFT", 2, -10)
frame.resetBody:SetPoint("RIGHT", frame.resetPanel, "RIGHT", -18, 0)
frame.resetBody:SetJustifyH("LEFT")
frame.resetBody:SetJustifyV("TOP")
frame.resetBody:SetSpacing(2)
frame.resetBody:SetTextColor(0.9, 0.9, 0.9)
frame.resetBody:SetText("")
frame.resetBody:Hide()

frame.resetSelectionFrame = CreateFrame("Frame", nil, frame.resetPanel)
frame.resetSelectionFrame:SetPoint("TOPLEFT", frame.resetDivider, "BOTTOMLEFT", 0, -11)
frame.resetSelectionFrame:SetPoint("BOTTOMRIGHT", frame.resetPanel, "BOTTOMRIGHT", -16, 20)

frame.resetZoneModeButton = CreateFrame("Button", nil, frame.resetSelectionFrame, "UIPanelButtonTemplate")
frame.resetZoneModeButton:SetSize(180, 22)
frame.resetZoneModeButton:SetPoint("TOP", frame.resetSelectionFrame, "TOP", 0, -2)
frame.resetZoneModeButton:SetText("Current Zone")
frame.resetZoneModeButton:SetNormalFontObject("GameFontNormalSmall")
frame.resetZoneModeButton:SetHighlightFontObject("GameFontHighlightSmall")

frame.resetZoneModeDescription = frame.resetSelectionFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.resetZoneModeDescription:SetPoint("TOP", frame.resetZoneModeButton, "BOTTOM", 0, -2)
frame.resetZoneModeDescription:SetPoint("LEFT", frame.resetSelectionFrame, "LEFT", 18, 0)
frame.resetZoneModeDescription:SetPoint("RIGHT", frame.resetSelectionFrame, "RIGHT", -18, 0)
frame.resetZoneModeDescription:SetJustifyH("CENTER")
frame.resetZoneModeDescription:SetText("Clear only this zone's tracked data.")

frame.resetSelectionSeparator1 = frame.resetSelectionFrame:CreateTexture(nil, "OVERLAY")
frame.resetSelectionSeparator1:SetHeight(1)
frame.resetSelectionSeparator1:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.resetSelectionSeparator1:SetPoint("TOPLEFT", frame.resetZoneModeDescription, "BOTTOMLEFT", 18, -5)
frame.resetSelectionSeparator1:SetPoint("TOPRIGHT", frame.resetZoneModeDescription, "BOTTOMRIGHT", -18, -5)

frame.resetAllModeButton = CreateFrame("Button", nil, frame.resetSelectionFrame, "UIPanelButtonTemplate")
frame.resetAllModeButton:SetSize(180, 22)
frame.resetAllModeButton:SetPoint("TOP", frame.resetSelectionSeparator1, "BOTTOM", 0, -6)
frame.resetAllModeButton:SetText("All Data")
frame.resetAllModeButton:SetNormalFontObject("GameFontNormalSmall")
frame.resetAllModeButton:SetHighlightFontObject("GameFontHighlightSmall")

frame.resetAllModeDescription = frame.resetSelectionFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.resetAllModeDescription:SetPoint("TOP", frame.resetAllModeButton, "BOTTOM", 0, -2)
frame.resetAllModeDescription:SetPoint("LEFT", frame.resetSelectionFrame, "LEFT", 18, 0)
frame.resetAllModeDescription:SetPoint("RIGHT", frame.resetSelectionFrame, "RIGHT", -18, 0)
frame.resetAllModeDescription:SetJustifyH("CENTER")
frame.resetAllModeDescription:SetText("Delete all tracked zones permanently.")

frame.resetSelectionSeparator2 = frame.resetSelectionFrame:CreateTexture(nil, "OVERLAY")
frame.resetSelectionSeparator2:SetHeight(1)
frame.resetSelectionSeparator2:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.resetSelectionSeparator2:SetPoint("TOPLEFT", frame.resetAllModeDescription, "BOTTOMLEFT", 18, -5)
frame.resetSelectionSeparator2:SetPoint("TOPRIGHT", frame.resetAllModeDescription, "BOTTOMRIGHT", -18, -5)

frame.resetCancelModeButton = CreateFrame("Button", nil, frame.resetSelectionFrame, "UIPanelButtonTemplate")
frame.resetCancelModeButton:SetSize(180, 22)
frame.resetCancelModeButton:SetPoint("TOP", frame.resetSelectionSeparator2, "BOTTOM", 0, -6)
frame.resetCancelModeButton:SetText("Cancel")
frame.resetCancelModeButton:SetNormalFontObject("GameFontNormalSmall")
frame.resetCancelModeButton:SetHighlightFontObject("GameFontHighlightSmall")

frame.resetCancelModeDescription = frame.resetSelectionFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.resetCancelModeDescription:SetPoint("TOP", frame.resetCancelModeButton, "BOTTOM", 0, -2)
frame.resetCancelModeDescription:SetPoint("LEFT", frame.resetSelectionFrame, "LEFT", 18, 0)
frame.resetCancelModeDescription:SetPoint("RIGHT", frame.resetSelectionFrame, "RIGHT", -18, 0)
frame.resetCancelModeDescription:SetJustifyH("CENTER")
frame.resetCancelModeDescription:SetText("Close this panel without deleting anything.")

frame.resetWarning = frame.resetPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.resetWarning:SetPoint("TOPLEFT", frame.resetDivider, "BOTTOMLEFT", 2, -12)
frame.resetWarning:SetPoint("RIGHT", frame.resetPanel, "RIGHT", -18, 0)
frame.resetWarning:SetJustifyH("LEFT")
frame.resetWarning:SetJustifyV("TOP")
frame.resetWarning:SetTextColor(1, 0.82, 0)
frame.resetWarning:SetText("")
frame.resetWarning:Hide()

frame.resetFooterDivider = frame.resetPanel:CreateTexture(nil, "OVERLAY")
frame.resetFooterDivider:SetHeight(1)
frame.resetFooterDivider:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
frame.resetFooterDivider:SetPoint("BOTTOMLEFT", frame.resetPanel, "BOTTOMLEFT", 10, 25)
frame.resetFooterDivider:SetPoint("BOTTOMRIGHT", frame.resetPanel, "BOTTOMRIGHT", -30, 25)
frame.resetFooterDivider:Hide()

frame.resetFooter = CreateFrame("Frame", nil, frame.resetPanel)
frame.resetFooter:SetHeight(STATS_FOOTER_HEIGHT)
frame.resetFooter:SetPoint("TOPLEFT", frame.resetFooterDivider, "BOTTOMLEFT", 0, -2)
frame.resetFooter:SetPoint("TOPRIGHT", frame.resetFooterDivider, "BOTTOMRIGHT", 0, -2)
frame.resetFooter:Hide()

frame.resetAllButton = CreateFrame("Button", nil, frame.resetFooter, "UIPanelButtonTemplate")
frame.resetAllButton:SetSize(74, 20)
frame.resetAllButton:SetPoint("RIGHT", frame.resetFooter, "RIGHT", 0, 0)
frame.resetAllButton:SetText("All Data")
frame.resetAllButton:SetNormalFontObject("GameFontNormalSmall")
frame.resetAllButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.resetAllButton:Hide()

frame.resetZoneButton = CreateFrame("Button", nil, frame.resetFooter, "UIPanelButtonTemplate")
frame.resetZoneButton:SetSize(92, 20)
frame.resetZoneButton:SetPoint("RIGHT", frame.resetAllButton, "LEFT", -6, 0)
frame.resetZoneButton:SetText("Current Zone")
frame.resetZoneButton:SetNormalFontObject("GameFontNormalSmall")
frame.resetZoneButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.resetZoneButton:Hide()

frame.resetCancelButton = CreateFrame("Button", nil, frame.resetFooter, "UIPanelButtonTemplate")
frame.resetCancelButton:SetSize(64, 20)
frame.resetCancelButton:SetPoint("RIGHT", frame.resetZoneButton, "LEFT", -6, 0)
frame.resetCancelButton:SetText("Cancel")
frame.resetCancelButton:SetNormalFontObject("GameFontNormalSmall")
frame.resetCancelButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.resetCancelButton:Hide()

frame.resetConfirmButton = CreateFrame("Button", nil, frame.resetFooter, "UIPanelButtonTemplate")
frame.resetConfirmButton:SetSize(86, 20)
frame.resetConfirmButton:SetPoint("RIGHT", frame.resetFooter, "RIGHT", 0, 0)
frame.resetConfirmButton:SetText("Confirm")
frame.resetConfirmButton:SetNormalFontObject("GameFontNormalSmall")
frame.resetConfirmButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.resetConfirmButton:Hide()

frame.resetBackButton = CreateFrame("Button", nil, frame.resetFooter, "UIPanelButtonTemplate")
frame.resetBackButton:SetSize(72, 20)
frame.resetBackButton:SetPoint("RIGHT", frame.resetConfirmButton, "LEFT", -6, 0)
frame.resetBackButton:SetText("Back")
frame.resetBackButton:SetNormalFontObject("GameFontNormalSmall")
frame.resetBackButton:SetHighlightFontObject("GameFontHighlightSmall")
frame.resetBackButton:Hide()

------------------------------------------------
-- Scroll area
------------------------------------------------
frame.scroll = CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
frame.scroll:SetPoint("TOPLEFT",frame.divider,"BOTTOMLEFT",0,-24)
frame.scroll:SetPoint("BOTTOMRIGHT", frame.footerDivider, "TOPRIGHT", 0, 6)

frame.content = CreateFrame("Frame",nil,frame.scroll)
frame.content:SetSize(300,1)
frame.scroll:SetScrollChild(frame.content)

ApplyBottomLayout()

------------------------------------------------
-- Headers frame
------------------------------------------------
frame.headerFrame = CreateFrame("Frame", nil, frame)
frame.headerFrame:SetHeight(16)
frame.headerFrame:SetWidth(WINDOW_WIDTH - (FRAME_SIDE_PADDING * 2) - 18)
frame.headerFrame:SetPoint("TOPLEFT", frame.divider, "BOTTOMLEFT", 0, -2)

local headerTitles = {"Item Name","Quality","Overall","Daily","Item/hr"}

-- Header controls per column:
-- alignment options: "LEFT", "CENTER", "RIGHT"
local headerAlignments = {"LEFT", "CENTER", "CENTER", "CENTER", "CENTER"}
local headerOffsets = {0, 0, 0, 0, 0}

-- Minimum final widths (in pixels) for each column.
-- You can tune these values manually to keep columns stable.
-- The column can still grow beyond this if the content needs more space.
-- Order: Item Name, Quality, Overall, Daily, Item/hr
local MIN_COLUMN_WIDTHS = {150, 55, 60, 50, 60}

frame.headerStrings = {}

for i=1,#headerTitles do
    local h = frame.headerFrame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    h:SetText(headerTitles[i])
    h:SetTextColor(1,0.82,0)
    table.insert(frame.headerStrings, h)
end

------------------------------------------------
-- Utilities
------------------------------------------------
local function GetCurrentZoneName()
    local zone = GetZoneText() or "Unknown"
    local sub = GetSubZoneText()

    if sub and sub ~= "" then
        return zone.." - "..sub
    end

    return zone
end

local function GetTodayKey()
    return date("%Y-%m-%d")
end

local function FormatTime(seconds)
    local totalMinutes = math.floor(seconds/60)
    local totalHours = math.floor(totalMinutes/60)
    local days = math.floor(totalHours/24)
    local hours = totalHours % 24
    local minutes = totalMinutes % 60

    local parts = {}

    if days > 0 then
        table.insert(parts, days.."d")
    end

    if hours > 0 then
        table.insert(parts, hours.."h")
    end

    table.insert(parts, minutes.."m")

    return table.concat(parts, " : ")
end

local function FormatStatsTime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local totalMinutes = math.floor(seconds / 60)
    local hours = math.floor(totalMinutes / 60)
    local minutes = totalMinutes % 60

    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end

    return string.format("%dm", totalMinutes)
end

FormatAHSyncAgeText = function(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60

    if hours > 0 then
        return string.format("AH Sync Age: %dh %02dm", hours, minutes)
    end

    return string.format("AH Sync Age: %dm", minutes)
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"
local FOOTER_SEPARATOR = "|cffffffff | |r"

local function FormatNumberGrouped(value)
    value = math.floor(tonumber(value) or 0)
    local formatted = tostring(value)
    local k
    repeat
        formatted, k = formatted:gsub("^(%-?%d+)(%d%d%d)", "%1.%2")
    until k == 0
    return formatted
end

local function FormatGoldEstimateText(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)

    if gold >= 1000 then
        gold = math.floor(gold / 100) * 100
    elseif gold >= 100 then
        gold = math.floor(gold / 10) * 10
    end

    if gold < 0 then
        gold = 0
    end

    return string.format("%s%s", FormatNumberGrouped(gold), GOLD_ICON)
end

local function FormatMoneyCompact(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100

    if gold > 0 then
        return string.format("%d%s %02d%s %02d%s", gold, GOLD_ICON, silver, SILVER_ICON, copperOnly, COPPER_ICON)
    end

    if silver > 0 then
        return string.format("%d%s %02d%s", silver, SILVER_ICON, copperOnly, COPPER_ICON)
    end

    return string.format("%d%s", copperOnly, COPPER_ICON)
end

local function GetFooterMoneyText(overallCopper, dailyCopper)
    return string.format(
        "Overall: %s%sDaily: %s",
        FormatMoneyCompact(overallCopper),
        FOOTER_SEPARATOR,
        FormatMoneyCompact(dailyCopper)
    )
end

local function ExtractMoneyFromMessage(msg)
    if not msg or msg == "" then return 0 end

    local gold = 0
    local silver = 0
    local copper = 0

    gold = tonumber(string.match(msg, "(%d+)%s*[Gg]old")) or tonumber(string.match(msg, "(%d+)|T.-UI%-GoldIcon")) or 0
    silver = tonumber(string.match(msg, "(%d+)%s*[Ss]ilver")) or tonumber(string.match(msg, "(%d+)|T.-UI%-SilverIcon")) or 0
    copper = tonumber(string.match(msg, "(%d+)%s*[Cc]opper")) or tonumber(string.match(msg, "(%d+)|T.-UI%-CopperIcon")) or 0

    return (gold * 10000) + (silver * 100) + copper
end

local function GetZoneData(zone)
    FarmWiseDB[zone] = FarmWiseDB[zone] or {
        items = {},
        gold = 0,
        time = 0,
        daily = {
            date = GetTodayKey(),
            items = {},
            gold = 0,
            time = 0
        }
    }

    FarmWiseDB[zone].items = FarmWiseDB[zone].items or {}
    FarmWiseDB[zone].gold = FarmWiseDB[zone].gold or 0
    FarmWiseDB[zone].time = FarmWiseDB[zone].time or 0
    FarmWiseDB[zone].daily = FarmWiseDB[zone].daily or {}
    FarmWiseDB[zone].daily.date = FarmWiseDB[zone].daily.date or GetTodayKey()
    FarmWiseDB[zone].daily.items = FarmWiseDB[zone].daily.items or {}
    FarmWiseDB[zone].daily.gold = FarmWiseDB[zone].daily.gold or 0
    FarmWiseDB[zone].daily.time = FarmWiseDB[zone].daily.time or 0

    return FarmWiseDB[zone]
end

local function GetZoneRuntime(zone)
    ZoneRuntimeDB[zone] = ZoneRuntimeDB[zone] or {
        totalStart = nil,
        dailyStart = nil,
        lastLootTime = nil,
        idle = true,
        dayKey = GetTodayKey()
    }

    return ZoneRuntimeDB[zone]
end

local function GetDisplayedTimes(zone)
    local data = GetZoneData(zone)
    local runtime = ZoneRuntimeDB[zone]
    local totalTime = data.time
    local dailyTime = data.daily.time

    if runtime then
        local now = GetTime()

        if runtime.totalStart then
            totalTime = totalTime + (now - runtime.totalStart)
        end

        if runtime.dailyStart then
            dailyTime = dailyTime + (now - runtime.dailyStart)
        end
    end

    return totalTime, dailyTime
end

local function UpdateIdleVisual()
    local runtime = ZoneRuntimeDB[currentZone]

    if runtime and runtime.idle then
        frame.idleLabel:Show()
    else
        frame.idleLabel:Hide()
        frame.idleLabel:SetAlpha(1)
    end
end

local function ResetDailyDataIfNeeded(zone)
    if not zone or zone == "" then return end

    local data = GetZoneData(zone)
    local runtime = GetZoneRuntime(zone)
    local todayKey = GetTodayKey()

    if data.daily.date == todayKey and runtime.dayKey == todayKey then
        return
    end

    local now = GetTime()

    if runtime.dailyStart then
        data.daily.time = data.daily.time + (now - runtime.dailyStart)
        runtime.dailyStart = nil
    end

    data.daily = {
        date = todayKey,
        items = {},
        gold = 0,
        time = 0
    }

    runtime.dayKey = todayKey

    if not runtime.idle then
        runtime.dailyStart = now
    end
end

local function StartZoneSession()
    if currentZone == "" then return end

    ResetDailyDataIfNeeded(currentZone)
    GetZoneData(currentZone)
    GetZoneRuntime(currentZone)
end

local function EndZoneSession(zone)
    zone = zone or currentZone
    if not zone or zone == "" then return end

    ResetDailyDataIfNeeded(zone)

    local data = GetZoneData(zone)
    local runtime = GetZoneRuntime(zone)
    local now = GetTime()

    if runtime.totalStart then
        data.time = data.time + (now - runtime.totalStart)
        runtime.totalStart = nil
    end

    if runtime.dailyStart then
        data.daily.time = data.daily.time + (now - runtime.dailyStart)
        runtime.dailyStart = nil
    end

    runtime.idle = true
end

local function SetIdleState(zone, isIdle)
    if not zone or zone == "" then return end

    ResetDailyDataIfNeeded(zone)

    local data = GetZoneData(zone)
    local runtime = GetZoneRuntime(zone)
    local now = GetTime()

    if runtime.idle == isIdle then
        return
    end

    runtime.idle = isIdle

    if isIdle then
        if runtime.totalStart then
            data.time = data.time + (now - runtime.totalStart)
            runtime.totalStart = nil
        end

        if runtime.dailyStart then
            data.daily.time = data.daily.time + (now - runtime.dailyStart)
            runtime.dailyStart = nil
        end
    else
        runtime.lastLootTime = now
        runtime.totalStart = now
        runtime.dailyStart = now
    end

    if zone == currentZone then
        UpdateIdleVisual()
    end
end

local function UpdateIdleState()
    if currentZone == "" then return end

    ResetDailyDataIfNeeded(currentZone)

    local runtime = GetZoneRuntime(currentZone)

    if runtime.idle then
        return
    end

    if runtime.lastLootTime and (GetTime() - runtime.lastLootTime) >= GetIdleThresholdSeconds() then
        SetIdleState(currentZone, true)
    end
end

local function RegisterZoneActivity(zone)
    if not zone or zone == "" then return end

    ResetDailyDataIfNeeded(zone)

    local runtime = GetZoneRuntime(zone)
    runtime.lastLootTime = GetTime()

    if runtime.idle then
        SetIdleState(zone, false)
    else
        runtime.totalStart = runtime.totalStart or GetTime()
        runtime.dailyStart = runtime.dailyStart or GetTime()
    end
end

------------------------------------------------
-- Add loot item
------------------------------------------------
local function AddLootItem(itemLink,quantity)
    if not itemLink or currentZone == "" then return end

    quantity = quantity or 1

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then return end

    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        local itemName,_,itemQuality,_,_,_,_,_,_,_,_,classID = GetItemInfo(itemID)

        if not itemName then return end
        if classID ~= 7 then return end

        ResetDailyDataIfNeeded(currentZone)

        local tier = itemLink:match("Quality%-%d+%-Tier(%d)")
        local qualityLabel = "Q"..(tier or "1")
        local key = itemID.."|"..qualityLabel

        local data = GetZoneData(currentZone)
        local entry = data.items[key]

        if not entry then
            entry = {
                id=itemID,
                name=itemName,
                count=0,
                quality=qualityLabel,
                itemQuality=itemQuality
            }
            data.items[key] = entry
        end

        entry.count = entry.count + quantity
        data.daily.items[key] = (data.daily.items[key] or 0) + quantity

        RegisterZoneActivity(currentZone)

        if frame:IsShown() then
            ShowLoot(currentZone,false)
        end
    end)
end

local function AddLootMoney(copper)
    if currentZone == "" or not copper or copper <= 0 then return end

    ResetDailyDataIfNeeded(currentZone)

    local data = GetZoneData(currentZone)
    data.gold = (data.gold or 0) + copper
    data.daily.gold = (data.daily.gold or 0) + copper

    RegisterZoneActivity(currentZone)

    if frame:IsShown() then
        ShowLoot(currentZone,false)
    end
end

local function ResetCurrentZoneData()
    if not currentZone or currentZone == "" then return end

    FarmWiseDB[currentZone] = nil
    ZoneRuntimeDB[currentZone] = nil

    GetZoneData(currentZone)
    local runtime = GetZoneRuntime(currentZone)
    runtime.idle = true
    UpdateIdleVisual()
end

local function ResetAllData()
    local preservedSettings = GetSettings()
    FarmWiseDB = {
        _settings = {
            idleMinutes = preservedSettings.idleMinutes,
            hideOptionsInCombat = preservedSettings.hideOptionsInCombat,
            showWindowOnLogin = preservedSettings.showWindowOnLogin,
            hideWindowInCombat = preservedSettings.hideWindowInCombat,
            visibleRows = preservedSettings.visibleRows,
            frameLocked = preservedSettings.frameLocked,
            minimapAngle = preservedSettings.minimapAngle,
            backgroundTransparency = preservedSettings.backgroundTransparency,
        ahFreshnessMinutes = preservedSettings.ahFreshnessMinutes,
            ahFreshnessMinutes = preservedSettings.ahFreshnessMinutes,
            framePosX = preservedSettings.framePosX,
            framePosY = preservedSettings.framePosY,
        }
    }
    ZoneRuntimeDB = {}

    if currentZone and currentZone ~= "" then
        GetZoneData(currentZone)
        local runtime = GetZoneRuntime(currentZone)
        runtime.idle = true
    end

    UpdateIdleVisual()
end

local function RefreshAfterReset(message)
    if frame.resetPanel and frame.resetPanel:IsShown() then
        frame.resetPanel:Hide()
        ApplyBottomLayout()
    end

    if frame:IsShown() and currentZone ~= "" then
        ShowLoot(currentZone, false)
    end

    if message and message ~= "" then
        print(message)
    end
end

frame.confirmBlocker = nil
frame.confirmBackdrop = nil
frame.confirmText = nil
frame.confirmSubText = nil
frame.confirmAllButton = frame.resetAllButton
frame.confirmZoneButton = frame.resetZoneButton
frame.confirmCancelButton = frame.resetCancelButton

local ToggleOptionsPanel
local ToggleStatsPanel
local ToggleResetPanel
local RefreshStatsPanel
local resetPendingMode = nil

local function SetResetPanelMode(mode)
    resetPendingMode = mode
    if not frame.resetWarning or not frame.resetConfirmButton or not frame.resetBackButton then
        return
    end

    if mode == "all" then
        frame.resetTitle:SetText("Reset Data")
        frame.resetHelp:SetText("Confirm full reset")
        if frame.resetSelectionFrame then frame.resetSelectionFrame:Hide() end
        if frame.resetBody then
            frame.resetBody:SetText("Delete all tracked data from FarmWise.")
            frame.resetBody:Show()
        end
        frame.resetWarning:SetText("Warning: This will permanently delete all tracked data. This action cannot be undone.")
        frame.resetWarning:Show()
        if frame.resetFooterDivider then frame.resetFooterDivider:Show() end
        if frame.resetFooter then frame.resetFooter:Show() end
        frame.resetConfirmButton:Show()
        frame.resetBackButton:Show()
        if frame.confirmCancelButton then frame.confirmCancelButton:Hide() end
    elseif mode == "zone" then
        local zoneName = currentZone or "Unknown"
        frame.resetTitle:SetText("Reset Data")
        frame.resetHelp:SetText("Confirm current zone reset")
        if frame.resetSelectionFrame then frame.resetSelectionFrame:Hide() end
        if frame.resetBody then
            frame.resetBody:SetText("Delete tracked data only for:\n\n" .. zoneName)
            frame.resetBody:Show()
        end
        frame.resetWarning:SetText("Warning: This will permanently delete data for this zone. This action cannot be undone.")
        frame.resetWarning:Show()
        if frame.resetFooterDivider then frame.resetFooterDivider:Show() end
        if frame.resetFooter then frame.resetFooter:Show() end
        frame.resetConfirmButton:Show()
        frame.resetBackButton:Show()
        if frame.confirmCancelButton then frame.confirmCancelButton:Hide() end
    else
        frame.resetTitle:SetText("Reset Data")
        frame.resetHelp:SetText("Choose what data to delete.")
        if frame.resetSelectionFrame then frame.resetSelectionFrame:Show() end
        if frame.resetBody then
            frame.resetBody:SetText("")
            frame.resetBody:Hide()
        end
        frame.resetWarning:Hide()
        if frame.resetFooterDivider then frame.resetFooterDivider:Hide() end
        if frame.resetFooter then frame.resetFooter:Hide() end
        frame.resetConfirmButton:Hide()
        frame.resetBackButton:Hide()
        if frame.confirmCancelButton then
            frame.confirmCancelButton:SetText("Cancel")
            frame.confirmCancelButton:Hide()
        end
    end
end

local function ToggleUtilityBar(forceShown)
    if not utilityButtonEnabled then
        return
    end

    local shouldShow = forceShown
    if shouldShow == nil then
        shouldShow = not frame.utilityBar:IsShown()
    end

    if shouldShow then
        frame.utilityDivider:Show()
        frame.utilityBar:Show()
    else
        frame.utilityDivider:Hide()
        frame.utilityBar:Hide()
        ToggleOptionsPanel(false)
        ToggleStatsPanel(false)
        ToggleResetPanel(false)
    end

    local left = frame:GetLeft()
    local top = frame:GetTop()

    frame:SetSize(WINDOW_WIDTH, GetCurrentWindowHeight())
    ApplyBottomLayout()

    if left and top then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

local function SetMenuButtonEnabled(enabled)
    utilityButtonEnabled = enabled
    frame.toolsButton:EnableMouse(enabled)
    if frame.utilityOptionsButton then
        frame.utilityOptionsButton:EnableMouse(enabled)
    end
    if frame.utilityStatsButton then
        frame.utilityStatsButton:EnableMouse(enabled)
    end
    if frame.utilityLockButton then
        frame.utilityLockButton:EnableMouse(enabled)
    end
    if enabled then
        frame.toolsButton:SetAlpha(1)
        if frame.utilityOptionsButton then
            frame.utilityOptionsButton:SetAlpha(1)
        end
        if frame.utilityStatsButton then
            frame.utilityStatsButton:SetAlpha(1)
        end
        if frame.utilityLockButton then
            frame.utilityLockButton:SetAlpha(1)
        end
    else
        frame.toolsButton:SetAlpha(0.55)
        if frame.utilityOptionsButton then
            frame.utilityOptionsButton:SetAlpha(0.55)
        end
        if frame.utilityStatsButton then
            frame.utilityStatsButton:SetAlpha(0.55)
        end
        if frame.utilityLockButton then
            frame.utilityLockButton:SetAlpha(0.55)
        end
    end
end

local function SetOptionButtonState(button, active)
    local text = button:GetFontString()
    if active then
        button:SetAlpha(1)
        button:Disable()
        if text then
            text:SetTextColor(1, 0.82, 0)
        end
    else
        button:SetAlpha(0.65)
        button:Enable()
        if text then
            text:SetTextColor(0.82, 0.82, 0.82)
        end
    end
end

local function RefreshOptionsPanel()
    local settings = GetSettings()
    if frame.optionsRowsInput and not frame.optionsRowsInput:HasFocus() then
        frame.optionsRowsInput:SetText(tostring(GetVisibleRows()))
        frame.optionsRowsInput:SetCursorPosition(0)
    end
    if frame.optionsIdleInput and not frame.optionsIdleInput:HasFocus() then
        frame.optionsIdleInput:SetText(tostring(settings.idleMinutes))
        frame.optionsIdleInput:SetCursorPosition(0)
    end
    if frame.optionsBackgroundInput and not frame.optionsBackgroundInput:HasFocus() then
        frame.optionsBackgroundInput:SetText(tostring(GetBackgroundTransparency()))
        frame.optionsBackgroundInput:SetCursorPosition(0)
    end
    if frame.optionsAHFreshnessInput and not frame.optionsAHFreshnessInput:HasFocus() then
        frame.optionsAHFreshnessInput:SetText(tostring(GetAHFreshnessMinutes()))
        frame.optionsAHFreshnessInput:SetCursorPosition(0)
    end
    RefreshLockButton()
    SetOptionButtonState(frame.optionsCombatYes, settings.hideOptionsInCombat == true)
    SetOptionButtonState(frame.optionsCombatNo, settings.hideOptionsInCombat == false)
    SetOptionButtonState(frame.optionsLoginYes, settings.showWindowOnLogin == true)
    SetOptionButtonState(frame.optionsLoginNo, settings.showWindowOnLogin == false)
    SetOptionButtonState(frame.optionsWindowCombatYes, settings.hideWindowInCombat == true)
    SetOptionButtonState(frame.optionsWindowCombatNo, settings.hideWindowInCombat == false)
    UpdateAHFreshnessIndicator()
end

ToggleOptionsPanel = function(forceShown)
    local shouldShow = forceShown
    if shouldShow == nil then
        shouldShow = not frame.optionsPanel:IsShown()
    end

    if shouldShow and not (frame.utilityBar and frame.utilityBar:IsShown()) then
        return
    end

    if shouldShow then
        if frame.statsPanel and frame.statsPanel:IsShown() then
            frame.statsPanel:Hide()
        end
        if frame.resetPanel and frame.resetPanel:IsShown() then
            frame.resetPanel:Hide()
        end
        RefreshOptionsPanel()
        frame.optionsPanel:Show()
    else
        frame.optionsPanel:Hide()
    end

    ApplyBottomLayout()
end

ToggleStatsPanel = function(forceShown)
    local shouldShow = forceShown
    if shouldShow == nil then
        shouldShow = not frame.statsPanel:IsShown()
    end

    if shouldShow and not (frame.utilityBar and frame.utilityBar:IsShown()) then
        return
    end

    if shouldShow then
        if frame.optionsPanel and frame.optionsPanel:IsShown() then
            frame.optionsPanel:Hide()
        end
        if frame.resetPanel and frame.resetPanel:IsShown() then
            frame.resetPanel:Hide()
        end
        frame.statsPanel:Show()
        if frame.statsInput then
            frame.statsInput:ClearFocus()
        end
        RefreshStatsPanel()
    else
        frame.statsPanel:Hide()
        if frame.statsInput then
            frame.statsInput:ClearFocus()
        end
    end

    ApplyBottomLayout()
end

ToggleResetPanel = function(forceShown)
    local shouldShow = forceShown
    if shouldShow == nil then
        shouldShow = not frame.resetPanel:IsShown()
    end

    if shouldShow and not (frame.utilityBar and frame.utilityBar:IsShown()) then
        return
    end

    if shouldShow then
        if frame.optionsPanel and frame.optionsPanel:IsShown() then
            frame.optionsPanel:Hide()
        end
        if frame.statsPanel and frame.statsPanel:IsShown() then
            frame.statsPanel:Hide()
        end
        frame.resetPanel:Show()
        SetResetPanelMode(nil)
    else
        SetResetPanelMode(nil)
        frame.resetPanel:Hide()
    end

    ApplyBottomLayout()
end

local function ShowResetConfirm()
    ToggleResetPanel(true)
end

local function HideResetConfirm()
    ToggleResetPanel(false)
end

frame.resetAllModeButton:SetScript("OnClick", function()
    SetResetPanelMode("all")
end)

frame.resetZoneModeButton:SetScript("OnClick", function()
    SetResetPanelMode("zone")
end)

frame.resetCancelModeButton:SetScript("OnClick", function()
    HideResetConfirm()
end)

frame.confirmCancelButton:SetScript("OnClick", function()
    HideResetConfirm()
end)

frame.resetConfirmButton:SetScript("OnClick", function()
    if resetPendingMode == "all" then
        ResetAllData()
        RefreshAfterReset(ADDON_DISPLAY_NAME .. ": All tracked data has been deleted.")
    elseif resetPendingMode == "zone" then
        local zoneName = currentZone or "Unknown"
        ResetCurrentZoneData()
        RefreshAfterReset(ADDON_DISPLAY_NAME .. ": Data for " .. zoneName .. " has been deleted.")
    end
end)

frame.resetBackButton:SetScript("OnClick", function()
    SetResetPanelMode(nil)
end)

frame.toolsButton:SetScript("OnClick", function()
    if not utilityButtonEnabled then
        return
    end

    ToggleUtilityBar()
end)

frame.utilityResetButton:SetScript("OnClick", function()
    ToggleResetPanel()
end)

frame.utilityOptionsButton:SetScript("OnClick", function()
    ToggleOptionsPanel()
end)

frame.utilityStatsButton:SetScript("OnClick", function()
    farmAdvisorMode = FARM_ADVISOR_MODE_SELECT
    ToggleStatsPanel()
end)

frame.statsBackButton:SetScript("OnClick", function()
    farmAdvisorMode = FARM_ADVISOR_MODE_SELECT
    RefreshStatsPanel()
end)

frame.statsItemModeButton:SetScript("OnClick", function()
    farmAdvisorMode = FARM_ADVISOR_MODE_ITEM
    RefreshStatsPanel()
    if frame.statsInput then
        frame.statsInput:SetFocus()
    end
end)

frame.statsGoldModeButton:SetScript("OnClick", function()
    farmAdvisorMode = FARM_ADVISOR_MODE_GOLD
    RefreshStatsPanel()
end)

if frame.utilityAHScanButton then
    frame.utilityAHScanButton:SetScript("OnClick", function()
        if FarmWise and FarmWise.StartAuctionHouseScan then
            FarmWise.StartAuctionHouseScan()
        end
    end)
end

frame.utilityLockButton:SetScript("OnClick", function()
    SetFrameLocked(not IsFrameLocked())
    RefreshLockButton()
end)

local function ApplyIdleMinutesFromInput()
    if not frame.optionsIdleInput then return end

    local rawValue = frame.optionsIdleInput:GetText() or ""
    local numericValue = tonumber(rawValue)
    if not numericValue then
        frame.optionsIdleInput:SetText(tostring(GetSettings().idleMinutes or DEFAULT_SETTINGS.idleMinutes))
        frame.optionsIdleInput:SetCursorPosition(0)
        return
    end

    SetIdleMinutes(numericValue)
    RefreshOptionsPanel()
    frame.optionsIdleInput:ClearFocus()
end

local function ApplyVisibleRowsFromInput()
    if not frame.optionsRowsInput then return end

    local rawValue = frame.optionsRowsInput:GetText() or ""
    local numericValue = tonumber(rawValue)
    if not numericValue then
        frame.optionsRowsInput:SetText(tostring(GetVisibleRows()))
        frame.optionsRowsInput:SetCursorPosition(0)
        return
    end

    SetVisibleRows(numericValue)
    RefreshOptionsPanel()
    ResizeFramePreserveBottom()
    if frame:IsShown() and currentZone ~= "" then
        ShowLoot(currentZone,false)
    end
    frame.optionsRowsInput:ClearFocus()
end

local function ApplyBackgroundTransparencyFromInput()
    if not frame.optionsBackgroundInput then return end

    local rawValue = frame.optionsBackgroundInput:GetText() or ""
    local numericValue = tonumber(rawValue)
    if not numericValue then
        frame.optionsBackgroundInput:SetText(tostring(GetBackgroundTransparency()))
        frame.optionsBackgroundInput:SetCursorPosition(0)
        return
    end

    SetBackgroundTransparency(numericValue)
    ApplyBackgroundTransparency()
    RefreshOptionsPanel()
    frame.optionsBackgroundInput:ClearFocus()
end

frame.optionsIdleSet:SetScript("OnClick", function()
    ApplyIdleMinutesFromInput()
end)

frame.optionsRowsSet:SetScript("OnClick", function()
    ApplyVisibleRowsFromInput()
end)

frame.optionsBackgroundSet:SetScript("OnClick", function()
    ApplyBackgroundTransparencyFromInput()
end)

local function ApplyAHFreshnessFromInput()
    if not frame.optionsAHFreshnessInput then return end

    local rawValue = frame.optionsAHFreshnessInput:GetText() or ""
    local numericValue = tonumber(rawValue)
    if numericValue ~= 15 and numericValue ~= 30 and numericValue ~= 60 then
        frame.optionsAHFreshnessInput:SetText(tostring(GetAHFreshnessMinutes()))
        frame.optionsAHFreshnessInput:SetCursorPosition(0)
        return
    end

    SetAHFreshnessMinutes(numericValue)
    UpdateAHFreshnessIndicator()
    RefreshOptionsPanel()
    frame.optionsAHFreshnessInput:ClearFocus()
end

frame.optionsAHFreshnessSet:SetScript("OnClick", function()
    ApplyAHFreshnessFromInput()
end)

frame.optionsRowsInput:SetScript("OnEnterPressed", function(self)
    ApplyVisibleRowsFromInput()
end)

frame.optionsRowsInput:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(GetVisibleRows()))
    self:SetCursorPosition(0)
    self:ClearFocus()
end)

frame.optionsRowsInput:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)

frame.optionsRowsInput:SetScript("OnEditFocusLost", function(self)
    self:HighlightText(0, 0)
end)

frame.optionsIdleInput:SetScript("OnEnterPressed", function(self)
    ApplyIdleMinutesFromInput()
end)

frame.optionsIdleInput:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(GetSettings().idleMinutes or DEFAULT_SETTINGS.idleMinutes))
    self:SetCursorPosition(0)
    self:ClearFocus()
end)

frame.optionsIdleInput:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)

frame.optionsIdleInput:SetScript("OnEditFocusLost", function(self)
    self:HighlightText(0, 0)
end)

frame.optionsBackgroundInput:SetScript("OnEnterPressed", function(self)
    ApplyBackgroundTransparencyFromInput()
end)

frame.optionsBackgroundInput:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then return end
    local textValue = self:GetText() or ""
    if textValue == "" then return end
    local numericValue = tonumber(textValue)
    if not numericValue then
        self:SetText("")
        return
    end
    if numericValue > 100 then
        self:SetText("100")
        self:SetCursorPosition(string.len("100"))
    end
end)

frame.optionsBackgroundInput:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(GetBackgroundTransparency()))
    self:SetCursorPosition(0)
    self:ClearFocus()
end)

frame.optionsBackgroundInput:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)

frame.optionsBackgroundInput:SetScript("OnEditFocusLost", function(self)
    self:HighlightText(0, 0)
end)

frame.optionsCombatYes:SetScript("OnClick", function()
    GetSettings().hideOptionsInCombat = true
    RefreshOptionsPanel()
end)

frame.optionsCombatNo:SetScript("OnClick", function()
    GetSettings().hideOptionsInCombat = false
    RefreshOptionsPanel()
end)

frame.optionsLoginYes:SetScript("OnClick", function()
    GetSettings().showWindowOnLogin = true
    RefreshOptionsPanel()
end)

frame.optionsLoginNo:SetScript("OnClick", function()
    GetSettings().showWindowOnLogin = false
    RefreshOptionsPanel()
end)

frame.optionsWindowCombatYes:SetScript("OnClick", function()
    GetSettings().hideWindowInCombat = true
    RefreshOptionsPanel()
end)

frame.optionsWindowCombatNo:SetScript("OnClick", function()
    GetSettings().hideWindowInCombat = false
    RefreshOptionsPanel()
end)

local function CleanStatsDisplayText(textValue)
    local plain = tostring(textValue or "")
    plain = plain:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    plain = plain:gsub("|Hitem:.-|h(.-)|h", "%1")
    plain = plain:gsub("|h", "")
    plain = plain:gsub("|A:.-|a", "")
    plain = plain:gsub("^%[+", "")
    plain = plain:gsub("%]+$", "")
    plain = plain:gsub("^%s*%[", "")
    plain = plain:gsub("%]%s*$", "")
    plain = plain:gsub("^%[([^%]]+)$", "%1")
    plain = plain:gsub("^%[([^%]]+)%]$", "%1")
    plain = plain:gsub("^%s+", ""):gsub("%s+$", "")
    plain = plain:gsub("%s+", " ")
    return plain
end

local function CleanStatsTypingText(textValue)
    local plain = tostring(textValue or "")
    local hadTrailingSpace = plain:match("%s$") ~= nil
    plain = plain:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    plain = plain:gsub("|Hitem:.-|h(.-)|h", "%1")
    plain = plain:gsub("|h", "")
    plain = plain:gsub("|A:.-|a", "")
    plain = plain:gsub("^%[+", "")
    plain = plain:gsub("%]+$", "")
    plain = plain:gsub("^%s*%[", "")
    plain = plain:gsub("%]%s*$", "")
    plain = plain:gsub("^%[([^%]]+)$", "%1")
    plain = plain:gsub("^%[([^%]]+)%]$", "%1")
    plain = plain:gsub("^%s+", "")
    plain = plain:gsub("%s+", " ")
    if not hadTrailingSpace then
        plain = plain:gsub("%s+$", "")
    end
    return plain
end

local function NormalizeTrackedItemName(name)
    if not name then return "" end
    name = CleanStatsDisplayText(name)
    name = name:gsub("%s*%([Qq]%d+%)$", "")
    name = name:gsub("%s+[Qq]uality%s*%d+$", "")
    name = name:gsub("%s+[Qq]%d+$", "")
    name = name:gsub("%s+%d+$", "")
    return strlower(name)
end

local function ParseStatsItemQuery(textValue)
    if not textValue or textValue == "" then
        return nil, nil, nil, nil
    end

    local plain = CleanStatsDisplayText(textValue)
    if plain == "" then
        return nil, nil, nil, nil
    end

    local typedQuality = plain:match("%(([Qq]%d+)%)$")
        or plain:match("([Qq]%d+)$")
        or plain:match("[Qq]uality%s*(%d+)$")
        or plain:match("%s(%d+)$")
    if typedQuality then
        if typedQuality:match("^%d+$") then
            typedQuality = "Q" .. typedQuality
        end
        typedQuality = string.upper(typedQuality)
    end

    if not typedQuality or typedQuality == "" then
        return nil, plain, nil, plain
    end

    if statsExactItemID and statsAutoFilledText and plain == CleanStatsDisplayText(statsAutoFilledText) then
        local itemName = GetItemInfo(statsExactItemID) or NormalizeTrackedItemName(plain)
        return statsExactItemID, itemName, statsExactQuality or typedQuality, plain
    end

    local itemID = tonumber(tostring(textValue):match("item:(%d+)"))
    if itemID then
        local itemName = GetItemInfo(itemID)
        return itemID, itemName, typedQuality, plain
    end

    return nil, plain, typedQuality, plain
end


local function BuildStatsResults(queryText)
    local itemID, itemName, qualityLabel = ParseStatsItemQuery(queryText)
    if not itemID and (not itemName or itemName == "") then
        return {}
    end

    local normalizedName = NormalizeTrackedItemName(itemName)
    local results = {}

    for zoneName, data in pairs(FarmWiseDB) do
        if type(data) == "table" and data.items then
            ResetDailyDataIfNeeded(zoneName)

            local totalCount = 0
            local matchedName = itemName

            for _, info in pairs(data.items) do
                local matches = false
                if itemID then
                    matches = (info.id == itemID)
                elseif normalizedName ~= "" then
                    matches = (NormalizeTrackedItemName(info.name) == normalizedName)
                end

                if matches and qualityLabel and qualityLabel ~= "" then
                    matches = (string.upper(info.quality or "") == qualityLabel)
                end

                if matches then
                    totalCount = totalCount + (info.count or 0)
                    matchedName = info.name
                end
            end

            if totalCount > 0 then
                local totalTime = select(1, GetDisplayedTimes(zoneName))
                if totalTime >= STATS_MIN_TIME_SECONDS then
                    local perHour = 0
                    if totalTime > 0 then
                        perHour = math.floor((totalCount / totalTime) * 3600)
                    end

                    table.insert(results, {
                    zone = zoneName,
                    totalTime = totalTime,
                    count = totalCount,
                    perHour = perHour,
                        itemName = matchedName
                    })
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.perHour == b.perHour then
            if a.count == b.count then
                return a.zone < b.zone
            end
            return a.count > b.count
        end
        return a.perHour > b.perHour
    end)

    return results
end

local function BuildGoldStatsResults()
    local results = {}
    local ahStore = FarmWise.GetAuctionDataStore and FarmWise.GetAuctionDataStore() or nil
    local ahItems = ahStore and ahStore.items or {}

    for zoneName, data in pairs(FarmWiseDB) do
        if type(data) == "table" and data.items then
            local totalTime = select(1, GetDisplayedTimes(zoneName))
            if totalTime >= STATS_MIN_TIME_SECONDS then
                local totalCopper = 0
                local pricedItems = 0
                local trackedItems = 0
                for _, info in pairs(data.items) do
                    local itemID = tonumber(info.id)
                    local count = tonumber(info.count) or 0
                    if itemID and count > 0 then
                        trackedItems = trackedItems + 1
                        local priceRecord = ahItems[tostring(itemID)]
                        local unitPrice = priceRecord and tonumber(priceRecord.unitPrice or priceRecord.price)
                        if unitPrice and unitPrice > 0 then
                            totalCopper = totalCopper + (unitPrice * count)
                            pricedItems = pricedItems + 1
                        end
                    end
                end
                if totalCopper > 0 and totalTime > 0 and pricedItems > 0 then
                    local copperPerHour = math.floor((totalCopper / totalTime) * 3600)
                    table.insert(results, {
                        zone = zoneName,
                        totalTime = totalTime,
                        goldPerHour = copperPerHour,
                        pricedItems = pricedItems,
                        trackedItems = trackedItems,
                    })
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.goldPerHour == b.goldPerHour then
            return a.zone < b.zone
        end
        return a.goldPerHour > b.goldPerHour
    end)

    return results
end

local function UpdateFarmAdvisorModeUI()
    if not frame.statsPanel then return end
    local mode = farmAdvisorMode or FARM_ADVISOR_MODE_SELECT
    local showSelect = mode == FARM_ADVISOR_MODE_SELECT
    local showItem = mode == FARM_ADVISOR_MODE_ITEM
    local showGold = mode == FARM_ADVISOR_MODE_GOLD

    frame.statsTitle:SetText("Advisor")
    frame.statsSelectionFrame:SetShown(showSelect)
    frame.statsItemModeButton:SetShown(showSelect)
    frame.statsItemModeDescription:SetShown(showSelect)
    frame.statsSelectionSeparator:SetShown(showSelect)
    frame.statsGoldModeButton:SetShown(showSelect)
    frame.statsGoldModeDescription:SetShown(showSelect)
    frame.statsInput:SetShown(showItem)
    frame.statsClearButton:SetShown(showItem)
    frame.statsBackButton:SetShown(not showSelect)
    frame.statsFooterDivider:SetShown(not showSelect)
    frame.statsFooter:SetShown(not showSelect)
    frame.statsScroll:SetShown(not showSelect)

    if showSelect then
        frame.statsHelp:SetText("Choose what you want to analyze.")
        frame.statsHint:Hide()
        for _, row in ipairs(frame.statsRows) do row:Hide() end
        frame.statsContent:SetHeight(132)
        return
    elseif showItem then
        frame.statsHelp:SetText("Top zone results for one tracked item by hourly yield.")
        SetStatsScrollAnchorToInput()
        frame.statsHint:Hide()
        if frame.statsInput.Instructions and (frame.statsInput:GetText() or "") == "" then
            frame.statsInput.Instructions:Show()
        end
    elseif showGold then
        frame.statsHelp:SetText("Top zone results by gold/hour from Auctionator prices.")
        SetStatsScrollAnchorToDivider()
        frame.statsHint:Hide()
        if frame.statsInput.Instructions then frame.statsInput.Instructions:Hide() end
    end
end

RefreshStatsPanel = function()
    if not frame.statsPanel then return end

    UpdateFarmAdvisorModeUI()

    if farmAdvisorMode == FARM_ADVISOR_MODE_SELECT then
        return
    end

    for _, row in ipairs(frame.statsRows) do
        row:Hide()
        if row.divider then
            row.divider:Show()
        end
    end

    if farmAdvisorMode == FARM_ADVISOR_MODE_GOLD then
        local results = BuildGoldStatsResults()
        if #results == 0 then
            frame.statsHint:SetText("No synced Auctionator prices available for tracked zone data (15m+ farming time).")
            frame.statsHint:Show()
            frame.statsContent:SetHeight(ADVISOR_VISIBLE_RESULTS * ADVISOR_ROW_PITCH)
            return
        end

        frame.statsHint:Hide()
        local shown = 0
        for i, result in ipairs(results) do
            local row = frame.statsRows[i]
            if row then
                row.zoneText:SetText(result.zone)
                row.statsText:SetText(string.format("Farming time: %s\nPriced items: %d/%d\nEstimated gold/hour: %s", FormatStatsTime(result.totalTime), result.pricedItems, result.trackedItems, FormatGoldEstimateText(result.goldPerHour)))
                row:Show()
                shown = i
            end
        end
        local contentHeight = shown * ADVISOR_ROW_PITCH
        local minContentHeight = ADVISOR_VISIBLE_RESULTS * ADVISOR_ROW_PITCH
        if contentHeight < minContentHeight then contentHeight = minContentHeight end
        frame.statsContent:SetHeight(contentHeight)
        return
    end

    local queryText = frame.statsInput:GetText() or ""
    local hasQuery = queryText ~= ""
    local results = BuildStatsResults(queryText)

    if not hasQuery then
        frame.statsHint:Hide()
        frame.statsContent:SetHeight(ADVISOR_VISIBLE_RESULTS * ADVISOR_ROW_PITCH)
        return
    end

    if #results == 0 then
        frame.statsHint:SetText("No tracked zone data found (15m+ farming time).")
        frame.statsHint:Show()
        frame.statsContent:SetHeight(ADVISOR_VISIBLE_RESULTS * ADVISOR_ROW_PITCH)
        return
    end

    frame.statsHint:Hide()
    local shown = 0
    for i, result in ipairs(results) do
        local row = frame.statsRows[i]
        if row then
            row.zoneText:SetText(result.zone)
            row.statsText:SetText(string.format("Farming time: %s\nGathered items: %d items\nAverage yield: %d/hour", FormatStatsTime(result.totalTime), result.count, result.perHour))
            row:Show()
            shown = i
        end
    end
    local contentHeight = shown * ADVISOR_ROW_PITCH
    local minContentHeight = ADVISOR_VISIBLE_RESULTS * ADVISOR_ROW_PITCH
    if contentHeight < minContentHeight then contentHeight = minContentHeight end
    frame.statsContent:SetHeight(contentHeight)
end

frame.statsInput:SetScript("OnTextChanged", function(self, userInput)
    local textValue = self:GetText() or ""

    if userInput and statsPendingSmartBackspace then
        local targetText = statsPendingSmartBackspace
        statsPendingSmartBackspace = nil
        statsExactItemID = nil
        statsExactQuality = nil
        statsAutoFilledText = nil
        if textValue ~= targetText then
            statsInternalTextUpdate = true
            self:SetText(targetText)
            self:SetCursorPosition(string.len(targetText))
            statsInternalTextUpdate = false
            textValue = targetText
        end
    end

    local cursorPosition = self:GetCursorPosition() or string.len(textValue)
    local cleanedImmediate = userInput and CleanStatsTypingText(textValue) or CleanStatsDisplayText(textValue)
    if cleanedImmediate ~= textValue then
        local newCursorPosition = cursorPosition - (string.len(textValue) - string.len(cleanedImmediate))
        if newCursorPosition < 0 then
            newCursorPosition = 0
        elseif newCursorPosition > string.len(cleanedImmediate) then
            newCursorPosition = string.len(cleanedImmediate)
        end

        statsInternalTextUpdate = true
        self:SetText(cleanedImmediate)
        self:SetCursorPosition(newCursorPosition)
        statsInternalTextUpdate = false
        textValue = cleanedImmediate
    end

    if self.Instructions then
        if textValue == "" then
            self.Instructions:Show()
        else
            self.Instructions:Hide()
        end
    end

    if userInput and not statsInternalTextUpdate then
        local plain = CleanStatsDisplayText(textValue)
        if not statsAutoFilledText or plain ~= CleanStatsDisplayText(statsAutoFilledText) then
            statsExactItemID = nil
            statsExactQuality = nil
            statsAutoFilledText = nil
        end
    end

    RefreshStatsPanel()
end)

frame.statsInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)


frame.statsInput:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
end)

frame.statsInput:SetScript("OnKeyDown", function(self, key)
    if key ~= "BACKSPACE" then
        statsPendingSmartBackspace = nil
        return
    end

    local textValue = self:GetText() or ""
    if textValue == "" then
        statsPendingSmartBackspace = nil
        return
    end

    local cursorPosition = self:GetCursorPosition()
    if cursorPosition ~= string.len(textValue) then
        statsPendingSmartBackspace = nil
        return
    end

    local trimmedText = CleanStatsDisplayText(textValue)
    local withoutQuality = trimmedText:gsub("%s*%([Qq]%d+%)$", "")
    if withoutQuality == trimmedText then
        withoutQuality = trimmedText:gsub("%s+[Qq]%d+$", "")
    end
    if withoutQuality == trimmedText then
        withoutQuality = trimmedText:gsub("%s+[Qq]uality%s*%d+$", "")
    end
    if withoutQuality == trimmedText then
        withoutQuality = trimmedText:gsub("%s+%d+$", "")
    end
    if withoutQuality == trimmedText then
        statsPendingSmartBackspace = nil
        return
    end

    statsPendingSmartBackspace = withoutQuality
end)

local function StatsInputCanAcceptLink()
    return frame
        and frame.statsPanel
        and frame.statsPanel:IsShown()
        and frame.statsInput
        and frame.statsInput:HasFocus()
end

local function ExtractQualityLabelFromLink(textValue)
    if not textValue or textValue == "" then
        return nil
    end

    local tier = textValue:match("Quality%-%d+%-Tier(%d+)")
        or textValue:match("Professions%-ChatIcon%-Quality%-Tier(%d+)")
        or textValue:match("%((Q%d+)%)")

    if not tier then
        return nil
    end

    if type(tier) == "string" and tier:match("^Q%d+$") then
        return tier
    end

    return "Q" .. tostring(tier)
end

local function ExtractDisplayNameFromLink(textValue, fallbackName)
    local sourceText = tostring(textValue or "")

    if fallbackName and fallbackName ~= "" then
        return CleanStatsDisplayText(fallbackName)
    end

    local bracketName = sourceText:match("|h%[(.-)%]|h") or sourceText:match("%[(.-)%]")
    if bracketName and bracketName ~= "" then
        bracketName = bracketName:gsub("|A:.-|a", "")
        bracketName = CleanStatsDisplayText(bracketName)
        if bracketName ~= "" then
            return bracketName
        end
    end

    local plain = CleanStatsDisplayText(sourceText)
    if plain ~= "" and not plain:match("^item:") and not plain:match("^%d+:") then
        return plain
    end

    return ""
end

local function InsertStatsItemLink(textValue)
    if not StatsInputCanAcceptLink() then
        return false
    end

    local sourceText = tostring(textValue or "")
    local itemID = tonumber(sourceText:match("item:(%d+)")) or tonumber(sourceText:match("^(%d+):"))
    local displayText = sourceText

    if itemID then
        local itemName = GetItemInfo(itemID) or GetItemInfo(sourceText) or ""
        local qualityLabel = ExtractQualityLabelFromLink(sourceText)
        itemName = ExtractDisplayNameFromLink(sourceText, itemName)
        if itemName == "" then
            return false
        end
        if qualityLabel and qualityLabel ~= "" then
            displayText = string.format("%s (%s)", itemName, qualityLabel)
        else
            displayText = itemName
        end
        statsExactItemID = nil
        statsExactQuality = nil
        statsAutoFilledText = nil
    else
        displayText = ExtractDisplayNameFromLink(displayText)
        if displayText == "" then
            return false
        end
        statsExactItemID = nil
        statsExactQuality = nil
        statsAutoFilledText = nil
    end

    displayText = CleanStatsDisplayText(displayText)
    displayText = displayText:gsub("^%[", ""):gsub("%]$", "")
    frame.statsInput:SetText(displayText)
    frame.statsInput:SetFocus()
    frame.statsInput:HighlightText(0, 0)
    frame.statsInput:SetCursorPosition(string.len(displayText or ""))
    RefreshStatsPanel()
    return true
end

local OriginalChatEdit_InsertLink = ChatEdit_InsertLink
ChatEdit_InsertLink = function(textValue)
    if InsertStatsItemLink(textValue) then
        return true
    end

    return OriginalChatEdit_InsertLink(textValue)
end

if HandleModifiedItemClick then
    local OriginalHandleModifiedItemClick = HandleModifiedItemClick
    HandleModifiedItemClick = function(link, ...)
        if InsertStatsItemLink(link) then
            return true
        end

        return OriginalHandleModifiedItemClick(link, ...)
    end
end


------------------------------------------------
-- Show loot
------------------------------------------------

------------------------------------------------
function ShowLoot(zone,allZones)
    for _,line in ipairs(frame.lines) do
        line:Hide()
    end
    wipe(frame.lines)

    if frame.columnSeparators then
        for _,sep in ipairs(frame.columnSeparators) do
            sep:Hide()
        end
    end
    frame.columnSeparators = {}

    local linesData = {}
    local footerGoldOverall = 0
    local footerGoldDaily = 0

    local function AddZone(zname,data)
        ResetDailyDataIfNeeded(zname)

        local totalTime, dailyTime = GetDisplayedTimes(zname)

        if zname == currentZone then
            frame.session:SetText(
                zname.."\n"
                .."Total: "..FormatTime(totalTime)
                .."   Daily: "..FormatTime(dailyTime)
            )
        end

        footerGoldOverall = footerGoldOverall + (data.gold or 0)
        footerGoldDaily = footerGoldDaily + ((data.daily and data.daily.gold) or 0)

        local sortedItems = {}
        for _,info in pairs(data.items) do
            table.insert(sortedItems, info)
        end

        table.sort(sortedItems, function(a,b)
            if a.name == b.name then
                local qa = tonumber(a.quality:match("%d+")) or 0
                local qb = tonumber(b.quality:match("%d+")) or 0
                return qa < qb
            end
            return a.name < b.name
        end)

        for _,info in ipairs(sortedItems) do
            local perHour = 0
            if totalTime > 0 then
                perHour = math.floor((info.count / totalTime) * 3600)
            end

            local dailyCount = 0
            if data.daily.items and data.daily.items[info.id.."|"..info.quality] then
                dailyCount = data.daily.items[info.id.."|"..info.quality]
            end

            table.insert(linesData,{
                type="item",
                info=info,
                perHour=perHour,
                currentCount=dailyCount
            })
        end
    end

    if allZones then
        UpdateIdleVisual()
        for zname,data in pairs(FarmWiseDB) do
            if type(data) == "table" and data.items then
                AddZone(zname,data)
            end
        end
    else
        AddZone(zone,GetZoneData(zone))
    end

    ------------------------------------------------
    -- Dynamic column widths
    ------------------------------------------------
    local colWidths = {}
    local padding = 10

    for i=1,#headerTitles do
        frame.measureFS:SetText(headerTitles[i])
        local maxWidth = frame.measureFS:GetStringWidth()
        local measureTarget = (i >= 3 and i <= 5) and frame.measureFSNumeric or frame.measureFS

        for _,lineData in ipairs(linesData) do
            local val = ""
            if i == 1 then
                val = lineData.info.name
            elseif i == 2 then
                val = lineData.info.quality
            elseif i == 3 then
                val = tostring(lineData.info.count)
            elseif i == 4 then
                if lineData.currentCount and lineData.currentCount > 0 then
                    val = tostring(lineData.currentCount)
                end
            elseif i == 5 then
                val = tostring(lineData.perHour)
            end

            measureTarget:SetText(val)
            maxWidth = math.max(maxWidth, measureTarget:GetStringWidth())
        end

        colWidths[i] = math.max(maxWidth + padding, MIN_COLUMN_WIDTHS[i] or 0)
    end

    -- Set header positions
    local offsetX = 0
    for i, h in ipairs(frame.headerStrings) do
        local headerOffset = headerOffsets[i] or 0
        local headerAlignment = headerAlignments[i] or "LEFT"

        h:SetWidth(colWidths[i])
        h:SetPoint("LEFT", frame.headerFrame, "LEFT", offsetX + headerOffset, 0)
        h:SetJustifyH(headerAlignment)

        offsetX = offsetX + colWidths[i]
    end

    local separatorOffsetX = 0
    for i = 1, #colWidths do
        separatorOffsetX = separatorOffsetX + colWidths[i]

        local headerSep = frame.headerFrame:CreateTexture(nil, "ARTWORK")
        headerSep:SetWidth(1)
        headerSep:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
        headerSep:SetPoint("TOPLEFT", frame.headerFrame, "TOPLEFT", separatorOffsetX - 2, 0)
        headerSep:SetPoint("BOTTOMLEFT", frame.headerFrame, "BOTTOMLEFT", separatorOffsetX - 2, 0)
        table.insert(frame.columnSeparators, headerSep)
    end

    ------------------------------------------------
    -- Draw lines
    ------------------------------------------------
    local y = 0
    for _, lineData in ipairs(linesData) do
        local info = lineData.info

        local lineFrame = CreateFrame("Frame", nil, frame.content)
        lineFrame:SetHeight(16)
        lineFrame:SetWidth(frame.headerFrame:GetWidth())
        lineFrame:SetPoint("TOPLEFT", 0, -y)

        local offsetX = 0

        local fsName = lineFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fsName:SetWidth(colWidths[1])
        fsName:SetPoint("LEFT", lineFrame, "LEFT", offsetX, 0)
        fsName:SetJustifyH("LEFT")
        fsName:SetText(info.name)
        offsetX = offsetX + colWidths[1]

        local fsQuality = lineFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fsQuality:SetWidth(colWidths[2])
        fsQuality:SetPoint("LEFT", lineFrame, "LEFT", offsetX, 0)
        fsQuality:SetJustifyH("CENTER")
        fsQuality:SetText(info.quality)
        offsetX = offsetX + colWidths[2]

        local dataColumnInset = 5

        local fsCount = lineFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        fsCount:SetWidth(colWidths[3] - dataColumnInset)
        fsCount:SetPoint("LEFT", lineFrame, "LEFT", offsetX, 0)
        fsCount:SetJustifyH("RIGHT")
        fsCount:SetText(tostring(info.count))
        offsetX = offsetX + colWidths[3]

        local fsCurrent = lineFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        fsCurrent:SetWidth(colWidths[4] - dataColumnInset)
        fsCurrent:SetPoint("LEFT", lineFrame, "LEFT", offsetX, 0)
        fsCurrent:SetJustifyH("RIGHT")
        if lineData.currentCount and lineData.currentCount > 0 then
            fsCurrent:SetText(tostring(lineData.currentCount))
        else
            fsCurrent:SetText("")
        end
        offsetX = offsetX + colWidths[4]

        local fsPerHour = lineFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        fsPerHour:SetWidth(colWidths[5] - dataColumnInset)
        fsPerHour:SetPoint("LEFT", lineFrame, "LEFT", offsetX, 0)
        fsPerHour:SetJustifyH("RIGHT")
        fsPerHour:SetText(tostring(lineData.perHour))
        offsetX = offsetX + colWidths[5]

        local lineSeparatorOffsetX = 0
        for i = 1, #colWidths do
            lineSeparatorOffsetX = lineSeparatorOffsetX + colWidths[i]

            local sep = lineFrame:CreateTexture(nil, "ARTWORK")
            sep:SetWidth(1)
            sep:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
            sep:SetPoint("TOPLEFT", lineFrame, "TOPLEFT", lineSeparatorOffsetX - 2, 0)
            sep:SetPoint("BOTTOMLEFT", lineFrame, "BOTTOMLEFT", lineSeparatorOffsetX - 2, 0)
        end

        local r, g, b = GetItemQualityColor(info.itemQuality)
        fsName:SetTextColor(r, g, b)
        fsQuality:SetTextColor(r, g, b)
        fsCount:SetTextColor(r, g, b)
        fsCurrent:SetTextColor(r, g, b)
        fsPerHour:SetTextColor(r, g, b)

        table.insert(frame.lines, lineFrame)
        y = y + 16
    end

    frame.content:SetHeight(y)

    frame.footerText:SetText(GetFooterMoneyText(footerGoldOverall, footerGoldDaily))
    UpdateAHFreshnessIndicator()

    frame:SetSize(WINDOW_WIDTH, GetCurrentWindowHeight())
    frame:Show()
end

------------------------------------------------
-- Chat banner / slash help
------------------------------------------------
local function GetAddonVersionString()
    local version = ""

    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ""
    elseif GetAddOnMetadata then
        version = GetAddOnMetadata(ADDON_NAME, "Version") or ""
    end

    if not version or version == "" then
        return ""
    end

    return tostring(version)
end

local function RefreshFrameTitle()
    local version = GetAddonVersionString()
    if version ~= "" then
        frame.title:SetText(ADDON_DISPLAY_NAME .. " |cffFF7F7Fv" .. version .. "|r")
    else
        frame.title:SetText(ADDON_DISPLAY_NAME)
    end
end

RefreshFrameTitle()

local function PrintAddonChatBanner()
    local title = "|cffFFD100" .. ADDON_DISPLAY_NAME .. ":|r"
    local version = GetAddonVersionString()
    local versionText = ""
    if version ~= "" then
        versionText = " |cffFFB347[Version " .. version .. "]|r"
    end
    local loaded = " |cffffffffloaded:|r"
    local commands = " |cff33CCFF/fw show|r, |cff33CCFF/fw hide|r, |cff33CCFF/fw help|r"
    DEFAULT_CHAT_FRAME:AddMessage(title .. versionText .. loaded .. commands)
end

local function PrintAddonSlashHelp()
    print("|cffFFD100" .. ADDON_DISPLAY_NAME .. "|r commands:")
    print("  |cff33CCFF/fw show|r  - show current zone loot")
    print("  |cff33CCFF/fw hide|r  - hide the " .. ADDON_DISPLAY_NAME .. " window")
    print("  |cff33CCFF/fw toggle|r - toggle the " .. ADDON_DISPLAY_NAME .. " window")
    print("  |cff33CCFF/fw show all|r - show all zones loot")
    print("  |cff33CCFF/fw clear|r - clear all data")
    print("  |cff33CCFF/fw help|r - show this help")
end

------------------------------------------------
-- Events
------------------------------------------------
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_MONEY")
frame:RegisterEvent("MAIL_SHOW")
frame:RegisterEvent("MAIL_CLOSED")
frame:RegisterEvent("TRADE_SHOW")
frame:RegisterEvent("TRADE_CLOSED")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

local function ClearLootIgnoreState()
    mailboxOpen = false
    tradeOpen = false
    auctionHouseOpen = false
end

local function IsUiFrameOpen(frameRef)
    return frameRef and frameRef.IsShown and frameRef:IsShown()
end

local function ShouldIgnoreLootMessages()
    if mailboxOpen and not IsUiFrameOpen(MailFrame) then
        mailboxOpen = false
    end

    if tradeOpen and not IsUiFrameOpen(TradeFrame) then
        tradeOpen = false
    end

    local auctionFrame = AuctionHouseFrame or AuctionFrame
    if auctionHouseOpen and not IsUiFrameOpen(auctionFrame) then
        auctionHouseOpen = false
    end

    return mailboxOpen or tradeOpen or auctionHouseOpen
end

frame:SetScript("OnEvent", function(self,event,msg)
    if event=="PLAYER_LOGIN" then
        ClearLootIgnoreState()
        GetSettings()
        RestoreSavedFramePosition()
        ApplyBackgroundTransparency()
        RefreshFrameTitle()
        currentZone = GetCurrentZoneName()
        ZoneRuntimeDB = {}
        StartZoneSession()
        UpdateIdleVisual()
        SetMenuButtonEnabled(true)
        RefreshOptionsPanel()
        if GetSettings().showWindowOnLogin then
            C_Timer.After(1, function()
                RestoreSavedFramePosition()
                ShowLoot(currentZone,false)
            end)
        else
            frame:Hide()
        end
        C_Timer.After(0.2, PrintAddonChatBanner)
    elseif event=="PLAYER_LOGOUT" then
        SaveCurrentFramePosition()
        EndZoneSession(currentZone)
    elseif event=="MAIL_SHOW" then
        mailboxOpen = true
    elseif event=="MAIL_CLOSED" then
        mailboxOpen = false
    elseif event=="TRADE_SHOW" then
        tradeOpen = true
    elseif event=="TRADE_CLOSED" then
        tradeOpen = false
    elseif event=="AUCTION_HOUSE_SHOW" then
        auctionHouseOpen = true
    elseif event=="AUCTION_HOUSE_CLOSED" then
        auctionHouseOpen = false
    elseif event=="CHAT_MSG_LOOT" then
        if ShouldIgnoreLootMessages() then
            return
        end
        local itemLink = msg and string.match(msg, "|Hitem:.-|h.-|h")
        if itemLink then
            local quantity = tonumber(msg and string.match(msg, "x(%d+)")) or 1
            AddLootItem(itemLink,quantity)
        else
            local copper = ExtractMoneyFromMessage(msg)
            if copper > 0 then
                AddLootMoney(copper)
            end
        end
    elseif event=="CHAT_MSG_MONEY" then
        if ShouldIgnoreLootMessages() then
            return
        end
        local copper = ExtractMoneyFromMessage(msg)
        if copper > 0 then
            AddLootMoney(copper)
        end
    elseif event=="PLAYER_REGEN_DISABLED" then
        ClearLootIgnoreState()
        if currentZone ~= "" then
            RegisterZoneActivity(currentZone)
            UpdateIdleVisual()
        end

        utilityWasOpenBeforeCombat = false
        optionsWasOpenBeforeCombat = false
        statsWasOpenBeforeCombat = false
        frameWasShownBeforeCombat = frame:IsShown()

        if GetSettings().hideOptionsInCombat then
            utilityWasOpenBeforeCombat = frame.utilityBar and frame.utilityBar:IsShown() or false
            optionsWasOpenBeforeCombat = frame.optionsPanel and frame.optionsPanel:IsShown() or false
            statsWasOpenBeforeCombat = frame.statsPanel and frame.statsPanel:IsShown() or false
            if utilityWasOpenBeforeCombat then
                ToggleUtilityBar(false)
            else
                ToggleOptionsPanel(false)
                ToggleStatsPanel(false)
            end
            SetMenuButtonEnabled(false)
        end

        if GetSettings().hideWindowInCombat and frameWasShownBeforeCombat then
            windowHiddenByCombat = true
            frame:Hide()
        else
            windowHiddenByCombat = false
        end
    elseif event=="PLAYER_REGEN_ENABLED" then
        if windowHiddenByCombat and GetSettings().hideWindowInCombat then
            if currentZone and currentZone ~= "" then
                ShowLoot(currentZone, false)
            else
                frame:Show()
            end
        end
        frameWasShownBeforeCombat = false
        windowHiddenByCombat = false
        SetMenuButtonEnabled(true)
        utilityWasOpenBeforeCombat = false
        optionsWasOpenBeforeCombat = false
        statsWasOpenBeforeCombat = false
    elseif event=="ZONE_CHANGED_NEW_AREA" or event=="ZONE_CHANGED" or event=="ZONE_CHANGED_INDOORS" then
        ClearLootIgnoreState()
        local newZone = GetCurrentZoneName()
        if newZone ~= currentZone then
            EndZoneSession(currentZone)
            currentZone = newZone
            StartZoneSession()
            UpdateIdleVisual()
            if frame:IsShown() then ShowLoot(currentZone,false) end
        end
    end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    refreshElapsed = refreshElapsed + elapsed
    flashElapsed = flashElapsed + elapsed

    local runtime = ZoneRuntimeDB[currentZone]
    if runtime and runtime.idle and frame.idleLabel:IsShown() then
        local alpha = 0.45 + (0.55 * math.abs(math.sin(flashElapsed * 2)))
        frame.idleLabel:SetAlpha(alpha)
    else
        frame.idleLabel:SetAlpha(1)
    end

    if refreshElapsed < REFRESH_INTERVAL_SECONDS then
        return
    end

    refreshElapsed = 0

    if currentZone ~= "" then
        UpdateIdleState()
        ResetDailyDataIfNeeded(currentZone)
        UpdateIdleVisual()
    end

    if frame:IsShown() and currentZone ~= "" then
        ShowLoot(currentZone,false)
    end

    UpdateAHFreshnessIndicator()

    if frame.statsPanel and frame.statsPanel:IsShown() then
        RefreshStatsPanel()
    end
end)




------------------------------------------------
-- Slash commands

------------------------------------------------
SLASH_FARMWISE1 = "/fw"
SlashCmdList["FARMWISE"] = function(msg)
    msg = string.lower((msg or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    if msg=="toggle" or msg=="" then
        if frame:IsShown() then
            frame:Hide()
        else
            if currentZone and currentZone ~= "" then
                ShowLoot(currentZone,false)
            else
                frame:Show()
            end
        end
    elseif msg=="show all" then
        ShowLoot(nil,true)
    elseif msg=="show" then
        ShowLoot(GetCurrentZoneName(),false)
    elseif msg=="hide" then
        frame:Hide()
    elseif msg=="help" then
        PrintAddonSlashHelp()
    elseif msg=="clear" then
        ResetAllData()
        if frame:IsShown() and currentZone ~= "" then
            ShowLoot(currentZone,false)
        end
        print(ADDON_DISPLAY_NAME .. ": All data cleared.")
    else
        PrintAddonSlashHelp()
    end
end
