local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- What is going on with my auctions, for the "Actions" page of the FarmWise tab: one line for each post, kept
-- until the gold (or the returned items) is taken from the mailbox.
--
-- The game lists my auctions only while the Auction House is open: active ones, and sold ones (until their mail
-- is there). Here every post is remembered, so a line stays after the game stops listing it:
--   active    -> still in the Auction House
--   sold      -> sold, the gold is not taken yet
--   ended     -> not in the Auction House any more and the end is not known (it was sold while I was away, or it
--                ran out): the mail tells, when the mailbox is opened
--   expired   -> ran out, the items are in the mail (known from the mail)
--   cancelled -> taken back by me, the items are in the mail
-- A line goes away when the History counts its mail as taken (the "auctionUnitCollected" event).

local SOLD = 1                                 -- Enum.AuctionStatus.Sold
local KEEP_SECONDS = 31 * 86400                -- a mail stays 30 days in the mailbox
local MAIL_LATE_SECONDS = 90 * 60          -- a sale mail comes within the hour; after this long it is taken
local CANCEL_KEEP_SECONDS = 600                -- a cancelled post is hidden at once, forgotten after this long
local EXPIRY_SLACK = 120                       -- seconds: a post that vanishes this close to its end expired

local ahOpen = false                          -- the Auction House window is open
local loaded = false                           -- the list of the game is known (since this Auction House opened)
local sessionStart = 0                         -- when this visit to the Auction House began

local function owner()
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
    return (UnitName and UnitName("player") or "?") .. "-" .. realm
end

local migrated = false

local function list()
    if type(FarmWiseDB) ~= "table" then
        return nil
    end
    if type(FarmWiseDB._actions) ~= "table" then
        FarmWiseDB._actions = {}
    end
    local key = owner()
    if type(FarmWiseDB._actions[key]) ~= "table" then
        FarmWiseDB._actions[key] = {}
    end
    if not migrated then
        migrated = true
        -- an older version called a post "expired" when it only had vanished after its time: that was a guess
        for _, record in ipairs(FarmWiseDB._actions[key]) do
            if record.state == "expired" and record.soldKnown == false then
                record.state = "ended"
            end
        end
    end
    return FarmWiseDB._actions[key]
end

local function readOwned()
    local owned = {}
    local api = C_AuctionHouse
    if type(api) ~= "table" or not api.GetNumOwnedAuctions or not api.GetOwnedAuctionInfo then
        return owned
    end
    for index = 1, tonumber(api.GetNumOwnedAuctions()) or 0 do
        local info = api.GetOwnedAuctionInfo(index)
        local key = type(info) == "table" and info.itemKey
        if type(key) == "table" and info.auctionID and key.itemID then
            owned[#owned + 1] = {
                id = info.auctionID,
                itemID = key.itemID,
                qty = tonumber(info.quantity) or 1,
                unit = tonumber(info.buyoutAmount) or 0,     -- of one piece, for the things sold by amount
                sold = info.status == SOLD,
                left = tonumber(info.timeLeftSeconds),
            }
        end
    end
    return owned
end

local function changed()
    if FWR.Emit then
        FWR:Emit("actionsChanged")
    end
end

-- compares the game's list with what is remembered
local function sync()
    local records = list()
    if not records or not loaded then
        return
    end
    local now = time()
    local byID = {}
    for _, record in ipairs(records) do
        if record.id then
            byID[record.id] = record
        end
    end

    local present = {}
    for _, info in ipairs(readOwned()) do
        present[info.id] = true
        local record = byID[info.id]
        if not record then
            -- (for a sold post the game gives the whole price of what was sold, not the price of one piece)
            local unit = info.unit
            if info.sold and info.qty > 1 then
                unit = math.floor(info.unit / info.qty + 0.5)
            end
            record = { id = info.id, itemID = info.itemID, qty = info.qty, unit = unit, since = now }
            records[#records + 1] = record
            byID[info.id] = record
        elseif (record.state == "active" or record.soldAt) and not info.sold and info.qty < record.qty then
            -- a part of it was sold: that part is a sold line (one line for all the parts of this post that were
            -- sold, it grows), the rest stays active
            local part = record.qty - info.qty
            local line
            for _, other in ipairs(records) do
                if other.state == "sold" and other.from == record.id then
                    line = other
                    break
                end
            end
            if line then
                line.qty = line.qty + part
                line.since = now
            else
                records[#records + 1] = { itemID = record.itemID, qty = part, unit = record.unit, state = "sold",
                    since = now, soldKnown = true, from = record.id }
            end
        end
        record.seen = sessionStart
        record.qty = info.qty
        if not info.sold and info.unit > 0 then
            record.unit = info.unit   -- an active post: the price of one piece (a sold one is not used for this)
        end
        if record.cancelling or record.state == "cancelled" then
            -- the game lists a post that I took back as "sold" for a short time: the cancel event tells the truth
            if record.state ~= "cancelled" then
                record.since = now
            end
            record.state = "cancelled"
            record.expires = nil
        elseif info.sold then
            if record.state ~= "sold" then
                record.since = now
                -- the game lists a sale only for a few minutes: so we saw it happen
                record.soldKnown = true
            end
            record.state = "sold"
            record.expires = nil

        else
            record.state = "active"
            record.soldAt = nil
            record.expires = info.left and (now + info.left) or record.expires
        end
    end

    -- an active post that the game does not list any more
    for _, record in ipairs(records) do
        if record.id and (record.state == "active" or record.state == nil) and not present[record.id] then
            if record.cancelling then
                record.state = "cancelled"
            elseif record.expires and now >= record.expires - EXPIRY_SLACK then
                if record.seen == sessionStart then
                    -- it was in the list during this visit and went away when its time was over: it ran out
                    record.state = "expired"
                else
                    -- its time is over and we were not looking: it may have been sold on the way or it ran out.
                    -- Only the mail knows (it is read when the mailbox opens), so it is not called one or the other
                    record.state = "ended"
                end
            else
                record.state = "sold"
                -- if it was in the list during this visit, it was sold in front of our eyes; if not, it was sold
                -- when we were away, and when is not known: no time is promised for its mail
                record.soldKnown = record.seen == sessionStart
            end
            record.since = now
        end
    end

    for position = #records, 1, -1 do
        local record = records[position]
        -- a post that ran out is not kept: only what is still going on (active) or waits for its gold (sold) is
        -- (a cancelled post is only kept a few minutes, hidden: the game lists it as "sold" for a short time and it
        -- must not come back as a sale)
        if record.state == "expired" or (record.state == "cancelled" and now - (record.since or now) > CANCEL_KEEP_SECONDS)
            or (record.state ~= "active" and now - (record.since or now) > KEEP_SECONDS) then
            table.remove(records, position)
        end
    end
    changed()
end

-- What a mail says about a post, and in which states a line may be that post, the best guess first (a line that
-- was wrongly kept as sold, ended or expired is put right by the mail that really came)
local SEARCH_ORDER = {
    sale = { "sold", "ended", "expired", "cancelled" },
    expired = { "expired", "ended", "sold" },
    cancelled = { "cancelled", "ended", "sold" },
}
local MAIL_STATE = { sale = "sold", expired = "expired", cancelled = "cancelled" }

local function sameItem(record, unit)
    if unit.itemID then
        return record.itemID == unit.itemID
    end
    if not unit.name then
        return false
    end
    local name = record.name or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(record.itemID))
    return name ~= nil and string.lower(name) == string.lower(unit.name)
end

-- the gold or the items of a post were taken from the mailbox: that line is finished
local function collected(unit)
    local records = list()
    local order = type(unit) == "table" and SEARCH_ORDER[unit.kind]
    if not records or not order then
        return
    end
    local left = tonumber(unit.count) or 0
    if left <= 0 then
        return
    end

    for rank, state in ipairs(order) do
        -- a line with exactly this amount first
        for position, record in ipairs(records) do
            if record.state == state and sameItem(record, unit) and record.qty == left then
                table.remove(records, position)
                changed()
                return
            end
        end
        -- then, for the first state only, the oldest lines (a mail can cover several posts, or part of one)
        if rank == 1 then
            table.sort(records, function(a, b)
                return (a.since or 0) > (b.since or 0)
            end)
            -- sorted newest first, so walking from the end takes the oldest first
            for position = #records, 1, -1 do
                local record = records[position]
                if left > 0 and record.state == state and sameItem(record, unit) then
                    if record.qty > left then
                        record.qty = record.qty - left
                        left = 0
                    else
                        left = left - record.qty
                        table.remove(records, position)
                    end
                end
            end
            if left <= 0 then
                changed()
                return
            end
        end
    end
    changed()
end

-- The mailbox was looked at: the mails that are in it tell how the posts ended (a sale, items back, a cancel).
-- Lines that are "ended" (or wrongly "expired", "sold" ...) take the state of the mail that is theirs.
local function mailSeen(units, inboxLoaded)
    local records = list()
    if not records or type(units) ~= "table" then
        return
    end
    local used = {}
    local unitUsed = {}
    local touched = false
    for _, unit in ipairs(units) do
        local state = MAIL_STATE[unit.kind]
        local count = tonumber(unit.count)
        if state and count and count > 0 then
            -- already a line of this state with this amount?
            local found
            for index, record in ipairs(records) do
                if not used[index] and record.state == state and record.qty == count and sameItem(record, unit) then
                    found = index
                    break
                end
            end
            if not found then
                for _, from in ipairs(SEARCH_ORDER[unit.kind]) do
                    if from ~= state then
                        for index, record in ipairs(records) do
                            if not used[index] and record.state == from and record.qty == count
                                and sameItem(record, unit)
                                and not (from == "sold" and record.soldKnown == true) then
                                record.state = state
                                found = index
                                touched = true
                                break
                            end
                        end
                    end
                    if found then
                        break
                    end
                end
            end
            if found then
                used[found] = true
                unitUsed[unit] = true
            end
        end
    end
    -- a sold line can be the sum of several sales (one mail for each buyer): the mails that are left in the
    -- mailbox for its item are counted against it, so that it is not taken for a line that was collected already
    for index, record in ipairs(records) do
        if record.state == "sold" and not used[index] then
            local remaining = record.qty
            for _, unit in ipairs(units) do
                local count = tonumber(unit.count)
                if unit.kind == "sale" and not unitUsed[unit] and count and count > 0 and count <= remaining
                    and sameItem(record, unit) then
                    remaining = remaining - count
                    unitUsed[unit] = true
                    used[index] = true
                end
            end
        end
    end
    -- A line that waits for a mail which is not in the mailbox, long after the mail had to come, was taken
    -- already (by a mail addon, or before this page knew about it): it is finished. Only when the game has said
    -- that the list of the mailbox is in (an empty list can also be a mailbox that is still loading) and every
    -- mail is shown in it (the game shows 50 at most).
    local count, total = 0, 0
    if GetInboxNumItems then
        count, total = GetInboxNumItems()
    end
    if inboxLoaded == true and tonumber(total) == tonumber(count) then
        local now = time()
        for position = #records, 1, -1 do
            local record = records[position]
            -- every mail of a post is there by an hour after its end (a sale before the end of its time, items
            -- back at the end), and at the latest by an hour after the moment it was noticed
            local ended = math.min(record.since or now, record.expires or now)
            if record.state ~= "active" and not used[position] and now - ended > MAIL_LATE_SECONDS then
                table.remove(records, position)
                touched = true
            end
        end
    end
    -- the mail said a post ran out: it is not shown (its items are only waiting in the mail)
    for position = #records, 1, -1 do
        if records[position].state == "expired" then
            table.remove(records, position)
            touched = true
        end
    end
    if touched then
        changed()
    end
end

-- The game gives the name of an item only when it has it loaded: it is asked for, and the page is made again
-- when it comes (GET_ITEM_INFO_RECEIVED). A name that was seen once is kept with the post.
local askedFor = {}

local function nameOf(record)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(record.itemID)
    if name then
        record.name = name
        return name
    end
    if record.itemID and not askedFor[record.itemID] and C_Item and C_Item.RequestLoadItemDataByID then
        askedFor[record.itemID] = true
        pcall(C_Item.RequestLoadItemDataByID, record.itemID)
    end
    return record.name
end

-- When a post was sold, as far as the ledger knows, for the History (called when the gold of a sale is taken).
-- A sale seen happening (in the Auction House, or told by the chat) has its moment. A post that was "ended" (its time
-- was over and nobody was looking) was sold, if it was sold at all, at the latest at the end of its time. Nothing
-- else is known: nil, and the History looks at the age of the mail.
function FWR:GetActionSaleMoment(itemID, name, count)
    local records = list()
    if not records then
        return nil
    end
    local now = time()
    local wanted = { itemID = itemID, name = name }
    local best, bestMoment
    for _, record in ipairs(records) do
        if sameItem(record, wanted) and record.qty >= (count or 0) then
            local moment
            if record.state == "sold" and record.soldKnown == true then
                moment = record.since
            elseif record.state == "ended" and record.expires then
                moment = math.min(record.expires, now)
            end
            -- the oldest of the lines that fit
            if moment and (not bestMoment or moment < bestMoment) then
                best, bestMoment = record, moment
            end
        end
    end
    return bestMoment
end

-- The lines to show for this character: { itemID, name, qty, unit, net, state, left }.
function FWR:GetActionRows()
    local records = list() or {}
    local now = time()
    local cut = tonumber(FWR.AUCTION_HOUSE_CUT) or 0.05
    local rows = {}
    for _, record in ipairs(records) do
      if record.state ~= "cancelled" and record.state ~= "expired" then
        local name = nameOf(record)
        rows[#rows + 1] = {
            id = record.id,
            itemID = record.itemID,
            name = name or ("item " .. tostring(record.itemID)),
            qty = record.qty,
            unit = record.unit,
            net = math.floor((record.unit or 0) * record.qty * (1 - cut)),
            state = record.state or "active",
            left = record.expires and math.max(0, record.expires - now) or nil,
            since = record.since or 0,
        }
      end
    end
    return rows
end

-- Asks the game again for my auctions (when the Auction House is open): the answer corrects the page. Called
-- every time the Actions page is opened.
function FWR:RefreshOwnedAuctions()
    local frame = _G.AuctionHouseFrame
    if frame and frame.IsShown and frame:IsShown() and C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
        pcall(C_AuctionHouse.QueryOwnedAuctions, {})
    end
end

-- Lets go of the lines of the posts that were taken back (their items stay in the mailbox).
function FWR:ClearCancelledPosts()
    local records = list()
    if not records then
        return
    end
    for position = #records, 1, -1 do
        if records[position].state == "cancelled" then
            table.remove(records, position)
        end
    end
    changed()
end

-- Takes an active post back (the Auction House must be open). The game answers with the items in the mail.
function FWR:CancelPost(auctionID)
    if auctionID and C_AuctionHouse and C_AuctionHouse.CancelAuction then
        C_AuctionHouse.CancelAuction(auctionID)
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

FWR:Subscribe("auctionUnitCollected", collected)
FWR:Subscribe("auctionMailSeen", mailSeen)

if type(C_AuctionHouse) == "table" and type(C_AuctionHouse.CancelAuction) == "function" then
    pcall(hooksecurefunc, C_AuctionHouse, "CancelAuction", function(auctionID)
        for _, record in ipairs(list() or {}) do
            if record.id == auctionID then
                record.cancelling = true
            end
        end
    end)
end

-- The game tells in the chat when a post is sold or runs out, but its list of my auctions does not always change
-- by itself: the message is the signal to ask for the list again (a moment later, when it has changed).
local function patternOf(message)
    if type(message) ~= "string" then
        return nil
    end
    -- (the % of the "%s" is escaped too, then that "%s" is the place of the name)
    return "^" .. message:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0"):gsub("%%%%s", "(.+)") .. "$"
end
local CHAT_PATTERNS = {
    { pattern = patternOf(_G.ERR_AUCTION_SOLD_S), kind = "sold" },
    { pattern = patternOf(_G.ERR_AUCTION_EXPIRED_S), kind = "expired" },
    { pattern = patternOf(_G.ERR_AUCTION_REMOVED) },
}

-- The chat tells at once, wherever I am (the Auction House can be closed), that a post was sold or ran out, but only
-- with the name of the item: of the posts with that name, the one that ends first is the one.
local function chatNameOf(text)
    if type(text) ~= "string" then
        return nil
    end
    return string.lower(text:match("|h%[(.-)%]|h") or text:match("^%[(.-)%]$") or text)
end

local function chatSeen(kind, text)
    local records = list()
    local wanted = chatNameOf(text)
    if not records or not wanted then
        return
    end
    local pick
    for _, record in ipairs(records) do
        if record.state == "active" then
            local name = record.name or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(record.itemID))
            if name and string.lower(name) == wanted
                and (not pick or (record.expires or math.huge) < (pick.expires or math.huge)) then
                pick = record
            end
        end
    end
    if not pick then
        return
    end
    local now = time()
    if kind == "sold" then
        pick.state = "sold"
        pick.since = now
        pick.soldKnown = true
        pick.soldAt = now
        pick.expires = nil
    else
        -- it ran out: only its items are waiting in the mail, the line is not shown
        for position, record in ipairs(records) do
            if record == pick then
                table.remove(records, position)
                break
            end
        end
    end
    changed()
end

local function askAgainSoon()
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            FWR:RefreshOwnedAuctions()
        end)
    end
end

local frame = CreateFrame("Frame")
for _, name in ipairs({ "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "GET_ITEM_INFO_RECEIVED", "CHAT_MSG_SYSTEM" }) do
    pcall(frame.RegisterEvent, frame, name)
end
frame:SetScript("OnEvent", function(_, event, itemID)
    if event == "CHAT_MSG_SYSTEM" then
        for _, entry in ipairs(CHAT_PATTERNS) do
            if type(itemID) == "string" and entry.pattern then
                local captured = itemID:match(entry.pattern)
                if captured then
                    -- with the Auction House open its list is asked for and tells the truth (with the amounts); the
                    -- chat is used when it is closed, and the list corrects it when it opens
                    if entry.kind and not ahOpen then
                        pcall(chatSeen, entry.kind, captured)
                    end
                    askAgainSoon()
                    return
                end
            end
        end
        return
    end
    -- (the game's AUCTION_CANCELED event is not used: it also came for posts that nobody took back)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if itemID and askedFor[itemID] == true then
            askedFor[itemID] = "answered"   -- asked once, never again (no loop if the game cannot tell)
            changed()
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        ahOpen = true
        loaded = false
        sessionStart = time()
        if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
            pcall(C_AuctionHouse.QueryOwnedAuctions, {})
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ahOpen = false
        loaded = false
    else
        loaded = true
        pcall(sync)
    end
end)
