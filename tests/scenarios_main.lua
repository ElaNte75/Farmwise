local H = dofile(HARNESS_PATH)
local check = H.check
local FWR

local function section(title) print("\n== " .. title) end

------------------------------------------------------------
section("1. Loading the files of the addon")
FarmWiseDB = {}
FarmWiseReforgedDB = {}
FarmWiseReforgedSettingsDB = {}
H.defineItem(236965, "Bright Linen", 7, 200, 1000)
H.defineItem(236963, "Bright Linen", 7, 200, 1000)
H.defineItem(242639, "Practically Pork", 7, 200, 100)
H.defineItem(275280, "Gamey Flank", 7, 200, 100)
H.defineItem(237359, "Refulgent Copper Ore", 7, 200, 500)
H.defineItem(236761, "Tranquility Bloom", 7, 200, 500)
H.defineItem(250000, "Flask of Tests", 0, 20, 5000)
H.defineItem(260000, "Potion of Tests", 0, 20, 5000)

local loaded = H.loadAddon()
print("  files loaded: " .. loaded)
for _, e in ipairs(H.results.errors) do print("  ERROR " .. e) end
check("every file of the toc loads without an error", #H.results.errors == 0, #H.results.errors .. " error(s)")
FWR = FarmWiseReforged
check("the addon table exists", type(FWR) == "table")

section("2. Starting up (ADDON_LOADED, PLAYER_LOGIN)")
local before = #H.results.errors
H.fire("ADDON_LOADED", "FarmWise")
H.fire("PLAYER_LOGIN")
H.advance(2)
for i = before + 1, #H.results.errors do print("  ERROR " .. H.results.errors[i]) end
check("startup runs without errors", #H.results.errors == before)
check("settings have their defaults (tabHistory on)", FWR.Settings and FWR.Settings.ah and FWR.Settings.ah.tabHistory == true)
check("scanCommodities is on by default", FWR.Settings.ah.scanCommodities == true)

section("3. Sales history: the mail of a real Open All (trace of the user)")
local function resetHistory()
    FWR:ClearSalesHistory()
    inbox = {}
    FWR:Emit("noop")
end
local function sale(name, count, gross, cut, id)
    return { subject = "Auction successful: " .. name, money = gross - cut + 100, daysLeft = 30,
        invoice = { type = "seller", name = name, bid = gross, buyout = count, deposit = 100, cut = cut, count = count } }
end
local function rows()
    local out = {}
    for _, r in ipairs(FWR:GetSalesHistoryRows()) do out[r.key] = r end
    return out
end
local function post(itemID, qty, unit)
    C_Item.GetItemID = function() return itemID end
    C_AuctionHouse.PostCommodity({}, 1, qty, unit)
    H.fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
end
local function openAll(seconds)
    local elapsed = 0
    while elapsed < seconds do
        for i = 1, #inbox do AutoLootMailItem(i) end
        H.advance(0.15)
        elapsed = elapsed + 0.15
    end
    H.advance(1)
end

resetHistory()
post(236965, 21, 13300)
post(236963, 18, 9800)
inbox = {
    sale("Bright Linen", 21, 279300, 13965),
    sale("Practically Pork", 3, 29100, 1455),
    sale("Bright Linen", 18, 176400, 8820),
    sale("Gamey Flank", 1, 29100, 1455),
}
FWR:Emit("noop")
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(3)
local r = rows()
check("Bright Linen (the 21 posted at 13300) sold 21", r["236965"] and r["236965"].sold == 21, r["236965"] and r["236965"].sold)
check("Bright Linen (quality 2) sold 18 and kept apart", r["236963"] and r["236963"].sold == 18, r["236963"] and r["236963"].sold)
check("Practically Pork sold 3 (not 9)", r["242639"] and r["242639"].sold == 3, r["242639"] and r["242639"].sold)
check("Gamey Flank sold 1 (not 2)", r["275280"] and r["275280"].sold == 1, r["275280"] and r["275280"].sold)
check("net of Bright Linen = gross - cut", r["236965"] and r["236965"].net == 279300 - 13965, r["236965"] and r["236965"].net)
check("one sale line each", r["236965"] and r["236965"].sales == 1 and r["242639"].sales == 1)
check("the mailbox is empty at the end", #inbox == 0, #inbox)

section("4. Sales history: two equal sales are two sales")
resetHistory()
post(236965, 10, 13300)
inbox = { sale("Bright Linen", 10, 133000, 6650), sale("Bright Linen", 10, 133000, 6650) }
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(3)
r = rows()
check("two equal mails: sold 20", r["236965"] and r["236965"].sold == 20, r["236965"] and r["236965"].sold)
check("two sales", r["236965"] and r["236965"].sales == 2, r["236965"] and r["236965"].sales)

section("5. Sales history: taken before the first look (a mail addon is faster)")
resetHistory()
post(242639, 3, 9700)
inbox = { sale("Practically Pork", 3, 29100, 1455) }
H.fire("MAIL_SHOW")
AutoLootMailItem(1)      -- the same instant, before any look
AutoLootMailItem(1)
H.advance(2)
r = rows()
check("taken at once: sold 3, counted once", r["242639"] and r["242639"].sold == 3 and r["242639"].sales == 1, r["242639"] and (r["242639"].sold .. "/" .. r["242639"].sales))

section("6. Sales history: a take that fails is not counted")
resetHistory()
post(242639, 3, 9700)
local blocked = sale("Practically Pork", 3, 29100, 1455)
blocked.blockTake = true
inbox = { blocked }
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(1.5)
r = rows()
check("nothing counted while the mail is still there", not r["242639"] or r["242639"].sold == 0, r["242639"] and r["242639"].sold)
blocked.blockTake = false
openAll(1.5)
r = rows()
check("counted once when it is finally taken", r["242639"] and r["242639"].sold == 3, r["242639"] and r["242639"].sold)

section("7. Sales history: expired auction (returned) and the success rate")
resetHistory()
post(236965, 200, 13300)
inbox = {
    sale("Bright Linen", 80, 1064000, 53200),
    { subject = "Auction expired: Bright Linen", money = 0, daysLeft = 30, items = { { name = "Bright Linen", id = 236965, count = 120 } } },
}
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(3)
r = rows()
check("sold 80", r["236965"] and r["236965"].sold == 80, r["236965"] and r["236965"].sold)
check("returned 120", r["236965"] and r["236965"].returned == 120, r["236965"] and r["236965"].returned)
check("success 40%", r["236965"] and math.abs((r["236965"].rate or 0) - 0.4) < 1e-9, r["236965"] and r["236965"].rate)
check("average price of one = net / sold", r["236965"] and math.abs(r["236965"].average - (1064000 - 53200) / 80) < 1e-6)

section("8. Sales history: open the mailbox, close it, open it again")
resetHistory()
post(242639, 6, 9700)
inbox = { sale("Practically Pork", 3, 29100, 1455), sale("Practically Pork", 3, 29100, 1455) }
H.fire("MAIL_SHOW")
H.advance(0.5)
AutoLootMailItem(1)
H.advance(1)
H.fire("MAIL_CLOSED")
H.advance(0.5)
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(2)
r = rows()
check("two mails over two visits: sold 6, two sales", r["242639"] and r["242639"].sold == 6 and r["242639"].sales == 2, r["242639"] and (r["242639"].sold .. "/" .. r["242639"].sales))

section("9. Sales history: switched off records nothing")
resetHistory()
FWR.Settings.ah.tabHistory = false
inbox = { sale("Practically Pork", 3, 29100, 1455) }
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(2)
r = rows()
check("nothing recorded while it is off", next(r) == nil)
FWR.Settings.ah.tabHistory = true

section("9b. Mails that are not sales of ours are not counted")
resetHistory()
inbox = {
    -- a purchase (Auction won): an invoice of the buyer
    { subject = "Auction won: Bright Linen (21)", money = 0, items = { { name = "Bright Linen", id = 236965, count = 21 } },
      invoice = { type = "buyer", name = "Bright Linen", bid = 279300, buyout = 21, deposit = 0, cut = 0, count = 21 } },
    -- gold from another player, with a subject that pretends to be a sale
    { sender = "Somebody", canReply = true, subject = "Auction successful: Bright Linen", money = 500000 },
    -- an item from another player with a subject that pretends to be an expired auction
    { sender = "Somebody", canReply = true, subject = "Auction expired: Bright Linen", money = 0,
      items = { { name = "Bright Linen", id = 236965, count = 50 } } },
    -- gold only
    { sender = "A friend", canReply = true, subject = "Here is your gold", money = 100000 },
    -- an item that was posted by someone else and outbid (gold back)
    { subject = "Outbid on Bright Linen", money = 90000 },
}
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(3)
r = rows()
check("purchases, gifts and gold transfers are not sales", next(r) == nil)

section("10. Auction House scan: the levels")
ah.market = {
    [236965] = { class = 7, price = 13300, qty = 500 },
    [237359] = { class = 7, price = 50000, qty = 100 },
    [250000] = { class = 0, price = 90000, qty = 30 },
    [260000] = { class = 0, price = 20000, qty = 30 },
}
FarmWiseDB._ah = nil
FWR.Settings.ah.scanCommodities = true
FWR.Settings.ah.fullScan = false
ah.queries = {}
H.fire("AUCTION_HOUSE_SHOW")
H.advance(20, 0.1)
local store = FWR:GetAuctionDataStore()
local count = 0
for _ in pairs(store.items) do count = count + 1 end
check("commodities level: trade goods and consumables are priced", count == 4, count)
check("one query for each class", #ah.queries == 5, #ah.queries)
check("the level is remembered", store.lastScanLevel == "commodities", store.lastScanLevel)
check("the scan is not running any more", not FWR:IsAuctionScanRunning())

FWR.Settings.ah.scanCommodities = false
check("a different level is allowed to scan at once", FWR:GetAuctionScanCooldownSeconds() == 0)
FarmWiseDB._ah = nil
ah.queries = {}
H.fire("AUCTION_HOUSE_CLOSED")
H.fire("AUCTION_HOUSE_SHOW")
H.advance(20, 0.1)
store = FWR:GetAuctionDataStore()
count = 0
for _ in pairs(store.items) do count = count + 1 end
check("trade level: only trade goods", count == 2, count)
check("trade level: one query", #ah.queries == 1, #ah.queries)

section("11. Prices: usual price, zones")
local listings = {}
for i = 1, 30 do listings[#listings + 1] = { price = 1000 + i * 10, quantity = 10 } end
-- a few listings at a silly low price must not move the usual price
table.insert(listings, 1, { price = 100, quantity = 2 })
local usual = FWR:GetUsualPrice(listings)
check("usual price is found", type(usual) == "number", tostring(usual))
check("a bait listing does not drag it down", usual and usual > 1000, tostring(usual))
check("low zone below 85%", FWR:GetPriceZone(usual * 0.5, usual) == "low")
check("normal zone", FWR:GetPriceZone(usual * 1.0, usual) == "normal")
check("high zone above 125%", FWR:GetPriceZone(usual * 1.5, usual) == "high")
check("too few listings gives no usual price", FWR:GetUsualPrice({ { price = 5, quantity = 1 } }) == nil)

section("12. Trend")
FarmWiseDB._priceHistory = nil
local today = math.floor(time() / 86400)
FarmWiseDB._priceHistory = { TestRealm = { ["236965"] = {} } }
for ago = 0, 6 do
    local value = ago <= 2 and 1300 or 1000
    FarmWiseDB._priceHistory.TestRealm["236965"][today - ago] = { value, value, value, 1, { value } }
end
local trend = FWR:GetPriceTrend(236965)
check("trend goes up when the last days are higher", trend and trend.direction == "up", trend and trend.direction)

section("13. Vendor comparison")
FarmWiseDB._ah = { items = { ["242639"] = { itemID = 242639, unitPrice = 90 } } }
FWR.Settings.ah.scanCommodities = true
check("vendor 100 > AH 90 after the cut", FWR:IsSoldBetterToVendor(242639) == true)
FarmWiseDB._ah = { items = { ["242639"] = { itemID = 242639, unitPrice = 5000 } } }
check("AH 5000 beats the vendor", FWR:IsSoldBetterToVendor(242639) == false)

section("14. Options window builds")
local errorsBefore = #H.results.errors
local ok, err = pcall(function() FWR:OpenControlPanelWindow() end)
check("the control panel opens", ok, err)
H.advance(1)
for i = errorsBefore + 1, #H.results.errors do print("  ERROR " .. H.results.errors[i]) end
check("no errors while it builds", #H.results.errors == errorsBefore)

section("15. Slash commands")
for _, command in ipairs({ "status", "advisor", "scan", "ui", "options" }) do
    local okCommand, errCommand = pcall(SlashCmdList.FARMWISEREFORGED, command)
    check("/fw " .. command, okCommand, errCommand)
end

section("16. Scan with many batches: the Advisor is not rebuilt for each one")
local refreshes = 0
local originalRefresh = FWR.RefreshAdvisorPanel
FWR.RefreshAdvisorPanel = function(self) refreshes = refreshes + 1 end
local batches = 0
C_AuctionHouse.HasFullBrowseResults = function() return batches >= 40 end
C_AuctionHouse.RequestMoreBrowseResults = function()
    batches = batches + 1
    C_Timer.After(0.05, function() H.fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED") end)
end
FWR.Settings.ah.scanCommodities = false
FWR.Settings.ah.fullScan = false
FarmWiseDB._ah = nil
H.fire("AUCTION_HOUSE_CLOSED")
H.fire("AUCTION_HOUSE_SHOW")
H.advance(30, 0.05)
check("the scan went through its 40 batches", batches >= 40, batches)
check("the Advisor was refreshed a few times only (not 40+)", refreshes > 0 and refreshes <= 8, refreshes)
FWR.RefreshAdvisorPanel = originalRefresh

section("17. The price step option")
FarmWiseReforgedSettingsDB.ah = FarmWiseReforgedSettingsDB.ah or {}
FarmWiseReforgedSettingsDB.ah.tabPriceStep = 3
check("step 3 is read", FWR:GetSellTabSettings().priceStep == 3)
FarmWiseReforgedSettingsDB.ah.tabPriceStep = 99
check("a step above 20 becomes 20", FWR:GetSellTabSettings().priceStep == 20)
FarmWiseReforgedSettingsDB.ah.tabPriceStep = 0
check("a step of 0 becomes 1", FWR:GetSellTabSettings().priceStep == 1)
FarmWiseReforgedSettingsDB.ah.tabPriceStep = nil
check("nothing set is 5", FWR:GetSellTabSettings().priceStep == 5)

section("Areas: the sub-zone is left out inside a dungeon, a delve, a raid, a battleground")
local realInInstance = IsInInstance
IsInInstance = nil
check("open world (no answer from the game): the sub-zone is used", FWR:GetAreaSubZoneText() == "The Waking Shores")
IsInInstance = function() return false, "none" end
check("open world: the sub-zone is used", FWR:GetAreaSubZoneText() == "The Waking Shores")
for _, kind in ipairs({ "party", "raid", "scenario", "pvp", "arena" }) do
    IsInInstance = function() return true, kind end
    check("inside '" .. kind .. "' the sub-zone is left out", FWR:GetAreaSubZoneText() == "")
end
IsInInstance = realInInstance

section("Price check: what it made you earn, counted when the pieces are sold")
resetHistory()
check("nothing yet", FWR:GetPriceCheckSavings() == 0)
FWR.PostGainNote = { itemID = 236965, perPiece = 2000 }
post(236965, 10, 13300)
post(242639, 5, 9800)             -- a post the price check did not touch
inbox = { sale("Bright Linen", 6, 79800, 3990), sale("Practically Pork", 5, 49000, 2450) }
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(3)
check("6 pieces sold: 6 x 2000, less the 5%", FWR:GetPriceCheckSavings() == 11400, FWR:GetPriceCheckSavings())
inbox = { sale("Bright Linen", 4, 53200, 2660) }
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(3)
check("the other 4 sold: 10 x 2000 less the 5% in all", FWR:GetPriceCheckSavings() == 19000, FWR:GetPriceCheckSavings())
inbox = { sale("Bright Linen", 3, 39900, 1995) }
H.fire("MAIL_SHOW")
H.advance(0.5)
openAll(3)
check("a later sale of the same price is not credited again", FWR:GetPriceCheckSavings() == 19000, FWR:GetPriceCheckSavings())
local _, savedPieces, savedItems = FWR:GetPriceCheckSavings()
check("the pieces and the items it counts: 10 pieces of 1 item", savedPieces == 10 and savedItems == 1,
    tostring(savedPieces) .. " pieces, " .. tostring(savedItems) .. " items")

section("Floating loot text while minimized")
local errorsBefore = #H.results.errors
local mini = CreateFrame("Button", nil, UIParent)
mini:SetSize(80, 20)
mini:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, 10)
mini:Show()
local realMini = FWR.GetMainWindowMiniButton
FWR.GetMainWindowMiniButton = function() return mini end
FWR.Settings.ui.floatLootText = true
FWR.Settings.ui.lootAlertGold = 0
FWR:Emit("lootRecorded", { itemName = "Bright Linen", itemRarity = 2, itemID = 236965 }, 3)
FWR:Emit("lootRecorded", { itemName = "Bright Linen", itemRarity = 2, itemID = 236965 }, 2)
FWR:Emit("lootRecorded", { itemName = "Radiant Shard", itemRarity = 3, itemID = 243602 }, 1)
H.advance(0.5)
H.advance(1)
H.advance(5)
check("looting with the window minimized makes no error", #H.results.errors == errorsBefore)
FWR.Settings.ui.lootAlertGold = 1
FWR:Emit("lootRecorded", { itemName = "Radiant Shard", itemRarity = 3, itemID = 243602 }, 5)
H.advance(6)
check("a valuable loot makes no error either", #H.results.errors == errorsBefore)
mini:Hide()
FWR:Emit("lootRecorded", { itemName = "Bright Linen", itemRarity = 2, itemID = 236965 }, 1)
H.advance(1)
check("with the window open nothing is shown and nothing breaks", #H.results.errors == errorsBefore)
FWR.GetMainWindowMiniButton = realMini
FWR.Settings.ui.floatLootText = false

section("The main window and combat: coming back after the fight is the user's choice")
check("the main window exists in the test", FWR.MainFrame ~= nil)
local ui = FWR.Settings.ui
ui.hideMainWindowInCombat = true
ui.restoreMainWindowAfterCombat = false
ui.mainWindowMinimized = false
FWR.minimizedByCombat = nil
FWR:ApplyMainWindowPresentation(true)
check("in combat it is minimized", FWR.minimizedByCombat == true)
FWR:ApplyMainWindowPresentation(false)
check("after the fight it stays minimized when 'open it again' is off", FWR.minimizedByCombat == true)
FWR:SetMainWindowMinimized(false)
check("a click on the small button opens it", FWR.minimizedByCombat == nil and ui.mainWindowMinimized == false)
ui.restoreMainWindowAfterCombat = true
FWR:ApplyMainWindowPresentation(true)
FWR:ApplyMainWindowPresentation(false)
check("after the fight it opens again when 'open it again' is on", FWR.minimizedByCombat == nil)
FWR:SetMainWindowMinimized(true)
FWR:ApplyMainWindowPresentation(true)
FWR:ApplyMainWindowPresentation(false)
check("a window minimized by hand is not opened after the fight", ui.mainWindowMinimized == true)
FWR:SetMainWindowMinimized(false)
ui.hideMainWindowInCombat = false
ui.restoreMainWindowAfterCombat = false

section("Price check strictness")
FarmWiseReforgedSettingsDB.ah = FarmWiseReforgedSettingsDB.ah or {}
local function zoneAt(level, price)
    FarmWiseReforgedSettingsDB.ah.tabPriceCheckLevel = level
    return (FWR:GetPriceZone(price, 10000))
end
check("normal (the default) is under 85% of the usual", zoneAt(nil, 8600) == "normal" and zoneAt(nil, 8400) == "low")
check("relaxed is under 70%", zoneAt(1, 7100) == "normal" and zoneAt(1, 6900) == "low")
check("strict is under 92%", zoneAt(3, 9300) == "normal" and zoneAt(3, 9100) == "low")
check("very strict is under 97%", zoneAt(4, 9800) == "normal" and zoneAt(4, 9600) == "low")
check("a value out of range is held to the nearest level (9 is very strict)", zoneAt(9, 9600) == "low" and zoneAt(0, 6900) == "low" and zoneAt(0, 7100) == "normal")
FarmWiseReforgedSettingsDB.ah.tabPriceCheckLevel = nil

section("Auctions: one mail for several posts (a buyer of 13 pieces from a post of 6 and one of 7)")
FWR:GetActionRows()
local ledger
for _, records in pairs(FarmWiseDB._actions or {}) do ledger = records end
local function lines(state, ...)
    for index = #ledger, 1, -1 do ledger[index] = nil end
    local now = time()
    for index, qty in ipairs({ ... }) do
        ledger[#ledger + 1] = { id = 9000 + index, itemID = 236965, name = "Bright Linen", qty = qty, unit = 13300,
            state = state, since = now, expires = now - 3600 * (10 - index), soldKnown = false }
    end
end
local function taken(count)
    FWR:Emit("auctionUnitCollected", { kind = "sale", itemID = 236965, name = "Bright Linen", count = count })
end
lines("ended", 6, 7)
taken(13)
check("ended lines of 6 and 7 are both cleared by one mail of 13", #ledger == 0, #ledger)
H.fire("AUCTION_HOUSE_CLOSED")
lines("active", 6, 7)
taken(13)
check("the same with the lines still 'active' (the mail was taken before the Auction House was opened)", #ledger == 0, #ledger)
lines("ended", 6, 7)
taken(10)
check("a mail of 10 clears the older line (6) and takes 4 of the next (7 becomes 3)", #ledger == 1 and ledger[1].qty == 3,
    #ledger .. " line(s), qty " .. tostring(ledger[1] and ledger[1].qty))
lines("ended", 6, 7)
taken(6)
check("a mail of 6 clears the line of 6 and leaves the 7", #ledger == 1 and ledger[1].qty == 7, #ledger)
-- while the mail is still in the mailbox: the lines that add up to it are that sale
lines("ended", 6, 7)
FWR:Emit("auctionMailSeen", { { kind = "sale", key = "x", expiry = time() + 86400, itemID = 236965, name = "Bright Linen",
    count = 13, gross = 100 } }, true)
check("seen in the mailbox: the two ended lines become 'sold'", ledger[1] and ledger[1].state == "sold" and ledger[2] and ledger[2].state == "sold")
for index = #ledger, 1, -1 do ledger[index] = nil end

section("Gathering is counted for the whole zone: the automatic reset")
FWR.Settings.engine.sessionResetMode = "auto"
FWR.Settings.engine.autoResetDelaySeconds = 15
local realReset = FWR.ResetSessionsInScope
local resets = {}
FWR.ResetSessionsInScope = function(_, scope)
    resets[#resets + 1] = (scope.zone or "?") .. "::" .. tostring(scope.subzone)
end
check("the view is by sub-zone", FWR:GetViewScope().mode == "subzone")
local function walk(fromKey, toKey)
    FWR:HandleAreaChanged(fromKey)   -- (the place we start from is only remembered; what was waiting is let to pass)
    H.advance(20)
    resets = {}
    FWR:HandleAreaChanged(toKey)
    H.advance(20)
    return table.concat(resets, " | ")
end
local zoneA = FWR:BuildDetailedContextKey("Zed", "Ridge")
local zoneB = FWR:BuildDetailedContextKey("Zed", "Valley")
local zoneWhole = FWR:BuildDetailedContextKey("Zed", nil)
local other = FWR:BuildDetailedContextKey("Yan", "Cove")
local r1 = walk(zoneA, zoneB)
check("from a sub-zone to another sub-zone of the zone: the old one is reset", r1 == "Zed::Ridge", r1)
local r2 = walk(zoneA, zoneWhole)
check("gathering starts in a sub-zone (the whole zone is the area): nothing is reset", r2 == "", r2)
local r3 = walk(zoneWhole, zoneB)
check("gathering is over, back to a sub-zone: nothing is reset", r3 == "", r3)
local r4 = walk(zoneWhole, other)
check("from the gathering of a zone into another zone: the zone starts over", r4 == "Zed::", r4)
local r5 = walk(zoneA, other)
check("from a sub-zone into another zone: the sub-zone and the gathering of the zone start over",
    r5:find("Zed::Ridge", 1, true) ~= nil and (r5 .. " |"):find("Zed:: |", 1, true) ~= nil, r5)
-- coming back in time cancels the reset of the gathering
FWR:HandleAreaChanged(zoneWhole)
H.advance(20)
resets = {}
FWR:HandleAreaChanged(other)
H.advance(5)
FWR:HandleAreaChanged(zoneB)
H.advance(30)
local backReset = false
for _, entry in ipairs(resets) do
    if entry == "Zed::" then backReset = true end
end
check("back in the zone before the delay is over: the gathering of the zone is not reset", not backReset,
    table.concat(resets, " | "))
FWR.ResetSessionsInScope = realReset
FWR.Settings.engine.sessionResetMode = "manual"

section("Gathering: the area is the whole zone while it goes on, and after it the sub-zone again")
check("not gathering: the sub-zone is used", FWR:GetAreaSubZoneText() == "The Waking Shores")
FWR:NoteGatheringActivity()
check("gathering: no sub-zone", FWR:GetAreaSubZoneText() == "")
H.advance(400)
check("long after the last gathering: the sub-zone again", FWR:GetAreaSubZoneText() == "The Waking Shores")
FWR.Settings.tracking.gatheringWholeZone = false
FWR:NoteGatheringActivity()
check("with the option off, gathering is counted per sub-zone", FWR:GetAreaSubZoneText() == "The Waking Shores")
FWR.Settings.tracking.gatheringWholeZone = true
H.advance(400)

print(string.format("\nRESULT: %d passed, %d failed, %d runtime error(s) caught", H.results.pass, H.results.fail, #H.results.errors))
for i, e in ipairs(H.results.errors) do
    if i <= 15 then print("  runtime error: " .. tostring(e):sub(1, 500)) end
end
