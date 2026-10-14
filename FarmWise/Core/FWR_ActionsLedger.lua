local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- What is going on with my auctions, for the "Actions" page of the FarmWise tab: one line for each post, kept
-- until the gold (or the returned items) is taken from the mailbox.
--
-- The game lists my auctions only while the Auction House is open: active ones, and sold ones (until their mail
-- is there). Here every post is remembered, so a line stays after the game stops listing it:
--   active    -> still in the Auction House
--   sold      -> sold, the gold is not taken yet
--   expired   -> ran out, the items are in the mail
--   cancelled -> taken back by me, the items are in the mail
-- A line goes away when the History counts its mail as taken (the "auctionUnitCollected" event).

local SOLD = 1                                 -- Enum.AuctionStatus.Sold
local KEEP_SECONDS = 31 * 86400                -- a mail stays 30 days in the mailbox
local EXPIRY_SLACK = 120                       -- seconds: a post that vanishes this close to its end expired

local loaded = false                           -- the list of the game is known (since this Auction House opened)
local sessionStart = 0                         -- when this visit to the Auction House began

local function owner()
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
    return (UnitName and UnitName("player") or "?") .. "-" .. realm
end

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
        elseif record.state == "active" and not info.sold and info.qty < record.qty then
            -- a part of it was sold (just now, we were looking): that part is a sold line of its own, the rest
            -- stays active
            records[#records + 1] = { itemID = record.itemID, qty = record.qty - info.qty, unit = record.unit,
                state = "sold", since = now, soldKnown = true }
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
            record.expires = info.left and (now + info.left) or record.expires
        end
    end

    -- an active post that the game does not list any more
    for _, record in ipairs(records) do
        if record.id and (record.state == "active" or record.state == nil) and not present[record.id] then
            if record.cancelling then
                record.state = "cancelled"
            elseif record.expires and now >= record.expires - EXPIRY_SLACK then
                record.state = "expired"
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
        if record.state ~= "active" and now - (record.since or now) > KEEP_SECONDS then
            table.remove(records, position)
        end
    end
    changed()
end

-- the gold or the items of a post were taken from the mailbox: that line is finished
local WANTED_STATE = { sale = "sold", expired = "expired", cancelled = "cancelled" }

local function collected(unit)
    local records = list()
    local state = type(unit) == "table" and WANTED_STATE[unit.kind]
    if not records or not state then
        return
    end
    local left = tonumber(unit.count) or 0
    if left <= 0 then
        return
    end
    local lowerName = unit.name and string.lower(unit.name)
    local function same(record)
        if record.state ~= state then
            return false
        end
        if unit.itemID then
            return record.itemID == unit.itemID
        end
        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(record.itemID)
        return lowerName ~= nil and name ~= nil and string.lower(name) == lowerName
    end

    -- gold arrives for a line that was thought cancelled: it was a sale
    if state == "sold" then
        local hasSold = false
        for _, record in ipairs(records) do
            if record.state == "sold" and record.itemID == unit.itemID then
                hasSold = true
                break
            end
        end
        if not hasSold then
            for position, record in ipairs(records) do
                if record.state == "cancelled" and record.itemID == unit.itemID and record.qty == left then
                    table.remove(records, position)
                    changed()
                    return
                end
            end
        end
    end

    -- items that come back are not a sale: a line wrongly kept as "sold" with exactly this amount goes too
    if state ~= "sold" then
        for position, record in ipairs(records) do
            if record.state == "sold" and record.itemID == unit.itemID and record.qty == left and not same(record) then
                local exact = false
                for _, other in ipairs(records) do
                    if same(other) then
                        exact = true
                        break
                    end
                end
                if not exact then
                    table.remove(records, position)
                    changed()
                    return
                end
            end
        end
    end

    -- a line with exactly this amount first, then the oldest ones
    for position, record in ipairs(records) do
        if same(record) and record.qty == left then
            table.remove(records, position)
            changed()
            return
        end
    end
    table.sort(records, function(a, b)
        return (a.since or 0) > (b.since or 0)
    end)
    -- sorted newest first, so walking from the end takes the oldest first
    for position = #records, 1, -1 do
        local record = records[position]
        if left > 0 and same(record) then
            if record.qty > left then
                record.qty = record.qty - left
                left = 0
            else
                left = left - record.qty
                table.remove(records, position)
            end
        end
    end
    changed()
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

-- The lines to show for this character: { itemID, name, qty, unit, net, state, left }.
function FWR:GetActionRows()
    local records = list() or {}
    local now = time()
    local cut = tonumber(FWR.AUCTION_HOUSE_CUT) or 0.05
    local rows = {}
    for _, record in ipairs(records) do
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

if type(C_AuctionHouse) == "table" and type(C_AuctionHouse.CancelAuction) == "function" then
    pcall(hooksecurefunc, C_AuctionHouse, "CancelAuction", function(auctionID)
        for _, record in ipairs(list() or {}) do
            if record.id == auctionID then
                record.cancelling = true
            end
        end
    end)
end

local frame = CreateFrame("Frame")
for _, name in ipairs({ "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "GET_ITEM_INFO_RECEIVED" }) do
    pcall(frame.RegisterEvent, frame, name)
end
frame:SetScript("OnEvent", function(_, event, itemID)
    -- (the game's AUCTION_CANCELED event is not used: it also came for posts that nobody took back)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if itemID and askedFor[itemID] == true then
            askedFor[itemID] = "answered"   -- asked once, never again (no loop if the game cannot tell)
            changed()
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        loaded = false
        sessionStart = time()
        if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
            pcall(C_AuctionHouse.QueryOwnedAuctions, {})
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        loaded = false
    else
        loaded = true
        pcall(sync)
    end
end)
