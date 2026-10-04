local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

local CONTROL_PANEL_CONFIG = (FWR.UI_CONFIG and FWR.UI_CONFIG.ControlPanelWindow) or {}
local WINDOW_CONFIG = CONTROL_PANEL_CONFIG.window or {}
local COLOR_CONFIG = CONTROL_PANEL_CONFIG.colors or {}
local HEADER_CONFIG = CONTROL_PANEL_CONFIG.header or {}
local FOOTER_CONFIG = CONTROL_PANEL_CONFIG.footer or {}
local CATEGORY_CONFIG = CONTROL_PANEL_CONFIG.categories or {}
local PAGE_CONFIG = CONTROL_PANEL_CONFIG.pages or {}

local WINDOW_WIDTH = WINDOW_CONFIG.width or 590
local WINDOW_HEIGHT = WINDOW_CONFIG.height or 370
local SIDEBAR_WIDTH = WINDOW_CONFIG.sidebarWidth or 150
local FOOTER_HEIGHT = WINDOW_CONFIG.footerHeight or 52
local HEADER_HEIGHT = WINDOW_CONFIG.headerHeight or 56
local CONTENT_PADDING = WINDOW_CONFIG.contentPadding or 18

local DISPLAY_PAGE_CONFIG = PAGE_CONFIG.display or {}
local DISPLAY_CONTROL_ENTRIES = DISPLAY_PAGE_CONFIG.controls or {
    { key = "item", label = "Item Name", locked = true, defaultValue = true, fixedOrder = 1 },
    { key = "quantity", label = "Session", defaultValue = true },
    { key = "total", label = "Total", defaultValue = true },
    { key = "itemPerHour", label = "Item / Hour", defaultValue = true },
    { key = "activity", label = "Activity", defaultValue = true },
    { key = "itemType", label = "Reagent Type", defaultValue = false },
    { key = "classification", label = "Profession", defaultValue = false },
    { key = "expansion", label = "Expansion", defaultValue = false },
    { key = "zone", label = "Zone", defaultValue = false },
    { key = "subZone", label = "Sub-Zone", defaultValue = false },
    { key = "character", label = "Character", defaultValue = false },
}

local CATEGORY_ORDER = CATEGORY_CONFIG.order or {
    { key = "interface", label = "Interface" },
    { key = "display", label = "Display" },
    { key = "tracking", label = "Tracking" },
    { key = "engine", label = "Engine" },
    { key = "data", label = "Data" },
    { key = "info", label = "Info" },
}

local INTERFACE_PAGE_CONFIG = PAGE_CONFIG.interface or {}
local INTERFACE_OPTIONS = INTERFACE_PAGE_CONFIG.options or {
    { key = "showMainWindowOnGameLoad", label = "Show main window when the game loads", defaultValue = true },
    { key = "hideMainWindowInCombat", label = "Hide main window during combat", defaultValue = false },
    { key = "hideControlPanelsInCombat", label = "Hide control panels during combat", defaultValue = false },
    { key = "restoreControlPanelsAfterCombat", label = "Restore control panels after combat", defaultValue = true },
    { key = "showMainFrameTooltips", label = "Show Main Frame Tooltips", defaultValue = true },
}

local TRACKING_PAGE_CONFIG = PAGE_CONFIG.tracking or {}
local TRACKING_OPTIONS = TRACKING_PAGE_CONFIG.options or {
    { key = "showSpecializedClassifications", label = "Show Processing / Crafting Reagents", settingPath = { "displayFilters", "showSpecializedClassifications" }, defaultValue = false },
    { key = "onlySpecializedClassifications", label = "Show Only Processing / Crafting Reagents", settingPath = { "displayFilters", "onlySpecializedClassifications" }, defaultValue = false },
    { key = "combinedAllData", label = "Combined All Character Data", settingPath = { "tracking", "combinedAllData" }, defaultValue = false },
    { key = "combinedCharacterAllZones", label = "All Current Character Data", settingPath = { "tracking", "combinedCharacterAllZones" }, defaultValue = false },
    { key = "zoneData", label = "Zone Data", settingPath = { "tracking", "zoneData" }, defaultValue = true },
    { key = "subZoneData", label = "Sub-Zone Data", settingPath = { "tracking", "subZoneData" }, defaultValue = false },
    { key = "showOldExpansions", label = "Show Old Expansion Items", settingPath = { "displayFilters", "showOldExpansions" }, defaultValue = false },
}

local CATEGORY_NOTES = CATEGORY_CONFIG.notes or {
    interface = "Main window startup and control panel behavior.",
    display = "Display columns, rows, and main background transparency.",
    tracking = "Tracking filters, combined views, and current data scope.",
    engine = "Internal timers, reset behavior, and rarity filter settings.",
    data = "Saved data tools, cleanup actions, and rebuild utilities.",
    info = "Addon commands, main window controls, and quick usage notes.",
}

local CLEAR_ALL_DATA_POPUP_KEY = "FWR_CONTROL_PANEL_CLEAR_ALL_DATA"
local REBUILD_SAVED_DATA_POPUP_KEY = "FWR_CONTROL_PANEL_REBUILD_SAVED_DATA"

local ENGINE_PAGE_CONFIG = PAGE_CONFIG.engine or {}
local ENGINE_RARITY_LEVEL_VALUES = ENGINE_PAGE_CONFIG.rarityLevels or {
    { value = 0, label = "Poor+" },
    { value = 1, label = "Common+" },
    { value = 2, label = "Uncommon+" },
    { value = 3, label = "Rare+" },
    { value = 4, label = "Epic+" },
}

local function formatQuarterHourLabel(totalMinutes)
    totalMinutes = math.max(0, math.min(1435, math.floor((tonumber(totalMinutes) or 0) / 15 + 0.5) * 15))
    local hours = math.floor(totalMinutes / 60)
    local minutes = totalMinutes % 60
    return string.format("%02d:%02d", hours, minutes)
end

local function getIndexedValueIndex(entries, currentValue, defaultIndex)
    if type(entries) ~= "table" then
        return defaultIndex or 1
    end
    for index, entry in ipairs(entries) do
        if entry.value == currentValue then
            return index
        end
    end
    return defaultIndex or 1
end

local function createBorderLine(parent, point, relativeTo, relativePoint, xOfs, yOfs, width, height, r, g, b, a)
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
    line:SetSize(width, height)
    line:SetColorTexture(r or 1, g or 1, b or 1, a or 0.14)
    return line
end


local function ensureClearAllDataPopup()
    StaticPopupDialogs = StaticPopupDialogs or {}
    if StaticPopupDialogs[CLEAR_ALL_DATA_POPUP_KEY] then
        return
    end

    StaticPopupDialogs[CLEAR_ALL_DATA_POPUP_KEY] = {
        text = "Erase all FarmWise saved data?\n\nThis cannot be undone.",
        button1 = YES,
        button2 = CANCEL,
        OnAccept = function()
            if FWR and FWR.ClearAllSavedData then
                FWR:ClearAllSavedData()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = STATICPOPUP_NUMDIALOGS,
    }
end

local function ensureRebuildSavedDataPopup()
    StaticPopupDialogs = StaticPopupDialogs or {}
    if StaticPopupDialogs[REBUILD_SAVED_DATA_POPUP_KEY] then
        return
    end

    StaticPopupDialogs[REBUILD_SAVED_DATA_POPUP_KEY] = {
        text = "Rebuild saved item classification metadata?\n\nThis may take a moment on larger databases.",
        button1 = YES,
        button2 = CANCEL,
        OnAccept = function()
            if FWR and FWR.StartSavedDataRebuild then
                FWR:StartSavedDataRebuild()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = STATICPOPUP_NUMDIALOGS,
    }
end

local function getBooleanSetting(path, defaultValue)
    local settings = FWR and FWR.Settings or nil
    local current = settings

    if type(path) == "string" then
        path = { "ui", path }
    end

    if type(path) ~= "table" then
        return defaultValue == true
    end

    for _, key in ipairs(path) do
        if type(current) ~= "table" then
            current = nil
            break
        end
        current = current[key]
    end

    if current == nil then
        return defaultValue == true
    end

    return current == true
end

local function setBooleanSetting(path, value)
    if type(path) == "string" then
        path = { "ui", path }
    end

    if type(path) ~= "table" or #path == 0 then
        return
    end

    FWR.Settings = FWR.Settings or {}
    local current = FWR.Settings
    for index = 1, #path - 1 do
        local key = path[index]
        if type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end

    current[path[#path]] = value == true

    if FWR.TouchDatabase then
        FWR:TouchDatabase()
    end
end

local function getNumberSetting(path, defaultValue)
    local settings = FWR and FWR.Settings or nil
    local current = settings

    if type(path) ~= "table" then
        return tonumber(defaultValue) or 0
    end

    for _, key in ipairs(path) do
        if type(current) ~= "table" then
            current = nil
            break
        end
        current = current[key]
    end

    current = tonumber(current)
    if current == nil then
        current = tonumber(defaultValue) or 0
    end

    return current
end

local function setNumberSetting(path, value)
    if type(path) ~= "table" or #path == 0 then
        return
    end

    FWR.Settings = FWR.Settings or {}
    local current = FWR.Settings
    for index = 1, #path - 1 do
        local key = path[index]
        if type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end

    current[path[#path]] = tonumber(value) or 0

    if FWR.TouchDatabase then
        FWR:TouchDatabase()
    end
end

local function setValueSetting(path, value)
    if type(path) ~= "table" or #path == 0 then
        return
    end

    FWR.Settings = FWR.Settings or {}
    local current = FWR.Settings
    for index = 1, #path - 1 do
        local key = path[index]
        if type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end

    current[path[#path]] = value

    if FWR.TouchDatabase then
        FWR:TouchDatabase()
    end
end

local function updateCheckboxVisual(check)
    if not check or not check.Text then
        return
    end

    if check:IsEnabled() then
        check:SetAlpha(1)
        if check:GetChecked() then
            check.Text:SetTextColor(1.0, 0.82, 0.0, 1.0)
        else
            check.Text:SetTextColor(0.82, 0.82, 0.82, 1.0)
        end
    else
        check:SetAlpha(0.45)
        check.Text:SetTextColor(0.55, 0.55, 0.55, 1.0)
    end
end

local function createCategoryButton(parent, label)
    local navButtonConfig = CATEGORY_CONFIG.button or {}
    local navTextColor = COLOR_CONFIG.navText or { 0.96, 0.96, 0.96, 1.0 }
    local navSelectedTextColor = COLOR_CONFIG.navSelectedText or { 1.0, 0.90, 0.55, 1.0 }
    local navSelectedBg = COLOR_CONFIG.navSelectedBg or { 1.0, 0.82, 0.02, 0.12 }
    local navHighlightBg = COLOR_CONFIG.navHighlightBg or { 1.0, 1.0, 1.0, 0.05 }

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(navButtonConfig.width or (SIDEBAR_WIDTH - 24), navButtonConfig.height or 28)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(1, 0.82, 0.02, 0.0)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetColorTexture(unpack(navHighlightBg))

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    button.text:SetPoint("LEFT", navButtonConfig.textX or 10, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetText(label)
    button.text:SetTextColor(unpack(navTextColor))

    function button:SetSelected(isSelected)
        if isSelected then
            self.bg:SetColorTexture(unpack(navSelectedBg))
            self.text:SetTextColor(unpack(navSelectedTextColor))
        else
            self.bg:SetColorTexture(1, 0.82, 0.02, 0.0)
            self.text:SetTextColor(unpack(navTextColor))
        end
    end

    button:SetSelected(false)
    return button
end

local function refreshInterfaceDependencies(frame)
    if not frame or not frame.InterfaceControls then
        return
    end

    local controls = frame.InterfaceControls
    local showOnLoadCheck = controls.showMainWindowOnGameLoad
    local hideMainFrameCheck = controls.hideMainWindowInCombat
    local hidePanelsCheck = controls.hideControlPanelsInCombat
    local restoreCheck = controls.restoreControlPanelsAfterCombat

    if showOnLoadCheck then
        showOnLoadCheck:Enable()
        updateCheckboxVisual(showOnLoadCheck)
    end

    if hideMainFrameCheck then
        hideMainFrameCheck:Enable()
        updateCheckboxVisual(hideMainFrameCheck)
    end

    if hidePanelsCheck and restoreCheck then
        if hidePanelsCheck:GetChecked() then
            restoreCheck:Enable()
        else
            restoreCheck:SetChecked(false)
            setBooleanSetting("restoreControlPanelsAfterCombat", false)
            restoreCheck:Disable()
        end
        updateCheckboxVisual(hidePanelsCheck)
        updateCheckboxVisual(restoreCheck)
    end
end

local function updateDisplayCheckboxVisual(check, isLocked, isEnabled)
    if not check then
        return
    end

    if isLocked then
        check:SetAlpha(0.75)
        if check.Text then
            check.Text:SetTextColor(0.88, 0.88, 0.88, 0.95)
        end
        return
    end

    if isEnabled then
        check:SetAlpha(1)
        if check.Text then
            check.Text:SetTextColor(0.82, 0.82, 0.82, 1)
        end
    else
        check:SetAlpha(0.55)
        if check.Text then
            check.Text:SetTextColor(0.55, 0.55, 0.55, 1)
        end
    end
end

local function createDisplayPage(parent, frame)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local displayConfig = PAGE_CONFIG.display or {}
    local rowSliderConfig = displayConfig.rowSlider or {}
    local transparencyConfig = displayConfig.transparencySlider or {}
    local dividerConfig = displayConfig.divider or {}
    local headerConfig = displayConfig.headers or {}
    local scrollConfig = displayConfig.scroll or {}
    local listConfig = displayConfig.list or {}
    local checkboxConfig = displayConfig.checkbox or listConfig.checkbox or {
        startX = listConfig.checkboxX or 0,
        startY = listConfig.startY or -8,
        spacing = listConfig.spacing or 6,
        textOffsetX = listConfig.textOffsetX or 0,
        textOffsetY = listConfig.textOffsetY or 1,
    }

    local visibleRowsTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visibleRowsTitle:SetPoint("TOPLEFT", rowSliderConfig.titleX or 0, rowSliderConfig.titleY or -2)
    visibleRowsTitle:SetJustifyH("LEFT")
    visibleRowsTitle:SetTextColor(1, 1, 1, 1)
    visibleRowsTitle:SetText(rowSliderConfig.title or "Set Visible Rows")

    local rowSlider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
    rowSlider:SetPoint("TOPLEFT", rowSliderConfig.sliderX or 180, rowSliderConfig.sliderY or -4)
    rowSlider:SetWidth(rowSliderConfig.sliderWidth or 140)
    rowSlider:SetMinMaxValues(rowSliderConfig.min or 5, rowSliderConfig.max or 20)
    rowSlider:SetValueStep(1)
    rowSlider:SetObeyStepOnDrag(true)
    rowSlider:SetOrientation("HORIZONTAL")
    rowSlider:SetStepsPerPage(1)
    rowSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    if rowSlider.Text then rowSlider.Text:SetText("") end
    if rowSlider.Low then
        rowSlider.Low:ClearAllPoints()
        rowSlider.Low:SetPoint("RIGHT", rowSlider, "LEFT", rowSliderConfig.lowOffsetX or -2, 0)
        rowSlider.Low:SetText(rowSliderConfig.low or "5")
    end
    if rowSlider.High then
        rowSlider.High:ClearAllPoints()
        rowSlider.High:SetPoint("LEFT", rowSlider, "RIGHT", rowSliderConfig.highOffsetX or 2, 0)
        rowSlider.High:SetText(rowSliderConfig.high or "20")
    end

    local transparencyTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    transparencyTitle:SetPoint("TOPLEFT", transparencyConfig.titleX or 0, transparencyConfig.titleY or -26)
    transparencyTitle:SetJustifyH("LEFT")
    transparencyTitle:SetTextColor(1, 1, 1, 1)
    transparencyTitle:SetText(transparencyConfig.title or "Frame Transparency")

    local transparencySlider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
    transparencySlider:SetPoint("TOPLEFT", transparencyConfig.sliderX or 180, transparencyConfig.sliderY or -28)
    transparencySlider:SetWidth(transparencyConfig.sliderWidth or 140)
    transparencySlider:SetMinMaxValues(transparencyConfig.min or 0, transparencyConfig.max or 100)
    transparencySlider:SetValueStep(1)
    transparencySlider:SetObeyStepOnDrag(true)
    transparencySlider:SetOrientation("HORIZONTAL")
    transparencySlider:SetStepsPerPage(1)
    transparencySlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    if transparencySlider.Text then transparencySlider.Text:SetText("") end
    if transparencySlider.Low then
        transparencySlider.Low:ClearAllPoints()
        transparencySlider.Low:SetPoint("RIGHT", transparencySlider, "LEFT", transparencyConfig.lowOffsetX or -2, 0)
        transparencySlider.Low:SetText(transparencyConfig.low or "0")
    end
    if transparencySlider.High then
        transparencySlider.High:ClearAllPoints()
        transparencySlider.High:SetPoint("LEFT", transparencySlider, "RIGHT", transparencyConfig.highOffsetX or 2, 0)
        transparencySlider.High:SetText(transparencyConfig.high or "100")
    end

    local divider = page:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(unpack(dividerConfig.color or { 1, 1, 1, 0.18 }))
    divider:SetPoint("TOPLEFT", dividerConfig.x or 0, dividerConfig.y or -64)
    divider:SetPoint("TOPRIGHT", -(dividerConfig.rightInset or 18), dividerConfig.y or -64)
    divider:SetHeight(dividerConfig.height or 1)

    local visibilityHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visibilityHeader:SetPoint("TOPLEFT", (headerConfig.visibility and headerConfig.visibility.x) or 0, (headerConfig.visibility and headerConfig.visibility.y) or -80)
    visibilityHeader:SetTextColor(1, 1, 1, 1)
    visibilityHeader:SetText((headerConfig.visibility and headerConfig.visibility.text) or "Enable / Disable Columns")

    local orderHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    orderHeader:SetPoint("TOPLEFT", (headerConfig.order and headerConfig.order.x) or 180, (headerConfig.order and headerConfig.order.y) or -80)
    orderHeader:SetTextColor(1, 1, 1, 1)
    orderHeader:SetText((headerConfig.order and headerConfig.order.text) or "Reorder Columns")

    local scrollFrame = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", scrollConfig.left or 0, scrollConfig.top or -102)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollConfig.right or -24, scrollConfig.bottom or 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    page.ScrollFrame = scrollFrame
    page.ScrollChild = scrollChild
    page.DisplayControls = {}

    local function refreshDisplayControls()
        if FWR.NormalizeDisplayColumnSettings then
            FWR:NormalizeDisplayColumnSettings()
        end

        local visibleRowsValue = math.max(5, math.min(20, getNumberSetting({ "display", "visibleRows" }, 5)))
        visibleRowsTitle:SetText(string.format("Set Visible Rows (%d)", visibleRowsValue))
        rowSlider.__fwrRefreshing = true
        rowSlider:SetValue(visibleRowsValue)
        rowSlider.__fwrPendingVisibleRowsValue = visibleRowsValue
        rowSlider.__fwrRefreshing = nil

        local transparencyValue = math.max(0, math.min(100, getNumberSetting({ "display", "frameTransparency" }, 50)))
        transparencyTitle:SetText(string.format("Frame Transparency (%d%%)", transparencyValue))
        transparencySlider.__fwrRefreshing = true
        transparencySlider:SetValue(transparencyValue)
        transparencySlider.__fwrPendingTransparencyValue = transparencyValue
        transparencySlider.__fwrRefreshing = nil

        local enabledCount = FWR.GetEnabledReorderableMainColumnCount and FWR:GetEnabledReorderableMainColumnCount() or 0
        local enabledMaxPosition = math.max(2, enabledCount + 1)

        for _, entry in ipairs(displayConfig.controls or DISPLAY_CONTROL_ENTRIES) do
            local widgets = page.DisplayControls[entry.key]
            if widgets then
                local isLocked = entry.locked == true
                local enabled = isLocked and true or getBooleanSetting({ "display", "optionalColumns", entry.key }, entry.defaultValue)
                local defaultOrderValue = widgets.defaultOrderValue or entry.fixedOrder or 1
                local value = getNumberSetting({ "display", "columnOrder", entry.key }, defaultOrderValue)
                local orderSuffix = ""
                if not isLocked then
                    orderSuffix = enabled and string.format(" (%d)", math.floor(value or defaultOrderValue or 0)) or " (Hidden)"
                end
                if widgets.check and widgets.check.Text then
                    widgets.check:SetChecked(enabled)
                    widgets.check.Text:SetText((entry.label or "") .. orderSuffix)
                    updateDisplayCheckboxVisual(widgets.check, isLocked, enabled)
                end
                if widgets.slider then
                    local sliderMin = 2
                    local sliderMax = enabledMaxPosition
                    local sliderValue = enabled and math.max(sliderMin, math.min(sliderMax, value)) or sliderMax
                    widgets.slider.__fwrRefreshing = true
                    widgets.slider:SetMinMaxValues(sliderMin, sliderMax)
                    if widgets.slider.Low then widgets.slider.Low:SetText(tostring(sliderMin)) end
                    if widgets.slider.High then widgets.slider.High:SetText(tostring(sliderMax)) end
                    widgets.slider:SetValue(sliderValue)
                    widgets.slider.__fwrRefreshing = nil
                    local thumb = widgets.slider.GetThumbTexture and widgets.slider:GetThumbTexture() or nil
                    if isLocked or not enabled then
                        widgets.slider:Disable()
                        if thumb and thumb.SetAlpha then thumb:SetAlpha(0) end
                    else
                        widgets.slider:Enable()
                        if thumb and thumb.SetAlpha then thumb:SetAlpha(1) end
                    end
                end
            end
        end
    end

    local function applyDisplayRefresh()
        if FWR.ApplyDisplaySettings then
            FWR:ApplyDisplaySettings()
        end
        if FWR.RefreshDisplayText then
            FWR:RefreshDisplayText()
            if FWR.RefreshDisplayLiveMetrics then
                FWR:RefreshDisplayLiveMetrics(true)
            end
        end
    end

    local function handleSliderValueChanged(changedKey, requestedValue)
        if not changedKey or not FWR.NormalizeDisplayColumnSettings then
            return
        end

        local display = FWR:NormalizeDisplayColumnSettings()
        local orderMap = display.columnOrder or {}
        local currentOrder = FWR.GetOrderedMainColumnKeys and FWR:GetOrderedMainColumnKeys() or nil
        if type(currentOrder) ~= "table" then
            return
        end

        local reorderable = {}
        for _, key in ipairs(currentOrder) do
            if key ~= "item" and key ~= "quality" then
                reorderable[#reorderable + 1] = key
            end
        end

        local currentIndex
        for index, key in ipairs(reorderable) do
            if key == changedKey then
                currentIndex = index
                break
            end
        end
        if not currentIndex then
            return
        end

        local enabledCount = FWR.GetEnabledReorderableMainColumnCount and FWR:GetEnabledReorderableMainColumnCount() or #reorderable
        local targetIndex = math.max(1, math.min(enabledCount, math.floor((tonumber(requestedValue) or 2) - 1)))
        if targetIndex ~= currentIndex then
            table.remove(reorderable, currentIndex)
            table.insert(reorderable, targetIndex, changedKey)
        end

        for index, key in ipairs(reorderable) do
            orderMap[key] = index + 1
        end

        setNumberSetting({ "display", "columnOrder", changedKey }, orderMap[changedKey])
        refreshDisplayControls()
        applyDisplayRefresh()
    end

    local function commitVisibleRows(value)
        local snapped = math.floor((tonumber(value) or 0) + 0.5)
        local clamped = math.max(5, math.min(20, snapped))
        if getNumberSetting({ "display", "visibleRows" }, 5) == clamped then
            visibleRowsTitle:SetText(string.format("Set Visible Rows (%d)", clamped))
            return
        end
        setNumberSetting({ "display", "visibleRows" }, clamped)
        visibleRowsTitle:SetText(string.format("Set Visible Rows (%d)", clamped))
        applyDisplayRefresh()
    end

    local function commitTransparency(value)
        local snapped = math.floor((tonumber(value) or 0) + 0.5)
        local clamped = math.max(0, math.min(100, snapped))
        if getNumberSetting({ "display", "frameTransparency" }, 50) == clamped then
            transparencyTitle:SetText(string.format("Frame Transparency (%d%%)", clamped))
            return
        end
        setNumberSetting({ "display", "frameTransparency" }, clamped)
        transparencyTitle:SetText(string.format("Frame Transparency (%d%%)", clamped))
        applyDisplayRefresh()
    end

    rowSlider:SetScript("OnValueChanged", function(self, value)
        local snapped = math.floor((tonumber(value) or 0) + 0.5)
        if math.abs((tonumber(value) or 0) - snapped) > 0.001 then
            self:SetValue(snapped)
            return
        end
        if self.__fwrRefreshing then
            return
        end
        local clamped = math.max(5, math.min(20, snapped))
        self.__fwrPendingVisibleRowsValue = clamped
        visibleRowsTitle:SetText(string.format("Set Visible Rows (%d)", clamped))
    end)
    rowSlider:SetScript("OnMouseUp", function(self)
        commitVisibleRows(self.__fwrPendingVisibleRowsValue or self:GetValue())
    end)
    rowSlider:SetScript("OnHide", function(self)
        commitVisibleRows(self.__fwrPendingVisibleRowsValue or self:GetValue())
    end)

    transparencySlider:SetScript("OnValueChanged", function(self, value)
        local snapped = math.floor((tonumber(value) or 0) + 0.5)
        if math.abs((tonumber(value) or 0) - snapped) > 0.001 then
            self:SetValue(snapped)
            return
        end
        if self.__fwrRefreshing then
            return
        end
        local clamped = math.max(0, math.min(100, snapped))
        self.__fwrPendingTransparencyValue = clamped
        transparencyTitle:SetText(string.format("Frame Transparency (%d%%)", clamped))
    end)
    transparencySlider:SetScript("OnMouseUp", function(self)
        commitTransparency(self.__fwrPendingTransparencyValue or self:GetValue())
    end)
    transparencySlider:SetScript("OnHide", function(self)
        commitTransparency(self.__fwrPendingTransparencyValue or self:GetValue())
    end)

    local previous
    for index, entry in ipairs(DISPLAY_CONTROL_ENTRIES) do
        local check = CreateFrame("CheckButton", nil, scrollChild, "InterfaceOptionsCheckButtonTemplate")
        if index == 1 then
            check:SetPoint("TOPLEFT", checkboxConfig.startX or 0, checkboxConfig.startY or -8)
        else
            check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(checkboxConfig.spacing or 6))
        end
        check:SetHitRectInsets(0, 0, 0, 0)
        if check.Text then
            check.Text:ClearAllPoints()
            check.Text:SetPoint("LEFT", check, "RIGHT", checkboxConfig.textOffsetX or 0, checkboxConfig.textOffsetY or 1)
            check.Text:SetJustifyH("LEFT")
            check.Text:SetText(entry.label or "")
        end

        if entry.locked then
            check:SetChecked(true)
            check:Disable()
            updateDisplayCheckboxVisual(check, true, true)
        else
            check:SetChecked(getBooleanSetting({ "display", "optionalColumns", entry.key }, entry.defaultValue))
            updateDisplayCheckboxVisual(check, false, check:GetChecked() == true)
            check:SetScript("OnClick", function(self)
                local checked = self:GetChecked() == true
                if FWR.SetOptionalMainColumnEnabled then
                    FWR:SetOptionalMainColumnEnabled(entry.key, checked)
                else
                    setBooleanSetting({ "display", "optionalColumns", entry.key }, checked)
                    if FWR.NormalizeDisplayColumnSettings then
                        FWR:NormalizeDisplayColumnSettings()
                    end
                end
                refreshDisplayControls()
                applyDisplayRefresh()
            end)
        end

        local slider
        if not entry.locked then
            slider = CreateFrame("Slider", nil, scrollChild, "OptionsSliderTemplate")
            slider:SetPoint("LEFT", 180, 0)
            slider:SetPoint("TOP", check, "TOP", 0, -4)
            slider:SetWidth(150)
            slider:SetMinMaxValues(2, math.max(2, #DISPLAY_CONTROL_ENTRIES))
            slider:SetValueStep(1)
            slider:SetObeyStepOnDrag(true)
            slider:SetOrientation("HORIZONTAL")
            slider:SetStepsPerPage(1)
            slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
            if slider.Text then slider.Text:SetText("") end
            if slider.Low then
                slider.Low:ClearAllPoints()
                slider.Low:SetPoint("RIGHT", slider, "LEFT", listConfig.lowOffsetX or -2, 0)
                slider.Low:SetText("2")
            end
            if slider.High then
                slider.High:ClearAllPoints()
                slider.High:SetPoint("LEFT", slider, "RIGHT", listConfig.highOffsetX or 2, 0)
                slider.High:SetText(tostring(math.max(2, #DISPLAY_CONTROL_ENTRIES)))
            end
            slider:SetScript("OnValueChanged", function(self, value)
                local snapped = math.floor((tonumber(value) or 0) + 0.5)
                if math.abs((tonumber(value) or 0) - snapped) > 0.001 then
                    self:SetValue(snapped)
                    return
                end
                if self.__fwrRefreshing then
                    return
                end
                if self:IsEnabled() then
                    handleSliderValueChanged(entry.key, snapped)
                end
            end)
        end

        page.DisplayControls[entry.key] = {
            check = check,
            slider = slider,
            defaultOrderValue = entry.fixedOrder or math.max(2, index),
        }

        previous = check
    end

    local childHeight = math.max(240, (#DISPLAY_CONTROL_ENTRIES * 30) + 20)
    scrollChild:SetSize(420, childHeight)

    page.RefreshDisplayControls = refreshDisplayControls
    page:SetScript("OnShow", function(self)
        if self.RefreshDisplayControls then
            self:RefreshDisplayControls()
        end
    end)
    page:RefreshDisplayControls()

    return page
end

local function createInterfacePage(parent, frame)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local interfaceConfig = PAGE_CONFIG.interface or {}
    local checkboxConfig = interfaceConfig.checkbox or {}
    page.InterfaceControls = {}

    local previous
    for index, option in ipairs(INTERFACE_OPTIONS) do
        local check = CreateFrame("CheckButton", nil, page, "InterfaceOptionsCheckButtonTemplate")
        check:SetHitRectInsets(0, 0, 0, 0)

        if index == 1 then
            check:SetPoint("TOPLEFT", checkboxConfig.startX or 0, checkboxConfig.startY or -2)
        else
            check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(checkboxConfig.spacing or 6))
        end

        if check.Text then
            check.Text:ClearAllPoints()
            check.Text:SetPoint("LEFT", check, "RIGHT", checkboxConfig.textOffsetX or 0, checkboxConfig.textOffsetY or 1)
            check.Text:SetJustifyH("LEFT")
            check.Text:SetText(option.label)
        end

        check:SetChecked(getBooleanSetting(option.key, option.defaultValue))
        updateCheckboxVisual(check)
        check:SetScript("OnClick", function(self)
            local checked = self:GetChecked() == true
            setBooleanSetting(option.key, checked)
            updateCheckboxVisual(self)
            refreshInterfaceDependencies(frame)
        end)

        page.InterfaceControls[option.key] = check
        previous = check
    end

    frame.InterfaceControls = page.InterfaceControls
    refreshInterfaceDependencies(frame)

    return page
end

local function refreshTrackingDependencies(page)
    if not page or not page.TrackingControls then
        return
    end

    local showControl = page.TrackingControls.showSpecializedClassifications
    local onlyControl = page.TrackingControls.onlySpecializedClassifications
    local onlyChecked = FWR and FWR.IsOnlySpecializedClassificationVisible and FWR:IsOnlySpecializedClassificationVisible() or false

    if showControl then
        if onlyChecked then
            showControl:SetChecked(false)
            showControl:Disable()
        else
            local showChecked = FWR and FWR.IsSpecializedClassificationVisible and FWR:IsSpecializedClassificationVisible() or false
            showControl:SetChecked(showChecked)
            showControl:Enable()
        end
        updateCheckboxVisual(showControl)
    end

    if onlyControl then
        onlyControl:SetChecked(onlyChecked)
        onlyControl:Enable()
        updateCheckboxVisual(onlyControl)
    end

    local combinedAllChecked = FWR and FWR.IsCombinedAllDataEnabled and FWR:IsCombinedAllDataEnabled() or false
    local combinedCharacterChecked = FWR and FWR.IsCombinedCharacterAllZonesEnabled and FWR:IsCombinedCharacterAllZonesEnabled() or false
    local combinedModeActive = combinedAllChecked or combinedCharacterChecked

    local combinedAllControl = page.TrackingControls.combinedAllData
    local combinedCharacterControl = page.TrackingControls.combinedCharacterAllZones
    local zoneControl = page.TrackingControls.zoneData
    local subZoneControl = page.TrackingControls.subZoneData

    if combinedAllControl then
        combinedAllControl:SetChecked(combinedAllChecked)
        combinedAllControl:Enable()
        updateCheckboxVisual(combinedAllControl)
    end

    if combinedCharacterControl then
        combinedCharacterControl:SetChecked(combinedCharacterChecked)
        combinedCharacterControl:Enable()
        updateCheckboxVisual(combinedCharacterControl)
    end

    if zoneControl then
        local zoneChecked = FWR and FWR.IsZoneDataEnabled and FWR:IsZoneDataEnabled() or false
        if combinedModeActive then
            zoneControl:SetChecked(false)
            zoneControl:Disable()
        else
            zoneControl:SetChecked(zoneChecked)
            zoneControl:Enable()
        end
        updateCheckboxVisual(zoneControl)
    end

    if subZoneControl then
        local subZoneChecked = FWR and FWR.IsSubZoneDataEnabled and FWR:IsSubZoneDataEnabled() or false
        if combinedModeActive then
            subZoneControl:SetChecked(false)
            subZoneControl:Disable()
        else
            subZoneControl:SetChecked(subZoneChecked)
            subZoneControl:Enable()
        end
        updateCheckboxVisual(subZoneControl)
    end
end

local function createTrackingPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page.TrackingControls = {}

    local trackingConfig = PAGE_CONFIG.tracking or {}
    local checkboxConfig = trackingConfig.checkbox or {}
    local previous
    for index, option in ipairs(TRACKING_OPTIONS) do
        local check = CreateFrame("CheckButton", nil, page, "InterfaceOptionsCheckButtonTemplate")
        check:SetHitRectInsets(0, 0, 0, 0)
        if index == 1 then
            check:SetPoint("TOPLEFT", checkboxConfig.startX or 0, checkboxConfig.startY or -2)
        else
            check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(checkboxConfig.spacing or 6))
        end

        if check.Text then
            check.Text:ClearAllPoints()
            check.Text:SetPoint("LEFT", check, "RIGHT", checkboxConfig.textOffsetX or 0, checkboxConfig.textOffsetY or 1)
            check.Text:SetJustifyH("LEFT")
            check.Text:SetText(option.label)
        end

        check:SetScript("OnClick", function(self)
            local checked = self:GetChecked() == true
            if option.key == "combinedAllData" and FWR.SetCombinedAllDataEnabled then
                FWR:SetCombinedAllDataEnabled(checked)
            elseif option.key == "combinedCharacterAllZones" and FWR.SetCombinedCharacterAllZonesEnabled then
                FWR:SetCombinedCharacterAllZonesEnabled(checked)
            elseif option.key == "zoneData" and FWR.SetZoneDataEnabled then
                FWR:SetZoneDataEnabled(checked)
            elseif option.key == "subZoneData" and FWR.SetSubZoneDataEnabled then
                FWR:SetSubZoneDataEnabled(checked)
            elseif option.key == "showSpecializedClassifications" and FWR.SetSpecializedClassificationVisible then
                FWR:SetSpecializedClassificationVisible(checked)
            elseif option.key == "onlySpecializedClassifications" and FWR.SetOnlySpecializedClassificationVisible then
                FWR:SetOnlySpecializedClassificationVisible(checked)
            elseif option.key == "showOldExpansions" and FWR.SetOldExpansionVisible then
                FWR:SetOldExpansionVisible(checked)
            else
                setBooleanSetting(option.settingPath, checked)
            end
            if FWR.ApplyDisplaySettings then
                FWR:ApplyDisplaySettings()
            end
            if FWR.RefreshDisplayText then
                FWR:RefreshDisplayText()
            end
            if page.RefreshTrackingControls then
                page:RefreshTrackingControls()
            end
        end)

        page.TrackingControls[option.key] = check
        previous = check
    end

    function page:RefreshTrackingControls()
        for _, option in ipairs(TRACKING_OPTIONS) do
            local check = self.TrackingControls[option.key]
            if check then
                local checked = getBooleanSetting(option.settingPath, option.defaultValue)
                check:SetChecked(checked)
                updateCheckboxVisual(check)
            end
        end
        refreshTrackingDependencies(self)
    end

    page:SetScript("OnShow", function(self)
        if self.RefreshTrackingControls then
            self:RefreshTrackingControls()
        end
    end)

    page:RefreshTrackingControls()
    return page
end

local function createEnginePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local engineConfig = PAGE_CONFIG.engine or {}
    local checkboxConfig = engineConfig.checkbox or {}
    local localResetConfig = engineConfig.localReset or {}
    local rarityConfig = engineConfig.rarity or {}

    local function styleEngineCheck(check, text)
        if not check then return end
        check:SetHitRectInsets(0, 0, 0, 0)
        if check.Text then
            check.Text:ClearAllPoints()
            check.Text:SetPoint("LEFT", check, "RIGHT", checkboxConfig.textOffsetX or 0, checkboxConfig.textOffsetY or 1)
            check.Text:SetJustifyH("LEFT")
            check.Text:SetText(text or "")
        end
    end

    local manualCheck = CreateFrame("CheckButton", nil, page, "InterfaceOptionsCheckButtonTemplate")
    manualCheck:SetPoint("TOPLEFT", checkboxConfig.startX or 0, checkboxConfig.startY or -2)
    styleEngineCheck(manualCheck, (engineConfig.manualReset and engineConfig.manualReset.label) or "Manual Session Reset")

    local localCheck = CreateFrame("CheckButton", nil, page, "InterfaceOptionsCheckButtonTemplate")
    localCheck:SetPoint("TOPLEFT", manualCheck, "BOTTOMLEFT", 0, -(checkboxConfig.spacing or 6))
    styleEngineCheck(localCheck, localResetConfig.label or "Local Session Reset")

    local localTimeSlider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
    localTimeSlider:SetPoint("LEFT", localCheck.Text, "RIGHT", localResetConfig.sliderX or 66, localResetConfig.sliderY or -1)
    localTimeSlider:SetWidth(localResetConfig.sliderWidth or 130)
    localTimeSlider:SetMinMaxValues(0, 95)
    localTimeSlider:SetValueStep(1)
    localTimeSlider:SetObeyStepOnDrag(true)
    localTimeSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    if localTimeSlider.Text then localTimeSlider.Text:SetText("") end
    if localTimeSlider.Low then localTimeSlider.Low:SetText(localResetConfig.low or "00:00") end
    if localTimeSlider.High then localTimeSlider.High:SetText(localResetConfig.high or "23:45") end

    local localTimeValue = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    localTimeValue:SetPoint("LEFT", localTimeSlider, "RIGHT", localResetConfig.valueTextX or 8, 0)
    localTimeValue:SetWidth(localResetConfig.valueTextWidth or 46)
    localTimeValue:SetJustifyH("LEFT")
    localTimeValue:SetTextColor(0.82, 0.82, 0.82, 1)

    local rarityCheck = CreateFrame("CheckButton", nil, page, "InterfaceOptionsCheckButtonTemplate")
    rarityCheck:SetPoint("TOPLEFT", localCheck, "BOTTOMLEFT", 0, -(checkboxConfig.spacing or 6))
    styleEngineCheck(rarityCheck, rarityConfig.label or "Set Rarity Level")

    local raritySlider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
    raritySlider:SetPoint("LEFT", rarityCheck.Text, "RIGHT", rarityConfig.sliderX or 92, rarityConfig.sliderY or -1)
    raritySlider:SetWidth(rarityConfig.sliderWidth or 130)
    raritySlider:SetMinMaxValues(1, #ENGINE_RARITY_LEVEL_VALUES)
    raritySlider:SetValueStep(1)
    raritySlider:SetObeyStepOnDrag(true)
    raritySlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    if raritySlider.Text then raritySlider.Text:SetText("") end
    if raritySlider.Low then raritySlider.Low:SetText(ENGINE_RARITY_LEVEL_VALUES[1].label) end
    if raritySlider.High then raritySlider.High:SetText(ENGINE_RARITY_LEVEL_VALUES[#ENGINE_RARITY_LEVEL_VALUES].label) end

    local rarityValueText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rarityValueText:SetPoint("LEFT", raritySlider, "RIGHT", rarityConfig.valueTextX or 8, 0)
    rarityValueText:SetWidth(rarityConfig.valueTextWidth or 62)
    rarityValueText:SetJustifyH("LEFT")
    rarityValueText:SetTextColor(0.82, 0.82, 0.82, 1)

    local function getNormalizedMode()
        local modeValue = ((FWR.Settings or {}).engine or {}).sessionResetMode or "manual"
        if modeValue ~= "local" then
            modeValue = "manual"
        end
        return modeValue
    end

    local function touchEngine()
        if FWR.TouchTrackingDisplay then
            FWR:TouchTrackingDisplay()
        elseif FWR.RefreshDisplayText then
            FWR:RefreshDisplayText()
        end
    end

    local function refreshEngineControls()
        local modeValue = getNormalizedMode()
        manualCheck:SetChecked(modeValue == "manual")
        localCheck:SetChecked(modeValue == "local")
        updateCheckboxVisual(manualCheck)
        updateCheckboxVisual(localCheck)

        local localMinutes = math.max(0, math.min(1435, getNumberSetting({ "engine", "localResetMinutes" }, 0)))
        local localIndex = math.floor(localMinutes / 15 + 0.5)
        localTimeSlider.__fwrRefreshing = true
        localTimeSlider:SetValue(localIndex)
        localTimeSlider.__fwrPendingLocalTimeIndex = localIndex
        localTimeSlider.__fwrRefreshing = nil
        localTimeSlider:SetEnabled(modeValue == "local")
        localTimeValue:SetText(formatQuarterHourLabel(localMinutes))
        localTimeValue:SetAlpha(modeValue == "local" and 1 or 0.45)
        do
            local thumb = localTimeSlider.GetThumbTexture and localTimeSlider:GetThumbTexture() or nil
            if thumb and thumb.SetAlpha then thumb:SetAlpha(modeValue == "local" and 1 or 0) end
        end
        if localTimeSlider.Low then localTimeSlider.Low:SetAlpha(modeValue == "local" and 1 or 0.45) end
        if localTimeSlider.High then localTimeSlider.High:SetAlpha(modeValue == "local" and 1 or 0.45) end

        local rarityEnabled = getBooleanSetting({ "engine", "rarityFilterEnabled" }, false)
        rarityCheck:SetChecked(rarityEnabled)
        updateCheckboxVisual(rarityCheck)

        local rarityValue = getNumberSetting({ "engine", "rarityLevel" }, 1)
        local rarityIndex = getIndexedValueIndex(ENGINE_RARITY_LEVEL_VALUES, rarityValue, 2)
        raritySlider.__fwrRefreshing = true
        raritySlider:SetValue(rarityIndex)
        raritySlider.__fwrPendingRarityIndex = rarityIndex
        raritySlider.__fwrRefreshing = nil
        raritySlider:SetEnabled(rarityEnabled)
        rarityValueText:SetText(ENGINE_RARITY_LEVEL_VALUES[rarityIndex].label)
        rarityValueText:SetAlpha(rarityEnabled and 1 or 0.45)
        do
            local thumb = raritySlider.GetThumbTexture and raritySlider:GetThumbTexture() or nil
            if thumb and thumb.SetAlpha then thumb:SetAlpha(rarityEnabled and 1 or 0) end
        end
        if raritySlider.Low then raritySlider.Low:SetAlpha(rarityEnabled and 1 or 0.45) end
        if raritySlider.High then raritySlider.High:SetAlpha(rarityEnabled and 1 or 0.45) end
    end

    local function setMode(modeValue)
        if modeValue ~= "local" then
            modeValue = "manual"
        end
        setValueSetting({ "engine", "sessionResetMode" }, modeValue)
        touchEngine()
        refreshEngineControls()
    end

    manualCheck:SetScript("OnClick", function(self)
        if not self:GetChecked() then
            self:SetChecked(true)
            return
        end
        setMode("manual")
    end)

    localCheck:SetScript("OnClick", function(self)
        if not self:GetChecked() then
            self:SetChecked(true)
            return
        end
        setMode("local")
    end)

    localTimeSlider:SetScript("OnValueChanged", function(self, value)
        if self.__fwrRefreshing then
            return
        end
        local snapped = math.max(0, math.min(95, math.floor((tonumber(value) or 0) + 0.5)))
        self.__fwrPendingLocalTimeIndex = snapped
        localTimeValue:SetText(formatQuarterHourLabel(snapped * 15))
    end)
    localTimeSlider:SetScript("OnMouseUp", function(self)
        local idx = self.__fwrPendingLocalTimeIndex or math.max(0, math.min(95, math.floor((tonumber(self:GetValue()) or 0) + 0.5)))
        setNumberSetting({ "engine", "localResetMinutes" }, idx * 15)
        refreshEngineControls()
    end)
    localTimeSlider:SetScript("OnHide", function(self)
        local idx = self.__fwrPendingLocalTimeIndex or math.max(0, math.min(95, math.floor((tonumber(self:GetValue()) or 0) + 0.5)))
        setNumberSetting({ "engine", "localResetMinutes" }, idx * 15)
    end)

    rarityCheck:SetScript("OnClick", function(self)
        local checked = self:GetChecked() == true
        setBooleanSetting({ "engine", "rarityFilterEnabled" }, checked)
        touchEngine()
        refreshEngineControls()
    end)

    raritySlider:SetScript("OnValueChanged", function(self, value)
        if self.__fwrRefreshing then
            return
        end
        local snapped = math.max(1, math.min(#ENGINE_RARITY_LEVEL_VALUES, math.floor((tonumber(value) or 1) + 0.5)))
        self.__fwrPendingRarityIndex = snapped
        rarityValueText:SetText(ENGINE_RARITY_LEVEL_VALUES[snapped].label)
    end)
    raritySlider:SetScript("OnMouseUp", function(self)
        local idx = self.__fwrPendingRarityIndex or math.max(1, math.min(#ENGINE_RARITY_LEVEL_VALUES, math.floor((tonumber(self:GetValue()) or 1) + 0.5)))
        setNumberSetting({ "engine", "rarityLevel" }, ENGINE_RARITY_LEVEL_VALUES[idx].value)
        touchEngine()
        refreshEngineControls()
    end)
    raritySlider:SetScript("OnHide", function(self)
        local idx = self.__fwrPendingRarityIndex or math.max(1, math.min(#ENGINE_RARITY_LEVEL_VALUES, math.floor((tonumber(self:GetValue()) or 1) + 0.5)))
        setNumberSetting({ "engine", "rarityLevel" }, ENGINE_RARITY_LEVEL_VALUES[idx].value)
    end)

    page:SetScript("OnShow", refreshEngineControls)
    page.RefreshEngineControls = refreshEngineControls
    refreshEngineControls()
    return page
end

local function createInfoPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local infoConfig = PAGE_CONFIG.info or {}
    local titleConfig = infoConfig.title or {}
    local bodyConfig = infoConfig.body or {}

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", titleConfig.x or 0, titleConfig.y or -2)
    title:SetTextColor(1, 1, 1, 1)
    title:SetText(titleConfig.text or "Quick Commands")

    local body = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", bodyConfig.x or 0, bodyConfig.y or -10)
    body:SetPoint("RIGHT", page, "RIGHT", -(bodyConfig.rightInset or 18), 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText(bodyConfig.text or "")

    return page
end

local function createDataPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local dataConfig = PAGE_CONFIG.data or {}
    local rebuildConfig = dataConfig.rebuild or {}
    local eraseConfig = dataConfig.erase or {}

    local rebuildNote = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rebuildNote:SetPoint("TOPLEFT", rebuildConfig.noteX or 0, rebuildConfig.noteY or -2)
    rebuildNote:SetPoint("RIGHT", page, "RIGHT", -18, 0)
    rebuildNote:SetJustifyH("LEFT")
    rebuildNote:SetJustifyV("TOP")
    rebuildNote:SetText(rebuildConfig.note or "")

    local rebuildLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rebuildLabel:SetPoint("TOPLEFT", rebuildNote, "BOTTOMLEFT", 0, rebuildConfig.labelOffsetY or -16)
    rebuildLabel:SetTextColor(1, 1, 1, 1)
    rebuildLabel:SetText(rebuildConfig.label or "Rebuild Saved Data")

    local rebuildButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    rebuildButton:SetSize(rebuildConfig.buttonWidth or 130, rebuildConfig.buttonHeight or 24)
    rebuildButton:SetPoint("LEFT", rebuildLabel, "RIGHT", rebuildConfig.buttonOffsetX or 28, 0)
    rebuildButton:SetText(rebuildConfig.buttonText or "Rebuild")
    rebuildButton:SetScript("OnClick", function()
        ensureRebuildSavedDataPopup()
        if StaticPopup_Show then
            StaticPopup_Show(REBUILD_SAVED_DATA_POPUP_KEY)
        end
    end)

    local progressBar = CreateFrame("Frame", nil, page, "BackdropTemplate")
    progressBar:SetSize(rebuildConfig.progressWidth or 260, rebuildConfig.progressHeight or 12)
    progressBar:SetPoint("TOPLEFT", rebuildLabel, "BOTTOMLEFT", 0, rebuildConfig.progressOffsetY or -12)
    progressBar:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    progressBar:SetBackdropColor(0.07, 0.07, 0.07, 0.85)
    progressBar:SetBackdropBorderColor(0.32, 0.32, 0.32, 0.9)

    local progressFill = progressBar:CreateTexture(nil, "ARTWORK")
    progressFill:SetTexture("Interface/Buttons/WHITE8X8")
    progressFill:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 1, -1)
    progressFill:SetPoint("BOTTOMLEFT", progressBar, "BOTTOMLEFT", 1, 1)
    progressFill:SetWidth(0)
    progressFill:SetColorTexture(0.78, 0.63, 0.18, 0.95)

    local progressText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressText:SetPoint("TOPLEFT", progressBar, "BOTTOMLEFT", 0, rebuildConfig.progressTextOffsetY or -6)
    progressText:SetPoint("RIGHT", page, "RIGHT", -18, 0)
    progressText:SetJustifyH("LEFT")
    progressText:SetText("Ready")

    local eraseNote = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    eraseNote:SetPoint("TOPLEFT", progressText, "BOTTOMLEFT", 0, eraseConfig.noteOffsetY or -22)
    eraseNote:SetPoint("RIGHT", page, "RIGHT", -18, 0)
    eraseNote:SetJustifyH("LEFT")
    eraseNote:SetJustifyV("TOP")
    eraseNote:SetText(eraseConfig.note or "")

    local eraseLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    eraseLabel:SetPoint("TOPLEFT", eraseNote, "BOTTOMLEFT", 0, eraseConfig.labelOffsetY or -16)
    eraseLabel:SetTextColor(1, 1, 1, 1)
    eraseLabel:SetText(eraseConfig.label or "Erase Data")

    local eraseButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    eraseButton:SetSize(eraseConfig.buttonWidth or 110, eraseConfig.buttonHeight or 24)
    eraseButton:SetPoint("LEFT", eraseLabel, "RIGHT", eraseConfig.buttonOffsetX or 36, 0)
    eraseButton:SetText(eraseConfig.buttonText or "Erase")
    eraseButton:SetScript("OnClick", function()
        ensureClearAllDataPopup()
        if StaticPopup_Show then
            StaticPopup_Show(CLEAR_ALL_DATA_POPUP_KEY)
        end
    end)

    function page:RefreshRebuildStatus()
        local status = FWR.GetSavedDataRebuildStatus and FWR:GetSavedDataRebuildStatus() or nil
        local percent = status and tonumber(status.percent) or 0
        if percent < 0 then
            percent = 0
        elseif percent > 100 then
            percent = 100
        end

        local width = math.floor((((rebuildConfig.progressWidth or 260) - 2) * percent) / 100)
        if width < 0 then
            width = 0
        end
        progressFill:SetWidth(width)

        if status and status.text and status.text ~= "" then
            progressText:SetText(status.text)
        else
            progressText:SetText("Ready")
        end

        local running = status and status.running == true
        rebuildButton:SetEnabled(not running)
        if running then
            progressFill:SetColorTexture(0.78, 0.63, 0.18, 0.95)
        elseif percent >= 100 then
            progressFill:SetColorTexture(0.26, 0.72, 0.34, 0.95)
        else
            progressFill:SetColorTexture(0.78, 0.63, 0.18, 0.95)
        end
    end

    page:SetScript("OnShow", function(self)
        if self.RefreshRebuildStatus then
            self:RefreshRebuildStatus()
        end
    end)
    page:SetScript("OnUpdate", function(self, elapsed)
        self._rebuildElapsed = (self._rebuildElapsed or 0) + (elapsed or 0)
        if self._rebuildElapsed < 0.1 then
            return
        end
        self._rebuildElapsed = 0
        if self.RefreshRebuildStatus then
            self:RefreshRebuildStatus()
        end
    end)

    page:RefreshRebuildStatus()
    return page
end

local function createPlaceholderPage(parent, note)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    page.text = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.text:SetPoint("TOPLEFT", 0, -2)
    page.text:SetPoint("RIGHT", page, "RIGHT", -4, 0)
    page.text:SetJustifyH("LEFT")
    page.text:SetJustifyV("TOP")
    page.text:SetTextColor(0.84, 0.84, 0.84)
    page.text:SetText(note or "This section will be moved in a later pass.")

    return page
end

local function selectCategory(frame, categoryKey)
    if not frame then
        return
    end

    frame.SelectedCategoryKey = categoryKey

    for _, entry in ipairs(CATEGORY_ORDER) do
        local button = frame.CategoryButtons and frame.CategoryButtons[entry.key]
        local page = frame.Pages and frame.Pages[entry.key]
        local selected = entry.key == categoryKey

        if button then
            button:SetSelected(selected)
        end

        if page then
            page:SetShown(selected)
        end
    end

    local selectedLabel = categoryKey
    for _, entry in ipairs(CATEGORY_ORDER) do
        if entry.key == categoryKey then
            selectedLabel = entry.label
            break
        end
    end

    if frame.titleAccent then
        frame.titleAccent:SetText((HEADER_CONFIG.titleAccent and HEADER_CONFIG.titleAccent.text) or "Control Panel")
    end
    if frame.subtitle then
        frame.subtitle:SetText(CATEGORY_NOTES[categoryKey] or "")
    end
end

local function buildWindow()
    if FWR.ControlPanelWindow then
        return FWR.ControlPanelWindow
    end

    local frame = CreateFrame("Frame", "FarmWiseReforgedControlPanelWindow", UIParent, "BackdropTemplate")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    do local fp = WINDOW_CONFIG.framePoint or {}; frame:SetPoint(fp.point or "CENTER", UIParent, fp.relativePoint or "CENTER", fp.x or 0, fp.y or 0) end
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(30)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(unpack(COLOR_CONFIG.frameBg or { 0.04, 0.03, 0.02, 0.94 }))
    frame:SetBackdropBorderColor(unpack(COLOR_CONFIG.frameBorder or { 0.85, 0.65, 0.15, 0.55 }))

    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT", 0, 0)
    frame.header:SetPoint("TOPRIGHT", 0, 0)
    frame.header:SetHeight(HEADER_HEIGHT)
    frame.header:EnableMouse(true)
    frame.header:RegisterForDrag("LeftButton")
    frame.header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame.header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    frame.headerBg = frame.header:CreateTexture(nil, "BACKGROUND")
    frame.headerBg:SetAllPoints()
    frame.headerBg:SetColorTexture(unpack(COLOR_CONFIG.headerBg or { 0.10, 0.08, 0.05, 0.95 }))

    frame.footer = CreateFrame("Frame", nil, frame)
    frame.footer:SetPoint("BOTTOMLEFT", 0, 0)
    frame.footer:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.footer:SetHeight(FOOTER_HEIGHT)

    frame.footerBg = frame.footer:CreateTexture(nil, "BACKGROUND")
    frame.footerBg:SetAllPoints()
    frame.footerBg:SetColorTexture(unpack(COLOR_CONFIG.footerBg or { 0.10, 0.08, 0.05, 0.95 }))

    frame.sidebar = CreateFrame("Frame", nil, frame)
    frame.sidebar:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT)
    frame.sidebar:SetPoint("BOTTOMLEFT", 0, FOOTER_HEIGHT)
    frame.sidebar:SetWidth(SIDEBAR_WIDTH)

    frame.sidebarBg = frame.sidebar:CreateTexture(nil, "BACKGROUND")
    frame.sidebarBg:SetAllPoints()
    frame.sidebarBg:SetColorTexture(unpack(COLOR_CONFIG.sidebarBg or { 0.08, 0.06, 0.04, 0.9 }))

    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", frame.sidebar, "TOPRIGHT", 0, 0)
    frame.content:SetPoint("BOTTOMRIGHT", 0, FOOTER_HEIGHT)

    frame.contentBg = frame.content:CreateTexture(nil, "BACKGROUND")
    frame.contentBg:SetAllPoints()
    frame.contentBg:SetColorTexture(unpack(COLOR_CONFIG.contentBg or { 0.06, 0.05, 0.03, 0.82 }))

    do local c = COLOR_CONFIG.divider or {1,1,1,0.10}; createBorderLine(frame, "BOTTOMLEFT", frame.header, "BOTTOMLEFT", 0, 0, WINDOW_WIDTH, 1, c[1], c[2], c[3], c[4]) end
    do local c = COLOR_CONFIG.divider or {1,1,1,0.10}; createBorderLine(frame, "TOPLEFT", frame.footer, "TOPLEFT", 0, 0, WINDOW_WIDTH, 1, c[1], c[2], c[3], c[4]) end
    do local c = COLOR_CONFIG.divider or {1,1,1,0.10}; createBorderLine(frame, "TOPRIGHT", frame.sidebar, "TOPRIGHT", 0, 0, 1, WINDOW_HEIGHT - HEADER_HEIGHT - FOOTER_HEIGHT, c[1], c[2], c[3], c[4]) end

    frame.title = frame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", (HEADER_CONFIG.title and HEADER_CONFIG.title.x) or 18, (HEADER_CONFIG.title and HEADER_CONFIG.title.y) or -12)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetTextColor(unpack(COLOR_CONFIG.title or { 0.95, 0.82, 0.42, 1.0 }))
    frame.title:SetText((HEADER_CONFIG.title and HEADER_CONFIG.title.text) or "FarmWise")

    frame.titleAccent = frame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.titleAccent:SetPoint("LEFT", frame.title, "RIGHT", (HEADER_CONFIG.titleAccent and HEADER_CONFIG.titleAccent.x) or 6, (HEADER_CONFIG.titleAccent and HEADER_CONFIG.titleAccent.y) or 0)
    frame.titleAccent:SetJustifyH("LEFT")
    frame.titleAccent:SetTextColor(unpack(COLOR_CONFIG.titleAccent or { 0.96, 0.96, 0.96, 1.0 }))
    frame.titleAccent:SetText((HEADER_CONFIG.titleAccent and HEADER_CONFIG.titleAccent.text) or "Control Panel")

    frame.subtitle = frame.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", (HEADER_CONFIG.subtitle and HEADER_CONFIG.subtitle.x) or 0, (HEADER_CONFIG.subtitle and HEADER_CONFIG.subtitle.y) or -6)
    frame.subtitle:SetJustifyH("LEFT")
    frame.subtitle:SetTextColor(unpack(COLOR_CONFIG.subtitle or { 0.80, 0.80, 0.80, 1.0 }))
    frame.subtitle:SetText(CATEGORY_NOTES.interface or "")

    frame.closeButton = CreateFrame("Button", nil, frame.footer, "UIPanelButtonTemplate")
    frame.closeButton:SetSize((FOOTER_CONFIG.closeButton and FOOTER_CONFIG.closeButton.width) or 84, (FOOTER_CONFIG.closeButton and FOOTER_CONFIG.closeButton.height) or 24)
    frame.closeButton:SetPoint("RIGHT", frame.footer, "RIGHT", (FOOTER_CONFIG.closeButton and FOOTER_CONFIG.closeButton.x) or -18, (FOOTER_CONFIG.closeButton and FOOTER_CONFIG.closeButton.y) or 0)
    frame.closeButton:SetText((FOOTER_CONFIG.closeButton and FOOTER_CONFIG.closeButton.text) or "Close")
    frame.closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.footerNote = frame.footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.footerNote:SetPoint("LEFT", frame.footer, "LEFT", (FOOTER_CONFIG.note and FOOTER_CONFIG.note.x) or 18, (FOOTER_CONFIG.note and FOOTER_CONFIG.note.y) or 0)
    frame.footerNote:SetJustifyH("LEFT")
    frame.footerNote:SetTextColor(unpack(COLOR_CONFIG.footerNote or { 0.72, 0.72, 0.72, 1.0 }))
    frame.footerNote:SetText((FOOTER_CONFIG.note and FOOTER_CONFIG.note.text) or "Use the left menu to move between Interface, Display, Tracking, Engine, Data, and Info.")

    frame.contentInset = CreateFrame("Frame", nil, frame.content)
    frame.contentInset:SetPoint("TOPLEFT", frame.content, "TOPLEFT", CONTENT_PADDING, -18)
    frame.contentInset:SetPoint("BOTTOMRIGHT", frame.content, "BOTTOMRIGHT", -CONTENT_PADDING, CONTENT_PADDING)

    frame.CategoryButtons = {}
    frame.Pages = {}

    local navButtonConfig = CATEGORY_CONFIG.button or {}
    local previousButton
    for index, entry in ipairs(CATEGORY_ORDER) do
        local button = createCategoryButton(frame.sidebar, entry.label)
        if index == 1 then
            button:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT", navButtonConfig.startX or 12, navButtonConfig.startY or -18)
        else
            button:SetPoint("TOPLEFT", previousButton, "BOTTOMLEFT", 0, -(navButtonConfig.spacing or 4))
        end
        button:SetScript("OnClick", function()
            selectCategory(frame, entry.key)
        end)
        frame.CategoryButtons[entry.key] = button
        previousButton = button
    end

    frame.Pages.interface = createInterfacePage(frame.contentInset, frame)
    frame.Pages.display = createDisplayPage(frame.contentInset, frame)
    frame.Pages.tracking = createTrackingPage(frame.contentInset)
    frame.Pages.engine = createEnginePage(frame.contentInset)
    frame.Pages.data = createDataPage(frame.contentInset)
    frame.Pages.info = createInfoPage(frame.contentInset)

    selectCategory(frame, "interface")

    FWR.ControlPanelWindow = frame
    FWR.ControlPanel = frame
    return frame
end

function FWR:OpenControlPanelWindow()
    local frame = buildWindow()
    if self.OptionsPanel and self.OptionsPanel.Hide then
        self.OptionsPanel:Hide()
    end
    selectCategory(frame, "interface")
    refreshInterfaceDependencies(frame)
    if self.ApplySettingsVisibilityRules then
        self:ApplySettingsVisibilityRules(true)
    end
    frame:Show()
    frame:Raise()
end
