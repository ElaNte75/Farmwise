local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

local CONTROL_PANEL_CONFIG = FWR.UI_CONFIG and FWR.UI_CONFIG.ControlPanel or nil
local FRAME_CONFIG = CONTROL_PANEL_CONFIG and CONTROL_PANEL_CONFIG.frame or {}
local HEADER_CONFIG = CONTROL_PANEL_CONFIG and CONTROL_PANEL_CONFIG.header or {}
local BODY_CONFIG = CONTROL_PANEL_CONFIG and CONTROL_PANEL_CONFIG.body or {}
local BLOCKS_CONFIG = CONTROL_PANEL_CONFIG and CONTROL_PANEL_CONFIG.blocks or {}
BLOCKS_CONFIG.navigation = BLOCKS_CONFIG.navigation or {}
BLOCKS_CONFIG.navigation.button = BLOCKS_CONFIG.navigation.button or {}
BLOCKS_CONFIG.content = BLOCKS_CONFIG.content or {}
local RAW_SECTIONS_CONFIG = CONTROL_PANEL_CONFIG and CONTROL_PANEL_CONFIG.sections or {}
local function buildNormalizedSections(rawSections)
    local normalized = {}
    for index, section in ipairs(rawSections) do
        if type(section) == "table" then
            local key = section.key
            if not key or key == "" then
                local source = section.name or section.title or ("section" .. tostring(index))
                key = tostring(source):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
                if key == "" then
                    key = "section" .. tostring(index)
                end
            end
            normalized[#normalized + 1] = {
                key = key,
                name = section.name or section.label or section.title or ("Section " .. tostring(index)),
                title = section.title or section.name or section.label or "FarmWise Reforged",
                note = section.note or section.description or "",
            }
        end
    end
    return normalized
end
local SECTIONS_CONFIG = buildNormalizedSections(RAW_SECTIONS_CONFIG)
local DEFAULT_SECTION_KEY = (SECTIONS_CONFIG[1] and SECTIONS_CONFIG[1].key) or "interface"
local PAGE_CONFIG = CONTROL_PANEL_CONFIG and CONTROL_PANEL_CONFIG.page or {}

local SETTINGS_CATEGORY_NAME = FRAME_CONFIG.categoryName or "FarmWise Reforged"
local CLEAR_ALL_DATA_POPUP_KEY = "FWR_CONFIRM_CLEAR_ALL_DATA"
local REBUILD_SAVED_DATA_POPUP_KEY = "FWR_CONFIRM_REBUILD_SAVED_DATA"

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

local function unpackColor(color, fallbackAlpha)
    if type(color) ~= "table" then
        return 1, 1, 1, fallbackAlpha or 1
    end

    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or fallbackAlpha or 1
end

local function applyBackdrop(frame, backdropConfig)
    if not frame or not backdropConfig or backdropConfig.enabled == false or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = backdropConfig.bgFile,
        edgeFile = backdropConfig.edgeFile,
        tile = backdropConfig.tile,
        tileSize = backdropConfig.tileSize,
        edgeSize = backdropConfig.edgeSize,
        insets = backdropConfig.insets,
    })

    local bgR, bgG, bgB = unpackColor(backdropConfig.bgColor, backdropConfig.bgAlpha or 1)
    local borderR, borderG, borderB = unpackColor(backdropConfig.borderColor, backdropConfig.borderAlpha or 1)

    frame:SetBackdropColor(bgR, bgG, bgB, backdropConfig.bgAlpha or 1)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, backdropConfig.borderAlpha or 1)
end

local function createBackdropFrame(parent, backdropConfig)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", nil, parent, template)
    applyBackdrop(frame, backdropConfig)
    return frame
end

local function getBooleanSetting(path, fallback)
    local settings = FWR and FWR.Settings or nil
    local current = settings

    if type(path) ~= "table" then
        return fallback == true
    end

    for _, key in ipairs(path) do
        if type(current) ~= "table" then
            current = nil
            break
        end
        current = current[key]
    end

    if current == nil then
        return fallback == true
    end

    return current == true
end

local function setBooleanSetting(path, value)
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

    if FWR.ApplySettingsVisibilityRules then
        FWR:ApplySettingsVisibilityRules()
    end

    if FWR.ApplyDisplaySettings then
        FWR:ApplyDisplaySettings()
    end
end

local function getNumberSetting(path, fallback)
    local settings = FWR and FWR.Settings or nil
    local current = settings

    if type(path) ~= "table" then
        return tonumber(fallback) or 0
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
        current = tonumber(fallback) or 0
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

    if FWR.NormalizeDisplayColumnSettings then
        FWR:NormalizeDisplayColumnSettings()
    end

    if FWR.TouchDatabase then
        FWR:TouchDatabase()
    end

    if FWR.ApplyDisplaySettings then
        FWR:ApplyDisplaySettings()
    end
end


local function updateButtonVisual(button, isSelected, buttonConfig)
    if not button then
        return
    end

    if isSelected then
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end

    if button.text then
        local color = isSelected and buttonConfig.selectedTextColor or buttonConfig.normalTextColor
        local r, g, b, a = unpackColor(color, 1)
        button.text:SetTextColor(r, g, b, a)
    end
end

local function updateSectionSelection(frame, selectedKey)
    if not frame or not frame.SectionButtons or not frame.SectionPages then
        return
    end

    frame.SelectedSectionKey = selectedKey

    if FWR then
        FWR.__fwrLastOptionsSectionKey = selectedKey
        FWR.Settings = FWR.Settings or {}
        FWR.Settings.ui = FWR.Settings.ui or {}
        FWR.Settings.ui.lastOptionsSectionKey = selectedKey
    end

    for _, section in ipairs(SECTIONS_CONFIG) do
        local button = frame.SectionButtons[section.key]
        local page = frame.SectionPages[section.key]
        local isSelected = (section.key == selectedKey)

        updateButtonVisual(button, isSelected, BLOCKS_CONFIG.navigation.button or {})

        if page then
            page:SetShown(isSelected)
        end

        if isSelected then
            if frame.Header then
                frame.Header:SetText(section.title or section.name or SETTINGS_CATEGORY_NAME)
            end
            if frame.Description then
                frame.Description:SetText(section.note or "")
            end
        end
    end
end

local function updateCheckboxLabelColor(check, optionConfig, isChecked)
    if not check or not check.Text then
        return
    end

    if optionConfig and optionConfig.isReadOnly then
        check:SetAlpha(0.95)
        check.Text:SetTextColor(1.0, 0.82, 0.0, 1.0)
        return
    end

    if check.IsEnabled and not check:IsEnabled() then
        check:SetAlpha(0.45)
        check.Text:SetTextColor(0.55, 0.55, 0.55, 1.0)
        return
    end

    check:SetAlpha(1.0)
    if isChecked then
        check.Text:SetTextColor(1.0, 0.82, 0.0, 1.0)
    else
        check.Text:SetTextColor(0.82, 0.82, 0.82, 1.0)
    end
end

local function setCheckboxEnabledState(check, isEnabled, optionConfig, isChecked)
    if not check then
        return
    end

    if isEnabled then
        check:Enable()
    else
        check:Disable()
    end

    updateCheckboxLabelColor(check, optionConfig, isChecked)
end

local function createCheckboxRow(parent, previous, optionConfig)
    if not parent or type(optionConfig) ~= "table" then
        return previous
    end

    local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetHitRectInsets(0, 0, 0, 0)

    if previous then
        check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(optionConfig.spacing or 12))
    else
        check:SetPoint("TOPLEFT", parent, "TOPLEFT", optionConfig.x or 18, optionConfig.y or -18)
    end

    if check.Text then
        check.Text:ClearAllPoints()
        check.Text:SetPoint("LEFT", check, "RIGHT", optionConfig.textOffsetX or 6, optionConfig.textOffsetY or 1)
        check.Text:SetJustifyH("LEFT")
        check.Text:SetText(optionConfig.label or "")
    end

    if optionConfig.isReadOnly then
        check:SetChecked(optionConfig.checked == true)
        check:Disable()
        updateCheckboxLabelColor(check, optionConfig, optionConfig.checked == true)
    else
        local isChecked = getBooleanSetting(optionConfig.settingPath, optionConfig.defaultValue)
        check:SetChecked(isChecked)
        updateCheckboxLabelColor(check, optionConfig, isChecked)
        check:SetScript("OnClick", function(self)
            local checked = self:GetChecked() == true
            setBooleanSetting(optionConfig.settingPath, checked)
            updateCheckboxLabelColor(self, optionConfig, checked)
            if type(optionConfig.onValueChanged) == "function" then
                optionConfig.onValueChanged(self:GetParent(), checked)
            end
        end)
    end

    return check
end


local function refreshInterfaceCombatDependency(page)
    if not page or type(page.InterfaceControls) ~= "table" then
        return
    end

    local controls = page.InterfaceControls
    local showMainFrameCheck = controls.showMainFrame
    local showOnLoadCheck = controls.showMainWindowOnGameLoad
    local hideMainFrameCheck = controls.hideMainWindowInCombat
    local hidePanelsCheck = controls.hideControlPanelsInCombat
    local restoreCheck = controls.restoreControlPanelsAfterCombat

    local mainFrameEnabled = showMainFrameCheck and showMainFrameCheck:GetChecked() == true

    if showOnLoadCheck then
        if mainFrameEnabled then
            setCheckboxEnabledState(showOnLoadCheck, true, nil, showOnLoadCheck:GetChecked() == true)
        else
            if showOnLoadCheck:GetChecked() then
                showOnLoadCheck:SetChecked(false)
            end
            setBooleanSetting({ "ui", "showMainWindowOnGameLoad" }, false)
            setCheckboxEnabledState(showOnLoadCheck, false, nil, false)
        end
    end

    if hideMainFrameCheck then
        if mainFrameEnabled then
            setCheckboxEnabledState(hideMainFrameCheck, true, nil, hideMainFrameCheck:GetChecked() == true)
        else
            if hideMainFrameCheck:GetChecked() then
                hideMainFrameCheck:SetChecked(false)
            end
            setBooleanSetting({ "ui", "hideMainWindowInCombat" }, false)
            setCheckboxEnabledState(hideMainFrameCheck, false, nil, false)
        end
    end

    if not hidePanelsCheck or not restoreCheck then
        return
    end

    local hideEnabled = hidePanelsCheck:GetChecked() == true
    if hideEnabled then
        setCheckboxEnabledState(restoreCheck, true, nil, restoreCheck:GetChecked() == true)
    else
        if restoreCheck:GetChecked() then
            restoreCheck:SetChecked(false)
        end
        setBooleanSetting({ "ui", "restoreControlPanelsAfterCombat" }, false)
        setCheckboxEnabledState(restoreCheck, false, nil, false)
    end
end

local function createDisplaySectionPage(parent, section)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local displayConfig = PAGE_CONFIG.displayOptions or {}
    local rowSliderConfig = displayConfig.rowSlider or {}
    local headerTexts = displayConfig.sectionHeaders or {}
    local checkboxColumnX = displayConfig.checkboxColumnX or 18
    local visibilityHeaderX = displayConfig.visibilityHeaderX or checkboxColumnX
    local sliderColumnX = displayConfig.sliderColumnX or 300
    local orderHeaderX = displayConfig.orderHeaderX or sliderColumnX
    local sliderWidth = displayConfig.sliderWidth or 210
    local rowSliderTitleX = rowSliderConfig.titleX or checkboxColumnX
    local rowSliderTitleY = rowSliderConfig.titleY or -18
    local rowSliderX = rowSliderConfig.sliderX or sliderColumnX
    local rowSliderY = rowSliderConfig.sliderY or rowSliderTitleY - 3
    local rowSliderWidth = rowSliderConfig.sliderWidth or sliderWidth or 210
    local rowSliderMin = math.max(5, math.floor(tonumber(rowSliderConfig.min) or 5))
    local rowSliderMax = math.max(rowSliderMin, math.floor(tonumber(rowSliderConfig.max) or 20))
    local rowSliderLowOffsetX = rowSliderConfig.lowOffsetX or 0
    local rowSliderHighOffsetX = rowSliderConfig.highOffsetX or 0
    local rowSliderEndLabelOffsetY = rowSliderConfig.endLabelOffsetY or 0
    local sliderOffsetY = displayConfig.sliderOffsetY or -8
    local sliderEndLabelOffsetY = displayConfig.sliderEndLabelOffsetY or 0
    local sliderLowOffsetX = displayConfig.sliderLowOffsetX or 0
    local sliderHighOffsetX = displayConfig.sliderHighOffsetX or 0
    local startY = displayConfig.startY or -44
    local rowSpacing = displayConfig.rowSpacing or 34
    local headerY = displayConfig.headerY or -20
    local controlEntries = displayConfig.controls or {}

    local visibilityHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visibilityHeader:SetPoint("TOPLEFT", page, "TOPLEFT", visibilityHeaderX, headerY)
    visibilityHeader:SetJustifyH("LEFT")
    visibilityHeader:SetTextColor(1, 1, 1, 1)
    visibilityHeader:SetText(headerTexts.visibility or "Enable / Disable Columns")

    local orderHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    orderHeader:SetPoint("TOPLEFT", page, "TOPLEFT", orderHeaderX, headerY)
    orderHeader:SetJustifyH("LEFT")
    orderHeader:SetTextColor(1, 1, 1, 1)
    orderHeader:SetText(headerTexts.order or "Reorder Columns")

    local rowSliderTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rowSliderTitle:SetPoint("TOPLEFT", page, "TOPLEFT", rowSliderTitleX, rowSliderTitleY)
    rowSliderTitle:SetJustifyH("LEFT")
    rowSliderTitle:SetTextColor(1, 1, 1, 1)
    rowSliderTitle:SetText(rowSliderConfig.title or "Set Visible Rows")

    local rowSlider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
    rowSlider:SetPoint("TOPLEFT", page, "TOPLEFT", rowSliderX, rowSliderY)
    rowSlider:SetWidth(rowSliderWidth)
    rowSlider:SetMinMaxValues(rowSliderMin, rowSliderMax)
    rowSlider:SetValueStep(1)
    rowSlider:SetObeyStepOnDrag(true)
    rowSlider:SetOrientation("HORIZONTAL")
    rowSlider:SetStepsPerPage(1)
    rowSlider:SetThumbTexture("Interface\Buttons\UI-SliderBar-Button-Horizontal")
    if rowSlider.Text then rowSlider.Text:SetText("") end
    if rowSlider.Low then
        rowSlider.Low:ClearAllPoints()
        rowSlider.Low:SetPoint("RIGHT", rowSlider, "LEFT", rowSliderLowOffsetX, rowSliderEndLabelOffsetY)
        rowSlider.Low:SetText(tostring(rowSliderMin))
    end
    if rowSlider.High then
        rowSlider.High:ClearAllPoints()
        rowSlider.High:SetPoint("LEFT", rowSlider, "RIGHT", rowSliderHighOffsetX, rowSliderEndLabelOffsetY)
        rowSlider.High:SetText(tostring(rowSliderMax))
    end

    local dividerConfig = displayConfig.divider or {}
    if dividerConfig.enabled ~= false then
        local divider = page:CreateTexture(nil, "ARTWORK")
        local dcolor = dividerConfig.color or {}
        divider:SetColorTexture(dcolor[1] or 1, dcolor[2] or 1, dcolor[3] or 1, dcolor[4] or 0.18)
        divider:SetPoint("TOPLEFT", page, "TOPLEFT", dividerConfig.x or 18, dividerConfig.y or -52)
        divider:SetPoint("TOPRIGHT", page, "TOPRIGHT", -(dividerConfig.rightInset or 18), dividerConfig.y or -52)
        divider:SetHeight(dividerConfig.height or 1)
    end

    page.DisplayControls = {}

    local function refreshDisplayControls()
        if FWR.NormalizeDisplayColumnSettings then
            FWR:NormalizeDisplayColumnSettings()
        end

        local visibleRowsValue = getNumberSetting({ "display", "visibleRows" }, rowSliderMin)
        visibleRowsValue = math.max(rowSliderMin, math.min(rowSliderMax, visibleRowsValue))
        rowSliderTitle:SetText(string.format("%s (%d)", rowSliderConfig.title or "Set Visible Rows", visibleRowsValue))
        if rowSlider then
            rowSlider:SetValue(visibleRowsValue)
            rowSlider.__fwrPendingVisibleRowsValue = visibleRowsValue
        end

        for _, entry in ipairs(controlEntries) do
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
                if widgets.check then
                    widgets.check:SetChecked(enabled)
                    if widgets.check.Text then
                        widgets.check.Text:SetText((entry.label or "") .. orderSuffix)
                    end
                    updateCheckboxLabelColor(widgets.check, { isReadOnly = isLocked }, enabled)
                end
                if widgets.slider then
                    local enabledCount = FWR.GetEnabledReorderableMainColumnCount and FWR:GetEnabledReorderableMainColumnCount() or 0
                    local enabledMaxPosition = math.max(2, enabledCount + 1)
                    local sliderMin = 2
                    local sliderMax = enabledMaxPosition
                    local sliderValue = enabled and math.max(sliderMin, math.min(sliderMax, value)) or sliderMax
                    widgets.slider:SetMinMaxValues(sliderMin, sliderMax)
                    if widgets.slider.Low then widgets.slider.Low:SetText(tostring(sliderMin)) end
                    if widgets.slider.High then widgets.slider.High:SetText(tostring(sliderMax)) end
                    widgets.slider:SetValue(sliderValue)
                    local thumb = widgets.slider.GetThumbTexture and widgets.slider:GetThumbTexture() or nil
                    if isLocked or not enabled then
                        widgets.slider:Disable()
                        if thumb and thumb.SetAlpha then thumb:SetAlpha(0) end
                        if widgets.slider.Low then widgets.slider.Low:SetAlpha(0.55) end
                        if widgets.slider.High then widgets.slider.High:SetAlpha(0.55) end
                        if widgets.slider.Text then widgets.slider.Text:SetAlpha(0.55) end
                    else
                        widgets.slider:Enable()
                        if thumb and thumb.SetAlpha then thumb:SetAlpha(1) end
                        if widgets.slider.Low then widgets.slider.Low:SetAlpha(1) end
                        if widgets.slider.High then widgets.slider.High:SetAlpha(1) end
                        if widgets.slider.Text then widgets.slider.Text:SetAlpha(1) end
                    end
                end
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
        if FWR.RefreshDisplayText then
            FWR:RefreshDisplayText()
            if FWR.RefreshDisplayLiveMetrics then
                FWR:RefreshDisplayLiveMetrics(true)
            end
        end
    end

    local function commitVisibleRowsSliderValue(value)
        local snapped = math.floor((tonumber(value) or 0) + 0.5)
        local clamped = math.max(rowSliderMin, math.min(rowSliderMax, snapped))
        if getNumberSetting({ "display", "visibleRows" }, rowSliderMin) == clamped then
            rowSliderTitle:SetText(string.format("%s (%d)", rowSliderConfig.title or "Set Visible Rows", clamped))
            return
        end

        setNumberSetting({ "display", "visibleRows" }, clamped)
        if FWR.ApplyDisplaySettings then
            FWR:ApplyDisplaySettings()
        elseif FWR.RefreshDisplayText then
            FWR:RefreshDisplayText()
            if FWR.RefreshDisplayLiveMetrics then
                FWR:RefreshDisplayLiveMetrics(true)
            end
        end
        rowSliderTitle:SetText(string.format("%s (%d)", rowSliderConfig.title or "Set Visible Rows", clamped))
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

        local clamped = math.max(rowSliderMin, math.min(rowSliderMax, snapped))
        self.__fwrPendingVisibleRowsValue = clamped
        rowSliderTitle:SetText(string.format("%s (%d)", rowSliderConfig.title or "Set Visible Rows", clamped))
    end)

    rowSlider:SetScript("OnMouseUp", function(self)
        commitVisibleRowsSliderValue(self.__fwrPendingVisibleRowsValue or self:GetValue())
    end)

    rowSlider:SetScript("OnHide", function(self)
        commitVisibleRowsSliderValue(self.__fwrPendingVisibleRowsValue or self:GetValue())
    end)

    for index, entry in ipairs(controlEntries) do
        local rowY = startY - ((index - 1) * rowSpacing)
        local check = CreateFrame("CheckButton", nil, page, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", page, "TOPLEFT", checkboxColumnX, rowY)
        check:SetHitRectInsets(0, 0, 0, 0)
        if check.Text then
            check.Text:ClearAllPoints()
            check.Text:SetPoint("LEFT", check, "RIGHT", 6, 1)
            check.Text:SetJustifyH("LEFT")
            check.Text:SetText(entry.label or "")
        end

        if entry.locked then
            check:SetChecked(true)
            check:Disable()
            updateCheckboxLabelColor(check, { isReadOnly = true }, true)
        else
            local enabled = getBooleanSetting({ "display", "optionalColumns", entry.key }, entry.defaultValue)
            check:SetChecked(enabled)
            updateCheckboxLabelColor(check, nil, enabled)
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
                updateCheckboxLabelColor(self, nil, checked)
                refreshDisplayControls()
                if FWR.TouchDatabase then
                    FWR:TouchDatabase()
                end
                if FWR.ApplyDisplaySettings then
                    FWR:ApplyDisplaySettings()
                end
                if FWR.RefreshDisplayText then
                    FWR:RefreshDisplayText()
                    if FWR.RefreshDisplayLiveMetrics then
                        FWR:RefreshDisplayLiveMetrics(true)
                    end
                end
            end)
        end

        local slider
        if not entry.locked then
            slider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
            slider:SetPoint("TOPLEFT", page, "TOPLEFT", sliderColumnX, rowY + sliderOffsetY)
            slider:SetWidth(sliderWidth)
            slider:SetMinMaxValues(2, math.max(2, #controlEntries))
            slider:SetValueStep(1)
            slider:SetObeyStepOnDrag(true)
            slider:SetOrientation("HORIZONTAL")
            slider:SetStepsPerPage(1)
            slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
            if slider.Text then slider.Text:SetText("") end
            if slider.Low then
                slider.Low:ClearAllPoints()
                slider.Low:SetPoint("RIGHT", slider, "LEFT", sliderLowOffsetX, sliderEndLabelOffsetY)
                slider.Low:SetText("2")
            end
            if slider.High then
                slider.High:ClearAllPoints()
                slider.High:SetPoint("LEFT", slider, "RIGHT", sliderHighOffsetX, sliderEndLabelOffsetY)
                slider.High:SetText(tostring(math.max(2, #controlEntries)))
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
    end

    page.RefreshDisplayControls = function()
        if rowSlider then
            rowSlider.__fwrRefreshing = true
        end
        for _, widgets in pairs(page.DisplayControls or {}) do
            if widgets.slider then
                widgets.slider.__fwrRefreshing = true
            end
        end
        refreshDisplayControls()
        for _, widgets in pairs(page.DisplayControls or {}) do
            if widgets.slider then
                widgets.slider.__fwrRefreshing = nil
            end
        end
        if rowSlider then
            rowSlider.__fwrRefreshing = nil
        end
    end

    page:SetScript("OnShow", function(self)
        if self.RefreshDisplayControls then
            self:RefreshDisplayControls()
        end
    end)

    if page.RefreshDisplayControls then
        page:RefreshDisplayControls()
    end

    return page
end

local function refreshTrackingFilterDependency(page, optionsByKey)
    if not page or not page.TrackingControls then
        return
    end

    local showControl = page.TrackingControls.showSpecializedClassifications
    local onlyControl = page.TrackingControls.onlySpecializedClassifications
    local onlyChecked = FWR and FWR.IsOnlySpecializedClassificationVisible and FWR:IsOnlySpecializedClassificationVisible() or false

    if showControl then
        if onlyChecked then
            showControl:SetChecked(false)
            setCheckboxEnabledState(showControl, false, optionsByKey and optionsByKey.showSpecializedClassifications, false)
        else
            local showChecked = FWR and FWR.IsSpecializedClassificationVisible and FWR:IsSpecializedClassificationVisible() or false
            showControl:SetChecked(showChecked)
            setCheckboxEnabledState(showControl, true, optionsByKey and optionsByKey.showSpecializedClassifications, showChecked)
        end
    end

    if onlyControl then
        onlyControl:SetChecked(onlyChecked)
        setCheckboxEnabledState(onlyControl, true, optionsByKey and optionsByKey.onlySpecializedClassifications, onlyChecked)
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
        setCheckboxEnabledState(combinedAllControl, true, optionsByKey and optionsByKey.combinedAllData, combinedAllChecked)
    end

    if combinedCharacterControl then
        combinedCharacterControl:SetChecked(combinedCharacterChecked)
        setCheckboxEnabledState(combinedCharacterControl, true, optionsByKey and optionsByKey.combinedCharacterAllZones, combinedCharacterChecked)
    end

    if zoneControl then
        local zoneChecked = FWR and FWR.IsZoneDataEnabled and FWR:IsZoneDataEnabled() or false
        if combinedModeActive then
            zoneControl:SetChecked(false)
            setCheckboxEnabledState(zoneControl, false, optionsByKey and optionsByKey.zoneData, false)
        else
            zoneControl:SetChecked(zoneChecked)
            setCheckboxEnabledState(zoneControl, true, optionsByKey and optionsByKey.zoneData, zoneChecked)
        end
    end

    if subZoneControl then
        local subZoneChecked = FWR and FWR.IsSubZoneDataEnabled and FWR:IsSubZoneDataEnabled() or false
        if combinedModeActive then
            subZoneControl:SetChecked(false)
            setCheckboxEnabledState(subZoneControl, false, optionsByKey and optionsByKey.subZoneData, false)
        else
            subZoneControl:SetChecked(subZoneChecked)
            setCheckboxEnabledState(subZoneControl, true, optionsByKey and optionsByKey.subZoneData, subZoneChecked)
        end
    end
end

local function createTrackingSectionPage(parent, section)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local options = PAGE_CONFIG.trackingOptions or {}
    local previous
    page.TrackingControls = {}
    local optionByKey = {}

    local function refreshTrackingControls()
        for _, optionConfig in ipairs(options) do
            local settingPath = optionConfig.settingPath or {}
            local settingKey = settingPath[#settingPath]
            local control = settingKey and page.TrackingControls[settingKey] or nil
            if control and settingKey then
                local checked = getBooleanSetting(optionConfig.settingPath, optionConfig.defaultValue)
                control:SetChecked(checked)
                updateCheckboxLabelColor(control, optionConfig, checked)
            end
        end

        refreshTrackingFilterDependency(page, optionByKey)
    end

    for _, optionConfig in ipairs(options) do
        local control = createCheckboxRow(page, previous, optionConfig)
        previous = control

        local settingPath = optionConfig.settingPath or {}
        local settingKey = settingPath[#settingPath]
        if settingKey then
            page.TrackingControls[settingKey] = control
            optionByKey[settingKey] = optionConfig
        end

        control:SetScript("OnClick", function(self)
            local checked = self:GetChecked() == true
            if settingKey == "combinedAllData" and FWR.SetCombinedAllDataEnabled then
                FWR:SetCombinedAllDataEnabled(checked)
            elseif settingKey == "combinedCharacterAllZones" and FWR.SetCombinedCharacterAllZonesEnabled then
                FWR:SetCombinedCharacterAllZonesEnabled(checked)
            elseif settingKey == "zoneData" and FWR.SetZoneDataEnabled then
                FWR:SetZoneDataEnabled(checked)
            elseif settingKey == "subZoneData" and FWR.SetSubZoneDataEnabled then
                FWR:SetSubZoneDataEnabled(checked)
            elseif settingKey == "showSpecializedClassifications" and FWR.SetSpecializedClassificationVisible then
                FWR:SetSpecializedClassificationVisible(checked)
            elseif settingKey == "onlySpecializedClassifications" and FWR.SetOnlySpecializedClassificationVisible then
                FWR:SetOnlySpecializedClassificationVisible(checked)
            elseif settingKey == "showOldExpansions" and FWR.SetOldExpansionVisible then
                FWR:SetOldExpansionVisible(checked)
            else
                setBooleanSetting(optionConfig.settingPath, checked)
                if type(optionConfig.onValueChanged) == "function" then
                    optionConfig.onValueChanged(self:GetParent(), checked)
                end
            end
            if FWR.ApplyDisplaySettings then
                FWR:ApplyDisplaySettings()
            end
            refreshTrackingControls()
        end)
    end

    page.RefreshTrackingControls = refreshTrackingControls
    page:SetScript("OnShow", function(self)
        if self.RefreshTrackingControls then
            self:RefreshTrackingControls()
        end
    end)

    if page.RefreshTrackingControls then
        page:RefreshTrackingControls()
    end

    return page
end

local function createDataSectionPage(parent, section)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local rebuildNote = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rebuildNote:SetPoint("TOPLEFT", page, "TOPLEFT", 18, -20)
    rebuildNote:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    rebuildNote:SetJustifyH("LEFT")
    rebuildNote:SetJustifyV("TOP")
    rebuildNote:SetText("Rebuild saved item metadata from the current database using the latest tracker rules.")

    local rebuildLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rebuildLabel:SetPoint("TOPLEFT", rebuildNote, "BOTTOMLEFT", 0, -18)
    rebuildLabel:SetJustifyH("LEFT")
    rebuildLabel:SetTextColor(1, 1, 1, 1)
    rebuildLabel:SetText("Rebuild Saved Data")

    local rebuildButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    rebuildButton:SetSize(140, 24)
    rebuildButton:SetPoint("LEFT", rebuildLabel, "RIGHT", 36, 0)
    rebuildButton:SetText("Rebuild")
    rebuildButton:SetScript("OnClick", function()
        ensureRebuildSavedDataPopup()
        if StaticPopup_Show then
            StaticPopup_Show(REBUILD_SAVED_DATA_POPUP_KEY)
        end
    end)

    local progressBarBackdrop = createBackdropFrame(page, {
        enabled = true,
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
        bgColor = { 0.07, 0.07, 0.07, 0.85 },
        borderColor = { 0.32, 0.32, 0.32, 0.9 },
        bgAlpha = 0.85,
        borderAlpha = 0.9,
    })
    progressBarBackdrop:SetSize(260, 12)
    progressBarBackdrop:SetPoint("TOPLEFT", rebuildLabel, "BOTTOMLEFT", 0, -12)

    local progressFill = progressBarBackdrop:CreateTexture(nil, "ARTWORK")
    progressFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    progressFill:SetPoint("TOPLEFT", progressBarBackdrop, "TOPLEFT", 1, -1)
    progressFill:SetPoint("BOTTOMLEFT", progressBarBackdrop, "BOTTOMLEFT", 1, 1)
    progressFill:SetWidth(0)
    progressFill:SetColorTexture(0.78, 0.63, 0.18, 0.95)

    local progressText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressText:SetPoint("TOPLEFT", progressBarBackdrop, "BOTTOMLEFT", 0, -6)
    progressText:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    progressText:SetJustifyH("LEFT")
    progressText:SetText("Ready")

    local note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT", progressText, "BOTTOMLEFT", 0, -22)
    note:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    note:SetJustifyH("LEFT")
    note:SetJustifyV("TOP")
    note:SetText("Erase the full saved tracking database and start from the clean state. Settings stay as they are.")

    local actionLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionLabel:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -18)
    actionLabel:SetJustifyH("LEFT")
    actionLabel:SetTextColor(1, 1, 1, 1)
    actionLabel:SetText("Erase Data")

    local eraseButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    eraseButton:SetSize(110, 24)
    eraseButton:SetPoint("LEFT", actionLabel, "RIGHT", 36, 0)
    eraseButton:SetText("Erase")
    eraseButton:SetScript("OnClick", function()
        ensureClearAllDataPopup()
        if StaticPopup_Show then
            StaticPopup_Show(CLEAR_ALL_DATA_POPUP_KEY)
        end
    end)

    local function refreshRebuildStatus()
        local status = FWR.GetSavedDataRebuildStatus and FWR:GetSavedDataRebuildStatus() or nil
        local percent = status and tonumber(status.percent) or 0
        if percent < 0 then
            percent = 0
        elseif percent > 100 then
            percent = 100
        end

        local width = math.floor((258 * percent) / 100)
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

    page.RefreshRebuildStatus = refreshRebuildStatus
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

    if page.RefreshRebuildStatus then
        page:RefreshRebuildStatus()
    end

    return page
end

local function createSectionPage(parent, section)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    if section and section.key == "interface" then
        local options = PAGE_CONFIG.interfaceOptions or {}
        local previous
        page.InterfaceControls = {}

        for _, optionConfig in ipairs(options) do
            local control = createCheckboxRow(page, previous, optionConfig)
            previous = control

            local settingPath = optionConfig.settingPath or {}
            local settingKey = settingPath[#settingPath]
            if settingKey then
                page.InterfaceControls[settingKey] = control
            end

            if settingKey == "hideControlPanelsInCombat" or settingKey == "showMainFrame" then
                control:SetScript("OnClick", function(self)
                    local checked = self:GetChecked() == true
                    setBooleanSetting(optionConfig.settingPath, checked)
                    updateCheckboxLabelColor(self, optionConfig, checked)
                    refreshInterfaceCombatDependency(page)
                    if settingKey == "showMainFrame" and FWR and FWR.ApplySettingsVisibilityRules then
                        FWR:ApplySettingsVisibilityRules(true)
                    end
                    if type(optionConfig.onValueChanged) == "function" then
                        optionConfig.onValueChanged(self:GetParent(), checked)
                    end
                end)
            end
        end

        refreshInterfaceCombatDependency(page)
    elseif section and section.key == "display" then
        return createDisplaySectionPage(parent, section)
    elseif section and section.key == "tracking" then
        return createTrackingSectionPage(parent, section)
    elseif section and section.key == "data" then
        return createDataSectionPage(parent, section)
    end

    return page
end
local function createSidebarButton(parent, text)
    local buttonConfig = BLOCKS_CONFIG.navigation.button or {}
    local button = CreateFrame("Button", nil, parent, buttonConfig.template or "OptionsListButtonTemplate")
    button:SetHeight(buttonConfig.height or 18)
    button.text:SetText(text)
    button.text:SetJustifyH(buttonConfig.justifyH or "LEFT")
    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", button, "LEFT", buttonConfig.textInsetLeft or 8, 0)
    button.text:SetPoint("RIGHT", button, "RIGHT", -(buttonConfig.textInsetRight or 8), 0)

    if buttonConfig.normalFont then
        button:SetNormalFontObject(buttonConfig.normalFont)
    end
    if buttonConfig.highlightFont then
        button:SetHighlightFontObject(buttonConfig.highlightFont)
    end

    updateButtonVisual(button, false, buttonConfig)
    return button
end

local function initializeInternalLayout(frame)
    if not frame or frame.__fwrInitialized then
        return frame
    end

    frame:SetClipsChildren(FRAME_CONFIG.clipsChildren ~= false)

    local titleConfig = HEADER_CONFIG.title or {}
    local descriptionConfig = HEADER_CONFIG.description or {}

    local header = frame:CreateFontString(nil, "OVERLAY", titleConfig.font or "GameFontNormalLarge")
    header:SetPoint(titleConfig.point or "TOPLEFT", frame, titleConfig.relativePoint or "TOPLEFT", titleConfig.x or 16, titleConfig.y or -16)
    header:SetText(titleConfig.text or SETTINGS_CATEGORY_NAME)
    frame.Header = header

    local description = frame:CreateFontString(nil, "OVERLAY", descriptionConfig.font or "GameFontHighlight")
    description:SetPoint(descriptionConfig.point or "TOPLEFT", header, descriptionConfig.relativePoint or "BOTTOMLEFT", descriptionConfig.x or 0, descriptionConfig.y or -10)
    description:SetPoint("RIGHT", frame, "RIGHT", -(descriptionConfig.rightInset or 20), 0)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetText(descriptionConfig.text or "")
    frame.Description = description

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint(BODY_CONFIG.point or "TOPLEFT", description, BODY_CONFIG.relativePoint or "BOTTOMLEFT", BODY_CONFIG.x or -2, BODY_CONFIG.y or -12)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", BODY_CONFIG.bottomRightX or -14, BODY_CONFIG.bottomRightY or 12)
    frame.Body = body

    local navigationConfig = BLOCKS_CONFIG.navigation or {}
    local contentConfig = BLOCKS_CONFIG.content or {}

    local sidebar = createBackdropFrame(body, navigationConfig.backdrop)
    sidebar:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(navigationConfig.width or 184)
    frame.Sidebar = sidebar

    local content = createBackdropFrame(body, contentConfig.backdrop)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", navigationConfig.gapToContent or 14, 0)
    content:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
    frame.Content = content

    frame.SectionButtons = {}
    frame.SectionPages = {}

    local previousButton
    for index, section in ipairs(SECTIONS_CONFIG) do
        local button = createSidebarButton(sidebar, section.name)
        button:SetPoint("LEFT", sidebar, "LEFT", (navigationConfig.innerPadding and navigationConfig.innerPadding.left) or 10, 0)
        button:SetPoint("RIGHT", sidebar, "RIGHT", -((navigationConfig.innerPadding and navigationConfig.innerPadding.right) or 24), 0)

        if index == 1 then
            button:SetPoint("TOP", sidebar, "TOP", 0, -((navigationConfig.innerPadding and navigationConfig.innerPadding.top) or 14))
        else
            button:SetPoint("TOP", previousButton, "BOTTOM", 0, -((navigationConfig.button and navigationConfig.button.spacing) or 6))
        end

        button:SetScript("OnClick", function()
            updateSectionSelection(frame, section.key)
        end)

        frame.SectionButtons[section.key] = button
        previousButton = button

        local page = createSectionPage(content, section)
        page:Hide()
        frame.SectionPages[section.key] = page
    end

    frame:SetScript("OnShow", function(self)
        updateSectionSelection(self, DEFAULT_SECTION_KEY)
    end)

    frame.__fwrInitialized = true
    return frame
end

local function createRootSettingsFrame()
    local frame = CreateFrame("Frame", FRAME_CONFIG.name or "FarmWiseReforgedSettingsRootPanel", UIParent)
    frame.name = SETTINGS_CATEGORY_NAME
    frame:SetSize(FRAME_CONFIG.width or 900, FRAME_CONFIG.height or 560)
    initializeInternalLayout(frame)
    return frame
end

local function closeOptionsBackToGame()
    local function tryCloseGameMenu()
        if not (_G and _G.GameMenuFrame and _G.GameMenuFrame:IsShown()) then
            return
        end

        if type(HideUIPanel) == "function" then
            HideUIPanel(_G.GameMenuFrame)
        end

        if _G.GameMenuFrame:IsShown() and type(ToggleGameMenu) == "function" then
            ToggleGameMenu()
        end
    end

    tryCloseGameMenu()

    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, tryCloseGameMenu)
        C_Timer.After(0.05, tryCloseGameMenu)
    end
end

local function collectManagedControlPanels(self)
    local panels = {}

    local function add(panel, key)
        if not panel or panels[key] then
            return
        end
        if type(panel.IsObjectType) == "function" and panel:IsObjectType("Frame") then
            panels[key] = panel
        end
    end

    add(self and self.ControlPanel, "customControlPanel")
    add(self and self.OptionsPanel, "optionsPanel")
    add(_G and _G.SettingsPanel, "settingsPanel")
    add(_G and _G.InterfaceOptionsFrame, "interfaceOptionsFrame")

    return panels
end

local function isPlayerInCombat()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return true
    end

    if type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player") then
        return true
    end

    return false
end

local function restoreLastOptionsCategory(self)
    if not self then
        return
    end

    local lastSectionKey = self.__fwrLastOptionsSectionKey
        or (self.Settings and self.Settings.ui and self.Settings.ui.lastOptionsSectionKey)
        or (SECTIONS_CONFIG[1] and SECTIONS_CONFIG[1].key)

    if self.OpenOptionsCategory then
        self:OpenOptionsCategory()
    end

    local panel = self.OptionsPanel
    if panel and not panel.__fwrInitialized then
        initializeInternalLayout(panel)
    end

    if panel and lastSectionKey then
        updateSectionSelection(panel, lastSectionKey)
    end
end

function FWR:ApplySettingsVisibilityRules(forceRefresh)
    local settings = self.Settings or {}
    local ui = settings.ui or {}
    local inCombat = isPlayerInCombat()
    local shouldShowMainFrame = ui.mainWindowVisible ~= false

    if self.MainFrame then
        if inCombat and ui.hideMainWindowInCombat == true then
            if self.__fwrMainFrameCombatSnapshot == nil then
                self.__fwrMainFrameCombatSnapshot = self.MainFrame:IsShown() == true
            end
            if self.MainFrame:IsShown() then
                self.MainFrame:Hide()
            end
        else
            local shouldRestoreMainFrame = (self.__fwrMainFrameCombatSnapshot == true) or (not inCombat and shouldShowMainFrame == true and forceRefresh == true)
            if shouldShowMainFrame and shouldRestoreMainFrame and not self.MainFrame:IsShown() then
                self.MainFrame:Show()
            elseif shouldShowMainFrame == false and self.MainFrame:IsShown() then
                self.MainFrame:Hide()
            end

            if not inCombat then
                self.__fwrMainFrameCombatSnapshot = nil
            end
        end
    end

    local managedPanels = collectManagedControlPanels(self)
    self.__fwrHiddenControlPanelsByCombat = self.__fwrHiddenControlPanelsByCombat or {}

    if inCombat and ui.hideControlPanelsInCombat == true then
        for key, panel in pairs(managedPanels) do
            if panel:IsShown() then
                self.__fwrHiddenControlPanelsByCombat[key] = true

                if key == "optionsPanel" or key == "settingsPanel" or key == "interfaceOptionsFrame" then
                    self.__fwrShouldRestoreOptionsCategory = true
                    self.__fwrLastOptionsSectionKey = self.__fwrLastOptionsSectionKey
                        or (self.OptionsPanel and self.OptionsPanel.SelectedSectionKey)
                        or (self.Settings and self.Settings.ui and self.Settings.ui.lastOptionsSectionKey)
                        or (SECTIONS_CONFIG[1] and SECTIONS_CONFIG[1].key)
                end

                panel:Hide()
            elseif self.__fwrHiddenControlPanelsByCombat[key] == nil then
                self.__fwrHiddenControlPanelsByCombat[key] = false
            end
        end
    elseif not inCombat then
        if ui.restoreControlPanelsAfterCombat == true then
            local shouldRestoreOptionsCategory = self.__fwrShouldRestoreOptionsCategory == true and (
                self.__fwrHiddenControlPanelsByCombat.optionsPanel == true
                or self.__fwrHiddenControlPanelsByCombat.settingsPanel == true
                or self.__fwrHiddenControlPanelsByCombat.interfaceOptionsFrame == true
            )

            for key, wasHidden in pairs(self.__fwrHiddenControlPanelsByCombat) do
                if wasHidden == true then
                    if key ~= "optionsPanel" and key ~= "settingsPanel" and key ~= "interfaceOptionsFrame" then
                        local panel = managedPanels[key]
                        if panel and type(panel.Show) == "function" and not panel:IsShown() then
                            panel:Show()
                        end
                    end
                end
            end

            if shouldRestoreOptionsCategory then
                restoreLastOptionsCategory(self)
            end
        end
        self.__fwrHiddenControlPanelsByCombat = {}
        self.__fwrShouldRestoreOptionsCategory = nil
    end
end

function FWR:RegisterOptionsCategory()
    if self.OptionsRegistered and self.OptionsCategoryID then
        return self.OptionsCategoryID
    end

    if type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function" then
        local rootPanel = self.OptionsPanel or createRootSettingsFrame()
        local rootCategory = Settings.RegisterCanvasLayoutCategory(rootPanel, rootPanel.name, rootPanel.name)
        self.OptionsPanel = rootPanel
        self.OptionsCategory = rootCategory
        self.OptionsCategoryID = rootCategory and rootCategory.GetID and rootCategory:GetID() or rootCategory and rootCategory.ID or nil

        if type(Settings.RegisterAddOnCategory) == "function" and rootCategory then
            Settings.RegisterAddOnCategory(rootCategory)
        end

        self.OptionsRegistered = true

        if not self.__fwrSettingsCloseHooked and _G and _G.SettingsPanel and _G.SettingsPanel.CloseButton and _G.SettingsPanel.CloseButton.HookScript then
            _G.SettingsPanel.CloseButton:HookScript("OnClick", closeOptionsBackToGame)
            self.__fwrSettingsCloseHooked = true
        end

        return self.OptionsCategoryID
    end

    if self.OptionsRegistered and self.OptionsPanel then
        return self.OptionsPanel
    end

    local panel = self.OptionsPanel or createRootSettingsFrame()
    panel.name = SETTINGS_CATEGORY_NAME

    if type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(panel)
    end

    self.OptionsPanel = panel
    self.OptionsRegistered = true

    if not self.__fwrInterfaceOptionsCloseHooked and _G and _G.InterfaceOptionsFrame and _G.InterfaceOptionsFrame.CloseButton and _G.InterfaceOptionsFrame.CloseButton.HookScript then
        _G.InterfaceOptionsFrame.CloseButton:HookScript("OnClick", closeOptionsBackToGame)
        self.__fwrInterfaceOptionsCloseHooked = true
    end

    return panel
end

function FWR:OpenOptionsCategory()
    self:RegisterOptionsCategory()

    local defaultSectionKey = DEFAULT_SECTION_KEY
    if self.OptionsPanel and not self.OptionsPanel.__fwrInitialized then
        initializeInternalLayout(self.OptionsPanel)
    end

    if type(Settings) == "table" and type(Settings.OpenToCategory) == "function" and self.OptionsCategoryID then
        Settings.OpenToCategory(self.OptionsCategoryID)
        if self.OptionsPanel then
            updateSectionSelection(self.OptionsPanel, defaultSectionKey)
        end
        return
    end

    if type(InterfaceOptionsFrame_OpenToCategory) == "function" and self.OptionsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.OptionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.OptionsPanel)
        updateSectionSelection(self.OptionsPanel, defaultSectionKey)
    end
end
