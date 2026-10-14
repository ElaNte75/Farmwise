local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- The "Actions" page of the FarmWise tab of the Auction House, between "Sell" and "History": one line for each
-- post of mine that is active or is waiting to be taken from the mailbox (the data: Core/FWR_ActionsLedger.lua).
-- It is built the way the History page is, and put in the tab strip by it ("addPage").

local GOLD = { 1, 0.82, 0 }

-- how each state of a post is told: the words, the colour, and its place when the list is not sorted by the user
local STATES = {
    sold = { text = "Sold", color = { 0.25, 0.9, 0.3 }, order = 1 },
    expired = { text = "Expired", color = { 1, 0.6, 0.2 }, order = 2 },
    cancelled = { text = "Cancelled", color = { 0.7, 0.7, 0.7 }, order = 3 },
    active = { text = "Active", color = { 1, 1, 1 }, order = 4 },
}

-- from the left: Item, Amount, Price each (after the cut), Expected (after the cut), Status, then the room that
-- is left, then the button that takes an active post back. Each column sits right after the one before.
-- The columns stand exactly where those of the History page stand (same distances from the right edge), so
-- the titles do not move when the page is changed: Amount under Sold, Expected under Earned, Price each under
-- Average price (first what I get, then what each one brings, as in the History); Status takes the places of Returned and Success; the button is where Last sale is.
local HISTORY = FWR.HISTORY_LAYOUT or { right = { sold = 528, net = 374, average = 220, returned = 152, rate = 88 },
    width = { sold = 50, net = 150, average = 150, returned = 64, rate = 60 } }
local QTY_WIDTH = HISTORY.width.sold
local NET_WIDTH = HISTORY.width.net
local UNIT_WIDTH = HISTORY.width.average
local STATE_WIDTH = HISTORY.right.returned + HISTORY.width.returned - HISTORY.right.rate
local CANCEL_WIDTH = 56
local QTY_INSET, QTY_TITLE_SHIFT = 4, 9   -- as the numbers of Sold
local COPPERS_FROM_RIGHT = 13   -- pixels from the right edge of a money column to the middle of its coppers
local POPUP_KEY = "FARMWISE_CANCEL_POST"

if type(StaticPopupDialogs) == "table" then
    StaticPopupDialogs[POPUP_KEY] = {
        text = "Cancel this auction: %s? The items come back to you by mail.",
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnAccept = function(_, data)
            if data and FarmWiseReforged.CancelPost then
                FarmWiseReforged:CancelPost(data)
            end
        end,
    }
end
local COLUMN_GAP = 4
-- the item column and its quality mark are the same in the Sell, Actions and History pages (see the Sell page)
local ITEM = FWR.ITEM_COLUMN or { width = 216, tierWidth = 14, tierHeight = 12, tierGap = 3 }
local TIER_W, TIER_H, TIER_GAP = ITEM.tierWidth, ITEM.tierHeight, ITEM.tierGap

local sortKey, sortDescending = "state", false

local function shortTime(seconds)
    -- hours while there is more than an hour left, minutes in the last hour
    if seconds <= 3600 then
        return string.format("%dm", math.max(1, math.ceil(seconds / 60)))
    end
    return string.format("%dh", math.ceil(seconds / 3600))
end

local function stateText(row)
    local state = STATES[row.state] or STATES.active
    if row.state == "active" and row.left then
        return string.format("%s  (%s left)", state.text, shortTime(row.left))
    end
    -- (a sale has no time: the game does not tell when its mail comes)
    return state.text
end

local function build(api)
    local panel = api.panel
    if not api.addPage or not api.createMoneyCell or not FWR.GetActionRows then
        return
    end

    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, 3)
    page:SetFrameLevel(panel:GetFrameLevel() + 20)
    page:EnableMouse(true)
    page:EnableMouseWheel(true)
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
    title:SetText("My auctions")
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local strip = page:CreateTexture(nil, "ARTWORK")
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

    local list = CreateFrame("Frame", nil, page)
    list:SetPoint("TOPLEFT", panel.list, "TOPLEFT", 0, 0)
    list:SetPoint("RIGHT", panel.list, "RIGHT", 0, 0)
    list:SetHeight(api.visibleRows * api.rowHeight)

    -- the titles of the columns: they sort
    local headers = {}
    local function makeHeader(key, text, width, pos, overCoppers, titleShift)
        local button = CreateFrame("Button", nil, page)
        button:SetHeight(21)
        button:SetWidth(width)
        if key == "name" then
            button:SetPoint("LEFT", strip, "LEFT", pos, 0)
        else
            button:SetPoint("RIGHT", strip, "RIGHT", -pos, 0)
        end
        button.label = button:CreateFontString(nil, "OVERLAY", api.titleFont)
        button.label:SetWordWrap(false)
        button.label:SetText(text)
        if key == "name" then
            button.label:SetPoint("LEFT", button, "LEFT", 0, 0)
            button.label:SetJustifyH("LEFT")
        else
            button.label:SetPoint("CENTER", button, "CENTER", titleShift or 0, 0)
        end
        button.arrow = button:CreateTexture(nil, "OVERLAY")
        button.arrow:SetTexture("Interface/Buttons/UI-SortArrow")
        button.arrow:SetSize(9, 8)
        if overCoppers and key ~= "name" then
            -- a money column: the sort arrow is right above the coppers of the amounts, the title ends before it
            button.arrow:SetPoint("CENTER", button, "RIGHT", -COPPERS_FROM_RIGHT, 0)
            button.label:ClearAllPoints()
            button.label:SetPoint("RIGHT", button.arrow, "LEFT", -3, 0)
        else
            button.arrow:SetPoint("LEFT", button.label, "RIGHT", 3, 0)
        end
        button.arrow:Hide()
        button.key = key
        headers[#headers + 1] = button
        return button
    end

    -- Distances from the left edge of the row. The item column is the same as in the Sell and History pages and
    -- never changes; the columns follow it, each right after the one before, and what is left over lies before
    -- the button on the right.
    local itemWidth = ITEM.width
    local column = {
        qty = HISTORY.right.sold,
        net = HISTORY.right.net,         -- Expected, under Earned (what I get: the total)
        unit = HISTORY.right.average,   -- Price each, under Average price (what each one brings)
        state = HISTORY.right.rate,
    }

    makeHeader("name", "Item", itemWidth, api.nameX)
    makeHeader("qty", "Amount", QTY_WIDTH, column.qty, false, QTY_TITLE_SHIFT)
    makeHeader("unit", "Price each (-5% cut)", UNIT_WIDTH, column.unit, true)
    makeHeader("net", "Expected (-5% cut)", NET_WIDTH, column.net, true)
    makeHeader("state", "Status", STATE_WIDTH, column.state)

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
        row.name:SetWidth(itemWidth - TIER_W - TIER_GAP)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.tier = row:CreateTexture(nil, "OVERLAY")
        row.tier:SetSize(TIER_W, TIER_H)
        row.tier:SetPoint("LEFT", row, "LEFT", api.nameX + itemWidth - TIER_W, 0)
        row.tier:Hide()

        row.netCell = api.createMoneyCell(row, column.net, NET_WIDTH, api.numberFont, api.rowHeight)
        row.unitCell = api.createMoneyCell(row, column.unit, UNIT_WIDTH, api.numberFont, api.rowHeight)

        row.qty = row:CreateFontString(nil, "OVERLAY", api.numberFont)
        row.qty:SetWidth(QTY_WIDTH - QTY_INSET)
        row.qty:SetPoint("RIGHT", row, "RIGHT", -(column.qty + QTY_INSET), 0)
        row.qty:SetJustifyH("RIGHT")
        row.qty:SetWordWrap(false)

        row.state = row:CreateFontString(nil, "OVERLAY", api.numberFont)
        row.state:SetWidth(STATE_WIDTH)
        row.state:SetPoint("RIGHT", row, "RIGHT", -column.state, 0)
        row.state:SetJustifyH("CENTER")
        row.state:SetWordWrap(false)

        -- takes an active post back (it asks first)
        row.cancel = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.cancel:SetSize(CANCEL_WIDTH - 10, 18)
        row.cancel:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        pcall(function()
            row.cancel:SetNormalFontObject("GameFontNormalSmall")
            row.cancel:SetHighlightFontObject("GameFontHighlightSmall")
        end)
        row.cancel:SetText("Cancel")
        row.cancel:SetScript("OnClick", function()
            local data = row.data
            if data and data.id and StaticPopup_Show then
                StaticPopup_Show(POPUP_KEY, string.format("%d x %s", data.qty, tostring(data.name)), nil, data.id)
            end
        end)
        row.cancel:Hide()

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
            pair("Amount", tostring(data.qty))
            if data.unit and data.unit > 0 then
                pair("Price of one", api.money(data.unit))
            end
            pair("Expected, after the 5% cut", api.money(data.net))
            pair("Status", stateText(data))
            if data.state == "sold" then
                GameTooltip:AddLine("Sold: the gold is waiting in your mailbox.", 0.7, 0.7, 0.7, true)
            elseif data.state == "expired" or data.state == "cancelled" then
                GameTooltip:AddLine("The items are waiting in your mailbox.", 0.7, 0.7, 0.7, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        rows[index] = row
    end

    local empty = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("CENTER", page, "CENTER", 0, 20)
    empty:SetWidth(380)
    empty:SetJustifyH("CENTER")

    local status = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", panel.status, "BOTTOMLEFT", 0, 0)
    status:SetJustifyH("LEFT")

    local sorted = {}
    local firstRow = 1
    local clearButton

    local function refreshHeaders()
        for _, header in ipairs(headers) do
            local selected = header.key == sortKey
            header.label:SetTextColor(selected and GOLD[1] or 1, selected and GOLD[2] or 1, selected and GOLD[3] or 1)
            header.arrow:SetShown(selected)
            if selected then
                if sortDescending then
                    header.arrow:SetTexCoord(0, 0.5625, 0, 1)
                else
                    header.arrow:SetTexCoord(0, 0.5625, 1, 0)
                end
            end
        end
    end

    local function sortValue(row)
        if sortKey == "name" then
            return string.lower(tostring(row.name or ""))
        elseif sortKey == "state" then
            -- the gold that arrives soonest first, the posts that end last at the bottom
            local order = (STATES[row.state] or STATES.active).order
            -- an active post by the time it has left; the others by when they were noticed (the oldest first)
            local second = row.state == "active" and (row.left or 0) or (row.since or 0)
            return order * 1e10 + second
        end
        return row[sortKey] or 0
    end

    local function refresh()
        if not page:IsShown() then
            return
        end
        refreshHeaders()

        sorted = FWR:GetActionRows()
        table.sort(sorted, function(a, b)
            local va, vb = sortValue(a), sortValue(b)
            if va ~= vb then
                if sortDescending then
                    return va > vb
                end
                return va < vb
            end
            if a.since ~= b.since then
                return a.since > b.since
            end
            return string.lower(tostring(a.name)) < string.lower(tostring(b.name))
        end)

        local maxFirst = math.max(1, #sorted - api.visibleRows + 1)
        firstRow = math.max(1, math.min(firstRow, maxFirst))

        local active, toCollect, expected = 0, 0, 0
        for _, line in ipairs(sorted) do
            if line.state == "active" then
                active = active + 1
            else
                toCollect = toCollect + 1
            end
            if line.state == "active" or line.state == "sold" then
                expected = expected + line.net
            end
        end

        local cancelledCount = 0
        for _, line in ipairs(sorted) do
            if line.state == "cancelled" then
                cancelledCount = cancelledCount + 1
            end
        end
        if clearButton then
            clearButton:SetShown(cancelledCount > 0)
        end

        for index = 1, api.visibleRows do
            local row = rows[index]
            local data = sorted[firstRow + index - 1]
            row.data = data
            if data then
                row:Show()
                local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(data.itemID)
                row.icon:SetTexture(icon or "Interface/Icons/INV_Misc_QuestionMark")
                row.name:SetText(tostring(data.name))
                row.name:SetTextColor(api.rarityColor(data.itemID))
                local tier = FWR.GetItemQualityTier and FWR:GetItemQualityTier(data.itemID)
                local tierShown = false
                if tier then
                    tierShown = pcall(function()
                        row.tier:SetAtlas(string.format("Professions-ChatIcon-Quality-12-Tier%d", tier))
                    end)
                end
                row.tier:SetShown(tierShown)
                row.qty:SetText(tostring(data.qty))
                api.setMoneyCell(row.netCell, data.net > 0 and data.net or nil)
                -- the price of one piece, as the expected gold: after the cut
                local cut = tonumber(FWR.AUCTION_HOUSE_CUT) or 0.05
                local unit = (data.unit or 0) > 0 and math.floor(data.unit * (1 - cut)) or nil
                api.setMoneyCell(row.unitCell, unit)
                local state = STATES[data.state] or STATES.active
                row.state:SetText(stateText(data))
                row.state:SetTextColor(state.color[1], state.color[2], state.color[3])
                row.cancel:SetShown(data.state == "active" and data.id ~= nil)
            else
                row:Hide()
            end
        end

        if #sorted == 0 then
            empty:SetText("Nothing here yet.\nYour posts show up while the Auction House is open,\nand stay until you take their gold or items from the mailbox.")
            empty:Show()
        else
            empty:Hide()
        end
        status:SetText(string.format("%d posts  -  %d active  -  %d to take from the mailbox  -  %s expected",
            #sorted, active, toCollect, api.money(expected)))
    end

    for _, header in ipairs(headers) do
        header:SetScript("OnClick", function(self)
            if sortKey == self.key then
                sortDescending = not sortDescending
            else
                sortKey = self.key
                sortDescending = self.key == "net" or self.key == "qty" or self.key == "unit"
            end
            firstRow = 1
            refresh()
        end)
    end

    page:SetScript("OnMouseWheel", function(_, delta)
        firstRow = firstRow - delta
        refresh()
    end)
    -- the times run: the page is made again once a minute, only while it is open
    local ticker
    page:SetScript("OnShow", function()
        firstRow = 1
        -- every time the page is opened the game is asked again, and the answer corrects what is shown
        if FWR.RefreshOwnedAuctions then
            FWR:RefreshOwnedAuctions()
        end
        refresh()
        if not ticker and C_Timer and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(60, refresh)
        end
    end)
    page:SetScript("OnHide", function()
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end)

    -- the round arrow, where the other pages have it: the list goes back to the order FarmWise chose
    local reset = CreateFrame("Button", nil, page)
    reset:SetSize(22, 22)
    reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -api.padding, -8)
    reset:SetNormalTexture("Interface/Buttons/UI-RefreshButton")
    reset:SetHighlightTexture("Interface/Buttons/UI-RefreshButton", "ADD")
    reset:SetScript("OnClick", function()
        sortKey, sortDescending = "state", false
        firstRow = 1
        refresh()
    end)
    reset:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine("Original order", 1, 0.82, 0)
        GameTooltip:AddLine("Puts the list back in the order FarmWise chose: the gold that arrives soonest first", 0.72, 0.72, 0.72, false)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", GameTooltip_Hide)

    -- a small quiet link at the bottom right: lets go of the lines of the posts that were taken back
    local clear = CreateFrame("Button", nil, page)
    clear:SetSize(110, 16)
    clear:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -api.padding, 8)
    clear.label = clear:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    clear.label:SetAllPoints()
    clear.label:SetJustifyH("RIGHT")
    clear.label:SetTextColor(0.5, 0.5, 0.5)
    clear.label:SetText("Clear cancelled")
    clear:SetScript("OnEnter", function(button)
        button.label:SetTextColor(1, 1, 1)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine("Clear cancelled", 1, 0.82, 0)
        GameTooltip:AddLine("Takes the cancelled posts out of this list. Their items stay in your mailbox.", 0.72, 0.72, 0.72, true)
        GameTooltip:Show()
    end)
    clear:SetScript("OnLeave", function(button)
        button.label:SetTextColor(0.5, 0.5, 0.5)
        GameTooltip_Hide()
    end)
    clear:SetScript("OnClick", function()
        if FWR.ClearCancelledPosts then
            FWR:ClearCancelledPosts()
        end
    end)
    clearButton = clear

    api.addPage({ key = "actions", title = "Actions", frame = page, onShow = refresh })
    FWR:Subscribe("actionsChanged", refresh)
end

FWR:Subscribe("auctionTabBuilt", function(api)
    pcall(build, api)
end)
