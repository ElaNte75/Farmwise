local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- The game moved these functions into C_Item / C_Spell. They are looked up here, for this file only: nothing
-- is written to the game's own global names (that would taint the game's code).
local GetItemInfoInstant = _G.GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
local GetItemInfo = _G.GetItemInfo or (C_Item and C_Item.GetItemInfo)
local GetItemIcon = _G.GetItemIcon or (C_Item and C_Item.GetItemIconByID)

-- "FarmWise" tab of the Auction House.
-- A list of the trade materials you have farmed and carry in your bags, with the lowest price on the
-- Auction House right now, a price you can raise or lower, an amount, and a Post button.
--
-- This is a separate module on purpose: it uses nothing from the rest of FarmWise except the saved data it
-- reads and the state of the Auction House scan, and nothing else uses it. To remove it, delete this file
-- and its line in FarmWise.toc.
--
-- What the list holds follows the filters of FWR_SellFilters (set in the right-click menu of an item): items
-- you hide, a number you keep in the bags, and items a vendor pays more for than the Auction House do not
-- appear. A line at the bottom switches to the list of those items that are left out, where a right-click
-- changes their filters again.
--
-- Price check (switched on per item in the right-click menu): when the price you are about to post is
-- unusually low against where most of the listings are, Post waits, the first "+" goes straight to the lowest
-- usual price and "-" goes down to it and stops there (the buttons only switch on and off, they do not change
-- colour: the tooltip of Post says where the price stands). Right-click on a price: back to the lowest price.
--
-- The tab asks the Auction House for its own prices as it goes, so it does not depend on how old the last
-- scan is (the Scanner options decide when to scan). While a scan runs, the tab shows its progress in
-- place of its name, and it opens again when the scan has finished.
--
-- It is added the way the game itself builds its tabs: our page is a sub-frame of the Auction House window,
-- registered as a "display mode" (like Buy, Sell and Auctions), with a tab button made from the game's own
-- tab template. So the game shows our page and hides all its own pages by itself, selects our tab like its
-- own, and nothing of the other pages can be seen behind ours.

local ROW_HEIGHT = 20
local VISIBLE_ROWS = 17
local PANEL_PADDING = 8
local PRICE_STEP_PERCENT = 5      -- the "+" and "-" buttons change the price by this much, if the option cannot be read
local HOURS = { 12, 24, 48 }       -- the posting times; which one is used: the item's own, or the one for all
local PRICE_QUEUE_SECONDS = 0.6   -- the game limits how fast prices can be asked for

local TRADEGOODS_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
local TAB_TITLE = "FarmWise AH"             -- the label of the tab
local WINDOW_TITLE = "FarmWise Auction House"   -- the title of the window while the tab is shown
local PAGE_KEY = "FarmWisePage"
local GOLD = { 1, 0.82, 0 }

-- Where each column sits inside a row. Every column except the item name is measured from the RIGHT edge
-- of the list (distance to the column's right edge, and its width), so nothing can ever stick out of the
-- page, whatever size the window or the screen has. The item name takes the room that is left.
local ICON_SIZE = 14
local ICON_X = 6
local NAME_X = 24   -- icon, then 4 pixels, like the game's own lists
local NAME_GAP = 6

-- The item column is the same in the Sell, Actions and History pages, and it never changes its size: a long name
-- is cut with "..." and the mark of the quality has a place of its own at the end of the column, so it is
-- always seen. The other pages read these numbers from FWR.ITEM_COLUMN.
local ITEM_WIDTH, TIER_W, TIER_H, TIER_GAP = 216, 14, 12, 3
FWR.ITEM_COLUMN = { x = NAME_X, width = ITEM_WIDTH, tierWidth = TIER_W, tierHeight = TIER_H, tierGap = TIER_GAP }
local MARK_WIDTH = 14   -- one "!" after the name (it takes room from the name)
local NUMBER_FONT = "Number13FontWhite"   -- numbers: a little smaller than the names (14)
local TITLE_FONT = "GameFontHighlightSmall"

-- width of a text in a font
local meters = {}
local function textWidth(fontObject, text)
    local meter = meters[fontObject]
    if not meter then
        meter = UIParent:CreateFontString(nil, "ARTWORK", fontObject)
        meter:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
        meters[fontObject] = meter
    end
    meter:SetText(text)
    return math.ceil(meter:GetStringWidth())
end

-- The columns have a size that holds what is normal. If something ever needs more, the column grows, for good:
-- the width is kept with the saved data of the user and never gets smaller, so the columns do not move
-- between lists. The new width is used the next time the page is made (a /reload); until then the value is
-- written in full anyway.
local function savedWidth(key)
    local layout = type(FarmWiseDB) == "table" and FarmWiseDB._ahTabLayout
    return type(layout) == "table" and tonumber(layout[key]) or 0
end

local function rememberWidth(key, width)
    if type(FarmWiseDB) ~= "table" then
        return
    end
    local layout = type(FarmWiseDB._ahTabLayout) == "table" and FarmWiseDB._ahTabLayout or {}
    FarmWiseDB._ahTabLayout = layout
    if width > (tonumber(layout[key]) or 0) then
        layout[key] = width
    end
end

-- The sizes of the columns are worked out by computeLayout(), when the page is made (the saved data of the user
-- is not there yet while the files are being read).
local NAME_WIDTH, OWNED_WIDTH, AMOUNT_WIDTH, TREND_WIDTH
local GOLD_DIGITS, GOLD_DIGITS_WIDTH, SMALL_DIGITS_WIDTH, PRICE_WIDTH
local VALUE_GOLD_DIGITS, VALUE_GOLD_WIDTH, VALUE_WIDTH
local NAME_END
local TAB_SETTINGS = { duration = 1, priceCheck = false, showTrend = true, showValue = true }

local COIN_WIDTH, COIN_HEIGHT = 10, 12
local COIN_GAP, PART_GAP = 3, 3
local COLUMN = {}
local SEPARATORS = {}

local function computeLayout(auctionHouseFrame)
    TAB_SETTINGS = FWR.GetSellTabSettings and FWR:GetSellTabSettings() or TAB_SETTINGS

    -- The item name column has one size, the same in the three pages. It is the size the History page has always
    -- had: what the page leaves to the item after the columns that stand at its right edge (they have a fixed
    -- width, see the History page). Worked out once from the width of the Auction House window.
    local itemWidth = ITEM_WIDTH
    local windowWidth = auctionHouseFrame and auctionHouseFrame.GetWidth and tonumber(auctionHouseFrame:GetWidth())
    if windowWidth and windowWidth > 0 and FWR.HISTORY_RIGHT_WIDTH then
        local listWidth = windowWidth - 4 - 5 - 2 * PANEL_PADDING
        itemWidth = math.max(120, math.floor(listWidth - FWR.HISTORY_RIGHT_WIDTH - NAME_X))
    end
    FWR.ITEM_COLUMN.width = itemWidth
    NAME_WIDTH = itemWidth

    -- The price: gold (up to six digits, growing to the left) and silver (two digits), each in a place of its
    -- own, so the numbers of all the rows stand in columns. Prices of the Auction House are in whole silver, so
    -- there is no place for copper (a price that does have copper is still written in full, see showMoney).
    -- The gold column holds six digits (999999) and grows, for good, if a price ever needs more.
    GOLD_DIGITS = math.max(6, math.floor(savedWidth("goldDigits")))
    -- (the measured width is a little short of what is drawn: one more pixel for each digit)
    GOLD_DIGITS_WIDTH = textWidth(NUMBER_FONT, string.rep("9", GOLD_DIGITS)) + GOLD_DIGITS + 2
    SMALL_DIGITS_WIDTH = textWidth(NUMBER_FONT, "99") + 2
    PRICE_WIDTH = GOLD_DIGITS_WIDTH + COIN_GAP + COIN_WIDTH + PART_GAP + SMALL_DIGITS_WIDTH + COIN_GAP + COIN_WIDTH + 8

    -- In bags: wide enough for its title on one line and for four digits. Amount: as wide as its title.
    OWNED_WIDTH = math.max(math.max(textWidth(NUMBER_FONT, "9999"), textWidth(TITLE_FONT, "In bags")) + 10,
        savedWidth("ownedWidth"))
    AMOUNT_WIDTH = math.max(textWidth(TITLE_FONT, "Amount") + 6, savedWidth("amountWidth"))
    TREND_WIDTH = textWidth(TITLE_FONT, "Trend") + 8

    -- Value: what the whole amount brings after the 5% cut, in gold (up to six digits) and silver, like the price
    VALUE_GOLD_DIGITS = math.max(6, math.floor(savedWidth("valueGoldDigits")))
    VALUE_GOLD_WIDTH = textWidth(NUMBER_FONT, string.rep("9", VALUE_GOLD_DIGITS)) + VALUE_GOLD_DIGITS + 2
    VALUE_WIDTH = math.max(VALUE_GOLD_WIDTH + 3 + 10 + 3 + textWidth(NUMBER_FONT, "99") + 2 + 3 + 10 + 8,
        textWidth(TITLE_FONT, "Value (-5% cut)") + 8)

    -- The columns, from the left, one after the other, starting right after the name: In bags, "-", the price,
    -- "+", Trend, Amount, Value, Post. Each is { left, width }: the distance of its left edge from the left
    -- edge of the list. What is left of the width of the page stays empty on the right.
    NAME_END = NAME_X + NAME_WIDTH + NAME_GAP
    for key in pairs(COLUMN) do
        COLUMN[key] = nil
    end
    COLUMN.owned = { left = NAME_END + 4, width = OWNED_WIDTH }
    COLUMN.minus = { left = COLUMN.owned.left + COLUMN.owned.width + 6, width = 24 }
    COLUMN.price = { left = COLUMN.minus.left + COLUMN.minus.width + 4, width = PRICE_WIDTH }
    COLUMN.plus = { left = COLUMN.price.left + COLUMN.price.width + 4, width = 24 }
    local afterPlus = COLUMN.plus
    if TAB_SETTINGS.showTrend then
        COLUMN.trend = { left = COLUMN.plus.left + COLUMN.plus.width + 8, width = TREND_WIDTH }
        afterPlus = COLUMN.trend
    end
    COLUMN.quantity = { left = afterPlus.left + afterPlus.width + 8, width = AMOUNT_WIDTH }
    local afterAmount = COLUMN.quantity
    if TAB_SETTINGS.showValue then
        COLUMN.value = { left = COLUMN.quantity.left + COLUMN.quantity.width + 8, width = VALUE_WIDTH }
        afterAmount = COLUMN.value
    end
    COLUMN.post = { left = afterAmount.left + afterAmount.width + 8, width = 52 }

    -- thin lines between the columns (distance from the left edge): after the name, after In bags, after the
    -- price with its buttons, after Trend, after Amount, after Value
    for index = #SEPARATORS, 1, -1 do
        SEPARATORS[index] = nil
    end
    SEPARATORS[#SEPARATORS + 1] = NAME_END
    SEPARATORS[#SEPARATORS + 1] = COLUMN.owned.left + COLUMN.owned.width + 3
    SEPARATORS[#SEPARATORS + 1] = COLUMN.plus.left + COLUMN.plus.width + 4
    if COLUMN.trend then
        SEPARATORS[#SEPARATORS + 1] = COLUMN.trend.left + COLUMN.trend.width + 4
    end
    SEPARATORS[#SEPARATORS + 1] = COLUMN.quantity.left + COLUMN.quantity.width + 4
    if COLUMN.value then
        SEPARATORS[#SEPARATORS + 1] = COLUMN.value.left + COLUMN.value.width + 4
    end
end

local installed = false
local panel
local rows = {}
local entries = {}        -- one per material in the bags
local entryById = {}
local known = {}          -- every entry made while the Auction House is open, by item: its price and choices are kept
local firstRow = 1        -- scroll position
local priceQueue = {}
local priceBusy = false
local askSerial = 0
local askedTimes = {}
local postedNote = nil
-- the post that is going on (from the button "Post next"), and what it waits for
local autoPost = { running = false, waiting = nil, since = 0, bagChanged = false, lastName = nil }
local updateAutoButton
local wheelActive = false   -- the mouse wheel is bound to the button now
local ourTab = nil
local viewHidden = false   -- the list shows the items that are left out, instead of the others
local hiddenCount = 0      -- how many are left out

------------------------------------------------------------
-- What is in the bags and was farmed
------------------------------------------------------------

-- Item IDs FarmWise has seen you gather, loot or process.
local function farmedItemIDs()
    if FWR.GetFarmedItemIDs then
        return FWR:GetFarmedItemIDs(0)
    end
    return {}
end

local function bagCount()
    local total = tonumber(NUM_BAG_SLOTS) or 4
    return total + (tonumber(NUM_REAGENTBAG_SLOTS) or 1)
end

-- The group of an item (by its class), for the options of what the list shows
local ITEM_CLASS = (Enum and Enum.ItemClass) or {}
local function itemGroup(classID)
    if classID == TRADEGOODS_CLASS then
        return "trade"
    elseif classID == (ITEM_CLASS.Consumable or 0) then
        return "consumables"
    elseif classID == (ITEM_CLASS.Gem or 3) or classID == (ITEM_CLASS.ItemEnhancement or 8) then
        return "gems"
    end
    return "other"
end

-- Set when the game did not know yet if something stacks: the list is made again a little later.
local infoMissing = false

-- Is the item sold by amount (a commodity)? The game says so; while it does not know yet, what stacks counts
-- (and gear never does).
local function isCommodity(bag, slot, itemID, classID)
    local statusEnum = Enum and Enum.ItemCommodityStatus
    if statusEnum and ItemLocation and C_AuctionHouse and C_AuctionHouse.GetItemCommodityStatus then
        local ok, status = pcall(function()
            return C_AuctionHouse.GetItemCommodityStatus(ItemLocation:CreateFromBagAndSlot(bag, slot))
        end)
        if ok and status == statusEnum.Commodity then
            return true
        elseif ok and status == statusEnum.Item then
            return false
        end
    end

    if classID == (ITEM_CLASS.Weapon or 2) or classID == (ITEM_CLASS.Armor or 4) then
        return false
    end
    local stack = C_Item and C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(itemID)
    if stack == nil then
        -- the game has not loaded what it knows of this item yet: go by its kind for now, and look again soon
        infoMissing = true
        return classID == (ITEM_CLASS.Consumable or 0) or classID == (ITEM_CLASS.Gem or 3)
            or classID == TRADEGOODS_CLASS or classID == (ITEM_CLASS.ItemEnhancement or 8)
            or classID == (ITEM_CLASS.Reagent or 5)
    end
    return (tonumber(stack) or 1) > 1
end

-- What is in the bags that can be sold from this list: { [itemID] = { owned, bag, slot } }. Everything that is
-- sold by amount and is not bound to you, except what the options of the list leave out.
local function scanBags()
    local settings = FWR.GetSellTabSettings and FWR:GetSellTabSettings()
        or { onlyFarmed = false, groups = { trade = true, consumables = true, gems = true, other = true } }
    local farmed = settings.onlyFarmed and farmedItemIDs() or nil
    local found = {}
    if not C_Container or not C_Container.GetContainerItemInfo then
        return found
    end

    for bag = 0, bagCount() do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and tonumber(info.itemID)
            -- grey (poor quality) items are never part of the list: a vendor takes them
            if itemID and tonumber(info.quality) ~= 0 and not info.isBound and not info.isLocked
                and (not farmed or farmed[itemID]) then
                local record = found[itemID]
                if record then
                    record.owned = record.owned + (tonumber(info.stackCount) or 1)
                else
                    local classID = select(6, GetItemInfoInstant(itemID))
                    if settings.groups[itemGroup(classID)] and isCommodity(bag, slot, itemID, classID) then
                        found[itemID] = { owned = tonumber(info.stackCount) or 1, bag = bag, slot = slot }
                    end
                end
            end
        end
    end
    return found
end

-- The price to post starts at the lowest price of the Auction House and follows it until you press "+" or "-".
-- After that it is the price you chose. A step is the percentage of the options (5 by default) of the lowest price.
local function stepSize(entry)
    local percent = PRICE_STEP_PERCENT
    if FWR.GetSellTabSettings then
        percent = FWR:GetSellTabSettings().priceStep or percent
    end
    local raw = entry.lowest * percent / 100
    if raw >= 100 then
        -- prices of the Auction House are in whole silver: so is a step
        return math.max(100, math.floor(raw / 100 + 0.5) * 100)
    end
    return math.max(1, math.floor(raw + 0.5))
end

-- Where the price starts: the lowest price of the Auction House, or your average price when that is higher (and
-- "never below my average price" is on). The average never pulls the price below the market.
local function startPrice(entry)
    if entry.average and entry.average > entry.lowest then
        return entry.average
    end
    return entry.lowest
end

local function updatePrice(entry)
    if not entry.lowest then
        entry.price = nil
        return
    end
    if not entry.touched or not entry.price then
        entry.price = startPrice(entry)
    end
    -- the price is never under your average (also when the average or the market changed)
    if entry.average and entry.price < entry.average then
        entry.price = entry.average
    end
end

-- Back to the lowest price of the Auction House.
local function resetPrice(entry)
    entry.touched = false
    entry.price = nil
    updatePrice(entry)
end

-- Where the price to post stands against the usual price: "low", "normal" or "high", and the lowest usual
-- price. nil when the check is off for the item or there is not enough to judge by.
local function priceZone(entry, price)
    if not (entry.check and entry.usual and FWR.GetPriceZone) then
        return nil
    end
    return FWR:GetPriceZone(price or entry.price, entry.usual)
end

local rebuildEntries

rebuildEntries = function()
    local previous = entryById
    entries, entryById = {}, {}
    hiddenCount = 0

    for itemID, record in pairs(scanBags()) do
        local old = previous[itemID] or known[itemID]

        -- the filters: hidden by you, all of it kept in the bags, or the vendor pays more
        local hide, keep, check, duration = false, 0, false, TAB_SETTINGS.duration
        if FWR.GetSellFilter then
            hide, keep, check, duration = FWR:GetSellFilter(itemID)
        end
        local sellable = record.owned - keep
        local leftOut
        local reasons = {}
        local isKept = keep > 0 and sellable < 1
        local isVendor = FWR.IsSoldBetterToVendor and FWR:IsSoldBetterToVendor(itemID)
        if not isVendor and old and old.lowest and FWR.IsVendorBetterThanPrice then
            isVendor = FWR:IsVendorBetterThanPrice(itemID, old.lowest)   -- the live price, for what the scan does not read
        end
        if hide then
            reasons[#reasons + 1] = "Hidden by you"
        end
        if isKept then
            reasons[#reasons + 1] = string.format("Keeping %d (you have %d)", keep, record.owned)
        end
        if isVendor then
            reasons[#reasons + 1] = "A vendor pays more than the Auction House"
        end
        if hide then
            leftOut = "hidden"
        elseif isKept or sellable < 1 then
            leftOut = "kept"
        elseif isVendor then
            leftOut = "vendor"
        end
        if leftOut then
            hiddenCount = hiddenCount + 1
        end

        if (leftOut ~= nil) == viewHidden then
            local name, _, rarity = nil, nil, 1
            if C_Item and C_Item.GetItemInfo then
                name, _, rarity = C_Item.GetItemInfo(itemID)
            elseif GetItemInfo then
                name, _, rarity = GetItemInfo(itemID)
            end

            local entry = {
                itemID = itemID,
                name = name or ("item:" .. itemID),
                rarity = rarity or 1,
                icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or (GetItemIcon and GetItemIcon(itemID)),
                owned = record.owned,                  -- all that is in the bags
                keep = keep,                           -- how many you keep
                duration = duration,                   -- how long it is posted for: 1, 2 or 3 (12, 24, 48 hours)
                check = check,                         -- the price check is on for this item
                average = FWR.GetAveragePriceFloor and FWR:GetAveragePriceFloor(itemID) or nil,   -- never post below this
                myAverage = FWR.GetMyAveragePrice and (FWR:GetMyAveragePrice(itemID)) or nil,     -- what you got, for the tooltip
                usual = old and old.usual or nil,      -- the usual price of the item (copper), nil until known
                sellable = math.max(0, sellable),      -- what may be posted from this list
                leftOut = leftOut,                     -- why it is not in the list (only shown on request)
                reasons = reasons,                     -- all the reasons, as texts
                bag = record.bag,
                slot = record.slot,
                lowest = old and old.lowest or nil,    -- lowest price on the Auction House (copper), nil until asked
                touched = old and old.touched or false, -- you changed the price with "+" or "-"
                price = old and old.price or nil,      -- the price to post (copper)
                -- the amount follows what may be posted until you set it yourself (typed in the box)
                quantityTouched = old and old.quantityTouched or false,
                quantity = (old and old.quantityTouched and old.quantity) or math.max(1, sellable),
            }
            updatePrice(entry)
            if entry.quantity > math.max(1, entry.sellable) then
                entry.quantity = math.max(1, entry.sellable)
            end

            -- a single-item auction (not a stack at a unit price) cannot be posted from this list
            entry.notCommodity = false
            pcall(function()
                if ItemLocation and C_AuctionHouse and C_AuctionHouse.GetItemCommodityStatus
                    and Enum and Enum.ItemCommodityStatus then
                    local status = C_AuctionHouse.GetItemCommodityStatus(ItemLocation:CreateFromBagAndSlot(record.bag, record.slot))
                    entry.notCommodity = status == Enum.ItemCommodityStatus.Item
                end
            end)

            entries[#entries + 1] = entry
            entryById[itemID] = entry
            known[itemID] = entry
        end
    end

    table.sort(entries, function(a, b)
        local first, second = string.lower(tostring(a.name)), string.lower(tostring(b.name))
        if first ~= second then
            return first < second
        end
        return a.itemID < b.itemID
    end)

    -- nothing left out any more (the last one was shown again): back to the normal list
    if viewHidden and hiddenCount == 0 then
        viewHidden = false
        rebuildEntries()
    end
end

------------------------------------------------------------
-- Asking for the lowest price (one item at a time)
------------------------------------------------------------

local refreshRows

local function queuePrice(itemID)
    for _, queued in ipairs(priceQueue) do
        if queued == itemID then
            return
        end
    end
    priceQueue[#priceQueue + 1] = itemID
end

local function askNextPrice()
    if priceBusy or #priceQueue == 0 or not panel or not panel:IsShown() then
        return
    end
    if autoPost.running then
        C_Timer.After(1, askNextPrice)   -- the Auction House is busy with the post
        return
    end
    if FWR.IsAuctionScanRunning and FWR:IsAuctionScanRunning() then
        C_Timer.After(2, askNextPrice)
        return
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        C_Timer.After(PRICE_QUEUE_SECONDS, askNextPrice)
        return
    end

    local itemID = table.remove(priceQueue, 1)
    priceBusy = true
    askSerial = askSerial + 1
    local mine = askSerial
    local ok = pcall(function()
        C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(itemID), {}, false)
    end)
    if not ok then
        priceBusy = false
        C_Timer.After(PRICE_QUEUE_SECONDS, askNextPrice)
        return
    end

    -- no answer in time: try this one once more later, and go on with the next
    C_Timer.After(6, function()
        if priceBusy and mine == askSerial then
            priceBusy = false
            askedTimes[itemID] = (askedTimes[itemID] or 0) + 1
            if askedTimes[itemID] < 2 then
                queuePrice(itemID)
            end
            askNextPrice()
        end
    end)
end

local function priceArrived(itemID)
    local entry = entryById[itemID]
    if not entry then
        return   -- an answer to someone else's question
    end
    priceBusy = false
    askSerial = askSerial + 1
    askedTimes[itemID] = nil

    -- what is for sale and at which prices: the usual price is where most of it is listed
    pcall(function()
        local listings = {}
        local count = C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
        for index = 1, math.min(count, 200) do
            local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
            if result and tonumber(result.unitPrice) then
                listings[#listings + 1] = { price = tonumber(result.unitPrice), quantity = tonumber(result.quantity) or 0 }
            end
        end
        entry.usual = FWR.GetUsualPrice and FWR:GetUsualPrice(listings) or nil

    end)

    local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
    local lowest = info and tonumber(info.unitPrice)
    if lowest and lowest > 0 then
        entry.lowest = lowest
        updatePrice(entry)

        -- a vendor pays more than this live price: the item goes to the ones that are left out
        if not entry.leftOut and FWR.IsVendorBetterThanPrice and FWR:IsVendorBetterThanPrice(itemID, lowest) then
            if FWR.NoteVendorBetter then
                FWR:NoteVendorBetter(itemID, lowest)   -- so the item's tooltip can say why it is left out
            end
            known[itemID] = entry
            rebuildEntries()
        end
    end

    if refreshRows then
        refreshRows()
    end
    C_Timer.After(PRICE_QUEUE_SECONDS, askNextPrice)
end

-- onlyMissing: ask only for the items whose price is not known yet (after a bag change)
local function requestAllPrices(onlyMissing)
    for _, entry in ipairs(entries) do
        if not entry.notCommodity and not entry.leftOut and (not onlyMissing or not entry.lowest) then
            queuePrice(entry.itemID)
        end
    end
    askNextPrice()
    if updateAutoButton then
        updateAutoButton()
    end
end

------------------------------------------------------------
-- The page
------------------------------------------------------------

local function money(copper)
    copper = tonumber(copper)
    if not copper then
        return "-"
    end
    copper = math.floor(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = gold .. "|A:Coin-Gold:10:9|a"
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. "|A:Coin-Silver:10:9|a"
    end
    if rest > 0 or #parts == 0 then
        parts[#parts + 1] = rest .. "|A:Coin-Copper:10:9|a"
    end
    return table.concat(parts, " ")
end

-- The arrow of the trend: up, down, or a dash, drawn with small rectangles (11 wide, 11 high) so that it can
-- be any colour and needs no picture of the game.
local ARROW_SIZE = 11
local TREND_COLOR = {
    up = { 0.25, 0.9, 0.3 },
    down = { 0.95, 0.25, 0.25 },
    flat = { 1, 0.85, 0.2 },
}

local function createTrendArrow(row)
    row.arrow = {}
    for index = 1, 7 do
        local bar = row:CreateTexture(nil, "OVERLAY")
        bar:SetColorTexture(1, 1, 1, 1)
        bar:Hide()
        row.arrow[index] = bar
    end
end

local function drawBar(row, bar, line, width, height)
    local x = COLUMN.trend.left + math.floor((COLUMN.trend.width - width) / 2)
    bar:ClearAllPoints()
    bar:SetSize(width, height)
    bar:SetPoint("TOPLEFT", row, "LEFT", x, math.floor(ARROW_SIZE / 2) - (line - 1))
    bar:Show()
end

-- direction: "up", "down", "flat" or nil (nothing is shown)
local function showTrend(row, direction)
    if not COLUMN.trend then
        return
    end
    for _, bar in ipairs(row.arrow) do
        bar:Hide()
    end
    local color = direction and TREND_COLOR[direction]
    if not color then
        return
    end
    for _, bar in ipairs(row.arrow) do
        bar:SetColorTexture(color[1], color[2], color[3], 1)
    end

    if direction == "up" then
        for index = 1, 6 do
            drawBar(row, row.arrow[index], index, 2 * index - 1, 1)
        end
        drawBar(row, row.arrow[7], 7, 3, 5)
    elseif direction == "down" then
        drawBar(row, row.arrow[7], 1, 3, 5)
        for index = 1, 6 do
            drawBar(row, row.arrow[index], 5 + index, 13 - 2 * index, 1)
        end
    else
        drawBar(row, row.arrow[7], 5, ARROW_SIZE, 3)
    end
end

-- the two places of a price in a column: { gold = { text, icon }, silver = { text, icon } }, centred in it
local function createMoneySlots(row, column, goldWidth)
    local total = goldWidth + COIN_GAP + COIN_WIDTH + PART_GAP + SMALL_DIGITS_WIDTH + COIN_GAP + COIN_WIDTH
    local x = column.left + math.floor((column.width - total) / 2)

    local slots = {}
    local specs = {
        { "gold", goldWidth, "Coin-Gold" },
        { "silver", SMALL_DIGITS_WIDTH, "Coin-Silver" },
    }
    for _, spec in ipairs(specs) do
        local text = row:CreateFontString(nil, "OVERLAY", NUMBER_FONT)
        text:SetWidth(spec[2])
        text:SetJustifyH("RIGHT")
        text:SetPoint("LEFT", row, "LEFT", x, 0)

        local icon = row:CreateTexture(nil, "OVERLAY")
        icon:SetSize(COIN_WIDTH, COIN_HEIGHT)
        icon:SetPoint("LEFT", row, "LEFT", x + spec[2] + COIN_GAP, 0)
        pcall(function()
            icon:SetAtlas(spec[3])
        end)

        x = x + spec[2] + COIN_GAP + COIN_WIDTH + PART_GAP
        slots[spec[1]] = { text = text, icon = icon }
    end
    return slots
end

local function showSlot(slot, value)
    if value then
        slot.text:SetText(tostring(value))
        slot.text:Show()
        slot.icon:Show()
    else
        slot.text:Hide()
        slot.icon:Hide()
    end
end

-- text in the place of a price ("...", "hidden by you", ...). unbounded: a text that may be wider than the place.
local function renderNote(slots, note, width, text, unbounded)
    for _, slot in pairs(slots) do
        showSlot(slot, nil)
    end
    note:SetWidth(unbounded and 0 or width)
    note:SetText(text)
    note:Show()
end

-- an amount of money in its two places. An amount with copper (it does not happen on the Auction House) is not
-- rounded: it is written in full. More digits of gold than the place holds: written in full for now, and the
-- column grows (for good) the next time the page is made (rememberKey; nil: nothing is remembered).
local function renderMoney(slots, note, width, copper, goldDigits, rememberKey)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)

    if copper % 100 ~= 0 then
        local parts = {}
        if gold > 0 then
            parts[#parts + 1] = string.format("%.0f", gold) .. "|A:Coin-Gold:12:10|a"
        end
        if gold > 0 or silver > 0 then
            parts[#parts + 1] = silver .. "|A:Coin-Silver:12:10|a"
        end
        parts[#parts + 1] = (copper % 100) .. "|A:Coin-Copper:12:10|a"
        renderNote(slots, note, width, table.concat(parts, " "), true)
        return
    end

    local digits = #tostring(gold)
    if digits > goldDigits then
        if rememberKey then
            rememberWidth(rememberKey, digits)
        end
        renderNote(slots, note, width, string.format("%.0f|A:Coin-Gold:12:10|a %.0f|A:Coin-Silver:12:10|a", gold, silver), true)
        return
    end

    note:Hide()
    showSlot(slots.gold, gold > 0 and gold or nil)
    showSlot(slots.silver, silver)
end

local function showNote(row, text, unbounded)
    renderNote(row.money, row.price, COLUMN.price.width, text, unbounded)
end

local function showMoney(row, copper)
    renderMoney(row.money, row.price, COLUMN.price.width, copper, GOLD_DIGITS, "goldDigits")
end

-- the value of the whole amount: after the 5% cut of the Auction House, in whole silver
local function showValue(row, entry)
    if not COLUMN.value then
        return
    end
    if entry.price and entry.quantity and not entry.leftOut and entry.sellable and entry.sellable >= 1 then
        local total = math.floor(math.floor(entry.price * math.min(entry.quantity, entry.sellable) * 0.95) / 100) * 100
        renderMoney(row.valueMoney, row.valueNote, COLUMN.value.width, total, VALUE_GOLD_DIGITS, "valueGoldDigits")
    else
        renderNote(row.valueMoney, row.valueNote, COLUMN.value.width, "", false)
    end
end

-- What a row needs from the columns: if a column is too narrow for it, it will be wider from the next time on.
-- Returns the widths the name and the number in the bags need now, so that it is written in full meanwhile.
local function needWidths(entry, marks, shownName)
    local ownedNeed = textWidth(NUMBER_FONT, tostring(entry.owned)) + 10
    if ownedNeed > OWNED_WIDTH then
        rememberWidth("ownedWidth", ownedNeed)
    end

    local amountNeed = textWidth(NUMBER_FONT, tostring(entry.quantity)) + 16
    if amountNeed > AMOUNT_WIDTH then
        rememberWidth("amountWidth", amountNeed)
    end

    return ownedNeed
end

local function setQuantity(entry, quantity)
    quantity = math.floor(tonumber(quantity) or 1)
    entry.quantity = math.max(1, math.min(entry.sellable, quantity))
    entry.quantityTouched = true
end

local function changePrice(entry, direction)
    if not entry.lowest or not entry.price then
        return
    end

    local zone, usualLowest = priceZone(entry)
    local price
    if direction > 0 then
        if zone == "low" then
            -- unusually low: the first "+" goes straight to the lowest usual price (not under your average)
            price = math.max(usualLowest, entry.average or 0)
        else
            price = entry.price + stepSize(entry)
        end
    else
        price = math.max(1, entry.price - stepSize(entry))
        -- "-" stops at the lowest usual price (price check) and at your average price, and does nothing below them
        local floor = math.max(usualLowest or 0, entry.average or 0)
        if floor > 0 then
            if entry.price <= floor then
                return
            end
            price = math.max(price, floor)
        end
    end

    entry.touched = true
    entry.price = price
end

-- ===== The tooltips of the tab =====
-- One piece of information on a line, never folded onto a second line: a title in gold, then "what: value"
-- pairs (the value to the right) and short lines. They are shown only if the option of tooltips is on.
local TIP_TITLE = { 1, 0.82, 0 }
local TIP_LABEL = { 0.72, 0.72, 0.72 }
local TIP_WHITE = { 1, 1, 1 }
local TIP_GOOD = TIP_WHITE
local TIP_BAD = TIP_WHITE
local TIP_WARN = TIP_WHITE
local tip = GameTooltip

local function tipsOn()
    return not FWR.GetSellTabSettings or FWR:GetSellTabSettings().tooltips ~= false
end

-- starts a tooltip for owner; false when the tooltips are switched off
local function tipBegin(owner, anchor, title, tooltipObject)
    if not tipsOn() then
        return false
    end
    tip = tooltipObject or GameTooltip
    tip:SetOwner(owner, anchor or "ANCHOR_TOP")
    tip:AddLine(title, TIP_TITLE[1], TIP_TITLE[2], TIP_TITLE[3])
    return true
end

local function tipLine(text, color)
    color = color or TIP_LABEL
    tip:AddLine(text, color[1], color[2], color[3], false)
end

local function tipPair(label, value, color)
    color = color or TIP_WHITE
    tip:AddDoubleLine(label, value, TIP_LABEL[1], TIP_LABEL[2], TIP_LABEL[3], color[1], color[2], color[3])
end

local function tipEnd()
    tip:Show()
end

-- what the price check found, for the tooltips of Post and "+"
local function addZoneLines(entry)
    if not entry.check then
        return
    end

    local zone, usualLowest = priceZone(entry)
    if not entry.usual then
        tipPair("Price check", "not enough listings", TIP_LABEL)
    elseif zone == "low" then
        tipPair("Price check", "unusually low", TIP_BAD)
        tipPair("Lowest usual price", money(usualLowest))
        tipLine('The "+" goes there')
    elseif zone == "high" then
        tipPair("Price check", "above the usual", TIP_WARN)
    else
        tipPair("Price check", "usual price", TIP_GOOD)
    end
end

-- what "never below my average price" does to this item, for the tooltips of Post and of the name
local function addAverageLines(entry)
    if entry.average then
        tipPair("Never below", money(entry.average))
    end
end

-- Starts the post of the amount shown for an item. Returns true when the game took it, false when not.
local function postEntry(entry)
    if not entry.price or entry.quantity < 1 or entry.notCommodity then
        return false
    end

    local location = ItemLocation and ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot)
    if not location or not C_Item.DoesItemExist(location) then
        postedNote = "That item is no longer in your bags."
        refreshRows()
        return false
    end

    -- The game's own limit of one post: all of the item that is in the bags together, not one stack (the
    -- game's Sell page uses the same number as its largest amount). Never more than that is asked for.
    local quantity = entry.quantity
    local available = C_AuctionHouse.GetAvailablePostCount and C_AuctionHouse.GetAvailablePostCount(location)
    if available then
        if available < 1 then
            postedNote = "None of it can be posted now."
            refreshRows()
            return false
        end
        quantity = math.min(quantity, available)
    end

    postedNote = string.format("Posting %d x %s...", quantity, tostring(entry.name))
    local duration = entry.duration or TAB_SETTINGS.duration
    -- What the game answers is whether the post NEEDS CONFIRMATION (not whether it worked): false: the auction
    -- is made, nothing more to do; true: the game asks "are you sure?" (AUCTION_HOUSE_POST_WARNING) and the post
    -- waits for the answer. Nothing at all (nil): the game did not take the call (for example it wants a click).
    local needsConfirmation = C_AuctionHouse.PostCommodity(location, duration, quantity, entry.price)
    if needsConfirmation == nil then
        postedNote = "The Auction House did not accept this post."
        refreshRows()
        return false
    end

    if needsConfirmation == true then
        -- its window confirms the post that its own Sell page has cached; cached there, a post started from here
        -- is confirmed by it too (Auctionator does the same).
        pcall(function()
            _G.AuctionHouseFrame.CommoditiesSellFrame:CachePendingPost(location, duration, quantity, entry.price)
        end)
    end
    refreshRows()
    return true
end

-- ===== Post next =====
-- The game accepts a post only when it comes from a click (a second post started by the addon, after the
-- answer of the first, is refused: it was seen in the log). So one click posts one item: the next one that is
-- ready. The button says how many are ready; it waits while the prices of the list are still being asked.

-- an item is ready to post: shown in the list, with a price and an amount, not held back by the price check
local function postIsReady(entry)
    if entry.leftOut or entry.notCommodity or not entry.price then
        return false
    end
    if (entry.sellable or 0) < 1 or (entry.quantity or 0) < 1 then
        return false
    end
    if entry.average and entry.price < entry.average then
        return false
    end
    return priceZone(entry) ~= "low"
end

local function readyEntries()
    local list = {}
    for _, entry in ipairs(entries) do
        if postIsReady(entry) then
            list[#list + 1] = entry
        end
    end
    return list
end

-- the prices of the list are still being asked for
local function pricesLoading()
    if priceBusy or #priceQueue > 0 then
        return true
    end
    for _, entry in ipairs(entries) do
        if not entry.notCommodity and not entry.leftOut and not entry.lowest and (askedTimes[entry.itemID] or 0) < 2 then
            return true
        end
    end
    return false
end

updateAutoButton = function()
    local button = panel and panel.autoPost
    if not button then
        return
    end

    if autoPost.running then
        button:SetText("Posting...")
        button:Disable()
    elseif pricesLoading() then
        button:SetText("Loading prices...")
        button:Disable()
    else
        local count = #readyEntries()
        local wheelText = "Scroll to post next (%d)"
        if wheelActive and FWR.GetSellTabSettings and FWR:GetSellTabSettings().wheelShift then
            wheelText = "Shift + scroll to post next (%d)"
        end
        button:SetText(string.format(wheelActive and wheelText or "Post next (%d)", count))
        button:SetEnabled(count > 0 and not viewHidden)
    end
    button:SetWidth(math.max(110, math.ceil(button:GetTextWidth()) + 24))
end

local function stopAutoPost(note)
    autoPost.running = false
    autoPost.waiting = nil
    if note then
        postedNote = note
    end
    refreshRows()
end

-- the game answered (the auction is made and the bags changed): ready for the next click
local function finishOne()
    local name = autoPost.lastName or ""
    stopAutoPost(nil)
    local left = #readyEntries()
    postedNote = left > 0 and string.format("Posted %s. Click again for the next (%d left).", name, left)
        or string.format("Posted %s.", name)
    refreshRows()
end

local function startAutoPost()
    if autoPost.running or pricesLoading() then
        return
    end
    local ready = readyEntries()
    local entry = ready[1]
    if not entry then
        return
    end

    autoPost.running = true
    autoPost.waiting = "created"
    autoPost.bagChanged = false
    autoPost.since = GetTime()
    autoPost.lastName = tostring(entry.name)

    local ok, started = pcall(postEntry, entry)
    if not (ok and started) then
        stopAutoPost("The Auction House did not accept this post.")
        return
    end

    -- if the game never answers, the button does not stay on "Posting..."
    local since = autoPost.since
    C_Timer.After(10, function()
        if autoPost.running and autoPost.waiting == "created" and autoPost.since == since then
            stopAutoPost("No answer from the Auction House.")
        end
    end)
    refreshRows()
end

-- ===== The mouse wheel =====
-- With the option on, while the page is shown, the wheel (up and down) "clicks" a button of ours, like the macro
-- of TradeSkillMaster does. It is an override of the bindings, made for the time the page is shown only: it goes
-- away when the page is closed (the saved bindings of the user are not touched). Every scroll is written down:
-- what the game answered, or why nothing was done.
local WHEEL_BUTTON = "FarmWiseWheelButton"
local wheelOwner
local wheelAt = 0

local function wheelPress()
    -- a binding can send the down and the up of a click: only one is a scroll
    local now = GetTime()
    if now - wheelAt < 0.05 then
        return
    end
    wheelAt = now

    if autoPost.running then
        return
    end
    if pricesLoading() then
        return
    end
    if #readyEntries() == 0 then
        return
    end

    startAutoPost()
end

local function applyWheelBinding()
    if not wheelOwner then
        wheelOwner = CreateFrame("Frame", nil, UIParent)
        local button = CreateFrame("Button", WHEEL_BUTTON, UIParent)
        button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
        button:SetScript("OnClick", wheelPress)
    end

    if not InCombatLockdown() then
        ClearOverrideBindings(wheelOwner)
        wheelActive = false
        local wanted = FWR.GetSellTabSettings and FWR:GetSellTabSettings().wheel and panel and panel:IsShown()
            and not panel.fwHistoryShown
        if wanted then
            local prefix = FWR:GetSellTabSettings().wheelShift and "SHIFT-" or ""
            SetOverrideBindingClick(wheelOwner, true, prefix .. "MOUSEWHEELUP", WHEEL_BUTTON, "LeftButton")
            SetOverrideBindingClick(wheelOwner, true, prefix .. "MOUSEWHEELDOWN", WHEEL_BUTTON, "LeftButton")
            wheelActive = true
        end
    end
    updateAutoButton()
end

-- the game answered the post that is waited for
local function autoPostCreated()
    if not (autoPost.running and autoPost.waiting) then
        return
    end
    autoPost.waiting = "bags"
    if autoPost.bagChanged then
        finishOne()
        return
    end
    -- the bags normally change just after; if not, go on anyway
    local since = autoPost.since
    C_Timer.After(2.5, function()
        if autoPost.running and autoPost.waiting == "bags" and autoPost.since == since then
            finishOne()
        end
    end)
end

local function autoPostBagsChanged()
    if not autoPost.running then
        return
    end
    if autoPost.waiting == "bags" then
        finishOne()
    elseif autoPost.waiting == "created" then
        autoPost.bagChanged = true
    end
end

-- the game asks to confirm the post: its own window shows; Accept makes the auction, which finishes this post
local function autoPostNeedsConfirmation()
    if not (autoPost.running and autoPost.waiting) then
        return
    end
    autoPost.waiting = "confirm"
    postedNote = "The game asks to confirm this post: press Accept."
    local since = autoPost.since
    refreshRows()
    C_Timer.After(90, function()
        if autoPost.running and autoPost.waiting == "confirm" and autoPost.since == since then
            stopAutoPost("Posting stopped.")
        end
    end)
end

local function createRow(index)
    local row = CreateFrame("Frame", nil, panel.list)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", panel.list, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", panel.list, "RIGHT", 0, 0)

    -- the game's own alternating row stripes
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    local striped = pcall(function()
        stripe:SetAtlas(index % 2 == 1 and "auctionhouse-rowstripe-1" or "auctionhouse-rowstripe-2")
    end)
    if not striped then
        stripe:SetColorTexture(1, 1, 1, index % 2 == 1 and 0.04 or 0)
    end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", ICON_X, 0)

    -- the small border the game puts around the icons of its lists
    row.iconBorder = row:CreateTexture(nil, "OVERLAY")
    row.iconBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
    pcall(function()
        row.iconBorder:SetAtlas("auctionhouse-itemicon-small-border")
    end)

    row.name = row:CreateFontString(nil, "OVERLAY", "Number14FontWhite")
    row.name:SetPoint("LEFT", row, "LEFT", NAME_X, -1)

    -- the "!" that tells a filter of yours is at work on this item: the size of the name, outlined, a little after it
    row.mark = row:CreateFontString(nil, "OVERLAY")
    row.mark:SetFont((Number14FontWhite and Number14FontWhite:GetFont()) or "Fonts/ARIALN.TTF", 14, "OUTLINE")
    row.mark:SetText("!")
    row.mark:SetTextColor(1, 0.82, 0)
    row.mark:Hide()

    -- the red "!": the price is not right (against the usual price), so Post waits or the price is far from usual
    row.problem = row:CreateFontString(nil, "OVERLAY")
    row.problem:SetFont((Number14FontWhite and Number14FontWhite:GetFont()) or "Fonts/ARIALN.TTF", 14, "OUTLINE")
    row.problem:SetText("!")
    row.problem:SetTextColor(1, 0.2, 0.2)
    row.problem:Hide()
    row.name:SetWidth(NAME_WIDTH - TIER_W - TIER_GAP)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- the mark of the quality: a place of its own at the end of the item column
    row.tier = row:CreateTexture(nil, "OVERLAY")
    row.tier:SetSize(TIER_W, TIER_H)
    row.tier:SetPoint("LEFT", row, "LEFT", NAME_X + NAME_WIDTH - TIER_W, 0)
    row.tier:Hide()

    local function place(region, column, yOffset, xOffset)
        region:ClearAllPoints()
        region:SetPoint("LEFT", row, "LEFT", column.left + (xOffset or 0), yOffset or 0)
    end

    row.owned = row:CreateFontString(nil, "OVERLAY", NUMBER_FONT)
    row.owned:SetWidth(COLUMN.owned.width)
    row.owned:SetJustifyH("CENTER")
    place(row.owned, COLUMN.owned)

    -- in the list of the items that are left out the row says only why (in place of price, amount and the rest)
    row.reason = row:CreateFontString(nil, "OVERLAY", NUMBER_FONT)
    row.reason:SetPoint("LEFT", row, "LEFT", COLUMN.minus.left, 0)
    row.reason:SetWidth(COLUMN.post.left + COLUMN.post.width - COLUMN.minus.left)
    row.reason:SetJustifyH("LEFT")
    row.reason:SetWordWrap(false)
    row.reason:Hide()

    row.minus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.minus:SetMotionScriptsWhileDisabled(true)
    row.minus:SetSize(COLUMN.minus.width, ROW_HEIGHT)
    row.minus:SetText("-")
    place(row.minus, COLUMN.minus)

    -- the note in place of a price, and the three places of a price
    row.price = row:CreateFontString(nil, "OVERLAY", NUMBER_FONT)
    row.price:SetWidth(COLUMN.price.width)
    row.price:SetJustifyH("CENTER")
    place(row.price, COLUMN.price)
    row.money = createMoneySlots(row, COLUMN.price, GOLD_DIGITS_WIDTH)

    -- hovering the price tells what the Auction House asks now and what you will sell at
    row.priceHover = CreateFrame("Frame", nil, row)
    row.priceHover:SetSize(COLUMN.price.width, ROW_HEIGHT)
    place(row.priceHover, COLUMN.price)
    row.priceHover:EnableMouse(true)
    row.priceHover:SetScript("OnEnter", function(frame)
        local entry = row.entry
        if not entry or not entry.price then
            return
        end
        if not tipBegin(frame, "ANCHOR_TOP", "Price") then
            return
        end
        tipPair("Lowest now", money(entry.lowest))
        if entry.myAverage then
            tipPair(entry.average and "Your average (the lowest you post)" or "Your average", money(entry.myAverage))
        end
        tipPair("You sell at", money(entry.price), GOLD)
        tipLine(entry.average and "Right-click: back to the start price" or "Right-click: back to the lowest price")
        tipEnd()
    end)
    row.priceHover:SetScript("OnLeave", GameTooltip_Hide)
    row.priceHover:SetScript("OnMouseUp", function(_, button)
        local entry = row.entry
        if button == "RightButton" and entry and entry.lowest then
            resetPrice(entry)
            refreshRows()
            GameTooltip:Hide()
        end
    end)

    row.plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.plus:SetMotionScriptsWhileDisabled(true)
    row.plus:SetSize(COLUMN.plus.width, ROW_HEIGHT)
    row.plus:SetText("+")
    place(row.plus, COLUMN.plus)

    if COLUMN.trend then
        createTrendArrow(row)
        row.trendHover = CreateFrame("Frame", nil, row)
        row.trendHover:SetSize(COLUMN.trend.width, ROW_HEIGHT)
        place(row.trendHover, COLUMN.trend)
        row.trendHover:EnableMouse(true)
        row.trendHover:SetScript("OnEnter", function(frame)
            local entry = row.entry
            if not entry or entry.leftOut then
                return
            end
            local trend = row.trendInfo
            if not trend then
                return   -- nothing shown, nothing to explain
            end
            if not tipBegin(frame, "ANCHOR_TOP", "Trend") then
                return
            end
            local words = { up = "going up", down = "going down", flat = "steady" }
            tipPair("Price", string.format("%s  %+.0f%%", words[trend.direction], trend.change * 100))
            tipPair(string.format("Last 3 days (%d)", trend.daysNow), money(trend.now))
            tipPair(string.format("The 4 before (%d)", trend.daysBefore), money(trend.before))
            tipPair("A trend above", string.format("%.0f%%", trend.threshold * 100))
            tipEnd()
        end)
        row.trendHover:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- the value: what the whole amount brings after the 5% cut, and the deposit
    if COLUMN.value then
        row.valueMoney = createMoneySlots(row, COLUMN.value, VALUE_GOLD_WIDTH)
        row.valueNote = row:CreateFontString(nil, "OVERLAY", NUMBER_FONT)
        row.valueNote:SetJustifyH("CENTER")
        row.valueNote:SetPoint("LEFT", row, "LEFT", COLUMN.value.left, 0)
        row.valueNote:SetWidth(COLUMN.value.width)

    end

    row.quantity = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.quantity:SetSize(COLUMN.quantity.width - 5, ROW_HEIGHT)
    row.quantity:SetAutoFocus(false)
    row.quantity:SetNumeric(true)
    row.quantity:SetMaxLetters(7)
    row.quantity:SetJustifyH("CENTER")
    row.quantity:SetFontObject(NUMBER_FONT)
    place(row.quantity, COLUMN.quantity, 0, 5)

    row.post = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.post:SetMotionScriptsWhileDisabled(true)
    row.post:SetSize(COLUMN.post.width, ROW_HEIGHT)
    row.post:SetNormalFontObject("GameFontNormalSmall")
    row.post:SetHighlightFontObject("GameFontHighlightSmall")
    row.post:SetDisabledFontObject("GameFontDisableSmall")
    row.post:SetText("Post")
    place(row.post, COLUMN.post)

    row.minus:SetScript("OnClick", function()
        if row.entry then
            changePrice(row.entry, -1)
            refreshRows()
        end
    end)
    row.plus:SetScript("OnClick", function()
        if row.entry then
            changePrice(row.entry, 1)
            refreshRows()
        end
    end)
    row.quantity:SetScript("OnEnterPressed", function(box)
        if row.entry then
            setQuantity(row.entry, box:GetNumber())
        end
        box:ClearFocus()
        refreshRows()
    end)
    row.quantity:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        refreshRows()
    end)
    row.post:SetScript("OnClick", function()
        if row.entry then
            postEntry(row.entry)
        end
    end)
    row.post:SetScript("OnEnter", function(button)
        local entry = row.entry
        if not entry then
            return
        end
        if not tipBegin(button, "ANCHOR_TOP", "Post") then
            return
        end
        -- why Post is grey (when it is)
        local zoneNow = priceZone(entry)
        if entry.notCommodity then
            tipLine("Sold one piece at a time: not posted from here")
            tipEnd()
            return
        elseif not entry.price then
            tipLine("Waiting for the price...")
            tipEnd()
            return
        elseif (entry.sellable or 0) < 1 then
            tipLine("Nothing to post: all of it is kept in your bags")
        elseif (entry.quantity or 0) < 1 then
            tipLine("The amount is 0")
        elseif entry.average and entry.price < entry.average then
            tipLine("Held back: below your average price", TIP_WHITE)
        elseif zoneNow == "low" then
            tipLine("Held back: the price is unusually low", TIP_WHITE)
        end
        local hours = HOURS[entry.duration or TAB_SETTINGS.duration]
        local deposit = FWR.GetPostDeposit and FWR:GetPostDeposit(entry.itemID, entry.duration, entry.quantity)
        tipLine(string.format("%d x %s", entry.quantity, tostring(entry.name)), TIP_WHITE)
        tipPair("Price each", money(entry.price))
        tipPair("You receive (-5% cut)", money(entry.price * entry.quantity * 0.95), TIP_GOOD)
        if deposit then
            tipPair(string.format("Deposit (%d hours)", hours), money(deposit))
        else
            tipPair("Posted for", string.format("%d hours", hours))
        end
        addZoneLines(entry)
        addAverageLines(entry)
        tipEnd()
    end)
    row.post:SetScript("OnLeave", GameTooltip_Hide)

    row.plus:SetScript("OnEnter", function(button)
        local entry = row.entry
        if not entry or priceZone(entry) ~= "low" then
            return
        end
        if not tipBegin(button, "ANCHOR_TOP", "Price check") then
            return
        end
        addZoneLines(entry)
        tipEnd()
    end)
    row.plus:SetScript("OnLeave", GameTooltip_Hide)

    -- right-click: the filters of this item; the mouse over a row that a filter touches tells how
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function(_, button)
        local entry = row.entry
        if button == "RightButton" and entry and FWR.OpenSellFilterMenu then
            GameTooltip:Hide()
            FWR:OpenSellFilterMenu(row, entry)
        end
    end)
    -- the tooltip of an item: its name, what is at work on it and, always (also when the tooltips of the tab are
    -- switched off), the hint that a right-click opens its options
    local function showItemTip(frame)
        local entry = row.entry
        if not entry then
            return
        end
        local quality = FWR.GetItemQualityLabel and FWR:GetItemQualityLabel(entry.itemID)
        tip = GameTooltip
        tip:SetOwner(frame, "ANCHOR_CURSOR_RIGHT")
        tip:AddLine(tostring(entry.name) .. (quality and ("  " .. quality) or ""), TIP_TITLE[1], TIP_TITLE[2], TIP_TITLE[3])
        if tipsOn() then
            for _, reason in ipairs(entry.reasons or {}) do
                tipLine(reason, TIP_WHITE)
            end
            if (entry.keep or 0) > 0 and not entry.leftOut then
                tipPair("Keeping in your bags", tostring(entry.keep))
            end
            if entry.check then
                tipPair("Price check", "on", TIP_GOOD)
            end
            local override = FWR.GetItemDurationOverride and FWR:GetItemDurationOverride(entry.itemID)
            if override then
                tipPair("Posting time", string.format("%d hours", HOURS[override]))
            end
            if entry.problem == "low" then
                tipLine("The price is unusually low: Post waits", TIP_WHITE)
            elseif entry.problem == "high" then
                tipLine("The price is above the usual", TIP_WHITE)
            elseif entry.problem == "average" then
                tipLine("Your average is above the market now: it may wait", TIP_WHITE)
            end
        end
        tipLine("Right-click for more options", TIP_LABEL)
        tipEnd()
    end

    row:SetScript("OnEnter", function(frame)
        local entry = row.entry
        if not entry or (not entry.leftOut and not (FWR.HasSellFilter and FWR:HasSellFilter(entry.itemID))) then
            return
        end
        showItemTip(frame)
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)

    -- the part of the row with the icon and the name always has the tooltip, so everyone finds the right-click
    row.nameHover = CreateFrame("Frame", nil, row)
    row.nameHover:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.nameHover:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.nameHover:SetWidth((NAME_END or (NAME_X + NAME_WIDTH)) - 2)
    row.nameHover:EnableMouse(true)
    row.nameHover:SetScript("OnEnter", showItemTip)
    row.nameHover:SetScript("OnLeave", GameTooltip_Hide)
    row.nameHover:SetScript("OnMouseUp", function(_, button)
        local entry = row.entry
        if button == "RightButton" and entry and FWR.OpenSellFilterMenu then
            GameTooltip:Hide()
            FWR:OpenSellFilterMenu(row, entry)
        end
    end)

    return row
end

refreshRows = function()
    if not panel then
        return
    end

    local maxFirst = math.max(1, #entries - VISIBLE_ROWS + 1)
    firstRow = math.max(1, math.min(firstRow, maxFirst))

    for index = 1, VISIBLE_ROWS do
        local row = rows[index]
        local entry = entries[firstRow + index - 1]
        row.entry = entry
        if entry then
            row:Show()
            row.icon:SetTexture(entry.icon)
            -- a "!" after the name: a filter of yours (of any kind) is at work on this item
            local filtered = FWR.HasSellFilter and FWR:HasSellFilter(entry.itemID)
            -- and a red one: the price is not right against the usual price (too low: Post waits; too high)
            local problem = false
            entry.problem = nil
            if not entry.leftOut and not entry.notCommodity and entry.price then
                local zoneNow = priceZone(entry)
                if zoneNow == "low" or zoneNow == "high" then
                    problem = true
                    entry.problem = zoneNow
                elseif entry.average and entry.lowest and entry.lowest * 100 < entry.average * 85 then
                    problem = true
                    entry.problem = "average"
                end
            end
            -- the name (cut with "..." when it is long), and at the end of the column the game's own indicator
            -- of the quality (as in the game's own lists), which is always seen
            local tier = FWR.GetItemQualityTier and FWR:GetItemQualityTier(entry.itemID)
            local tierShown = false
            if tier then
                tierShown = pcall(function()
                    row.tier:SetAtlas(string.format("Professions-ChatIcon-Quality-12-Tier%d", tier))
                end)
            end
            row.tier:SetShown(tierShown)
            local marks = (filtered and 1 or 0) + (problem and 1 or 0)
            local nameRoom = NAME_WIDTH - TIER_W - TIER_GAP - marks * MARK_WIDTH
            row.name:SetWidth(nameRoom)
            row.name:SetText(tostring(entry.name))
            local ownedNeed = needWidths(entry, marks)
            row.owned:SetWidth(math.max(OWNED_WIDTH, ownedNeed))
            -- the "!" marks stand right before the quality mark (they take their room from the name)
            local markX = NAME_X + nameRoom + 2
            if filtered then
                row.mark:ClearAllPoints()
                row.mark:SetPoint("LEFT", row, "LEFT", markX, -1)
                row.mark:Show()
                markX = markX + MARK_WIDTH
            else
                row.mark:Hide()
            end
            if problem then
                row.problem:ClearAllPoints()
                row.problem:SetPoint("LEFT", row, "LEFT", markX, -1)
                row.problem:Show()
            else
                row.problem:Hide()
            end
            local r, g, b = 1, 1, 1
            if C_Item and C_Item.GetItemQualityColor then
                r, g, b = C_Item.GetItemQualityColor(entry.rarity or 1)
            end
            row.name:SetTextColor(r or 1, g or 1, b or 1)
            row.owned:SetText(tostring(entry.owned))
            if entry.leftOut then
                -- left out of the list: only why, nothing else of the row
                row.owned:Hide()
                row.minus:Hide()
                row.plus:Hide()
                row.quantity:Hide()
                row.post:Hide()
                showNote(row, "")
                if COLUMN.trend then
                    row.trendInfo = nil
                    showTrend(row, nil)
                end
                showValue(row, entry)
                row.reason:SetText(table.concat(entry.reasons or {}, ", "))
                row.reason:Show()
            else
                row.reason:Hide()
                row.owned:Show()
                row.minus:Show()
                row.plus:Show()
                row.quantity:Show()
                row.post:Show()
                if entry.notCommodity then
                    showNote(row, "single item - not here")
                elseif entry.price then
                    showMoney(row, entry.price)
                else
                    showNote(row, "...")
                end
                if not row.quantity:HasFocus() then
                    row.quantity:SetText(tostring(entry.quantity))
                end
                if COLUMN.trend then
                    row.trendInfo = FWR.GetPriceTrend and FWR:GetPriceTrend(entry.itemID) or nil
                    showTrend(row, row.trendInfo and row.trendInfo.direction or nil)
                end
                showValue(row, entry)
            end

            local usable = entry.price ~= nil and not entry.notCommodity and not entry.leftOut
            local zone = priceZone(entry)
            local belowAverage = usable and entry.average ~= nil and entry.price < entry.average
            row.post:SetEnabled(usable and entry.sellable >= 1 and entry.quantity >= 1 and zone ~= "low" and not belowAverage)

            -- "-" cannot go below the lowest usual price or your average price: it is off once the price is there
            local minusAllowed = usable
            if usable and zone then
                local _, usualLowest = priceZone(entry)
                minusAllowed = entry.price > usualLowest
            end
            if minusAllowed and entry.average then
                minusAllowed = entry.price > entry.average
            end
            row.minus:SetEnabled(minusAllowed)
            row.plus:SetEnabled(usable)

        else
            row:Hide()
        end
    end

    panel.empty:SetText(viewHidden and panel.empty.hiddenText or panel.empty.normalText)
    if #entries == 0 then
        panel.empty:Show()
    else
        panel.empty:Hide()
    end
    panel.title:SetText(viewHidden and "Items left out of the list" or "Sell from your bags")

    -- the titles and the lines between the columns: the list of the items left out has only Item and the reason
    for key, title in pairs(panel.titles) do
        if key == "item" then
            title:Show()
        elseif key == "reason" then
            title:SetShown(viewHidden)
        else
            title:SetShown(not viewHidden)
        end
    end
    for index, line in ipairs(panel.separators) do
        line:SetShown(index == 1 or not viewHidden)
    end
    if viewHidden then
        panel.status:SetText("Right-click an item to show it again or to change its filters."
            .. (#entries > VISIBLE_ROWS and "  Scroll with the mouse wheel." or ""))
    else
        panel.status:SetText(postedNote or (string.format("%d items from your bags that can be sold.", #entries)
            .. (#entries > VISIBLE_ROWS and "  Scroll with the mouse wheel." or "")))
    end

    -- the way to the items that are left out of the list (and back)
    if viewHidden then
        panel.hidden:SetText("Back to the list")
    else
        panel.hidden:SetText(string.format("Show hidden items (%d)", hiddenCount))
    end
    panel.hidden:SetWidth(panel.hidden:GetTextWidth() + 4)
    panel.hidden:SetShown(viewHidden or hiddenCount > 0)

    updateAutoButton()
end

local function buildPage(auctionHouseFrame)
    panel = CreateFrame("Frame", "FarmWiseAuctionHousePage", auctionHouseFrame)
    panel:SetFrameLevel(auctionHouseFrame:GetFrameLevel() + 5)
    panel:SetPoint("LEFT", auctionHouseFrame, "LEFT", 4, 0)
    panel:SetPoint("RIGHT", auctionHouseFrame, "RIGHT", -5, 0)
    panel:SetPoint("TOP", auctionHouseFrame, "TOP", 0, -73)
    if auctionHouseFrame.MoneyFrameBorder then
        panel:SetPoint("BOTTOM", auctionHouseFrame.MoneyFrameBorder, "TOP", 0, 2)
    else
        panel:SetPoint("BOTTOM", auctionHouseFrame, "BOTTOM", 0, 34)
    end
    panel:EnableMouseWheel(true)
    panel:Hide()

    -- the game's own background of its lists, and its own frame line
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", 3, -3)
    background:SetPoint("BOTTOMRIGHT", -3, 3)
    local ok = pcall(function()
        background:SetAtlas("auctionhouse-background-index")
    end)
    if not ok then
        background:SetColorTexture(0.12, 0.115, 0.11, 1)
    end
    pcall(function()
        local nine = CreateFrame("Frame", nil, panel, "NineSlicePanelTemplate")
        NineSliceUtil.ApplyLayoutByName(nine, "InsetFrameTemplate")
        nine:SetAllPoints()
        nine:SetFrameLevel(panel:GetFrameLevel())
    end)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", PANEL_PADDING, -10)
    panel.title:SetText("Sell from your bags")
    panel.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    -- the strip behind the column titles
    local headerStrip = panel:CreateTexture(nil, "ARTWORK")
    headerStrip:SetPoint("TOPLEFT", PANEL_PADDING, -36)
    headerStrip:SetPoint("RIGHT", panel, "RIGHT", -PANEL_PADDING, 0)
    headerStrip:SetHeight(21)
    local gradient = false
    if headerStrip.SetGradient and CreateColor then
        gradient = pcall(function()
            headerStrip:SetGradient("VERTICAL", CreateColor(0.11, 0.11, 0.105, 1), CreateColor(0.27, 0.26, 0.24, 1))
        end)
    end
    if not gradient then
        headerStrip:SetColorTexture(0.2, 0.19, 0.18, 1)
    end

    panel.headerStrip = headerStrip   -- the History page lines up with these, so its titles are at the same place
    panel.list = CreateFrame("Frame", nil, panel)
    panel.list:SetPoint("TOPLEFT", PANEL_PADDING, -58)
    panel.list:SetPoint("RIGHT", panel, "RIGHT", -PANEL_PADDING, 0)
    panel.list:SetHeight(VISIBLE_ROWS * ROW_HEIGHT)

    for index = 1, VISIBLE_ROWS do
        rows[index] = createRow(index)
    end

    local function headerText(text, anchorPoint, relativePoint, x, width, justify)
        local fontString = panel:CreateFontString(nil, "OVERLAY", TITLE_FONT)
        fontString:SetWordWrap(false)
        fontString:SetPoint(anchorPoint, headerStrip, relativePoint, x, 0)
        if width then
            fontString:SetWidth(width)
        end
        fontString:SetJustifyH(justify)
        fontString:SetText(text)
        return fontString
    end

    -- the titles of the columns of the list; the list of the items left out has only Item and the reason
    panel.titles = {
        item = headerText("Item", "LEFT", "LEFT", NAME_X, nil, "LEFT"),
        owned = headerText("In bags", "LEFT", "LEFT", COLUMN.owned.left, COLUMN.owned.width, "CENTER"),
        price = headerText("Price", "LEFT", "LEFT", COLUMN.price.left, COLUMN.price.width, "CENTER"),
    }
    if COLUMN.trend then
        panel.titles.trend = headerText("Trend", "LEFT", "LEFT", COLUMN.trend.left, COLUMN.trend.width, "CENTER")
    end
    panel.titles.quantity = headerText("Amount", "LEFT", "LEFT", COLUMN.quantity.left, COLUMN.quantity.width, "CENTER")
    if COLUMN.value then
        panel.titles.value = headerText("Value (-5% cut)", "LEFT", "LEFT", COLUMN.value.left, COLUMN.value.width, "CENTER")
    end
    panel.titles.reason = headerText("Why it is left out", "LEFT", "LEFT", COLUMN.minus.left, nil, "LEFT")
    panel.titles.reason:Hide()

    -- no vertical lines between the columns (the History page has none either): the list is only the
    -- header strip and the alternating stripes of the rows
    panel.separators = {}

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.empty:SetPoint("CENTER", panel, "CENTER", 0, 20)
    panel.empty:SetText("Nothing in your bags that can be sold here (or it is bound to you).")
    panel.empty.normalText = "Nothing in your bags that can be sold here (or it is bound to you)."
    panel.empty.hiddenText = "No items are left out of the list."

    panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.status:SetPoint("BOTTOMLEFT", PANEL_PADDING, 8)
    panel.status:SetJustifyH("LEFT")

    panel.autoPost = CreateFrame("Button", "FarmWisePostNextButton", panel, "UIPanelButtonTemplate")
    panel.autoPost:SetHeight(22)
    panel.autoPost:SetPoint("BOTTOMRIGHT", -PANEL_PADDING, 5)
    panel.autoPost:SetNormalFontObject("GameFontNormalSmall")
    panel.autoPost:SetHighlightFontObject("GameFontHighlightSmall")
    panel.autoPost:SetDisabledFontObject("GameFontDisableSmall")
    panel.autoPost:SetText("Post next (0)")
    panel.autoPost:SetScript("OnClick", startAutoPost)
    panel.autoPost:SetScript("OnEnter", function(button)
        if not tipBegin(button, "ANCHOR_TOP", "Post next") then
            return
        end
        tipLine("Posts the next ready item, with its amount and price")
        tipLine("The game needs one click for each post")
        tipLine("Items held back by the price check are skipped")
        tipEnd()
    end)
    panel.autoPost:SetScript("OnLeave", GameTooltip_Hide)

    panel.hidden = CreateFrame("Button", nil, panel)
    panel.hidden:SetHeight(14)
    panel.hidden:SetPoint("BOTTOMRIGHT", panel.autoPost, "BOTTOMLEFT", -14, 4)
    panel.hidden:SetNormalFontObject("GameFontHighlightSmall")
    panel.hidden:SetHighlightFontObject("GameFontNormalSmall")
    panel.hidden:SetText(" ")
    panel.hidden:Hide()
    panel.hidden:SetScript("OnClick", function()
        viewHidden = not viewHidden
        firstRow = 1
        rebuildEntries()
        refreshRows()
        requestAllPrices(true)
    end)
    panel.hidden:SetScript("OnEnter", function(button)
        if not tipBegin(button, "ANCHOR_TOP", viewHidden and "Back to the list" or "Hidden items") then
            return
        end
        if viewHidden then
            tipLine("Right-click an item to show it again")
        else
            tipLine("Items you hid")
            tipLine("Items you keep in your bags")
            tipLine("Items a vendor pays more for")
        end
        tipEnd()
    end)
    panel.hidden:SetScript("OnLeave", GameTooltip_Hide)

    -- refresh: read the bags again and ask for all the prices again
    panel.refresh = CreateFrame("Button", nil, panel)
    panel.refresh:SetSize(22, 22)
    panel.refresh:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -8)
    panel.refresh:SetNormalTexture("Interface/Buttons/UI-RefreshButton")
    panel.refresh:SetHighlightTexture("Interface/Buttons/UI-RefreshButton", "ADD")
    panel.refresh:SetScript("OnClick", function()
        postedNote = nil
        known = {}
        entryById = {}   -- the list is made again from nothing: nothing of what you set is carried over
        rebuildEntries()
        for _, entry in ipairs(entries) do
            entry.lowest = nil
            resetPrice(entry)
        end
        refreshRows()
        requestAllPrices()
    end)
    panel.refresh:SetScript("OnEnter", function(button)
        if not tipBegin(button, "ANCHOR_LEFT", "Refresh") then
            return
        end
        tipLine("Reads your bags again")
        tipLine("Asks the Auction House for the prices again")
        tipEnd()
    end)
    panel.refresh:SetScript("OnLeave", GameTooltip_Hide)

    panel:SetScript("OnMouseWheel", function(_, delta)
        -- with Shift held (and the wheel option on) the scroll posts, also over the list
        if wheelActive and IsShiftKeyDown() and FWR:GetSellTabSettings().wheelShift then
            wheelPress()
            return
        end
        firstRow = firstRow - delta
        refreshRows()
    end)
    -- the game shows this page (and hides the others) when our tab is chosen: this is where we fill it
    panel:SetScript("OnHide", function()
        applyWheelBinding()
    end)
    -- the list can be empty for a moment when the page opens (the game still loads what it knows of the items
    -- in the bags): it is made again a few times, until there is something or the tries are over
    local function fillAgain(triesLeft)
        if not panel or not panel:IsShown() or triesLeft < 1 then
            return
        end
        if #entries > 0 or hiddenCount > 0 then
            if not infoMissing then
                return
            end
        end
        infoMissing = false
        rebuildEntries()
        refreshRows()
        requestAllPrices(true)
        if #entries == 0 or infoMissing then
            C_Timer.After(0.7, function()
                fillAgain(triesLeft - 1)
            end)
        end
    end

    panel:SetScript("OnShow", function()
        applyWheelBinding()
        postedNote = nil
        viewHidden = false
        infoMissing = false
        rebuildEntries()
        refreshRows()
        requestAllPrices()
        if #entries == 0 or infoMissing then
            C_Timer.After(0.7, function()
                fillAgain(4)
            end)
        end
    end)
end

------------------------------------------------------------
-- The tab itself: its text and whether it can be used
------------------------------------------------------------

local function scanProgress()
    if FWR.GetAuctionScanProgress then
        return FWR:GetAuctionScanProgress()
    end
    return false, nil, 0
end

local SCAN_LABEL_WIDEST = "Scanning 99%"

-- While scanning the tab shows how far the scan is ("Scanning 37%"), in a fixed width, the one of the
-- widest text, so it does not jump around while the numbers change.
local function setTabLabel(label)
    if ourTab.fwLabel == label then
        return
    end
    ourTab.fwLabel = label
    ourTab:SetText(label)
    if label == TAB_TITLE then
        if type(ourTab.OnShow) == "function" then
            ourTab:OnShow()   -- the game's own sizing of a tab to its text
        end
        ourTab.fwNameWidth = ourTab:GetWidth()
    else
        if not ourTab.fwScanWidth then
            ourTab:SetText(SCAN_LABEL_WIDEST)
            pcall(PanelTemplates_TabResize, ourTab, 20, nil, 70)
            ourTab.fwScanWidth = ourTab:GetWidth()
            ourTab:SetText(label)
        end
        pcall(PanelTemplates_TabResize, ourTab, 20, ourTab.fwScanWidth, 70)
    end
end

local function refreshTab()
    local frame = _G.AuctionHouseFrame
    if not ourTab or type(frame) ~= "table" then
        return
    end

    local running, percent = scanProgress()
    if running then
        setTabLabel(percent and string.format("Scanning %d%%", percent) or "Scanning...")
    else
        setTabLabel(TAB_TITLE)
    end

    -- the tab you are on is never switched off under you
    local selected = panel and panel:IsShown()
    local usable = selected or not running
    if ourTab.fwUsable ~= usable then
        ourTab.fwUsable = usable
        if not selected then
            ourTab:SetEnabled(usable)
        end
    end
end

-- The option "open the FarmWise tab first". It waits while the prices are being read (or are about to be: the tab
-- cannot be used then), and opens when they are ready. Only if the game's first page is what is shown: a page the
-- game chose, for example to sell an item that was right-clicked in the bags, or one that I chose, is left alone.
local openFirstPending = false

local function tryOpenFirst()
    if not openFirstPending then
        return
    end
    local settings = FWR.GetSellTabSettings and FWR:GetSellTabSettings()
    local frame = _G.AuctionHouseFrame
    local modes = _G.AuctionHouseFrameDisplayMode
    if not (settings and settings.enabled and settings.openFirst and frame and frame:IsShown()
        and ourTab and ourTab:IsShown() and panel and not panel:IsShown()) then
        openFirstPending = false
        return
    end
    if modes and type(frame.GetDisplayMode) == "function" and frame:GetDisplayMode() ~= modes.Buy then
        openFirstPending = false
        return
    end
    if FWR.IsAuctionScanComing and FWR:IsAuctionScanComing() then
        return   -- not yet: this is called again when the scan changes
    end
    openFirstPending = false
    local onClick = ourTab:GetScript("OnClick")
    if onClick then
        pcall(onClick, ourTab)
    end
end

-- Why the tab cannot be used yet, shown when the mouse is over it.
local function showTabHint(button)
    if button.fwUsable ~= false then
        return
    end

    local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
    if not tipBegin(button, "ANCHOR_RIGHT", TAB_TITLE, tooltip) then
        return
    end

    local running, percent = scanProgress()
    if running then
        tipPair("Reading the prices", percent and string.format("%d%%", percent) or "...", TIP_WARN)
        tipLine("The tab opens when it has finished")
    end
    tipEnd()
end

------------------------------------------------------------
-- Installing: a display mode of the game, and a tab made from the game's own tab template
------------------------------------------------------------

local function install()
    -- once only: set before anything is built, so a failure half way can never build a second tab
    if installed then
        return
    end

    -- switched off in the options: nothing at all is added to the Auction House
    if FWR.GetSellTabSettings and FWR:GetSellTabSettings().enabled == false then
        return
    end

    local frame = _G.AuctionHouseFrame
    if type(frame) ~= "table" or type(frame.Tabs) ~= "table" or type(frame.SetDisplayMode) ~= "function" then
        return
    end
    installed = true

    computeLayout(frame)
    buildPage(frame)

    -- what other parts (the History page) need to know to sit on this page in the same way
    FWR.AuctionTab = {
        panel = panel,
        money = money,
        rowHeight = ROW_HEIGHT,
        visibleRows = VISIBLE_ROWS,
        padding = PANEL_PADDING,
        nameX = NAME_X,
        iconX = ICON_X,
        iconSize = ICON_SIZE,
        numberFont = NUMBER_FONT,
        titleFont = TITLE_FONT,
        applyWheel = applyWheelBinding,
    }
    FWR:Emit("auctionTabBuilt", FWR.AuctionTab)

    -- The page is a child of the Auction House window, and the tab a child of a small frame of ours that sits
    -- right of the game's tabs. NOTHING of ours is written into the game's own tables (its display modes, its
    -- list of tabs, its keys): whatever an addon writes there is marked untrusted, and the game then blocks its
    -- own protected actions (a bag item used with the right mouse button) when its code reads that mark.
    local lastTab = frame.Tabs[#frame.Tabs]
    local root = CreateFrame("Frame", nil, frame)
    root:SetSize(10, 10)
    if lastTab then
        root:SetPoint("TOPLEFT", lastTab, "TOPRIGHT")
    end

    -- made like the game's own tabs (its template), but its own parent, so that it is not put into the game's
    -- list of tabs by the template
    local tab = CreateFrame("Button", "AuctionHouseFrameFarmWiseTab", root, "AuctionHouseFrameDisplayModeTabTemplate")
    ourTab = tab
    setTabLabel(TAB_TITLE)
    tab:HookScript("OnShow", refreshTab)
    tab:HookScript("OnEnter", showTabHint)
    if lastTab then
        -- placed exactly as the game places its own tabs one after the other: the way the last one is anchored
        -- to the one before it (a measured example: TOPLEFT to TOPRIGHT, 3 pixels to the right)
        local point, _, relativePoint, x, y = lastTab:GetPoint(1)
        if point and relativePoint and point ~= "BOTTOMLEFT" then
            tab:SetPoint(point, lastTab, relativePoint, x or 3, y or 0)
        else
            tab:SetPoint("TOPLEFT", lastTab, "TOPRIGHT", 3, 0)
        end
    end
    PanelTemplates_DeselectTab(tab)
    panel:Hide()

    -- our tab chosen: the game is told to show a page with nothing in it (so it hides its own pages), the tabs
    -- of the game are drawn as not selected, and our page is shown
    tab:SetScript("OnClick", function()
        frame:SetDisplayMode({})
        frame.displayMode = nil
        for _, other in ipairs(frame.Tabs) do
            PanelTemplates_DeselectTab(other)
        end
        PanelTemplates_SelectTab(tab)
        if type(frame.SetTitle) == "function" then
            frame:SetTitle(WINDOW_TITLE)
        end
        panel:Show()
        refreshTab()
    end)

    -- A page of the game shown (the user chose one of its tabs, or the game switched by itself, for example to
    -- sell an item that was right-clicked in the bags): ours goes away. This is watched on the pages of the game
    -- themselves (a script hook on each page), not by hooking the functions of the Auction House window.
    local function pageOfTheGameShown()
        if panel and panel:IsShown() then
            panel:Hide()
        end
        PanelTemplates_DeselectTab(tab)
        refreshTab()
    end
    for _, key in ipairs({ "SearchBar", "CategoriesList", "BrowseResultsFrame", "ItemBuyFrame", "CommoditiesBuyFrame",
        "WoWTokenResults", "ItemSellFrame", "CommoditiesSellFrame", "WoWTokenSellFrame", "ItemSellList",
        "CommoditiesSellList", "AuctionsFrame" }) do
        local page = frame[key]
        if type(page) == "table" and type(page.HookScript) == "function" then
            page:HookScript("OnShow", pageOfTheGameShown)
        end
    end

    -- the filters of an item changed (in its right-click window): make the list again
    FWR:Subscribe("sellFiltersChanged", function()
        if panel and panel:IsShown() then
            rebuildEntries()
            refreshRows()
            requestAllPrices(true)
        end
    end)

    -- follow the scan and the age of the prices
    FWR:Subscribe("auctionScanChanged", function()
        refreshTab()
        tryOpenFirst()
    end)
    C_Timer.NewTicker(5, function()
        if frame:IsShown() then
            refreshTab()
        end
    end)
    refreshTab()
end

------------------------------------------------------------
-- Events: its own, so nothing outside this file needs to know about it
------------------------------------------------------------

-- The option "show the FarmWise tab" changed: the tab appears (built if it was never), or goes away and the page
-- is left for the Auction House's own first page.
FWR:Subscribe("sellTabWheelChanged", function()
    if applyWheelBinding then
        applyWheelBinding()
    end
end)

FWR:Subscribe("sellTabEnabledChanged", function()
    local enabled = not FWR.GetSellTabSettings or FWR:GetSellTabSettings().enabled ~= false
    if not installed then
        if enabled then
            pcall(install)
        end
        return
    end

    if ourTab then
        ourTab:SetShown(enabled)
    end
    if not enabled and panel and panel:IsShown() then
        local frame = _G.AuctionHouseFrame
        local modes = _G.AuctionHouseFrameDisplayMode
        if frame and frame.SetDisplayMode and modes then
            frame:SetDisplayMode(modes.Buy)
        end
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
events:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED")
events:RegisterEvent("AUCTION_HOUSE_POST_WARNING")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("AUCTION_HOUSE_POST_ERROR")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == "Blizzard_AuctionHouseUI" then
            C_Timer.After(0, function()
                pcall(install)
            end)
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        pcall(install)
        refreshTab()
        -- the option "open the FarmWise tab first": a moment later, when the game has made its own first page
        openFirstPending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0.2, tryOpenFirst)
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        openFirstPending = false
        priceQueue, priceBusy = {}, false
        known = {}
        if autoPost.running then
            stopAutoPost("Posting stopped.")
        end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        if panel and panel:IsShown() then
            priceArrived(...)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- the bindings cannot be changed in combat: done when it ends
        if panel and panel:IsShown() then
            applyWheelBinding()
        end
    elseif event == "AUCTION_HOUSE_POST_WARNING" then
        autoPostNeedsConfirmation()
    elseif event == "AUCTION_HOUSE_POST_ERROR" then
        if autoPost.running then
            stopAutoPost("The Auction House refused a post: posting stopped.")
        end
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        if autoPost.running then
            autoPostCreated()
        else
            postedNote = "Posted. The list updates when your bags do."
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if panel and panel:IsShown() then
            local itemID = ...
            local entry = entryById[tonumber(itemID)]
            if entry and C_Item and C_Item.GetItemInfo then
                local name, _, rarity = C_Item.GetItemInfo(entry.itemID)
                if name then
                    entry.name = name
                    entry.rarity = rarity or entry.rarity
                    refreshRows()
                end
            end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if panel and panel:IsShown() then
            rebuildEntries()
            refreshRows()
            requestAllPrices(true)
        end
        autoPostBagsChanged()
    end
end)
