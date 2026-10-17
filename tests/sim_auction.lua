-- SIMULATION of what can happen to the posts of a player at the Auction House, and in the mailbox, over days.
--
-- A small model of the server is put around the real files of the addon (world: auctions, sales, expiry, mails
-- that come an hour after a sale), and the addon is driven with the events the game would send. Then
--   * a set of fixed stories (one for each thing that can happen), and
--   * a few hundred random stories
-- are run, and after each of them the player "does everything": opens the Auction House, opens the mailbox, takes
-- all, and looks again. Then what the addon shows must be what the model says is true.

local H = dofile(HARNESS_PATH)
local check = H.check

local function section(title) print("\n== " .. title) end

------------------------------------------------------------
-- items
------------------------------------------------------------
local ITEMS = {
    { id = 236965, name = "Bright Linen", price = 1360 },
    { id = 237359, name = "Refulgent Copper Ore", price = 5000 },
    { id = 237015, name = "Sunfire Silk", price = 698500 },
    { id = 243605, name = "Dawn Crystal", price = 960100 },
    { id = 242639, name = "Practically Pork", price = 8500 },
}
for _, item in ipairs(ITEMS) do
    H.defineItem(item.id, item.name, 7, 200, 100)
end

------------------------------------------------------------
-- the server
------------------------------------------------------------
local CUT = 0.05
local DEPOSIT = 100
local SOLD_VISIBLE = 100          -- seconds a sold post is still listed by the game
local MAIL_DELAY = 3600           -- a sale mail comes an hour after the sale

local world

local function newWorld()
    return {
        open = false,             -- the Auction House window
        mailboxOpen = false,
        auctions = {},            -- { id, item, qty, unit, expires, soldAt, state = "active"|"sold"|"cancelled" }
        mails = {},               -- { arrives, mail } not yet in the mailbox
        nextId = 1067000000,
        soldPieces = {},          -- [itemID] = pieces sold (the truth)
        soldGross = {},           -- [itemID] = gross gold
        returnedPieces = {},      -- items that came back by mail
    }
end

local function worldNow()
    return time()
end

local function itemById(id)
    for _, item in ipairs(ITEMS) do
        if item.id == id then return item end
    end
end

local function addMail(arrives, mail)
    world.mails[#world.mails + 1] = { arrives = arrives, mail = mail, created = arrives }
end

local function saleMail(auction, pieces)
    local item = itemById(auction.item)
    local gross = auction.unit * pieces
    local cut = math.floor(gross * CUT)
    return {
        sender = "Auction House",
        subject = "Auction successful: " .. item.name .. (pieces > 1 and (" (" .. pieces .. ")") or ""),
        money = gross - cut + DEPOSIT,
        invoice = { type = "seller", name = item.name, bid = gross, buyout = pieces, deposit = DEPOSIT, cut = cut, count = pieces },
    }
end

local function returnMail(auction, kind)
    local item = itemById(auction.item)
    return {
        sender = "Auction House",
        subject = (kind == "expired" and "Auction expired: " or "Auction cancelled: ") .. item.name,
        money = 0,
        items = { { name = item.name, id = item.id, count = auction.qty } },
    }
end

-- what the game's functions answer
local function visibleAuctions()
    local list = {}
    for _, auction in ipairs(world.auctions) do
        if auction.state == "active" then
            list[#list + 1] = auction
        elseif auction.state ~= "gone" and worldNow() - (auction.soldAt or 0) <= SOLD_VISIBLE then
            list[#list + 1] = auction
        end
    end
    return list
end

C_AuctionHouse.GetNumOwnedAuctions = function() return #visibleAuctions() end
C_AuctionHouse.GetOwnedAuctionInfo = function(index)
    local auction = visibleAuctions()[index]
    if not auction then return nil end
    local sold = auction.state ~= "active"
    return {
        auctionID = auction.id,
        itemKey = { itemID = auction.item },
        quantity = auction.qty,
        buyoutAmount = sold and (auction.unit * auction.qty) or auction.unit,
        status = sold and 1 or 0,
        timeLeftSeconds = sold and math.max(0, SOLD_VISIBLE - (worldNow() - auction.soldAt)) or math.max(0, auction.expires - worldNow()),
    }
end
C_AuctionHouse.QueryOwnedAuctions = function()
    if world.open then
        C_Timer.After(0.1, function() H.fire("OWNED_AUCTIONS_UPDATED") end)
    end
end
C_AuctionHouse.CancelAuction = function(id)
    for _, auction in ipairs(world.auctions) do
        if auction.id == id and auction.state == "active" then
            auction.state = "cancelled"
            auction.soldAt = worldNow()
            addMail(worldNow(), returnMail(auction, "cancelled"))
            world.returned = world.returned or {}
            if world.open then
                C_Timer.After(0.1, function()
                    H.fire("AUCTION_CANCELED", id)
                    H.fire("OWNED_AUCTIONS_UPDATED")
                end)
            end
        end
    end
end

ERR_AUCTION_SOLD_S = "A buyer has been found for your auction of %s."
ERR_AUCTION_EXPIRED_S = "Your auction of %s has expired."
ERR_AUCTION_REMOVED = "Auction removed."

------------------------------------------------------------
-- what happens in the world
------------------------------------------------------------
local function post(itemIndex, qty, unitPrice)
    local item = ITEMS[itemIndex]
    world.nextId = world.nextId + 1
    local auction = {
        id = world.nextId, item = item.id, qty = qty, unit = unitPrice or item.price,
        expires = worldNow() + 12 * 3600, state = "active",
    }
    world.auctions[#world.auctions + 1] = auction
    if world.open then
        H.fire("AUCTION_HOUSE_AUCTION_CREATED", auction.id)
        C_Timer.After(0.1, function() H.fire("OWNED_AUCTIONS_UPDATED") end)
    end
    return auction
end

local function sell(auction, pieces)
    if auction.state ~= "active" then return end
    pieces = math.min(pieces or auction.qty, auction.qty)
    local gross = auction.unit * pieces
    world.soldPieces[auction.item] = (world.soldPieces[auction.item] or 0) + pieces
    world.soldGross[auction.item] = (world.soldGross[auction.item] or 0) + gross
    addMail(worldNow() + MAIL_DELAY, saleMail(auction, pieces))
    if pieces >= auction.qty then
        auction.state = "sold"
        auction.soldAt = worldNow()
    else
        auction.qty = auction.qty - pieces
    end
    if world.open then
        H.fire("CHAT_MSG_SYSTEM", string.format(ERR_AUCTION_SOLD_S, itemById(auction.item).name))
        C_Timer.After(1.2, function() H.fire("OWNED_AUCTIONS_UPDATED") end)
    end
end

local function activeAuctions()
    local list = {}
    for _, auction in ipairs(world.auctions) do
        if auction.state == "active" then list[#list + 1] = auction end
    end
    return list
end

-- the server moves on: posts that ran out go back by mail, mails come, sold posts leave the list
local function tickWorld()
    local now = worldNow()
    for _, auction in ipairs(world.auctions) do
        if auction.state == "active" and now >= auction.expires then
            auction.state = "gone"
            world.returnedPieces[auction.item] = (world.returnedPieces[auction.item] or 0) + auction.qty
            addMail(auction.expires, returnMail(auction, "expired"))
            if world.open then
                -- the game updates the list of the player by itself when a post runs out
                C_Timer.After(0.1, function() H.fire("OWNED_AUCTIONS_UPDATED") end)
            end
        end
    end
    for index = #world.mails, 1, -1 do
        local entry = world.mails[index]
        if entry.arrives <= now then
            local mail = entry.mail
            mail.daysLeft = 30     -- set again below when the mailbox shows it
            mail.arrivedAt = entry.arrives
            inbox[#inbox + 1] = mail
            table.remove(world.mails, index)
            if world.mailboxOpen then H.fire("MAIL_INBOX_UPDATE") end
        end
    end
    for _, mail in ipairs(inbox) do
        -- the mail lives 30 days from its arrival
        mail.daysLeft = 30 - (now - (mail.arrivedAt or now)) / 86400
    end
end

local function step(seconds)
    local left = seconds
    while left > 0 do
        local dt = math.min(left, 300)
        -- small steps for short times; for long waits the timers of the addon are run at 30 s
        H.advance(dt, dt <= 60 and math.min(dt, 5) or 30)
        left = left - dt
        tickWorld()
    end
end

------------------------------------------------------------
-- what the player does
------------------------------------------------------------
local function openAH()
    if world.open then return end
    world.open = true
    AuctionHouseFrame = AuctionHouseFrame or {}
    AuctionHouseFrame.IsShown = function() return world.open end
    H.fire("AUCTION_HOUSE_SHOW")
    step(1)
    H.fire("OWNED_AUCTIONS_UPDATED")
    step(1)
end

local function closeAH()
    if not world.open then return end
    world.open = false
    H.fire("AUCTION_HOUSE_CLOSED")
    step(0.2)
end

local function openMailbox()
    if world.mailboxOpen then return end
    world.mailboxOpen = true
    MailFrame = MailFrame or { IsShown = function() return world.mailboxOpen end }
    MailFrame.IsShown = function() return world.mailboxOpen end
    tickWorld()
    H.fire("MAIL_SHOW")
    step(0.3)
    H.fire("MAIL_INBOX_UPDATE")
    step(0.5)
end

local function closeMailbox()
    if not world.mailboxOpen then return end
    world.mailboxOpen = false
    H.fire("MAIL_CLOSED")
    step(0.2)
end

local function takeAllMail()
    local guard = 0
    while #inbox > 0 and guard < 200 do
        guard = guard + 1
        for index = #inbox, 1, -1 do
            AutoLootMailItem(index)
        end
        step(0.6)
    end
end

------------------------------------------------------------
-- what the addon shows, and what is true
------------------------------------------------------------
local function rowsByState()
    local counts = {}
    for _, row in ipairs(FarmWiseReforged:GetActionRows()) do
        counts[row.state] = (counts[row.state] or 0) + 1
    end
    return counts
end

local function historyTotals()
    local sold, returned = {}, {}
    for _, row in ipairs(FarmWiseReforged:GetSalesHistoryRows()) do
        if row.itemID then
            sold[row.itemID] = (sold[row.itemID] or 0) + row.sold
            returned[row.itemID] = (returned[row.itemID] or 0) + row.returned
        end
    end
    return sold, returned
end

-- the player "does everything" and the books must balance
local function settle(label)
    step(2 * 3600)                   -- every mail has come
    openAH()
    openMailbox()
    takeAllMail()
    step(2)
    closeMailbox()
    step(1)
    openMailbox()                    -- and looks again, with nothing in it
    step(3)
    closeMailbox()
    local problems = {}

    local active = activeAuctions()
    local counts = rowsByState()
    local rows = FarmWiseReforged:GetActionRows()
    local activeRows = counts.active or 0
    if activeRows ~= #active then
        problems[#problems + 1] = string.format("active posts: model %d, page %d", #active, activeRows)
    end
    for state, count in pairs(counts) do
        if state ~= "active" then
            problems[#problems + 1] = string.format("a line of state '%s' is left (%d) with nothing in the mailbox", state, count)
        end
    end
    -- the pieces of an active line add up to the model
    local modelPieces, pagePieces = 0, 0
    for _, auction in ipairs(active) do modelPieces = modelPieces + auction.qty end
    for _, row in ipairs(rows) do
        if row.state == "active" then pagePieces = pagePieces + row.qty end
    end
    if modelPieces ~= pagePieces then
        problems[#problems + 1] = string.format("active pieces: model %d, page %d", modelPieces, pagePieces)
    end

    local sold, returned = historyTotals()
    for _, item in ipairs(ITEMS) do
        local truth = world.soldPieces[item.id] or 0
        if (sold[item.id] or 0) ~= truth then
            problems[#problems + 1] = string.format("%s: sold in the history %d, in the model %d", item.name, sold[item.id] or 0, truth)
        end
        local back = world.returnedPieces[item.id] or 0
        if (returned[item.id] or 0) ~= back then
            problems[#problems + 1] = string.format("%s: returned in the history %d, in the model %d", item.name, returned[item.id] or 0, back)
        end
    end
    local errors = #H.results.errors
    if errors > 0 then
        problems[#problems + 1] = errors .. " error(s): " .. tostring(H.results.errors[1]):sub(1, 200)
        for index = #H.results.errors, 1, -1 do H.results.errors[index] = nil end
    end
    check(label, #problems == 0, table.concat(problems, "; "))
    return #problems == 0
end

------------------------------------------------------------
-- the start
------------------------------------------------------------
local function startAddon()
    FarmWiseDB, FarmWiseReforgedDB, FarmWiseReforgedSettingsDB = {}, {}, {}
    world = newWorld()
    inbox = {}
    ah = ah or {}
    H.loadAddon()
    FarmWiseReforged = FarmWiseReforged or {}
    H.fire("ADDON_LOADED", "FarmWise")
    H.fire("PLAYER_LOGIN")
    H.advance(1)
end

-- load the addon once; the stories each start from a clean player
H.loadAddon()
for _, e in ipairs(H.results.errors) do print("  LOAD ERROR " .. tostring(e):sub(1, 200)) end
for index = #H.results.errors, 1, -1 do H.results.errors[index] = nil end
H.fire("ADDON_LOADED", "FarmWise")
H.fire("PLAYER_LOGIN")
H.advance(1)
local FWR = FarmWiseReforged

local function freshPlayer()
    world = newWorld()
    inbox = {}
    -- the saved data of the addon starts empty: the history of the realm, the posts of the player
    FarmWiseDB._sales = nil
    FarmWiseDB._salesPosts = nil
    FarmWiseDB._salesNames = nil
    FarmWiseDB._actions = nil
    FWR:Emit("salesHistoryChanged")
end

------------------------------------------------------------
-- the fixed stories
------------------------------------------------------------
section("S1. A post sold in two parts while the Auction House is open")
freshPlayer()
openAH()
local a = post(1, 50)
step(30)
sell(a, 20)
step(10)
do
    local counts = rowsByState()
    check("S1 the sold part is a line of its own and the rest stays active", counts.sold == 1 and counts.active == 1,
        string.format("sold=%s active=%s", tostring(counts.sold), tostring(counts.active)))
end
sell(a, 30)
step(10)
settle("S1 everything taken: the books balance")

section("S2. A post that is sold while the player is away")
freshPlayer()
openAH()
local b = post(3, 3)
step(60)
closeAH()
step(3600 * 2)
sell(b, 3)
step(3600 * 3)
openAH()
do
    local counts = rowsByState()
    check("S2 back at the Auction House: the post is not shown as active", (counts.active or 0) == 0,
        tostring(counts.active))
end
settle("S2 mail taken: the books balance")

section("S3. A post that runs out while the Auction House is open")
freshPlayer()
openAH()
local c = post(2, 5)
step(12 * 3600 + 120)
do
    local counts = rowsByState()
    check("S3 a post that ran out is not shown", (counts.expired or 0) == 0 and (counts.ended or 0) == 0,
        "expired " .. tostring(counts.expired) .. ", ended " .. tostring(counts.ended))
end
settle("S3 expired post: items back, the books balance")

section("S4. A post that runs out while the player is away, and one that was sold meanwhile")
freshPlayer()
openAH()
post(1, 9)
local d = post(4, 8)
closeAH()
step(3600)
sell(d, 8)
step(13 * 3600)
openAH()
settle("S4 one ran out, one was sold: the books balance")
do
    local counts = rowsByState()
    check("S4 nothing is left in 'ended' or 'expired'", (counts.ended or 0) == 0 and (counts.expired or 0) == 0,
        "ended " .. tostring(counts.ended) .. ", expired " .. tostring(counts.expired))
end

section("S4b. The chat tells about a sale and about a post that ran out while the Auction House is closed")
freshPlayer()
openAH()
local g1 = post(1, 9)
local g2 = post(4, 8)
closeAH()
step(3600)
sell(g2, 8)
H.fire("CHAT_MSG_SYSTEM", string.format(ERR_AUCTION_SOLD_S, itemById(g2.item).name))
do
    local counts = rowsByState()
    check("S4b the sale is a 'sold' line before the Auction House is opened", counts.sold == 1 and counts.active == 1,
        "sold " .. tostring(counts.sold) .. ", active " .. tostring(counts.active))
end
step(13 * 3600)
H.fire("CHAT_MSG_SYSTEM", string.format(ERR_AUCTION_EXPIRED_S, itemById(g1.item).name))
do
    local counts = rowsByState()
    check("S4b the post that ran out is gone, without 'ended'", (counts.active or 0) == 0 and (counts.ended or 0) == 0
        and counts.sold == 1, "active " .. tostring(counts.active) .. ", ended " .. tostring(counts.ended)
        .. ", sold " .. tostring(counts.sold))
end
openAH()
settle("S4b the books balance")

section("S4c. A stack sold in several parts is one sold line that grows")
freshPlayer()
openAH()
local h1 = post(2, 10)
step(30)
sell(h1, 3)
step(5)
sell(h1, 2)
step(5)
do
    local counts = rowsByState()
    check("S4c one sold line and one active line", counts.sold == 1 and counts.active == 1,
        "sold " .. tostring(counts.sold) .. ", active " .. tostring(counts.active))
    local soldPieces
    for _, row in ipairs(FarmWiseReforged:GetActionRows()) do
        if row.state == "sold" then soldPieces = row.qty end
    end
    check("S4c the sold line has all the pieces sold", soldPieces == 5, tostring(soldPieces))
end
closeAH()
step(3 * 3600)
openMailbox()
step(5)
closeMailbox()
do
    local counts = rowsByState()
    check("S4c the sold line stays while its mails are in the mailbox", counts.sold == 1, tostring(counts.sold))
end
settle("S4c the books balance")

section("S4d. A sale is dated when it happened, not when the gold is taken")
freshPlayer()
openAH()
local k1 = post(3, 4)
step(30)
sell(k1, 4)
step(5)
local soldMoment = time()
closeAH()
step(20 * 3600)
settle("S4d the books balance")
do
    local last
    for _, row in ipairs(FarmWiseReforged:GetSalesHistoryRows()) do
        if row.itemID == ITEMS[3].id then last = row.last end
    end
    check("S4d the History dates the sale from when it happened", last and math.abs(last - soldMoment) < 60,
        tostring(last and (last - soldMoment)))
end

section("S4e. The mail is taken before the Auction House is opened again")
freshPlayer()
openAH()
post(1, 9)
local m2 = post(4, 8)
closeAH()
step(3600)
sell(m2, 8)
step(13 * 3600)
openMailbox()
takeAllMail()
step(2)
closeMailbox()
step(2)
openAH()
step(5)
do
    local counts = rowsByState()
    local left = 0
    for _, count in pairs(counts) do left = left + count end
    check("S4e nothing is left after the mail was taken first", left == 0, "lines left: " .. tostring(left)
        .. " (ended " .. tostring(counts.ended) .. ", sold " .. tostring(counts.sold) .. ", active "
        .. tostring(counts.active) .. ")")
end
settle("S4e the books balance")

section("S5. A post taken back (cancel) with the button of the page")
freshPlayer()
openAH()
local e = post(5, 12)
step(30)
FWR:CancelPost(e.id)
step(10)
do
    local counts = rowsByState()
    check("S5 a cancelled post is not shown", (counts.cancelled or 0) == 0 and (counts.sold or 0) == 0,
        "cancelled " .. tostring(counts.cancelled) .. ", sold " .. tostring(counts.sold))
end
settle("S5 cancelled and taken: the books balance")

section("S6. The mailbox is opened before the sale mail has come")
freshPlayer()
openAH()
local f = post(3, 2)
step(30)
sell(f, 2)
step(600)
openMailbox()
step(5)
closeMailbox()
do
    local counts = rowsByState()
    check("S6 the sold line is still there (the mail is not here yet)", counts.sold == 1, tostring(counts.sold))
end
settle("S6 later everything is taken: the books balance")

section("S7. Many posts of the same item and the same amount")
freshPlayer()
openAH()
local same = {}
for i = 1, 6 do same[i] = post(1, 10) end
step(30)
for i = 1, 4 do sell(same[i], 10) end
step(20)
step(3600 * 13)
settle("S7 six equal posts: four sold, two ran out")

section("S8. The game gives nothing (the functions answer nil)")
freshPlayer()
openAH()
post(1, 5)
local realNum, realInfo = C_AuctionHouse.GetNumOwnedAuctions, C_AuctionHouse.GetOwnedAuctionInfo
C_AuctionHouse.GetNumOwnedAuctions = function() return nil end
C_AuctionHouse.GetOwnedAuctionInfo = function() return nil end
H.fire("OWNED_AUCTIONS_UPDATED")
step(2)
check("S8 no error when the list is not there", #H.results.errors == 0, H.results.errors[1])
C_AuctionHouse.GetNumOwnedAuctions, C_AuctionHouse.GetOwnedAuctionInfo = realNum, realInfo
for index = #H.results.errors, 1, -1 do H.results.errors[index] = nil end

------------------------------------------------------------
-- the random stories
------------------------------------------------------------
section("R. Random stories (each ends with the player doing everything)")

local function random(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

local STORIES = tonumber(STORY_COUNT) or 60
local failed = 0
for story = (tonumber(STORY_FROM) or 1), STORIES do
    freshPlayer()
    local rnd = random(story * 7919)
    local log = {}
    for _ = 1, 25 do
        local action = rnd(11)
        if action == 1 or action == 2 then
            openAH(); log[#log + 1] = "open"
        elseif action == 3 then
            closeAH(); log[#log + 1] = "close"
        elseif action == 4 or action == 5 then
            local item, qty = rnd(#ITEMS), rnd(60)
            if not world.open then openAH() end
            post(item, qty); log[#log + 1] = "post " .. item .. "x" .. qty
        elseif action == 6 then
            local list = activeAuctions()
            if #list > 0 then
                local target = list[rnd(#list)]
                local part = rnd(target.qty)
                sell(target, part); log[#log + 1] = "sell " .. part .. "/" .. target.qty
            end
        elseif action == 7 then
            local list = activeAuctions()
            if #list > 0 then
                local target = list[rnd(#list)]
                sell(target); log[#log + 1] = "sell all"
            end
        elseif action == 8 then
            step(rnd(4) * 1800); log[#log + 1] = "wait"
        elseif action == 9 then
            step(13 * 3600); log[#log + 1] = "wait long"
        elseif action == 10 then
            openMailbox(); takeAllMail(); closeMailbox(); log[#log + 1] = "mailbox"
        elseif action == 11 then
            local list = activeAuctions()
            if #list > 0 and world.open then
                local target = list[rnd(#list)]
                FWR:CancelPost(target.id); log[#log + 1] = "cancel"
                step(2)
            end
        end
        step(rnd(3) * 20)
        if VERBOSE then
            local sold = historyTotals()
            local total = 0
            for _, n in pairs(sold) do total = total + n end
            local salesKeys = 0
            for realm, rec in pairs(FarmWiseDB._sales or {}) do for _ in pairs(rec) do salesKeys = salesKeys + 1 end end
            print("        sales records: " .. salesKeys .. "  enabled=" .. tostring(FarmWiseReforged.IsSalesHistoryEnabled and FarmWiseReforged:IsSalesHistoryEnabled()))
            print(string.format("      [%s] inbox=%d unseen=%d  history sold=%d  page rows=%d  open=%s mail=%s", log[#log] or "-",
                #inbox, #world.mails, total, #FarmWiseReforged:GetActionRows(), tostring(world.open), tostring(world.mailboxOpen)))
        end
    end
    local ok = settle("R" .. story)
    if not ok then
        failed = failed + 1
        print("      story: " .. table.concat(log, ", "))
        if VERBOSE then
            print("      inbox now: " .. #inbox .. " mails; model mails not yet here: " .. #world.mails)
            for _, row in ipairs(FarmWiseReforged:GetActionRows()) do
                print(string.format("      row %s x%d %s", row.name, row.qty, row.state))
            end
        end
        if failed >= 6 then
            print("      (stopping the random stories: too many failures)")
            break
        end
    end
end
