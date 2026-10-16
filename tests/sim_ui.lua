-- SIMULATION of the window: opening and closing the Auction House many times, switching between the tabs of the
-- game and the FarmWise AH tab and its pages, the options, and the switch that adds the tab. After all that nothing
-- may have raised an error, and nothing may have been built again and again (frames, timers).

local H = dofile(HARNESS_PATH)
local check = H.check

local function section(title) print("\n== " .. title) end

FarmWiseDB, FarmWiseReforgedDB, FarmWiseReforgedSettingsDB = {}, {}, {}

H.defineItem(236965, "Bright Linen", 7, 200, 1000)
H.defineItem(237359, "Refulgent Copper Ore", 7, 200, 500)
H.defineItem(250000, "Flask of Tests", 0, 20, 5000)

-- the bags: three stacks
local bagSlots = {
    [0] = {
        [1] = { itemID = 236965, stackCount = 118, isBound = false },
        [2] = { itemID = 237359, stackCount = 40, isBound = false },
        [3] = { itemID = 250000, stackCount = 5, isBound = false },
    },
}
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 3 or 0 end
C_Container.GetContainerItemInfo = function(bag, slot) return bagSlots[bag] and bagSlots[bag][slot] end
C_Container.GetContainerItemID = function(bag, slot) local s = bagSlots[bag] and bagSlots[bag][slot] return s and s.itemID end

-- the window of the game, with the pages it shows for each display mode
local frame = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
local function tab(name) local t = CreateFrame("Button", name, frame) t.__w = 80 return t end
frame.Tabs = { tab("AuctionHouseFrameBuyTab"), tab("AuctionHouseFrameSellTab"), tab("AuctionHouseFrameAuctionsTab") }
frame.tabsForDisplayMode = {}
frame.MoneyFrameBorder = CreateFrame("Frame", nil, frame)
local pageNames = { "SearchBar", "CategoriesList", "BrowseResultsFrame", "ItemBuyFrame", "CommoditiesBuyFrame",
    "WoWTokenResults", "ItemSellFrame", "CommoditiesSellFrame", "WoWTokenSellFrame", "ItemSellList",
    "CommoditiesSellList", "AuctionsFrame" }
for _, name in ipairs(pageNames) do
    frame[name] = CreateFrame("Frame", nil, frame)
    frame[name]:Hide()
end
AuctionHouseFrameDisplayMode = {
    Buy = { "SearchBar", "CategoriesList", "BrowseResultsFrame" },
    Sell = { "ItemSellFrame", "ItemSellList" },
    Auctions = { "AuctionsFrame" },
}
function frame:SetDisplayMode(mode)
    self.displayMode = mode
    for _, name in ipairs(pageNames) do self[name]:Hide() end
    for _, name in ipairs(mode or {}) do self[name]:Show() end
end
function frame:GetDisplayMode() return self.displayMode end
function frame:UpdateTitle() end
function frame:SetTitle(text) self.title = text end
function PanelTemplates_SetNumTabs() end
function PanelTemplates_SetTab() end
function PanelTemplates_SetTabEnabled() end

-- prices
C_AuctionHouse.MakeItemKey = function(id) return { itemID = id } end
C_AuctionHouse.SendSearchQuery = function(key)
    C_Timer.After(0.1, function() H.fire("COMMODITY_SEARCH_RESULTS_UPDATED", key.itemID) end)
end
C_AuctionHouse.GetNumCommoditySearchResults = function() return 20 end
C_AuctionHouse.GetCommoditySearchResultInfo = function(id, index) return { unitPrice = 10000 + index * 100, quantity = 10 } end
C_AuctionHouse.GetItemCommodityStatus = function() return Enum.ItemCommodityStatus.Commodity end
C_AuctionHouse.GetAvailablePostCount = function() return 100 end
ItemLocation.CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end

section("U1. The tab is built once")
H.loadAddon()
H.fire("ADDON_LOADED", "FarmWise")
H.fire("PLAYER_LOGIN")
H.advance(1)
ah.market = {
    [236965] = { class = 7, price = 13300, qty = 500 },
    [237359] = { class = 7, price = 60000, qty = 100 },
}
H.fire("ADDON_LOADED", "Blizzard_AuctionHouseUI")
H.advance(0.5)
H.fire("AUCTION_HOUSE_SHOW")
H.advance(1)
local FWR = FarmWiseReforged
check("loading raised no error", #H.results.errors == 0, H.results.errors[1])
check("the tab exists", _G.AuctionHouseFrameFarmWiseTab ~= nil)
local panel = FWR.AuctionTab and FWR.AuctionTab.panel
check("the page exists", panel ~= nil)

local function click(button)
    if button and button.__scripts and button.__scripts.OnClick then
        button.__scripts.OnClick(button, "LeftButton")
    end
end

local function findByText(root, text, seen)
    seen = seen or {}
    if type(root) ~= "table" or seen[root] then return nil end
    seen[root] = true
    if root.__text == text and root.__scripts and root.__scripts.OnClick then return root end
    for _, child in ipairs(root.__children or {}) do
        local found = findByText(child, text, seen)
        if found then return found end
    end
end

local pageButtons = {}
for _, name in ipairs({ "Sell", "Auctions", "History", "Options" }) do
    pageButtons[name] = findByText(panel, name)
end
check("the four pages have their buttons", pageButtons.Sell and pageButtons.Auctions and pageButtons.History and pageButtons.Options)

section("U2. Opening and closing the Auction House 40 times, switching tabs and pages every time")
local framesBefore = #H.allFrames
local errorsBefore = #H.results.errors
local mem0 = collectgarbage("count")
local ourTab = _G.AuctionHouseFrameFarmWiseTab
local framesSettled
for cycle = 1, 40 do
    if cycle == 3 then framesSettled = #H.allFrames end   -- what is built on first use is built by now
    H.fire("AUCTION_HOUSE_SHOW")
    H.advance(0.3)
    click(ourTab)
    H.advance(0.2)
    check(cycle == 1 and "our page shows when its tab is chosen" or ("cycle " .. cycle .. ": our page shows"), panel:IsShown())
    for _, name in ipairs({ "Actions", "History", "Options", "Sell" }) do
        click(pageButtons[name])
        H.advance(0.1)
    end
    -- a tab of the game: ours goes away
    frame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
    H.advance(0.1)
    if cycle == 1 or not panel:IsShown() then
        -- (only the first cycle is printed, the others only count when they fail)
    end
    if panel:IsShown() then
        check("cycle " .. cycle .. ": a page of the game hides ours", false)
    end
    frame:SetDisplayMode(AuctionHouseFrameDisplayMode.Sell)
    frame:SetDisplayMode(AuctionHouseFrameDisplayMode.Auctions)
    click(ourTab)
    H.advance(0.1)
    H.fire("AUCTION_HOUSE_CLOSED")
    H.advance(0.2)
end
H.advance(5)
for _, e in ipairs(H.results.errors) do print("  ERROR " .. tostring(e):sub(1, 240)) end
check("40 cycles raised no error", #H.results.errors == errorsBefore, H.results.errors[errorsBefore + 1])
local framesAfter = #H.allFrames
check("frames are not built again at each opening (37 more cycles)", framesAfter - framesSettled == 0, framesAfter - framesSettled)

section("U3. Every option, on and off")
local settings = FWR.Settings and FWR.Settings.ah or {}
local optionsClicked = 0
local function walk(root, fn, seen)
    seen = seen or {}
    if type(root) ~= "table" or seen[root] then return end
    seen[root] = true
    fn(root)
    for _, child in ipairs(root.__children or {}) do walk(child, fn, seen) end
end
H.fire("AUCTION_HOUSE_SHOW")
click(ourTab)
click(pageButtons.Options)
H.advance(0.3)
local categoryTabs = {}
for _, name in ipairs({ "Posting", "Average price", "Sell list", "Display", "History" }) do
    categoryTabs[name] = findByText(panel, name)
end
check("the five category tabs of the options exist", categoryTabs.Posting and categoryTabs["Average price"] and categoryTabs["Sell list"]
    and categoryTabs.Display and categoryTabs.History)
errorsBefore = #H.results.errors
for _, name in ipairs({ "Posting", "Average price", "Sell list", "Display", "History" }) do
    click(categoryTabs[name])
    H.advance(0.1)
    -- every check button of the page is clicked twice (on, off)
    local category
    walk(panel, function(object)
        if object.__kind == "CheckButton" and object.__scripts.OnClick and object.__shown then
            local parentShown = true
            local p = object.__parent
            while p do
                if p.__shown == false then parentShown = false break end
                p = p.__parent
            end
            if parentShown then
                for _ = 1, 2 do
                    object.__checked = not object.__checked
                    object.__scripts.OnClick(object)
                    optionsClicked = optionsClicked + 1
                end
            end
        end
    end)
    H.advance(0.2)
end
check("the options were clicked", optionsClicked > 8, optionsClicked)
check("clicking every option raised no error", #H.results.errors == errorsBefore, H.results.errors[errorsBefore + 1])
click(pageButtons.Sell)
H.advance(0.5)
check("the Sell page works after the options changed", #H.results.errors == errorsBefore, H.results.errors[errorsBefore + 1])

section("U4. The switch that adds the tab, off and on")
errorsBefore = #H.results.errors
FWR.Settings.ah.tabEnabled = false
FWR:Emit("sellTabEnabledChanged")
H.advance(0.3)
check("switched off: the tab is hidden", ourTab:IsShown() == false)
FWR.Settings.ah.tabEnabled = true
FWR:Emit("sellTabEnabledChanged")
H.advance(0.3)
check("switched on: the tab is back", ourTab:IsShown() == true)
check("switching raised no error", #H.results.errors == errorsBefore, H.results.errors[errorsBefore + 1])

section("U5. The history switched off: the Options page stays reachable")
FWR.Settings.ah.tabHistory = false
FWR:Emit("sellTabHistoryChanged")
H.advance(0.2)
H.fire("AUCTION_HOUSE_SHOW")
click(ourTab)
H.advance(0.2)
check("the Options button is still shown", pageButtons.Options.__shown ~= false)
check("the History button is hidden", pageButtons.History.__shown == false)
FWR.Settings.ah.tabHistory = true
FWR:Emit("sellTabHistoryChanged")
H.advance(0.2)

section("U6. Memory and timers after all of it")
collectgarbage("collect")
local mem1 = collectgarbage("count")
check("memory did not grow by more than 8 MB", (mem1 - mem0) / 1024 < 8, string.format("%.1f MB", (mem1 - mem0) / 1024))
