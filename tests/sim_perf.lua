-- SPEED and MEMORY of the whole addon (not only the Auction House tab): the loop that runs every frame, the
-- main window, the Advisor with a lot of saved data, loot events, the tooltips, a mailbox of 50 mails, the
-- Actions page with hundreds of posts, a scan of a whole Auction House, and the memory after all of it.
-- Each measure has a limit: a change that makes the addon much slower fails here.
-- (The limits are generous: this runs on a modern Lua, the game's is slower, so they are for catching a
-- change of an order of magnitude, not for exact numbers.)

local H = dofile(HARNESS_PATH)
local check = H.check

local function section(title) print("\n== " .. title) end

local function bench(label, iterations, limitMs, fn)
    collectgarbage("collect")
    local start = os.clock()
    for _ = 1, iterations do fn() end
    local perCall = (os.clock() - start) / iterations * 1000
    print(string.format("  %-60s %9.4f ms/call", label, perCall))
    check(string.format("%s is under %.2f ms", label, limitMs), perCall <= limitMs, string.format("%.4f ms", perCall))
    return perCall
end

FarmWiseDB, FarmWiseReforgedDB, FarmWiseReforgedSettingsDB = {}, {}, {}
H.loadAddon()
H.fire("ADDON_LOADED", "FarmWise")
H.fire("PLAYER_LOGIN")
H.advance(1)
local FWR = FarmWiseReforged
check("the addon loads without errors", #H.results.errors == 0, H.results.errors[1])

section("P1. The loop that runs at every frame")
local updates = {}
for _, frame in ipairs(H.allFrames) do
    local f = frame.__scripts.OnUpdate
    if f then updates[#updates + 1] = { frame, f } end
end
check("there are few OnUpdate loops (each one costs at every frame)", #updates <= 4, #updates)
for index, pair in ipairs(updates) do
    bench("OnUpdate " .. index .. " (a frame of 16 ms)", 20000, 0.05, function() pair[2](pair[1], 0.016) end)
end

section("P2. Saved data: 60 zones x 120 items, the Advisor")
local zoneIndex = 0
function GetZoneText() return "Zone " .. zoneIndex end
function GetRealZoneText() return "Zone " .. zoneIndex end
function GetSubZoneText() return "Sub " .. (zoneIndex % 3) end
for i = 1, 120 do H.defineItem(300000 + i, "Item " .. i, 7, 200, 100 * i) end
local fillStart = os.clock()
for z = 1, 60 do
    zoneIndex = z
    for i = 1, 120 do
        FWR:RecordAdvisorItem({ itemID = 300000 + i, itemName = "Item " .. i, itemQuality = 1, expansionID = 10, baseProfession = "Herbalism" }, 3)
    end
    FWR:RecordAdvisorTime(1800)
    FWR:RecordAdvisorGold(500000)
end
check("filling 7200 records takes under 3 s", os.clock() - fillStart < 3, string.format("%.2f s", os.clock() - fillStart))
FarmWiseDB._ah = { items = {}, lastSyncTime = time(), lastSyncCount = 120 }
for i = 1, 120 do
    FarmWiseDB._ah.items[tostring(300000 + i)] = { itemID = 300000 + i, unitPrice = 1000 * i, lastSeen = time() }
end
bench("the Advisor: places ranked by gold", 10, 400, function() FWR:BuildAdvisorGoldResults() end)
bench("the Advisor: overview of the items", 10, 400, function() FWR:BuildAdvisorItemOverview(true) end)
bench("the Advisor: one item", 30, 150, function() FWR:BuildAdvisorItemResults("Item 5") end)
bench("farmed items (cached)", 20000, 0.2, function() FWR:GetFarmedItemIDs() end)
bench("price of an item (the tooltip path)", 20000, 0.1, function() FWR:GetAuctionPrice(300050) end)

section("P3. Loot events")
local link = "|cff1eff00|Hitem:300005:::::::::::::::|h[Item 5]|h|r"
bench("a loot message in the chat", 2000, 1.5, function() H.fire("CHAT_MSG_LOOT", "You receive loot: " .. link .. ".", "", "", "", "Tester") end)

section("P4. A scan of a whole Auction House (60000 items)")
local scanItems = {}
for i = 1, 60000 do scanItems[tostring(i)] = { itemID = i, unitPrice = 1000 + i % 977, lastSeen = time() } end
bench("the price history of 60000 items", 3, 2500, function() FWR:RecordPriceHistory(scanItems, time()) end)

section("P5. The Actions page with 600 posts (many days at the Auction House)")
FarmWiseDB._actions = {}
local owner = "Tester-TestRealm"
local list = {}
for i = 1, 600 do
    list[i] = { id = 1000 + i, itemID = 300000 + (i % 120) + 1, qty = i % 40 + 1, unit = 1000 + i, state = (i % 5 == 0) and "active" or "sold",
        since = time() - i * 60, expires = time() + 3600, seen = 1 }
end
FarmWiseDB._actions[owner] = list
bench("the rows of the Actions page (600 posts)", 50, 40, function() FWR:GetActionRows() end)
C_AuctionHouse.GetNumOwnedAuctions = function() return 0 end
bench("a refresh of the list of the game (nothing listed)", 50, 80, function() H.fire("OWNED_AUCTIONS_UPDATED") end)

section("P6. A mailbox of 50 sales taken with Open All")
inbox = {}
for i = 1, 50 do
    inbox[#inbox + 1] = { subject = "Auction successful: Item " .. i, money = 10000 + i, daysLeft = 30,
        invoice = { type = "seller", name = "Item " .. i, bid = 11000, buyout = 5, deposit = 100, cut = 550, count = 5 } }
end
H.fire("MAIL_SHOW")
H.advance(0.5)
local hookTime, rounds = 0, 0
while #inbox > 0 and rounds < 400 do
    rounds = rounds + 1
    for i = 1, #inbox do
        local t = os.clock()
        AutoLootMailItem(i)
        hookTime = hookTime + (os.clock() - t)
    end
    H.advance(0.15)
end
H.advance(1)
check("50 mails taken: all gone", #inbox == 0, #inbox)
check("the take calls cost under 250 ms in total", hookTime * 1000 < 250, string.format("%.1f ms", hookTime * 1000))
local sold = 0
for _, row in ipairs(FWR:GetSalesHistoryRows()) do sold = sold + row.sold end
check("all 50 sales (250 pieces) are in the history", sold == 250, sold)

section("P7. Memory")
collectgarbage("collect")
local mb = collectgarbage("count") / 1024
print(string.format("  everything of this test (Lua tables): %.1f MB", mb))
check("under 120 MB with 7200 advisor records, 60000 prices, 600 posts", mb < 120, string.format("%.1f MB", mb))
check("no error in the whole run", #H.results.errors == 0, H.results.errors[1])
