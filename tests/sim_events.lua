-- SIMULATION of every event the addon listens to, with the arguments the game gives, with none, and with odd ones
-- (nil, empty text, a number where text is expected). An event handler must never raise an error.

local H = dofile(HARNESS_PATH)
local check = H.check

local function section(title) print("\n== " .. title) end

FarmWiseDB, FarmWiseReforgedDB, FarmWiseReforgedSettingsDB = {}, {}, {}
H.defineItem(236965, "Bright Linen", 7, 200, 1000)
H.defineItem(237359, "Refulgent Copper Ore", 7, 200, 500)

H.loadAddon()
H.fire("ADDON_LOADED", "FarmWise")
H.fire("PLAYER_LOGIN")
H.advance(1)
for index = #H.results.errors, 1, -1 do H.results.errors[index] = nil end

section("E1. Every registered event, with several kinds of arguments")

-- the events the addon registered, from the frames that were made
local names, seen = {}, {}
for _, frame in ipairs(H.allFrames) do
    for event in pairs(frame.__events) do
        if not seen[event] then
            seen[event] = true
            names[#names + 1] = event
        end
    end
end
table.sort(names)
print(string.format("  %d different events are listened to", #names))

local link = "|cff1eff00|Hitem:236965::::::::70:::::|h[Bright Linen]|h|r"
local argSets = {
    {},
    { nil },
    { "" },
    { "text" },
    { 0 },
    { 236965 },
    { 1, 2, 3 },
    { link },
    { "You receive loot: " .. link .. ".", "", "", "", "Tester" },
    { "player", nil, 12345 },
    { {} },
}

local problems = 0
for _, event in ipairs(names) do
    if event ~= "ADDON_LOADED" then
        local first
        for _, args in ipairs(argSets) do
            local before = #H.results.errors
            H.fire(event, table.unpack(args, 1, 5))
            H.advance(0.3)
            if #H.results.errors > before and not first then
                first = H.results.errors[before + 1]
            end
        end
        if first then
            problems = problems + 1
            check("event " .. event .. " raises no error", false, tostring(first):sub(1, 220))
        end
        for index = #H.results.errors, 1, -1 do H.results.errors[index] = nil end
    end
end
check("no event raised an error with any of the argument sets (" .. #names .. " events x " .. #argSets .. ")", problems == 0, problems .. " events failed")

section("E2. The same events with the game's functions answering nothing")
local silent = {
    "GetNumOwnedAuctions", "GetOwnedAuctionInfo", "GetOwnedAuctions", "QueryOwnedAuctions", "GetCommoditySearchResultInfo",
    "GetNumCommoditySearchResults", "GetBrowseResults",
}
local saved = {}
for _, name in ipairs(silent) do
    saved[name] = C_AuctionHouse[name]
    C_AuctionHouse[name] = function() return nil end
end
local problems2 = 0
for _, event in ipairs({ "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "COMMODITY_SEARCH_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "GET_ITEM_INFO_RECEIVED", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED" }) do
    local before = #H.results.errors
    H.fire(event, 236965)
    H.advance(0.5)
    if #H.results.errors > before then
        problems2 = problems2 + 1
        check("event " .. event .. " with silent functions raises no error", false, tostring(H.results.errors[before + 1]):sub(1, 220))
    end
end
check("silent functions: no error", problems2 == 0)
for _, name in ipairs(silent) do C_AuctionHouse[name] = saved[name] end
