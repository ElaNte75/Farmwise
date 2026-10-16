local H = dofile(HARNESS_PATH)
local FWR

local function bench(label, iterations, fn)
    collectgarbage("collect")
    local memBefore = collectgarbage("count")
    local start = os.clock()
    for _ = 1, iterations do fn() end
    local elapsed = os.clock() - start
    local memAfter = collectgarbage("count")
    print(string.format("  %-58s %8.3f ms/call   (%d calls, %+.0f KB)", label, elapsed / iterations * 1000, iterations, memAfter - memBefore))
    return elapsed / iterations
end

FarmWiseDB, FarmWiseReforgedDB, FarmWiseReforgedSettingsDB = {}, {}, {}
H.loadAddon()
for _, e in ipairs(H.results.errors) do print("LOAD ERROR", e) end
FWR = FarmWiseReforged
H.fire("ADDON_LOADED", "FarmWise")
H.fire("PLAYER_LOGIN")
H.advance(1)

print("\n== The frame loop (runs all the time)")
local mainUpdate, blinkerUpdate
for _, frame in ipairs(H.allFrames) do
    local f = frame.__scripts.OnUpdate
    if f then
        if not mainUpdate then mainUpdate = { frame, f } else blinkerUpdate = { frame, f } end
    end
end
local perCallMain = bench("main OnUpdate (called every frame, works every 0.2 s)", 20000, function() mainUpdate[2](mainUpdate[1], 0.016) end)
print(string.format("     -> at 60 fps: %.3f ms per second of game time", perCallMain * 1000 * 60))
local workPerCall = bench("main OnUpdate, the call that does the work", 2000, function() mainUpdate[2](mainUpdate[1], 0.25) end)
print(string.format("     -> 5 calls a second: %.3f ms per second", workPerCall * 1000 * 5))

print("\n== A big amount of saved data (60 zones x 120 items)")
local zoneIndex = 0
function GetZoneText() return "Zone " .. zoneIndex end
function GetRealZoneText() return "Zone " .. zoneIndex end
function GetSubZoneText() return "Sub " .. (zoneIndex % 3) end
for i = 1, 120 do
    H.defineItem(300000 + i, "Item " .. i, 7, 200, 100 * i)
end
local fill = os.clock()
for z = 1, 60 do
    zoneIndex = z
    for i = 1, 120 do
        FWR:RecordAdvisorItem({ itemID = 300000 + i, itemName = "Item " .. i, itemQuality = 1, expansionID = 10, baseProfession = "Herbalism" }, 3)
    end
    FWR:RecordAdvisorTime(1800)
    FWR:RecordAdvisorGold(500000)
end
print(string.format("  filling the store: %.0f ms for %d records", (os.clock() - fill) * 1000, 60 * 120))

-- prices for all of them
FarmWiseDB._ah = { items = {}, lastSyncTime = time(), lastSyncCount = 120 }
for i = 1, 120 do
    FarmWiseDB._ah.items[tostring(300000 + i)] = { itemID = 300000 + i, unitPrice = 1000 * i, lastSeen = time() }
end
bench("BuildAdvisorGoldResults (places ranked by gold)", 20, function() FWR:BuildAdvisorGoldResults() end)
bench("BuildAdvisorItemOverview", 20, function() FWR:BuildAdvisorItemOverview(true) end)
bench("BuildAdvisorItemResults for one item", 50, function() FWR:BuildAdvisorItemResults("Item 5") end)
bench("GetFarmedItemIDs (rebuilt, age 0)", 20, function() FWR:GetFarmedItemIDs(0) end)
bench("GetFarmedItemIDs (cached)", 20000, function() FWR:GetFarmedItemIDs() end)
bench("GetAuctionPrice (tooltip path)", 20000, function() FWR:GetAuctionPrice(300050) end)
bench("GetVendorBetterInfo (tooltip path)", 20000, function() FWR:GetVendorBetterInfo(300050) end)

print("\n== The main window")
for _, name in ipairs({ "RefreshDisplayText", "RefreshMainWindowText", "RefreshDisplayLiveMetrics" }) do
    if FWR[name] then
        bench(name, 20, function() pcall(FWR[name], FWR, name == "RefreshDisplayLiveMetrics" and true or nil) end)
    end
end

print("\n== Loot events")
local link = "|cff1eff00|Hitem:300005:::::::::::::::|h[Item 5]|h|r"
bench("CHAT_MSG_LOOT event", 2000, function() H.fire("CHAT_MSG_LOOT", "You receive loot: " .. link .. ".", "", "", "", "Tester") end)

print("\n== Price history of a whole-Auction-House scan (60000 items)")
local scanItems = {}
for i = 1, 60000 do scanItems[tostring(i)] = { itemID = i, unitPrice = 1000 + i % 977, lastSeen = time() } end
bench("RecordPriceHistory for 60000 priced items", 3, function() FWR:RecordPriceHistory(scanItems, time()) end)

print("\n== Sales history: a mailbox of 50 mails taken with Open All")
inbox = {}
for i = 1, 50 do
    inbox[#inbox + 1] = { subject = "Auction successful: Item " .. i, money = 10000 + i, daysLeft = 30,
        invoice = { type = "seller", name = "Item " .. i, bid = 11000, buyout = 5, deposit = 100, cut = 550, count = 5 } }
end
H.fire("MAIL_SHOW")
H.advance(0.5)
local hookTime, hookCalls, timerTime = 0, 0, 0
-- the time of the addon's own timers (the looks at the mailbox)
local origAfter = C_Timer.After
C_Timer.After = function(delay, fn)
    origAfter(delay, function(...)
        local t = os.clock()
        fn(...)
        timerTime = timerTime + (os.clock() - t)
    end)
end
local rounds = 0
while #inbox > 0 and rounds < 400 do
    rounds = rounds + 1
    for i = 1, #inbox do
        local t = os.clock()
        AutoLootMailItem(i)
        hookTime = hookTime + (os.clock() - t)
        hookCalls = hookCalls + 1
    end
    H.advance(0.15)
end
H.advance(1)
print(string.format("  Open All, 50 mails: %d take calls took %.1f ms in total (%.3f ms each)", hookCalls, hookTime * 1000, hookTime / hookCalls * 1000))
print(string.format("  the looks at the mailbox: %.1f ms in total", timerTime * 1000))
print(string.format("  mails left: %d, rounds: %d", #inbox, rounds))

print("\n== Memory of the addon (Lua tables)")
collectgarbage("collect")
print(string.format("  everything in this test: %.1f MB", collectgarbage("count") / 1024))
