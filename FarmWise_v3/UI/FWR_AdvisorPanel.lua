local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Advisor window: ranks zones by items/hour for one item, or by estimated gold/hour.

local PANEL_WIDTH = 470
local PANEL_HEIGHT = 470
local ROW_HEIGHT = 58
local MAX_ROWS = 40

local MODE_ITEM = "item"
local MODE_GOLD = "gold"

local panel = nil
local mode = MODE_ITEM
local exactItemID = nil
local exactQuality = nil
local autoFilledText = nil

local function formatTime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes % 60)
    end
    return string.format("%dm", minutes)
end

local function formatGold(copper)
    local gold = math.floor((tonumber(copper) or 0) / 10000)
    if gold >= 1000 then
        gold = math.floor(gold / 100) * 100
    elseif gold >= 100 then
        gold = math.floor(gold / 10) * 10
    end
    local text = tostring(gold)
    local replaced
    repeat
        text, replaced = text:gsub("^(%-?%d+)(%d%d%d)", "%1.%2")
    until replaced == 0
    return text .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
end

local function createButton(parent, width, label)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    return button
end

local function getRow(index)
    local row = panel.rows[index]
    if row then
        return row
    end

    row = {}
    row.zone = panel.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.zone:SetJustifyH("LEFT")
    row.stats = panel.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.stats:SetJustifyH("LEFT")
    row.stats:SetSpacing(2)
    row.divider = panel.content:CreateTexture(nil, "ARTWORK")
    row.divider:SetColorTexture(1, 1, 1, 0.12)
    row.divider:SetHeight(1)

    local top = -((index - 1) * ROW_HEIGHT)
    row.zone:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 4, top - 4)
    row.zone:SetPoint("RIGHT", panel.content, "RIGHT", -4, 0)
    row.stats:SetPoint("TOPLEFT", row.zone, "BOTTOMLEFT", 0, -3)
    row.stats:SetPoint("RIGHT", panel.content, "RIGHT", -4, 0)
    row.divider:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, top - ROW_HEIGHT + 2)
    row.divider:SetPoint("RIGHT", panel.content, "RIGHT", 0, 0)

    panel.rows[index] = row
    return row
end

local function setRowVisible(row, visible)
    row.zone:SetShown(visible)
    row.stats:SetShown(visible)
    row.divider:SetShown(visible)
end

local function showHint(text)
    panel.hint:SetText(text or "")
    panel.hint:SetShown(text ~= nil and text ~= "")
end

local function refreshSettingButtons()
    local settings = FWR:GetAdvisorSettings()
    panel.groupButton:SetText(settings.aggregate == "zone" and "Group: Zone" or "Group: Subzone")
    panel.expansionButton:SetText(settings.currentExpansionOnly and "Items: Current expansion" or "Items: All expansions")
    panel.professionButton:SetText(settings.professionFilter and "My professions" or "All professions")
end

local function refreshModeButtons()
    panel.itemModeButton:SetEnabled(mode ~= MODE_ITEM)
    panel.goldModeButton:SetEnabled(mode ~= MODE_GOLD)
    panel.input:SetShown(mode == MODE_ITEM)
    panel.clearButton:SetShown(mode == MODE_ITEM)
    panel.scroll:ClearAllPoints()
    if mode == MODE_ITEM then
        panel.scroll:SetPoint("TOPLEFT", panel.input, "BOTTOMLEFT", -4, -8)
        panel.help:SetText("Best zones for one item, by items per hour.")
    else
        panel.scroll:SetPoint("TOPLEFT", panel.settingsAnchor, "BOTTOMLEFT", 0, -8)
        panel.help:SetText("Best zones by estimated gold per hour (Auctionator prices).")
    end
    panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 46)
end

function FWR:RefreshAdvisorPanel()
    if not panel or not panel:IsShown() then
        return
    end

    refreshModeButtons()
    refreshSettingButtons()

    local text, r, g, b = self:GetAuctionSyncAgeText()
    panel.syncAge:SetText(text)
    panel.syncAge:SetTextColor(r, g, b)
    panel.syncButton:SetEnabled(self:HasAuctionator() and self:IsAuctionHouseOpen())

    local minutes = math.floor(self.ADVISOR_MIN_SECONDS / 60)
    local results
    local emptyHint
    if mode == MODE_GOLD then
        results = self:BuildAdvisorGoldResults()
        emptyHint = string.format("No priced zone data yet (needs %d+ min of farming and synced AH prices).", minutes)
    else
        local query = panel.input:GetText() or ""
        if query == "" then
            results = {}
            emptyHint = "Type an item name, or shift-click an item."
        else
            results = self:BuildAdvisorItemResults(query, exactItemID, exactQuality)
            emptyHint = string.format("No zone data for this item (needs %d+ min of farming).", minutes)
        end
    end

    local shown = math.min(#results, MAX_ROWS)
    for index = 1, shown do
        local row = getRow(index)
        local result = results[index]
        row.zone:SetText(result.zone)
        if mode == MODE_GOLD then
            row.stats:SetText(string.format(
                "Farming time: %s\nPriced items: %d/%d\nEstimated gold/hour: %s",
                formatTime(result.totalTime), result.pricedItems, result.trackedItems, formatGold(result.goldPerHour)))
        else
            row.stats:SetText(string.format(
                "Farming time: %s\nGathered: %d items\nAverage yield: %d/hour",
                formatTime(result.totalTime), result.count, result.perHour))
        end
        setRowVisible(row, true)
    end

    for index = shown + 1, #panel.rows do
        setRowVisible(panel.rows[index], false)
    end

    panel.content:SetHeight(math.max(shown * ROW_HEIGHT, 1))
    showHint(shown == 0 and emptyHint or nil)
end

local function clearExactSelection()
    exactItemID = nil
    exactQuality = nil
    autoFilledText = nil
end

local function applyItemLink(link)
    if not panel or not panel.input:HasFocus() or type(link) ~= "string" then
        return false
    end

    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then
        return false
    end

    local name = GetItemInfo(itemID) or link:match("%[(.-)%]") or tostring(itemID)
    local tier = C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo
        and C_TradeSkillUI.GetItemReagentQualityByItemInfo(link) or 0

    exactItemID = itemID
    exactQuality = (tier and tier > 0) and ("Q" .. tier) or nil
    autoFilledText = exactQuality and string.format("%s (%s)", name, exactQuality) or name
    panel.input:SetText(autoFilledText)
    panel.input:SetCursorPosition(#autoFilledText)
    FWR:RefreshAdvisorPanel()
    return true
end

local function buildPanel()
    panel = CreateFrame("Frame", "FarmWiseAdvisorFrame", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)
    panel:Hide()
    panel.rows = {}

    if panel.TitleText then
        panel.TitleText:SetText("FarmWise Advisor")
    end
    table.insert(UISpecialFrames, "FarmWiseAdvisorFrame")

    panel.itemModeButton = createButton(panel, 100, "Item")
    panel.itemModeButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -34)
    panel.itemModeButton:SetScript("OnClick", function()
        mode = MODE_ITEM
        FWR:RefreshAdvisorPanel()
    end)

    panel.goldModeButton = createButton(panel, 100, "Gold")
    panel.goldModeButton:SetPoint("LEFT", panel.itemModeButton, "RIGHT", 6, 0)
    panel.goldModeButton:SetScript("OnClick", function()
        mode = MODE_GOLD
        FWR:RefreshAdvisorPanel()
    end)

    panel.help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.help:SetPoint("LEFT", panel.goldModeButton, "RIGHT", 10, 0)
    panel.help:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    panel.help:SetJustifyH("LEFT")
    panel.help:SetWordWrap(true)

    panel.settingsAnchor = CreateFrame("Frame", nil, panel)
    panel.settingsAnchor:SetSize(1, 22)
    panel.settingsAnchor:SetPoint("TOPLEFT", panel.itemModeButton, "BOTTOMLEFT", 0, -8)

    panel.groupButton = createButton(panel, 120, "")
    panel.groupButton:SetPoint("LEFT", panel.settingsAnchor, "LEFT", 0, 0)
    panel.groupButton:SetScript("OnClick", function()
        local settings = FWR:GetAdvisorSettings()
        settings.aggregate = settings.aggregate == "zone" and "subzone" or "zone"
        FWR:RefreshAdvisorPanel()
    end)

    panel.expansionButton = createButton(panel, 170, "")
    panel.expansionButton:SetPoint("LEFT", panel.groupButton, "RIGHT", 6, 0)
    panel.expansionButton:SetScript("OnClick", function()
        local settings = FWR:GetAdvisorSettings()
        settings.currentExpansionOnly = not settings.currentExpansionOnly
        FWR:RefreshAdvisorPanel()
    end)

    panel.professionButton = createButton(panel, 120, "")
    panel.professionButton:SetPoint("LEFT", panel.expansionButton, "RIGHT", 6, 0)
    panel.professionButton:SetScript("OnClick", function()
        local settings = FWR:GetAdvisorSettings()
        settings.professionFilter = not settings.professionFilter
        FWR:RefreshAdvisorPanel()
    end)

    panel.input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.input:SetSize(PANEL_WIDTH - 110, 22)
    panel.input:SetPoint("TOPLEFT", panel.settingsAnchor, "BOTTOMLEFT", 8, -10)
    panel.input:SetAutoFocus(false)
    panel.input:SetScript("OnEscapePressed", panel.input.ClearFocus)
    panel.input:SetScript("OnEnterPressed", panel.input.ClearFocus)
    panel.input:SetScript("OnTextChanged", function(self, userInput)
        if userInput and autoFilledText and self:GetText() ~= autoFilledText then
            clearExactSelection()
        end
        FWR:RefreshAdvisorPanel()
    end)

    panel.clearButton = createButton(panel, 60, "Clear")
    panel.clearButton:SetPoint("LEFT", panel.input, "RIGHT", 6, 0)
    panel.clearButton:SetScript("OnClick", function()
        clearExactSelection()
        panel.input:SetText("")
        panel.input:ClearFocus()
        FWR:RefreshAdvisorPanel()
    end)

    panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetSize(PANEL_WIDTH - 60, 1)
    panel.scroll:SetScrollChild(panel.content)

    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.hint:SetPoint("TOPLEFT", panel.scroll, "TOPLEFT", 6, -8)
    panel.hint:SetPoint("RIGHT", panel.scroll, "RIGHT", -6, 0)
    panel.hint:SetJustifyH("LEFT")

    panel.syncAge = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.syncAge:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 18)

    panel.syncButton = createButton(panel, 90, "AH Sync")
    panel.syncButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 12)
    panel.syncButton:SetScript("OnClick", function()
        FWR:SyncAuctionPrices()
    end)
    panel.syncButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if not FWR:HasAuctionator() then
            GameTooltip:SetText("Requires the Auctionator addon.")
        elseif not FWR:IsAuctionHouseOpen() then
            GameTooltip:SetText("Open the Auction House and refresh Auctionator first.")
        else
            GameTooltip:SetText("Copy current Auctionator prices for your tracked items.")
        end
        GameTooltip:Show()
    end)
    panel.syncButton:SetScript("OnLeave", GameTooltip_Hide)

    panel:SetScript("OnShow", function()
        FWR:RefreshAdvisorPanel()
    end)

    if type(hooksecurefunc) == "function" then
        if type(ChatEdit_InsertLink) == "function" then
            hooksecurefunc("ChatEdit_InsertLink", applyItemLink)
        end
        if type(HandleModifiedItemClick) == "function" then
            hooksecurefunc("HandleModifiedItemClick", function(link)
                if IsModifiedClick and IsModifiedClick("CHATLINK") then
                    applyItemLink(link)
                end
            end)
        end
    end

    return panel
end

function FWR:ToggleAdvisorPanel()
    if not panel then
        buildPanel()
    end
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

function FWR:ShowAdvisorPanel()
    if not panel then
        buildPanel()
    end
    panel:Show()
end
