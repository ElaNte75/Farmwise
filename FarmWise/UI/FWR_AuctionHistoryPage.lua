local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- The "History" page of the FarmWise tab of the Auction House: a second page next to "Sell", chosen with
-- small tabs at the top left of the page, in the way the game's own Auctions page has its "Auctions" and "Bids".
-- It shows what the sales history (Core/FWR_SalesHistory.lua) has kept, one line per item, and every column
-- title sorts the list. The page is built when the FarmWise tab is (it is told by "auctionTabBuilt").

local GOLD = { 1, 0.82, 0 }
local DAY = 86400

-- columns from the right edge: key, title, width, how it is sorted first (descending: biggest first)
local COLUMNS = {
    { key = "last", title = "Last sale", width = 84 },
    { key = "rate", title = "Success", width = 66 },
    { key = "returned", title = "Returned", width = 70 },
    { key = "average", title = "Average price (-5%)", width = 150 },
    { key = "net", title = "Earned (-5% cut)", width = 150 },
    { key = "sold", title = "Sold", width = 62 },
}
local COLUMN_GAP = 4

-- the order FarmWise chooses (the round arrow goes back to it): the most gold earned first
local DEFAULT_SORT_KEY, DEFAULT_SORT_DESCENDING = "net", true
local sortKey, sortDescending = DEFAULT_SORT_KEY, DEFAULT_SORT_DESCENDING

local function money(api, copper)
    return api.money(copper)
end

-- An amount of money in three places of its own (gold, silver, copper), each with its coin after it, so that in
-- every line the golds stand under the golds, the silvers under the silvers and the coppers under the coppers.
local COIN_W, COIN_H, COIN_GAP, PART_GAP = 10, 12, 2, 1
local meter

local function textWidth(fontObject, text)
    meter = meter or UIParent:CreateFontString(nil, "ARTWORK")
    meter:SetFontObject(fontObject)
    meter:SetText(text)
    return math.ceil(meter:GetStringWidth() or 0)
end

-- the amount sits in the middle of its column; rightOffset: distance of the column from the right edge of the row
local function createMoneyCell(row, rightOffset, columnWidth, fontObject, rowHeight)
    local goldWidth = textWidth(fontObject, "9999999") + 8
    local smallWidth = textWidth(fontObject, "99") + 1
    local total = goldWidth + COIN_GAP + COIN_W + PART_GAP + smallWidth + COIN_GAP + COIN_W + PART_GAP
        + smallWidth + COIN_GAP + COIN_W

    local cell = CreateFrame("Frame", nil, row)
    cell:SetSize(total, rowHeight)
    cell:SetPoint("RIGHT", row, "RIGHT", -(rightOffset + math.max(0, math.floor((columnWidth - total) / 2))), 0)

    local parts = {}
    local x = 0
    for _, spec in ipairs({ { "gold", goldWidth, "Coin-Gold" }, { "silver", smallWidth, "Coin-Silver" },
        { "copper", smallWidth, "Coin-Copper" } }) do
        local text = cell:CreateFontString(nil, "OVERLAY", fontObject)
        text:SetWidth(spec[2])
        text:SetJustifyH("RIGHT")
        text:SetWordWrap(false)
        text:SetPoint("LEFT", cell, "LEFT", x, 0)

        local icon = cell:CreateTexture(nil, "OVERLAY")
        icon:SetSize(COIN_W, COIN_H)
        icon:SetPoint("LEFT", cell, "LEFT", x + spec[2] + COIN_GAP, 0)
        pcall(function()
            icon:SetAtlas(spec[3])
        end)

        parts[spec[1]] = { text = text, icon = icon }
        x = x + spec[2] + COIN_GAP + COIN_W + PART_GAP
    end

    -- what is written when there is no amount
    local none = cell:CreateFontString(nil, "OVERLAY", fontObject)
    none:SetPoint("CENTER", cell, "CENTER", 0, 0)
    none:SetText("-")

    return { parts = parts, none = none }
end

local function showPart(part, value)
    if value then
        part.text:SetText(tostring(value))
        part.text:Show()
        part.icon:Show()
    else
        part.text:Hide()
        part.icon:Hide()
    end
end

local function setMoneyCell(cell, copper)
    if not copper then
        for _, part in pairs(cell.parts) do
            showPart(part, nil)
        end
        cell.none:Show()
        return
    end
    cell.none:Hide()
    copper = math.max(0, math.floor(copper + 0.5))
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100
    showPart(cell.parts.gold, gold > 0 and string.format("%.0f", gold) or nil)
    showPart(cell.parts.silver, (gold > 0 or silver > 0) and silver or nil)
    showPart(cell.parts.copper, rest)
end

local function relativeDay(last)
    if not last or last <= 0 then
        return "-"
    end
    local days = math.floor((time() - last) / DAY)
    if days <= 0 then
        return "Today"
    elseif days == 1 then
        return "Yesterday"
    end
    return string.format("%d days ago", days)
end

local function rateColor(rate)
    if not rate then
        return 0.7, 0.7, 0.7
    elseif rate >= 0.8 then
        return 0.25, 0.9, 0.3
    elseif rate >= 0.5 then
        return 1, 0.85, 0.2
    end
    return 0.95, 0.35, 0.3
end

-- one of the game's own tab buttons, when one of the templates is there; else a plain button
local TAB_TEMPLATES = { "PanelTopTabButtonTemplate", "AuctionHouseFrameAuctionsTabTemplate", "PanelTabButtonTemplate" }

local function createSubTab(parent, text)
    local tab
    for _, template in ipairs(TAB_TEMPLATES) do
        local ok, created = pcall(CreateFrame, "Button", nil, parent, template)
        if ok and created then
            tab = created
            tab.fwTemplate = template
            break
        end
    end
    if not tab then
        tab = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        tab:SetHeight(22)
        tab.fwPlain = true
    end
    tab:SetText(text)
    if tab.fwTemplate then
        pcall(PanelTemplates_TabResize, tab, 10, nil, 60)
    else
        tab:SetWidth(math.max(70, (tab:GetTextWidth() or 40) + 24))
    end
    return tab
end

local function setTabSelected(tab, selected)
    if tab.fwTemplate then
        if selected then
            pcall(PanelTemplates_SelectTab, tab)
        else
            pcall(PanelTemplates_DeselectTab, tab)
        end
    else
        tab:SetEnabled(not selected)
    end
end

-- where the game puts the first tab of its own Auctions page, measured from the page; nil when it cannot be told
local function gameTabPosition(panel)
    local x, y
    pcall(function()
        local frame = _G.AuctionHouseFrame
        local auctions = frame and frame.AuctionsFrame
        local tab = auctions and (auctions.AuctionsTab or (auctions.Tabs and auctions.Tabs[1]))
        if not tab then
            return
        end
        local left, bottom = tab:GetLeft(), tab:GetBottom()
        local panelLeft, panelTop = panel:GetLeft(), panel:GetTop()
        if left and bottom and panelLeft and panelTop then
            x, y = left - panelLeft, bottom - panelTop
        end
    end)
    return x, y
end

local function build(api)
    local panel = api.panel
    if api.historyBuilt then
        return
    end
    api.historyBuilt = true

    ----------------------------------------------------------
    -- the two small tabs
    ----------------------------------------------------------
    local sellTab = createSubTab(panel, "Sell")
    local historyTab = createSubTab(panel, "History")

    local x, y = gameTabPosition(panel)
    x = x or 6
    y = y or -2
    sellTab:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", x, y)
    historyTab:SetPoint("LEFT", sellTab, "RIGHT", 4, 0)   -- a small gap, like the game's Auctions and Bids

    ----------------------------------------------------------
    -- the page: it covers the page of the list, which is left as it is underneath
    ----------------------------------------------------------
    local hist = CreateFrame("Frame", nil, panel)
    hist:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    hist:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, 3)
    hist:SetFrameLevel(panel:GetFrameLevel() + 20)
    hist:EnableMouse(true)
    hist:EnableMouseWheel(true)
    hist:Hide()

    local background = hist:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local ok = pcall(function()
        background:SetAtlas("auctionhouse-background-index")
    end)
    if not ok then
        background:SetColorTexture(0.12, 0.115, 0.11, 1)
    end

    -- the title, the titles of the columns and the lines are put where those of the Sell page are
    local title = hist:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel.title, "TOPLEFT", 0, 0)
    title:SetText("Sales history")
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local strip = hist:CreateTexture(nil, "ARTWORK")
    strip:SetPoint("TOPLEFT", panel.headerStrip, "TOPLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", panel.headerStrip, "BOTTOMRIGHT", 0, 0)
    local gradient = false
    if strip.SetGradient and CreateColor then
        gradient = pcall(function()
            strip:SetGradient("VERTICAL", CreateColor(0.11, 0.11, 0.105, 1), CreateColor(0.27, 0.26, 0.24, 1))
        end)
    end
    if not gradient then
        strip:SetColorTexture(0.2, 0.19, 0.18, 1)
    end

    local list = CreateFrame("Frame", nil, hist)
    list:SetPoint("TOPLEFT", panel.list, "TOPLEFT", 0, 0)
    list:SetPoint("RIGHT", panel.list, "RIGHT", 0, 0)
    list:SetHeight(api.visibleRows * api.rowHeight)

    -- the titles of the columns: they sort
    local headers = {}
    local function makeHeader(key, text, width, anchorRight)
        local button = CreateFrame("Button", nil, hist)
        button:SetHeight(21)
        if key == "name" then
            button:SetPoint("LEFT", strip, "LEFT", api.nameX, 0)
            button:SetPoint("RIGHT", strip, "RIGHT", -anchorRight, 0)
        else
            button:SetWidth(width)
            button:SetPoint("RIGHT", strip, "RIGHT", -anchorRight, 0)
        end
        button.label = button:CreateFontString(nil, "OVERLAY", api.titleFont)
        button.label:SetWordWrap(false)
        button.label:SetText(text)
        if key == "name" then
            button.label:SetPoint("LEFT", button, "LEFT", 0, 0)
            button.label:SetJustifyH("LEFT")
        else
            button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
        end
        button.arrow = button:CreateTexture(nil, "OVERLAY")
        button.arrow:SetTexture("Interface/Buttons/UI-SortArrow")
        button.arrow:SetSize(9, 8)
        button.arrow:SetPoint("LEFT", button.label, "RIGHT", 3, 0)
        button.arrow:Hide()
        button.key = key
        headers[#headers + 1] = button
        return button
    end

    -- the columns from the right; the name takes what is left
    local offset = 0
    local columnRight = {}
    for _, column in ipairs(COLUMNS) do
        columnRight[column.key] = offset
        makeHeader(column.key, column.title, column.width, offset)
        offset = offset + column.width + COLUMN_GAP
    end
    local nameRight = offset + 4
    makeHeader("name", "Item", nil, nameRight)

    ----------------------------------------------------------
    -- the lines
    ----------------------------------------------------------
    local rows = {}
    for index = 1, api.visibleRows do
        local row = CreateFrame("Frame", nil, list)
        row:SetHeight(api.rowHeight)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -((index - 1) * api.rowHeight))
        row:SetPoint("RIGHT", list, "RIGHT", 0, 0)
        row:EnableMouse(true)

        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints()
        local striped = pcall(function()
            stripe:SetAtlas(index % 2 == 1 and "auctionhouse-rowstripe-1" or "auctionhouse-rowstripe-2")
        end)
        if not striped then
            stripe:SetColorTexture(1, 1, 1, index % 2 == 1 and 0.04 or 0)
        end

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(api.iconSize, api.iconSize)
        row.icon:SetPoint("LEFT", api.iconX, 0)

        row.iconBorder = row:CreateTexture(nil, "OVERLAY")
        row.iconBorder:SetSize(api.iconSize + 2, api.iconSize + 2)
        row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
        pcall(function()
            row.iconBorder:SetAtlas("auctionhouse-itemicon-small-border")
        end)

        row.name = row:CreateFontString(nil, "OVERLAY", "Number14FontWhite")
        row.name:SetPoint("LEFT", row, "LEFT", api.nameX, -1)
        row.name:SetPoint("RIGHT", row, "RIGHT", -nameRight, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        for _, column in ipairs(COLUMNS) do
            if column.key == "net" or column.key == "average" then
                row[column.key .. "Cell"] = createMoneyCell(row, columnRight[column.key], column.width, api.numberFont, api.rowHeight)
            else
                local text = row:CreateFontString(nil, "OVERLAY", api.numberFont)
                text:SetWidth(column.width)
                text:SetPoint("RIGHT", row, "RIGHT", -columnRight[column.key], 0)
                text:SetJustifyH("CENTER")
                text:SetWordWrap(false)
                row[column.key] = text
            end
        end

        row:SetScript("OnEnter", function(self)
            local data = self.data
            if not data then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tostring(data.name), 1, 0.82, 0)
            local function pair(label, value)
                GameTooltip:AddDoubleLine(label, value, 0.8, 0.8, 0.8, 1, 1, 1)
            end
            pair("Sold", string.format("%d (in %d sales)", data.sold, data.sales))
            pair("Earned, after the 5% cut", money(api, data.net))
            pair("Cut kept by the Auction House", money(api, math.max(0, data.gross - data.net)))
            if data.average then
                pair("Average price of one piece, after the cut", money(api, math.floor(data.average + 0.5)))
            end
            pair("Returned unsold", tostring(data.returned))
            if data.cancelled > 0 then
                pair("Taken back by you", tostring(data.cancelled))
            end
            if data.posted > 0 then
                pair("Posted", string.format("%d (in %d posts)", data.posted, data.posts))
            end
            if not data.itemID then
                GameTooltip:AddLine("The quality of this item could not be told from the mail.", 1, 0.6, 0.3, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        rows[index] = row
    end

    local empty = hist:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("CENTER", hist, "CENTER", 0, 20)
    empty:SetWidth(380)
    empty:SetJustifyH("CENTER")

    local status = hist:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", panel.status, "BOTTOMLEFT", 0, 0)
    status:SetJustifyH("LEFT")

    ----------------------------------------------------------
    -- filling and sorting
    ----------------------------------------------------------
    local sorted = {}
    local firstRow = 1

    local function refreshHeaders()
        for _, header in ipairs(headers) do
            local selected = header.key == sortKey
            header.label:SetTextColor(selected and GOLD[1] or 1, selected and GOLD[2] or 1, selected and GOLD[3] or 1)
            header.arrow:SetShown(selected)
            if selected then
                -- the game's arrow points down for the biggest first
                if sortDescending then
                    header.arrow:SetTexCoord(0, 0.5625, 0, 1)
                else
                    header.arrow:SetTexCoord(0, 0.5625, 1, 0)
                end
            end
        end
    end

    local function refresh()
        if not hist:IsShown() then
            return
        end
        refreshHeaders()

        if not FWR.IsSalesHistoryEnabled or not FWR:IsSalesHistoryEnabled() then
            for _, row in ipairs(rows) do
                row:Hide()
            end
            empty:SetText("The sales history is switched off (Options > Auction House).")
            empty:Show()
            status:SetText("")
            return
        end

        sorted = FWR:GetSalesHistoryRows()
        local function value(row)
            local v = row[sortKey]
            if sortKey == "name" then
                return string.lower(tostring(row.name or ""))
            end
            return v or -1
        end
        table.sort(sorted, function(a, b)
            local va, vb = value(a), value(b)
            if va ~= vb then
                if sortDescending then
                    return va > vb
                end
                return va < vb
            end
            return string.lower(tostring(a.name)) < string.lower(tostring(b.name))
        end)

        local maxFirst = math.max(1, #sorted - api.visibleRows + 1)
        firstRow = math.max(1, math.min(firstRow, maxFirst))

        local totalSold, totalNet = 0, 0
        for _, line in ipairs(sorted) do
            totalSold = totalSold + line.sold
            totalNet = totalNet + line.net
        end

        for index = 1, api.visibleRows do
            local row = rows[index]
            local data = sorted[firstRow + index - 1]
            row.data = data
            if data then
                row:Show()
                local icon = data.itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(data.itemID)
                row.icon:SetTexture(icon or "Interface/Icons/INV_Misc_QuestionMark")
                local shown = tostring(data.name)
                local tier = data.itemID and FWR.GetItemQualityTier and FWR:GetItemQualityTier(data.itemID)
                if tier then
                    shown = shown .. string.format(" |A:Professions-ChatIcon-Quality-12-Tier%d:15:17:1:0|a", tier)
                elseif not data.itemID then
                    shown = shown .. " |cff999999(quality unknown)|r"
                end
                row.name:SetText(shown)
                row.sold:SetText(tostring(data.sold))
                setMoneyCell(row.netCell, data.net)
                setMoneyCell(row.averageCell, data.average)
                row.returned:SetText(tostring(data.returned))
                if data.rate then
                    row.rate:SetText(string.format("%d%%", math.floor(data.rate * 100 + 0.5)))
                    row.rate:SetTextColor(rateColor(data.rate))
                else
                    row.rate:SetText("-")
                    row.rate:SetTextColor(0.7, 0.7, 0.7)
                end
                row.last:SetText(relativeDay(data.last))
            else
                row:Hide()
            end
        end

        if #sorted == 0 then
            empty:SetText("Nothing is recorded yet.\nSales are counted when you take the gold from your mailbox.")
            empty:Show()
        else
            empty:Hide()
        end
        status:SetText(string.format("%d items  -  %d sold  -  %s earned", #sorted, totalSold, money(api, totalNet)))
    end

    -- the round arrow, where the Sell page has its own: the list goes back to the order we chose
    local reset = CreateFrame("Button", nil, hist)
    reset:SetSize(22, 22)
    reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -api.padding, -8)
    reset:SetNormalTexture("Interface/Buttons/UI-RefreshButton")
    reset:SetHighlightTexture("Interface/Buttons/UI-RefreshButton", "ADD")
    reset:SetScript("OnClick", function()
        sortKey, sortDescending = DEFAULT_SORT_KEY, DEFAULT_SORT_DESCENDING
        firstRow = 1
        refresh()
    end)
    reset:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine("Original order", 1, 0.82, 0)
        GameTooltip:AddLine("Puts the list back in the order FarmWise chose: the most gold earned first", 0.72, 0.72, 0.72, false)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", GameTooltip_Hide)

    for _, header in ipairs(headers) do
        header:SetScript("OnClick", function(self)
            if sortKey == self.key then
                sortDescending = not sortDescending
            else
                sortKey = self.key
                sortDescending = self.key ~= "name"
            end
            firstRow = 1
            refresh()
        end)
    end

    hist:SetScript("OnMouseWheel", function(_, delta)
        firstRow = firstRow - delta
        refresh()
    end)

    ----------------------------------------------------------
    -- switching between the two pages
    ----------------------------------------------------------
    local function showPage(which)
        local history = which == "history"
        panel.fwHistoryShown = history
        hist:SetShown(history)
        setTabSelected(sellTab, not history)
        setTabSelected(historyTab, history)
        if history then
            firstRow = 1
            refresh()
        end
        -- the mouse wheel of the Sell page belongs to it only
        if api.applyWheel then
            api.applyWheel()
        end
    end

    local function applyEnabled()
        local on = FWR.IsSalesHistoryEnabled and FWR:IsSalesHistoryEnabled()
        sellTab:SetShown(on)
        historyTab:SetShown(on)
        if not on then
            showPage("sell")
        end
    end

    sellTab:SetScript("OnClick", function()
        showPage("sell")
    end)
    historyTab:SetScript("OnClick", function()
        showPage("history")
    end)

    -- every time the FarmWise tab is opened it starts on the Sell page
    panel:HookScript("OnShow", function()
        showPage("sell")
        applyEnabled()
    end)
    panel:HookScript("OnHide", function()
        hist:Hide()
        panel.fwHistoryShown = false
    end)

    FWR:Subscribe("salesHistoryChanged", refresh)
    FWR:Subscribe("sellTabHistoryChanged", applyEnabled)

    showPage("sell")
    applyEnabled()
end

FWR:Subscribe("auctionTabBuilt", function(api)
    pcall(build, api)
end)
