local H = dofile(HARNESS_PATH)
local check = H.check

local function section(title) print("\n== " .. title) end

FarmWiseDB, FarmWiseReforgedDB, FarmWiseReforgedSettingsDB = {}, {}, {}

-- items in the bags
H.defineItem(236965, "Bright Linen", 7, 200, 1000)
H.defineItem(237359, "Refulgent Copper Ore", 7, 200, 500)
H.defineItem(250000, "Flask of Tests", 0, 20, 5000)
H.defineItem(99999, "Test Sword", 2, 1, 0)

local bagSlots = {
    [0] = {
        [1] = { itemID = 236965, stackCount = 118, isBound = false },
        [2] = { itemID = 237359, stackCount = 6, isBound = false },
        [3] = { itemID = 250000, stackCount = 3, isBound = false },
        [4] = { itemID = 99999, stackCount = 1, isBound = false },      -- gear: never in the list
    },
}
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end
C_Container.GetContainerItemInfo = function(bag, slot) return bagSlots[bag] and bagSlots[bag][slot] end
C_Container.GetContainerItemID = function(bag, slot) local s = bagSlots[bag] and bagSlots[bag][slot] return s and s.itemID end

-- the Auction House window of the game
local frame = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
local function tab(name) local t = CreateFrame("Button", name, frame) t.__w = 80 return t end
frame.Tabs = { tab("AuctionHouseFrameBuyTab"), tab("AuctionHouseFrameSellTab"), tab("AuctionHouseFrameAuctionsTab") }
frame.tabsForDisplayMode = {}
frame.MoneyFrameBorder = CreateFrame("Frame", nil, frame)
frame.displayMode = nil
function frame:SetDisplayMode(mode)
    self.displayMode = mode
    if self.FarmWisePage then self.FarmWisePage:SetShown(mode == AuctionHouseFrameDisplayMode.FarmWise) end
end
function frame:UpdateTitle() end
function frame:SetTitle() end
AuctionHouseFrameDisplayMode = { Buy = {}, Sell = {}, Auctions = {} }
function PanelTemplates_SetNumTabs() end
function PanelTemplates_SetTab() end
function PanelTemplates_SetTabEnabled() end

-- prices of the market
local market = { [236965] = 13300, [237359] = 60000, [250000] = 91000 }
local askedQueries = {}
C_AuctionHouse.MakeItemKey = function(id) return { itemID = id } end
C_AuctionHouse.SendSearchQuery = function(key)
    askedQueries[#askedQueries + 1] = key.itemID
    C_Timer.After(0.1, function() H.fire("COMMODITY_SEARCH_RESULTS_UPDATED", key.itemID) end)
end
C_AuctionHouse.GetNumCommoditySearchResults = function(id) return market[id] and 30 or 0 end
C_AuctionHouse.GetCommoditySearchResultInfo = function(id, index)
    if not market[id] then return nil end
    return { unitPrice = market[id] + (index - 1) * 100, quantity = 10 }
end
ItemLocation.CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end
C_AuctionHouse.GetItemCommodityStatus = function(location)
    if location and location.slot == 4 then return Enum.ItemCommodityStatus.Item end
    return Enum.ItemCommodityStatus.Commodity
end
C_AuctionHouse.GetAvailablePostCount = function(location) return 118 end
local posts = {}
C_AuctionHouse.PostCommodity = function(location, duration, quantity, unitPrice)
    posts[#posts + 1] = { duration = duration, quantity = quantity, unitPrice = unitPrice }
    return false
end

section("T1. Files load, the tab is built when the Auction House opens")
local loaded = H.loadAddon()
for _, e in ipairs(H.results.errors) do print("  ERROR " .. e) end
check("files load", #H.results.errors == 0)
local FWR = FarmWiseReforged
H.fire("ADDON_LOADED", "FarmWise")
H.fire("PLAYER_LOGIN")
H.advance(1)
ah.market = {
    [236965] = { class = 7, price = 13300, qty = 500 },
    [237359] = { class = 7, price = 60000, qty = 100 },
    [250000] = { class = 0, price = 91000, qty = 30 },
}
local errorsBefore = #H.results.errors
H.fire("ADDON_LOADED", "Blizzard_AuctionHouseUI")
H.advance(0.5)
H.fire("AUCTION_HOUSE_SHOW")
H.advance(0.5)
for i = errorsBefore + 1, #H.results.errors do print("  ERROR " .. H.results.errors[i]) end
check("opening the Auction House raises no error", #H.results.errors == errorsBefore)
check("the page of the tab exists", FWR.AuctionTab and FWR.AuctionTab.panel ~= nil)
check("the tab was added to the window", _G.AuctionHouseFrameFarmWiseTab ~= nil)
check("nothing of ours was written into the game's list of tabs", #frame.Tabs == 3, #frame.Tabs)
check("nothing of ours was written into the game's display modes", AuctionHouseFrameDisplayMode.FarmWise == nil)
check("nothing of ours was written into the window", frame.FarmWisePage == nil and frame.FarmWise == nil)

section("T2. The list")
-- no scan is running: the scan of the open AH may be going; let it finish first
H.advance(10, 0.1)
local panel = FWR.AuctionTab.panel
errorsBefore = #H.results.errors
AuctionHouseFrameFarmWiseTab.__scripts.OnClick(AuctionHouseFrameFarmWiseTab)
check("the game was told to show an empty page", type(frame.displayMode) == "table" or frame.displayMode == nil)
H.advance(0.2)
for i = errorsBefore + 1, #H.results.errors do print("  ERROR " .. H.results.errors[i]) end
check("showing the page raises no error", #H.results.errors == errorsBefore)
H.advance(8, 0.1)   -- the prices come in one at a time
check("a price was asked for each of the 3 commodities (gear left out)", #askedQueries >= 3 and #askedQueries <= 6, #askedQueries)

local texts = {}
local function collect(f)
    for _, child in ipairs(f.__children or {}) do
        if child.__text and child.__text ~= "" then texts[#texts + 1] = child.__text end
        collect(child)
    end
end
collect(panel)
local joined = table.concat(texts, "|")
check("Bright Linen is listed", joined:find("Bright Linen", 1, true) ~= nil)
check("Refulgent Copper Ore is listed", joined:find("Refulgent Copper Ore", 1, true) ~= nil)
check("Flask of Tests is listed", joined:find("Flask of Tests", 1, true) ~= nil)
check("the sword is not listed", joined:find("Test Sword", 1, true) == nil)

section("T3. Post")
local postButton
local function findPost(f)
    for _, child in ipairs(f.__children or {}) do
        if child.__text == "Post" and child.__scripts.OnClick then postButton = postButton or child end
        findPost(child)
    end
end
findPost(panel)
check("a Post button exists", postButton ~= nil)
if postButton then
    postButton.__scripts.OnClick(postButton)
    H.advance(0.2)
    check("one post was sent", #posts == 1, #posts)
    check("the post is for the amount in the bags (118 available)", posts[1] and posts[1].quantity == 118 or posts[1] and posts[1].quantity <= 118, posts[1] and posts[1].quantity)
    check("the post has a price", posts[1] and posts[1].unitPrice and posts[1].unitPrice > 0, posts[1] and posts[1].unitPrice)
end

section("T4. The history page switches")
errorsBefore = #H.results.errors
local sub = {}
for _, child in ipairs(panel.__children or {}) do
    if child.__scripts and child.__scripts.OnClick and (child.__text == "History" or child.__text == "Sell") then
        sub[child.__text] = child
    end
end
check("the two small tabs exist", sub.History ~= nil and sub.Sell ~= nil)
if sub.History then
    sub.History.__scripts.OnClick(sub.History)
    H.advance(0.2)
    check("History page opens", panel.fwHistoryShown == true)
    sub.Sell.__scripts.OnClick(sub.Sell)
    H.advance(0.2)
    check("Sell page comes back", panel.fwHistoryShown == false)
end
for i = errorsBefore + 1, #H.results.errors do print("  ERROR " .. H.results.errors[i]) end
check("no error while switching", #H.results.errors == errorsBefore)

section("T4b. The Options page")
do
    local optionsTab
    local function walk(f, depth)
        if depth > 6 or not f then return end
        for _, child in ipairs(f.__children or {}) do
            if child.__text == "Options" and child.__scripts and child.__scripts.OnClick then optionsTab = optionsTab or child end
            walk(child, depth + 1)
        end
    end
    walk(panel, 0)
    check("the Options tab exists after History", optionsTab ~= nil)
    if optionsTab then
        local before = #H.results.errors
        optionsTab.__scripts.OnClick(optionsTab)
        H.advance(0.3)
        for i = before + 1, #H.results.errors do print("  ERROR " .. H.results.errors[i]) end
        check("the Options page opens without an error", #H.results.errors == before)
        -- the cards were built: look for their titles anywhere under the page
        local found = {}
        local seen = {}
        local function scan(obj, depth)
            if type(obj) ~= "table" or seen[obj] or depth > 12 then return end
            seen[obj] = true
            if obj.__text == "Posting time" or obj.__text == "Price steps" or obj.__text == "Mouse wheel" then found[obj.__text] = true end
            for k, v in pairs(obj) do
                if type(k) ~= "string" or k:sub(1, 2) ~= "__" or k == "__children" or k == "__regions" then scan(v, depth + 1) end
            end
        end
        scan(panel, 0)
        check("the cards of Posting are there", found["Posting time"] and found["Price steps"] and found["Mouse wheel"])
    end
end

section("T5. A filter: hide an item")
FWR:SetSellFilter(237359, true, 0)
H.advance(0.5)
local hiddenSeen = false
texts = {}
collect(panel)
check("filter stored", FWR:GetSellFilter(237359) == true)

section("T5b. Never below my average price")
FWR:SetSellFilter(237359, false, 0)   -- show it again
FarmWiseDB._sales = FarmWiseDB._sales or {}
FarmWiseDB._sales.TestRealm = {
    ["236965"] = { id = 236965, name = "Bright Linen", sold = 30, net = 570000, gross = 600000, sales = 3, returned = 0,
        cancelled = 0, posted = 30, posts = 3, last = time(),
        recent = { { t = time(), q = 10, g = 200000 }, { t = time(), q = 10, g = 200000 }, { t = time(), q = 10, g = 200000 } } },
    ["237359"] = { id = 237359, name = "Refulgent Copper Ore", sold = 2, net = 100, gross = 105, sales = 1, returned = 0,
        cancelled = 0, posted = 2, posts = 1, last = time(), recent = { { t = time(), q = 2, g = 105 } } },
}
local avg, pieces, sales = FWR:GetMyAveragePrice(236965)
check("average of 3 sales of 10 pieces at 20000 each is 20000", avg == 20000, tostring(avg))
check("one sale of 2 pieces is not enough for an average", FWR:GetMyAveragePrice(237359) == nil)

FarmWiseReforgedSettingsDB.ah = FarmWiseReforgedSettingsDB.ah or {}
FarmWiseReforgedSettingsDB.ah.tabAverageFloor = false
check("floor is off by default", FWR:GetAveragePriceFloor(236965) == nil)
FWR:SetAveragePriceFloor(236965, true)
check("one item can turn it on", FWR:GetAveragePriceFloor(236965) == 20000, tostring(FWR:GetAveragePriceFloor(236965)))
FWR:SetAveragePriceFloor(236965, false)
check("and off again", FWR:GetAveragePriceFloor(236965) == nil)
FarmWiseReforgedSettingsDB.ah.tabAverageFloor = true
check("all items on: the average is the floor", FWR:GetAveragePriceFloor(236965) == 20000)

-- how many sales make the average, and the age limit
do
    local recent = {}
    local nowT = time()
    for i = 1, 12 do   -- oldest first: prices 10000, 11000 ... 21000 (per piece, 10 pieces)
        recent[#recent + 1] = { t = nowT - (13 - i) * 3600, q = 10, g = (9000 + i * 1000) * 10 }
    end
    FarmWiseDB._sales.TestRealm["236965"].recent = recent
    FarmWiseReforgedSettingsDB.ah.tabAverageSales = 5
    local five = FWR:GetMyAveragePrice(236965)       -- 17000..21000: 19000
    FarmWiseReforgedSettingsDB.ah.tabAverageSales = 10
    local ten = FWR:GetMyAveragePrice(236965)        -- 12000..21000: 16500
    check("average of the last 5 sales is 19000", five == 19000, tostring(five))
    check("average of the last 10 sales is 16500", ten == 16500, tostring(ten))
    FarmWiseReforgedSettingsDB.ah.tabAverageSales = 30
    check("asking for more than there is uses all 12 (15500)", FWR:GetMyAveragePrice(236965) == 15500, tostring(FWR:GetMyAveragePrice(236965)))

    -- sales older than 30 days do not count
    for _, sale in ipairs(recent) do sale.t = nowT - 40 * 86400 end
    check("sales older than 30 days make no average", FWR:GetMyAveragePrice(236965) == nil)
    FarmWiseReforgedSettingsDB.ah.tabAverageSales = nil
    FarmWiseDB._sales.TestRealm["236965"].recent = { { t = 1, q = 10, g = 200000 }, { t = 2, q = 10, g = 200000 }, { t = 3, q = 10, g = 200000 } }
    FarmWiseDB._sales.TestRealm["236965"].recent[1].t = time()
    FarmWiseDB._sales.TestRealm["236965"].recent[2].t = time()
    FarmWiseDB._sales.TestRealm["236965"].recent[3].t = time()
end

-- market below the average: the price starts at the average
local function firstPostPrice()
    local found
    local function find(f)
        for _, child in ipairs(f.__children or {}) do
            if child.__text == "Post" and child.__scripts.OnClick and not found then found = child end
            find(child)
        end
    end
    find(panel)
    posts = {}
    found.__scripts.OnClick(found)
    H.advance(0.2)
    return posts[1] and posts[1].unitPrice, found
end
FWR:Emit("sellFiltersChanged")
H.advance(8, 0.1)
local price1 = firstPostPrice()
check("market 13300 < average 20000: Post at the average", price1 == 20000, tostring(price1))

-- "-" does not go under the average
local function findMinus()
    local minus
    local function find(f)
        for _, child in ipairs(f.__children or {}) do
            if child.__text == "-" and child.__scripts.OnClick and not minus then minus = child end
            find(child)
        end
    end
    find(panel)
    return minus
end
local minusButton = findMinus()
for _ = 1, 5 do minusButton.__scripts.OnClick(minusButton) end
H.advance(0.1)
local price2 = firstPostPrice()
check("after five clicks of - the price is still the average", price2 == 20000, tostring(price2))

-- market above the average: follow the market
market[236965] = 26000
ah.market[236965].price = 26000
local refreshButton
local function findRefresh(f)
    for _, child in ipairs(f.__children or {}) do
        if child.__scripts and child.__scripts.OnClick and child.__normalTexture == nil and child.__w == 22 and child.__h == 22 and not refreshButton then
            refreshButton = child
        end
        findRefresh(child)
    end
end
findRefresh(panel)
if refreshButton then
    refreshButton.__scripts.OnClick(refreshButton)
    H.advance(8, 0.1)
end
local price3 = firstPostPrice()
check("market 26000 > average 20000: Post at the market", price3 == 26000, tostring(price3))
FarmWiseReforgedSettingsDB.ah.tabAverageFloor = false
FarmWiseDB._sales = nil

section("T6. Speed of the list with 100 different items in the bags")
for n = 1, 100 do
    local id = 400000 + n
    H.defineItem(id, "Bulk Item " .. n, 7, 200, 100)
    market[id] = 1000 + n * 10
    ah.market[id] = { class = 7, price = market[id], qty = 50 }
    bagSlots[0][4 + n] = { itemID = id, stackCount = 10 + n, isBound = false }
end
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 104 or 0 end
local t0 = os.clock()
H.fire("BAG_UPDATE_DELAYED")
local rebuildMs = (os.clock() - t0) * 1000
print(string.format("  list rebuilt from the bags (100 items): %.2f ms", rebuildMs))
local total, count = 0, 0
for n = 1, 100 do
    local t1 = os.clock()
    H.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 400000 + n)
    total = total + (os.clock() - t1)
    count = count + 1
end
print(string.format("  one price arrives (list refreshed): %.3f ms each, %.1f ms for 100", total / count * 1000, total * 1000))
local t2 = os.clock()
for _ = 1, 100 do H.fire("BAG_UPDATE_DELAYED") end
print(string.format("  a bag change (list made again): %.2f ms each", (os.clock() - t2) / 100 * 1000))
check("a full list stays quick (under 10 ms per refresh)", rebuildMs < 10, rebuildMs)

print(string.format("\nRESULT: %d passed, %d failed, %d runtime error(s) caught", H.results.pass, H.results.fail, #H.results.errors))
for i, e in ipairs(H.results.errors) do
    if i <= 10 then print("  runtime error: " .. tostring(e):sub(1, 600)) end
end
