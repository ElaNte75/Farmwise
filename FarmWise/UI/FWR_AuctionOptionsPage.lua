local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- The "Options" page of the FarmWise AH tab (the FarmWise Auction House), after "History".
--
-- It holds the settings of what the tab does (Sell, Actions, History): how it posts, the average price, what the
-- list holds, what it shows, the sales history. The settings of FarmWise itself (the scan, the prices in tooltips,
-- the switch that adds the tab) are in the control panel of FarmWise.
--
-- Made like a small web page: a row of category tabs across the whole width, and under the tab that is chosen,
-- "cards" in two columns, each with one subject.

local GOLD = { 1, 0.82, 0 }
local GREY = { 0.72, 0.72, 0.72 }

------------------------------------------------------------
-- the settings (FWR.Settings.ah)
------------------------------------------------------------
local function aheadSettings()
    FWR.Settings = FWR.Settings or {}
    FWR.Settings.ah = type(FWR.Settings.ah) == "table" and FWR.Settings.ah or {}
    return FWR.Settings.ah
end

local function getBool(key, default)
    local value = aheadSettings()[key]
    if value == nil then
        return default == true
    end
    return value == true
end

local function setBool(key, value)
    aheadSettings()[key] = value == true
    if FWR.TouchDatabase then
        FWR:TouchDatabase()
    end
end

local function getNumber(key, default)
    local value = tonumber(aheadSettings()[key])
    if value == nil then
        return tonumber(default) or 0
    end
    return value
end

local function setNumber(key, value)
    aheadSettings()[key] = tonumber(value) or 0
    if FWR.TouchDatabase then
        FWR:TouchDatabase()
    end
end

-- the wording (labels and explanations) is the one of the configuration of the control panel
local function texts(section)
    local config = FWR.UI_CONFIG and FWR.UI_CONFIG.ControlPanelWindow
    local pages = config and config.pages or {}
    return pages[section] or {}
end

------------------------------------------------------------
-- small pieces of interface
------------------------------------------------------------
local function explain(frame, title, text)
    if not frame or type(text) ~= "string" or text == "" then
        return
    end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function paintCheck(check)
    if not check.Text then
        return
    end
    if check:IsEnabled() then
        check:SetAlpha(1)
        if check:GetChecked() then
            check.Text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            check.Text:SetTextColor(0.85, 0.85, 0.85)
        end
    else
        check:SetAlpha(0.45)
        check.Text:SetTextColor(0.55, 0.55, 0.55)
    end
end

local function build(api)
    local panel = api.panel
    if not api.addPage or not api.createSubTab then
        return
    end

    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, 3)
    page:SetFrameLevel(panel:GetFrameLevel() + 20)
    page:EnableMouse(true)
    page:Hide()

    local background = page:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local ok = pcall(function()
        background:SetAtlas("auctionhouse-background-index")
    end)
    if not ok then
        background:SetColorTexture(0.12, 0.115, 0.11, 1)
    end

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel.title, "TOPLEFT", 0, 0)
    title:SetText("FarmWise AH options")
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    -- the area under the title, as wide as the list of the other pages
    local area = CreateFrame("Frame", nil, page)
    area:SetPoint("TOPLEFT", panel.list, "TOPLEFT", 0, 4)
    area:SetPoint("RIGHT", panel.list, "RIGHT", 0, 0)
    area:SetPoint("BOTTOM", page, "BOTTOM", 0, 12)

    local built = false
    local refreshers = {}

    local function refreshAll()
        for _, refresh in ipairs(refreshers) do
            refresh()
        end
    end

    ----------------------------------------------------------
    -- the building blocks of a category
    ----------------------------------------------------------
    local CARD_GAP = 14

    local function newCategory()
        local category = CreateFrame("Frame", nil, area)
        category:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -36)
        category:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, 0)
        category:Hide()
        category.nextY = { left = 0, right = 0 }
        return category
    end

    -- a card: column = "left", "right" or "full"
    local function newCard(category, column, titleText, height)
        local card = CreateFrame("Frame", nil, category, "BackdropTemplate")
        local y = column == "full" and math.max(category.nextY.left, category.nextY.right) or category.nextY[column]
        if column == "left" or column == "full" then
            card:SetPoint("TOPLEFT", category, "TOPLEFT", 0, -y)
        else
            card:SetPoint("TOPLEFT", category, "TOP", CARD_GAP / 2, -y)
        end
        if column == "left" then
            card:SetPoint("RIGHT", category, "CENTER", -CARD_GAP / 2, 0)
        else
            card:SetPoint("RIGHT", category, "RIGHT", 0, 0)
        end
        card:SetHeight(height)
        card:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
        card:SetBackdropColor(0, 0, 0, 0.30)
        card:SetBackdropBorderColor(0.55, 0.45, 0.2, 0.55)

        local label = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -10)
        label:SetText(titleText or "")
        label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

        local line = card:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
        line:SetPoint("RIGHT", card, "RIGHT", -14, 0)
        line:SetHeight(1)
        line:SetColorTexture(0.85, 0.65, 0.15, 0.35)

        card.body = 0   -- how far down the content has got (pixels under the line)
        if column == "full" then
            category.nextY.left = y + height + CARD_GAP
            category.nextY.right = y + height + CARD_GAP
        else
            category.nextY[column] = y + height + CARD_GAP
        end
        card.line = line
        return card
    end

    local function note(card, text)
        local fontString = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fontString:SetPoint("TOPLEFT", card.line, "BOTTOMLEFT", 0, -(card.body + 8))
        fontString:SetPoint("RIGHT", card, "RIGHT", -14, 0)
        fontString:SetJustifyH("LEFT")
        fontString:SetJustifyV("TOP")
        fontString:SetTextColor(GREY[1], GREY[2], GREY[3])
        fontString:SetText(text or "")
        card.body = card.body + 8 + math.max(14, fontString:GetStringHeight() + 2)
        return fontString
    end

    local function check(card, entry, key, onChange, indent)
        local button = CreateFrame("CheckButton", nil, card, "InterfaceOptionsCheckButtonTemplate")
        button:SetPoint("TOPLEFT", card.line, "BOTTOMLEFT", indent or 0, -(card.body + 6))
        button:SetHitRectInsets(0, 0, 0, 0)
        if button.Text then
            button.Text:ClearAllPoints()
            button.Text:SetPoint("LEFT", button, "RIGHT", 0, 1)
            button.Text:SetJustifyH("LEFT")
            button.Text:SetFontObject("GameFontHighlight")
            button.Text:SetText(entry.label or "")
        end
        explain(button, entry.label, entry.tooltip)
        card.body = card.body + 6 + 26
        button:SetScript("OnClick", function(self)
            setBool(key, self:GetChecked() == true)
            if onChange then
                onChange(self)
            end
            refreshAll()
        end)
        refreshers[#refreshers + 1] = function()
            button:SetChecked(getBool(key, button.fwDefault))
            paintCheck(button)
        end
        return button
    end

    local function slider(card, entry, key, low, high, default, format, onChange)
        local label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", card.line, "BOTTOMLEFT", 0, -(card.body + 8))
        label:SetText(entry.title or "")
        label:SetTextColor(0.9, 0.9, 0.9)

        local control = CreateFrame("Slider", nil, card, "OptionsSliderTemplate")
        control:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -16)
        control:SetPoint("RIGHT", card, "RIGHT", -90, 0)
        control:SetMinMaxValues(low, high)
        control:SetValueStep(1)
        control:SetObeyStepOnDrag(true)
        control:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        if control.Text then control.Text:SetText("") end
        if control.Low then control.Low:SetText(format(low)) end
        if control.High then control.High:SetText(format(high)) end
        explain(control, entry.title, entry.tooltip)

        local value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("LEFT", control, "RIGHT", 12, 0)
        value:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

        card.body = card.body + 8 + 14 + 16 + 40

        control:SetScript("OnValueChanged", function(self, newValue)
            if self.fwRefreshing then
                return
            end
            local snapped = math.max(low, math.min(high, math.floor((tonumber(newValue) or default) + 0.5)))
            value:SetText(format(snapped))
            setNumber(key, snapped)
            if onChange then
                onChange(snapped)
            end
        end)
        refreshers[#refreshers + 1] = function()
            local current = math.max(low, math.min(high, math.floor(getNumber(key, default) + 0.5)))
            control.fwRefreshing = true
            control:SetValue(current)
            control.fwRefreshing = nil
            value:SetText(format(current))
        end
        return control, label, value
    end

    ----------------------------------------------------------
    -- the categories
    ----------------------------------------------------------
    local tabsConfig = texts("selltab")
    local listConfig = texts("selllist")
    local categories = {}

    local function sellFiltersChanged()
        FWR:Emit("sellFiltersChanged")
    end

    -- POSTING
    local function buildPosting()
        local category = newCategory()

        local timeCard = newCard(category, "left", "Posting time", 118)
        note(timeCard, tabsConfig.durationTitle and "How long an auction stays in the Auction House." or "")
        local durationChecks = {}
        local previous
        for _, entry in ipairs(tabsConfig.durations or {}) do
            local button = CreateFrame("CheckButton", nil, timeCard, "InterfaceOptionsCheckButtonTemplate")
            if previous then
                button:SetPoint("LEFT", previous.Text, "RIGHT", 22, 0)
            else
                button:SetPoint("TOPLEFT", timeCard.line, "BOTTOMLEFT", 0, -(timeCard.body + 8))
            end
            button:SetHitRectInsets(0, 0, 0, 0)
            if button.Text then
                button.Text:ClearAllPoints()
                button.Text:SetPoint("LEFT", button, "RIGHT", 0, 1)
                button.Text:SetFontObject("GameFontHighlight")
                button.Text:SetText(entry.label or "")
            end
            button.fwValue = entry.value
            explain(button, "Posting time", "The time an auction stays up. An item can have its own time (right-click it in the Sell page).")
            button:SetScript("OnClick", function(self)
                setNumber("tabPostTime", self.fwValue)
                sellFiltersChanged()
                refreshAll()
            end)
            durationChecks[#durationChecks + 1] = button
            previous = button
        end
        refreshers[#refreshers + 1] = function()
            local current = getNumber("tabPostTime", 1)
            for _, button in ipairs(durationChecks) do
                button:SetChecked(button.fwValue == current)
                paintCheck(button)
            end
        end

        local stepCard = newCard(category, "left", "Price steps", 128)
        slider(stepCard, tabsConfig.priceStep or {}, "tabPriceStep", 1, 20, 5, function(v)
            return string.format("%d%%", v)
        end)

        local checkCard = newCard(category, "right", "Price check", 118)
        note(checkCard, "Post waits while the price is unusually low against the listings.")
        check(checkCard, tabsConfig.priceCheck or {}, "tabPriceCheck", sellFiltersChanged)

        local wheelCard = newCard(category, "right", "Mouse wheel", 128)
        note(wheelCard, "Post the next item with the wheel, while the tab is open.")
        local wheel = check(wheelCard, tabsConfig.wheel or {}, "tabWheel", function()
            FWR:Emit("sellTabWheelChanged")
        end)
        wheel.fwDefault = false
        local shift = check(wheelCard, tabsConfig.wheelShift or {}, "tabWheelShift", function()
            FWR:Emit("sellTabWheelChanged")
        end, 24)
        shift.fwDefault = true
        refreshers[#refreshers + 1] = function()
            if wheel:GetChecked() then
                shift:Enable()
            else
                shift:Disable()
            end
            paintCheck(shift)
        end
        return category
    end

    -- AVERAGE PRICE
    local function buildAverage()
        local category = newCategory()

        local floorCard = newCard(category, "left", "Never sell below my average", 140)
        note(floorCard, "The price starts at the higher of the lowest price now and the average of your last sales; - and Post stop at that average.")
        local floorCheck = check(floorCard, tabsConfig.averageFloor or {}, "tabAverageFloor", sellFiltersChanged)
        floorCheck.fwDefault = false
        refreshers[#refreshers + 1] = function()
            -- the average is made of the sales history: without it there is nothing to turn on
            if getBool("tabHistory", true) then
                floorCheck:Enable()
            else
                floorCheck:Disable()
            end
            paintCheck(floorCheck)
        end

        local salesCard = newCard(category, "right", "Sales in the average", 140)
        local control = slider(salesCard, tabsConfig.averageSales or {}, "tabAverageSales", 5, 30, 10, function(v)
            return string.format("%d sales", v)
        end, function()
            sellFiltersChanged()
        end)
        refreshers[#refreshers + 1] = function()
            control:SetEnabled(getBool("tabHistory", true))
        end
        return category
    end

    -- LIST: which items (where they come from) and which kinds; and a sentence that says what the list shows now
    local function buildList()
        local category = newCategory()

        local sourceCard = newCard(category, "left", "Which items", 132)
        note(sourceCard, "Where the items of the Sell page list come from (the list of the items of your bags that the Sell page shows).")
        local choices = {}
        for _, option in ipairs({
            { farmedOnly = false, label = "Everything in my bags that can be sold",
                tooltip = "The Sell page list holds every item of your bags that the Auction House sells by amount, whatever way you got it (bought, found, crafted, farmed)." },
            { farmedOnly = true, label = "Only what I have farmed",
                tooltip = "The Sell page list holds only the items that FarmWise has seen you gather, loot or process. What you bought or got from another player is left out." },
        }) do
            local button = CreateFrame("CheckButton", nil, sourceCard, "InterfaceOptionsCheckButtonTemplate")
            button:SetPoint("TOPLEFT", sourceCard.line, "BOTTOMLEFT", 0, -(sourceCard.body + 6))
            button:SetHitRectInsets(0, 0, 0, 0)
            if button.Text then
                button.Text:ClearAllPoints()
                button.Text:SetPoint("LEFT", button, "RIGHT", 0, 1)
                button.Text:SetFontObject("GameFontHighlight")
                button.Text:SetText(option.label)
            end
            explain(button, option.label, option.tooltip)
            sourceCard.body = sourceCard.body + 6 + 26
            button.fwFarmedOnly = option.farmedOnly
            button:SetScript("OnClick", function(self)
                setBool("tabOnlyFarmed", self.fwFarmedOnly)
                sellFiltersChanged()
                refreshAll()
            end)
            choices[#choices + 1] = button
        end
        refreshers[#refreshers + 1] = function()
            local farmedOnly = getBool("tabOnlyFarmed", false)
            for _, button in ipairs(choices) do
                button:SetChecked(button.fwFarmedOnly == farmedOnly)
                paintCheck(button)
            end
        end

        local kinds = {
            { key = "trade", setting = "tabShowTrade", name = "trade materials" },
            { key = "consumables", setting = "tabShowConsumables", name = "consumables" },
            { key = "gems", setting = "tabShowGems", name = "gems and enhancements" },
            { key = "other", setting = "tabShowOther", name = "other things sold by amount" },
        }
        local groupsCard = newCard(category, "right", "Which kinds of items", 190)
        note(groupsCard, "Tick the kinds you want in the Sell page list. A kind that is not ticked is left out of it.")
        for _, kind in ipairs(kinds) do
            local button = check(groupsCard, listConfig[kind.key] or {}, kind.setting, sellFiltersChanged)
            button.fwDefault = true
            groupsCard.body = groupsCard.body - 2
        end

        local summaryCard = newCard(category, "left", "What the Sell page list shows now", 96)
        local summary = note(summaryCard, "")
        summary:SetTextColor(0.9, 0.9, 0.9)
        refreshers[#refreshers + 1] = function()
            local names = {}
            for _, kind in ipairs(kinds) do
                if getBool(kind.setting, true) then
                    names[#names + 1] = kind.name
                end
            end
            local source = getBool("tabOnlyFarmed", false) and "only what you have farmed" or "everything in your bags that can be sold"
            if #names == 0 then
                summary:SetText("Nothing: every kind is switched off, so the Sell page list is empty.")
            else
                summary:SetText("The Sell page list shows " .. table.concat(names, ", ") .. " - " .. source .. ".")
            end
        end
        return category
    end

    -- DISPLAY
    local function buildDisplay()
        local category = newCategory()

        local tipsCard = newCard(category, "left", "Tooltips", 100)
        local tips = check(tipsCard, tabsConfig.tooltips or {}, "tabTooltips")
        tips.fwDefault = true

        local openCard = newCard(category, "left", "When the Auction House opens", 100)
        local openFirst = check(openCard, tabsConfig.openFirst or {}, "tabOpenFirst")
        openFirst.fwDefault = true

        local columnsCard = newCard(category, "right", "Columns", 150)
        note(columnsCard, "A change here is made when the game is reloaded (/reload).")
        local trend = check(columnsCard, tabsConfig.showTrend or {}, "tabShowTrend", sellFiltersChanged)
        trend.fwDefault = true
        local value = check(columnsCard, tabsConfig.showValue or {}, "tabShowValue", sellFiltersChanged)
        value.fwDefault = true
        return category
    end

    -- HISTORY
    local function buildHistory()
        local category = newCategory()

        local historyCard = newCard(category, "left", "Sales history", 140)
        note(historyCard, "What you sell is counted when you take the gold from the mailbox.")
        local record = check(historyCard, tabsConfig.history or {}, "tabHistory", function()
            sellFiltersChanged()
            FWR:Emit("sellTabHistoryChanged")
        end)
        record.fwDefault = true
        return category
    end

    local definitions = {
        { label = "Posting", build = buildPosting },
        { label = "Average price", build = buildAverage },
        { label = "Sell list", build = buildList },
        { label = "Display", build = buildDisplay },
        { label = "History", build = buildHistory },
    }

    ----------------------------------------------------------
    -- the row of tabs, across the whole width, and the choice
    ----------------------------------------------------------
    local tabs = {}
    local placeTabs

    local function choose(index)
        for position, tab in ipairs(tabs) do
            api.setTabSelected(tab, position == index)
            if categories[position] then
                categories[position]:SetShown(position == index)
            end
        end
        refreshAll()
    end

    local function buildAll()
        if built then
            return
        end
        built = true

        local count = #definitions
        for index, definition in ipairs(definitions) do
            local tab = api.createSubTab(area, definition.label)
            tab:ClearAllPoints()
            tabs[index] = tab
            tab:SetScript("OnClick", function()
                choose(index)
            end)
            -- the template sizes a tab to its text each time it is shown: ours has the share of the width
            tab:HookScript("OnShow", function(self)
                if self.fwWidth then
                    pcall(PanelTemplates_TabResize, self, 0, self.fwWidth)
                    self:SetWidth(self.fwWidth)
                end
            end)
            local category = definition.build()
            categories[index] = category
        end

        -- every tab takes the same share of the width
        placeTabs = function()
            local width = area:GetWidth()
            if not width or width <= 0 then
                return
            end
            local each = math.floor(width / count)
            for index, tab in ipairs(tabs) do
                tab.fwWidth = each - 4
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", area, "TOPLEFT", (index - 1) * each, 0)
                if tab.fwTemplate then
                    pcall(PanelTemplates_TabResize, tab, 0, tab.fwWidth)
                end
                tab:SetWidth(tab.fwWidth)
            end
        end
        area:SetScript("OnSizeChanged", placeTabs)
        placeTabs()
        choose(1)
    end

    api.addPage({
        key = "options",
        title = "Options",
        frame = page,
        after = true,
        onShow = function()
            local okBuild, err = pcall(buildAll)
            if not okBuild and type(geterrorhandler) == "function" then
                geterrorhandler()("FarmWise AH options: " .. tostring(err))
            end
            if placeTabs then
                placeTabs()
            end
            refreshAll()
        end,
    })
end

FWR:Subscribe("auctionTabBuilt", function(api)
    pcall(build, api)
end)
