local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- The small menu that opens with a right-click on an item of the FarmWise tab of the Auction House:
-- do not show the item in the list, and keep a number of it in the bags.
--
-- It is the game's own context menu (the one every right-click menu of the game uses), so it looks and
-- behaves like the others. A number that is not in the menu is asked for with the game's small input popup.

-- The game moved GetCoinText into C_CurrencyInfo. It is looked up here (nothing is written to the game's names).
local GetCoinText = _G.GetCoinText or (C_CurrencyInfo and C_CurrencyInfo.GetCoinText) or function(amount, separator)
    amount = math.floor(tonumber(amount) or 0)
    separator = separator or " "
    local parts = {}
    local gold, silver, copper = math.floor(amount / 10000), math.floor((amount % 10000) / 100), amount % 100
    if gold > 0 then
        parts[#parts + 1] = gold .. "g"
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. "s"
    end
    if copper > 0 or #parts == 0 then
        parts[#parts + 1] = copper .. "c"
    end
    return table.concat(parts, separator)
end

local KEEP_CHOICES = { 10, 20, 50, 100 }
local HOURS = { 12, 24, 48 }
local POPUP_KEY = "FARMWISE_KEEP_AMOUNT"

local function editBoxOf(popup)
    return popup.editBox or popup.EditBox or (popup.GetName and popup:GetName() and _G[popup:GetName() .. "EditBox"])
end

local function acceptKeep(popup, data)
    local box = editBoxOf(popup)
    if box and data and data.itemID then
        local hide = FWR:GetSellFilter(data.itemID)
        FWR:SetSellFilter(data.itemID, hide, tonumber(box:GetText()) or 0)
    end
end

if type(StaticPopupDialogs) == "table" then
    StaticPopupDialogs[POPUP_KEY] = {
        text = "Keep at least how many of %s in your bags?",
        button1 = OKAY,
        button2 = CANCEL,
        hasEditBox = 1,
        maxLetters = 5,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnShow = function(popup, data)
            local box = editBoxOf(popup)
            if box then
                box:SetNumeric(true)
                box:SetText(tostring(data and data.keep or 0))
                box:HighlightText()
            end
        end,
        OnAccept = acceptKeep,
        EditBoxOnEnterPressed = function(box)
            local popup = box:GetParent()
            acceptKeep(popup, popup.data)
            popup:Hide()
        end,
        EditBoxOnEscapePressed = function(box)
            box:GetParent():Hide()
        end,
    }
end

-- owner: the row that was clicked; entry: { itemID, name, leftOut } of that row.
function FWR:OpenSellFilterMenu(owner, entry)
    if not (MenuUtil and MenuUtil.CreateContextMenu) or not entry or not entry.itemID then
        return
    end
    local itemID = entry.itemID

    MenuUtil.CreateContextMenu(owner, function(_, root)
        local quality = FWR.GetItemQualityLabel and FWR:GetItemQualityLabel(itemID)
        root:CreateTitle(tostring(entry.name or itemID) .. (quality and ("  " .. quality) or ""))

        -- items that are left out: show it again (when hidden) and what to keep in the bags; nothing about prices
        local leftOut = entry.leftOut
        if leftOut == "vendor" then
            root:CreateTitle("A vendor pays more for it than the Auction House")
        elseif leftOut == "hidden" then
            root:CreateButton("Show in the list", function()
                local _, keep = FWR:GetSellFilter(itemID)
                FWR:SetSellFilter(itemID, false, keep)
            end)
        else
            root:CreateButton("Hide from the list", function()
                local _, keep = FWR:GetSellFilter(itemID)
                FWR:SetSellFilter(itemID, true, keep)
            end)
        end

        local keepMenu = root:CreateButton("Keep in my bags")
        local function addKeepChoice(label, value)
            keepMenu:CreateRadio(label, function()
                local _, keep = FWR:GetSellFilter(itemID)
                return keep == value
            end, function()
                local hide = FWR:GetSellFilter(itemID)
                FWR:SetSellFilter(itemID, hide, value)
            end)
        end
        addKeepChoice("No limit", 0)
        for _, value in ipairs(KEEP_CHOICES) do
            addKeepChoice(tostring(value), value)
        end
        keepMenu:CreateButton("Other number...", function()
            local hide, keep = FWR:GetSellFilter(itemID)
            if StaticPopup_Show then
                StaticPopup_Show(POPUP_KEY, tostring(entry.name or itemID), nil, { itemID = itemID, hide = hide, keep = keep })
            end
        end)

        if leftOut then
            return
        end

        -- the posting time of this item, with what the deposit would be for each
        local override = FWR:GetItemDurationOverride(itemID)
        local default = FWR:GetSellTabSettings().duration
        local timeMenu = root:CreateButton("Posting time")
        local function addTimeChoice(label, value)
            timeMenu:CreateRadio(label, function()
                return FWR:GetItemDurationOverride(itemID) == value
            end, function()
                FWR:SetItemDuration(itemID, value)
            end)
        end
        local function depositText(duration)
            local deposit = FWR:GetPostDeposit(itemID, duration, entry.quantity)
            if not deposit then
                return ""
            end
            return "  (deposit " .. GetCoinText(deposit, " ") .. ")"
        end
        addTimeChoice(string.format("My default: %d hours%s", HOURS[default], depositText(default)), nil)
        for duration = 1, 3 do
            addTimeChoice(string.format("%d hours%s", HOURS[duration], depositText(duration)), duration)
        end

        -- the price check: Post waits while the price is unusually low
        local _, _, check = FWR:GetSellFilter(itemID)
        root:CreateButton(check and "Turn off price check" or "Turn on price check", function()
            FWR:SetPriceCheck(itemID, not check)
        end)

        -- never post below the average of the last sales (from the History)
        -- it can be turned on only when there is a history to make the average from; turning it off is always possible
        local floorOn = FWR:IsAveragePriceFloorOn(itemID)
        local average, pieces, sales = FWR:GetMyAveragePrice(itemID)
        local available = floorOn or average ~= nil
        local floorButton = root:CreateButton(floorOn and "Turn off: never below my average price" or "Turn on: never below my average price", function()
            if available then
                FWR:SetAveragePriceFloor(itemID, not floorOn)
            end
        end)
        if not available then
            pcall(function()
                floorButton:SetEnabled(false)
            end)
        end
        if average then
            root:CreateTitle("My average: " .. GetCoinText(average, " ") .. "  (" .. sales .. " sales)")
        else
            local historyOn = FWR.IsSalesHistoryEnabled and FWR:IsSalesHistoryEnabled()
            root:CreateTitle(historyOn and "My average: not enough sales yet (3 sales, 20 pieces)"
                or "My average: the sales history is switched off")
        end

    end)
end
