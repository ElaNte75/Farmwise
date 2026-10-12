local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Auction House scan.
-- Reads the lowest price of every trade good (or of every item, when the whole-Auction-House option
-- is on) straight from the Auction House and stores it in FarmWiseDB._ah, which the Advisor
-- uses for gold per hour. It runs automatically when the Auction House opens (and while it stays open)
-- if the "Scan automatically" option is on and the last scan is older than the interval chosen in the
-- options, and never sooner than MIN_SECONDS_BETWEEN_SCANS (15 minutes) after the previous one.
-- The AH Tab does not depend on it: the tab asks the Auction House for its own prices as it goes.

local PREFIX = "|cffd7be6aFarmWise|r "
local ITEM_CLASS = (Enum and Enum.ItemClass) or {}
local TRADEGOODS_CLASS_ID = ITEM_CLASS.Tradegoods or 7

-- The scan levels. Trade materials are always read. "Commodities" adds the other things that are sold by
-- amount (one query for each class, one after the other); "full" reads the whole Auction House in one query.
local COMMODITY_CLASS_IDS = {
    TRADEGOODS_CLASS_ID,
    ITEM_CLASS.Consumable or 0,
    ITEM_CLASS.Gem or 3,
    ITEM_CLASS.ItemEnhancement or 8,
    ITEM_CLASS.Reagent or 5,
}

local START_DELAY_SECONDS = 0.5
local MIN_SECONDS_BETWEEN_SCANS = 15 * 60
local RESULT_TIMEOUT_SECONDS = 8   -- waiting for the first answer
local BATCH_TIMEOUT_SECONDS = 15   -- waiting for the next batch of an answer that already started
local MAX_ATTEMPTS = 3
local MORE_RESULTS_RETRY_SECONDS = 0.3
local MORE_RESULTS_RETRY_LIMIT = 40
local THROTTLE_RETRY_SECONDS = 1
local THROTTLE_RETRY_LIMIT = 10

local auctionHouseOpen = false
local scan = {
    running = false,
    pendingStart = false,
    found = 0,
    expected = 0, -- items found by the previous scan, used to estimate progress
    startedAt = 0,
    activity = 0,        -- grows with every sign of life; the watchdog compares against it
    attempt = 1,         -- the query is sent at most twice
    gotResults = false,  -- real results of our query arrived
    classes = nil,       -- the item classes this scan reads one after the other (nil: the whole Auction House)
    classIndex = 1,      -- the class being read now
    collected = {},      -- what the classes read before this one gave
}

local function say(message)
    print(PREFIX .. message)
end


local function playFinishedSound(settings)
    if settings.sound ~= false and type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT.READY_CHECK then
        PlaySound(SOUNDKIT.READY_CHECK)
    end
end

local function getSettings(self)
    local settings = self.Settings and self.Settings.ah
    return type(settings) == "table" and settings or {}
end

function FWR:IsAuctionHouseOpen()
    return auctionHouseOpen == true
end

function FWR:IsAuctionScanRunning()
    return scan.running == true
end

function FWR:GetAuctionDataStore()
    local db = self:EnsureAdvisorStore()
    db._ah = type(db._ah) == "table" and db._ah or {}
    db._ah.items = type(db._ah.items) == "table" and db._ah.items or {}
    return db._ah
end

function FWR:GetAuctionFreshnessMinutes()
    return tonumber(getSettings(self).freshnessMinutes) or 30
end

-- Seconds until a new scan is allowed. Only a finished scan locks, a failed one never does.
function FWR:GetAuctionScanCooldownSeconds()
    local age = self:GetAuctionSyncAgeSeconds()
    if not age then
        return 0
    end
    -- a different scan level than the one that made the prices: the prices are not what is wanted now
    local settings = getSettings(self)
    local level = settings.fullScan == true and "full" or (settings.scanCommodities ~= false and "commodities" or "trade")
    if (self:GetAuctionDataStore().lastScanLevel or "trade") ~= level then
        return 0
    end
    return math.max(0, MIN_SECONDS_BETWEEN_SCANS - age)
end

-- "about 40 seconds" from the previous scan, or a general warning before the first one.
function FWR:GetAuctionScanEstimateText()
    local seconds = tonumber(self:GetAuctionDataStore().lastScanSeconds)
    if seconds then
        return string.format("It usually takes about %d seconds.", math.max(5, seconds))
    end
    return "The first scan can take up to a minute."
end

-- Seconds since the last completed scan, or nil when there never was one.
function FWR:GetAuctionSyncAgeSeconds()
    local store = self:GetAuctionDataStore()
    local lastSync = tonumber(store.lastSyncTime)
    -- a "scan" that priced nothing (earlier builds) does not count as a scan
    if not lastSync or (tonumber(store.lastSyncCount) or 0) <= 0 then
        return nil
    end
    return math.max(0, time() - lastSync)
end

-- Text and colour for the scanner indicator:
--   blue    scanning, with progress
--   green   prices are newer than the update interval
--   yellow  older than the interval, up to twice the interval
--   red     older than that, or never scanned
function FWR:GetAuctionSyncAgeText()
    if scan.running then
        if scan.expected > 0 then
            local percent = math.min(99, math.floor((scan.found / scan.expected) * 100))
            return string.format("Now scanning... %d%%", percent), 0.4, 0.8, 1
        end
        return string.format("Now scanning... %d items", scan.found), 0.4, 0.8, 1
    end

    local age = self:GetAuctionSyncAgeSeconds()
    if not age then
        return "AH prices: not scanned yet", 1, 0.3, 0.3
    end

    local minutes = math.floor(age / 60)
    local hours = math.floor(minutes / 60)
    local text
    if hours >= 24 then
        text = string.format("AH prices: %dd %dh old", math.floor(hours / 24), hours % 24)
    elseif hours > 0 then
        text = string.format("AH prices: %dh %02dm old", hours, minutes % 60)
    else
        text = string.format("AH prices: %dm old", minutes)
    end

    local limit = self:GetAuctionFreshnessMinutes() * 60
    if age <= limit then
        return text, 0.3, 1, 0.3
    elseif age <= limit * 2 then
        return text, 1, 0.85, 0.2
    end
    return text, 1, 0.3, 0.3
end

-- Whether a scan is running, how far it is (0-99, or nil when the size is not known yet, the first scan)
-- and how many items it has found so far.
function FWR:GetAuctionScanProgress()
    if not scan.running then
        return false, nil, 0
    end
    if scan.expected > 0 then
        return true, math.min(99, math.floor((scan.found / scan.expected) * 100)), scan.found
    end
    return true, nil, scan.found
end

function FWR:GetAuctionScanMinimumMinutes()
    return math.floor(MIN_SECONDS_BETWEEN_SCANS / 60)
end

-- "trade", "commodities" or "full"
local function scanLevel(self)
    local settings = getSettings(self)
    if settings.fullScan == true then
        return "full"
    elseif settings.scanCommodities ~= false then
        return "commodities"
    end
    return "trade"
end

local LEVEL_TEXT = {
    trade = "trade materials only",
    commodities = "trade materials and everything sold by amount",
    full = "whole Auction House",
}

-- All trade materials of every expansion, or everything when the whole-Auction-House option is on.
-- The game returns nothing when the "current expansion" filter is combined with an item class, so
-- the Advisor filters by expansion itself.
local function buildQuery(self)
    local sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0

    return {
        searchString = "",
        sorts = { { sortOrder = sortOrder, reverseSort = false } },
        filters = {},
        itemClassFilters = scan.classes and { { classID = scan.classes[scan.classIndex] } } or nil,
        separateOwnerItems = false,
    }
end

-- The Advisor works out all its places and items again when it is refreshed, which is a lot of work while a scan
-- sends a new batch every fraction of a second. While a scan runs it is refreshed at most once a second; the
-- last state is always shown (a refresh is kept for the end of the pause).
local ADVISOR_REFRESH_SECONDS = 1
local advisorRefreshedAt = -100
local advisorRefreshWaiting = false

local function refreshAdvisorThrottled(self)
    if not self.RefreshAdvisorPanel then
        return
    end

    local waited = GetTime() - advisorRefreshedAt
    if not scan.running or waited >= ADVISOR_REFRESH_SECONDS then
        advisorRefreshedAt = GetTime()
        self:RefreshAdvisorPanel()
        return
    end

    if not advisorRefreshWaiting then
        advisorRefreshWaiting = true
        C_Timer.After(ADVISOR_REFRESH_SECONDS - waited, function()
            advisorRefreshWaiting = false
            advisorRefreshedAt = GetTime()
            if FWR.RefreshAdvisorPanel then
                FWR:RefreshAdvisorPanel()
            end
        end)
    end
end

local function refreshPanels(self)
    -- other parts (the Auction House tab) follow the scan through this one announcement
    if self.Emit then
        self:Emit("auctionScanChanged")
    end
    refreshAdvisorThrottled(self)
    if self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end
end

local function abortScan(self, message)
    scan.running = false
    scan.pendingStart = false
    say(message)
    refreshPanels(self)
end

-- The game also sends its own queries when the Auction House opens. Unless the whole Auction House is read,
-- only a list made purely of the class we asked for can be the answer to our query; anything else is ignored.
local function isExpectedList(self, results)
    if #results == 0 then
        -- a later class with nothing for sale is a real answer (the first class never is empty)
        return scan.classes ~= nil and scan.classIndex > 1 and #scan.collected > 0
            and C_AuctionHouse.HasFullBrowseResults() == true
    end

    if not scan.classes then
        return true
    end

    local wanted = scan.classes[scan.classIndex]
    for _, result in ipairs(results) do
        local itemID = result.itemKey and result.itemKey.itemID
        if not itemID then
            return false
        end
        local classID = select(6, GetItemInfoInstant(itemID))
        if classID ~= wanted then
            return false
        end
    end
    return true
end

local sendQuery
local sendNextClassQuery

-- Watchdog: every sign of life re-arms it. If nothing happens in time the whole scan is started again
-- (another addon may have replaced the query, or the game was busy), up to MAX_ATTEMPTS times, and
-- then it gives up with a message that says how far it got.
local function watch(self, seconds)
    scan.activity = scan.activity + 1
    local seen = scan.activity

    C_Timer.After(seconds or RESULT_TIMEOUT_SECONDS, function()
        if not scan.running or scan.activity ~= seen then
            return
        end

        if scan.attempt < MAX_ATTEMPTS then
            scan.attempt = scan.attempt + 1
            sendQuery(FWR)
        elseif scan.gotResults then
            abortScan(FWR, string.format("The Auction House stopped answering after %d items. Prices were not updated (/fw scan to try again).", scan.found))
        elseif scan.classes and scan.classIndex > 1 and #scan.collected > 0 then
            -- this class never answered: there is nothing of it for sale; go on with what the others gave
            if scan.classIndex < #scan.classes then
                scan.classIndex = scan.classIndex + 1
                scan.attempt = 1
                sendNextClassQuery(FWR, 1)
            else
                FWR:FinishAuctionScanFromCollected()
            end
        else
            abortScan(FWR, "The Auction House returned no items. Try again in a moment (/fw scan).")
        end
    end)
end

sendQuery = function(self)
    scan.gotResults = false

    local ok, err = pcall(C_AuctionHouse.SendBrowseQuery, buildQuery(self))
    if not ok then
        abortScan(self, "The Auction House scan could not start: " .. tostring(err))
        return false
    end

    watch(self)
    return true
end

-- The game only accepts the next request when it says it is ready.
local function requestMore(self, tries)
    if not scan.running then
        return
    end

    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        if tries < MORE_RESULTS_RETRY_LIMIT then
            C_Timer.After(MORE_RESULTS_RETRY_SECONDS, function()
                requestMore(FWR, tries + 1)
            end)
        end
        return
    end

    C_AuctionHouse.RequestMoreBrowseResults()
end

local function startNow(self)
    scan.pendingStart = false
    scan.running = true
    scan.found = 0
    scan.expected = tonumber(self:GetAuctionDataStore().lastSyncCount) or 0
    scan.startedAt = GetTime()
    scan.attempt = 1
    scan.collected = {}
    scan.classIndex = 1
    local level = scanLevel(self)
    if level == "full" then
        scan.classes = nil
    elseif level == "commodities" then
        scan.classes = COMMODITY_CLASS_IDS
    else
        scan.classes = { TRADEGOODS_CLASS_ID }
    end
    -- the size of the last scan only helps when it was a scan of this level
    if self:GetAuctionDataStore().lastScanLevel ~= level then
        scan.expected = 0
    end

    if sendQuery(self) then
        say("Auction House scan started (" .. LEVEL_TEXT[level] .. "). Keep the Auction House open until it finishes. " .. self:GetAuctionScanEstimateText())
        refreshPanels(self)
    end
end

-- The game limits how fast Auction House queries may be sent; wait until it allows one.
local function startWhenReady(self, attempt)
    if not auctionHouseOpen or scan.running then
        scan.pendingStart = false
        return
    end

    if not C_AuctionHouse.IsThrottledMessageSystemReady or C_AuctionHouse.IsThrottledMessageSystemReady() then
        startNow(self)
        return
    end

    scan.pendingStart = true
    if attempt >= THROTTLE_RETRY_LIMIT then
        scan.pendingStart = false
        say("The Auction House is busy right now. Try the scan again in a moment.")
        return
    end

    C_Timer.After(THROTTLE_RETRY_SECONDS, function()
        startWhenReady(FWR, attempt + 1)
    end)
end

-- Starts a scan. Returns false when it cannot start (not at the Auction House, already running).
function FWR:StartAuctionScan()
    if scan.running then
        say("An Auction House scan is already running.")
        return false
    end

    local cooldown = self:GetAuctionScanCooldownSeconds()
    if cooldown > 0 then
        say(string.format("The prices are still fresh. A new scan is possible in %d minutes.", math.ceil(cooldown / 60)))
        return false
    end

    if not auctionHouseOpen or type(C_AuctionHouse) ~= "table" then
        say("Open the Auction House first, then start the scan.")
        return false
    end

    startWhenReady(self, 1)
    return true
end

local function finishScan(self, results)
    local items = {}
    local priced = 0
    local now = time()

    for _, result in ipairs(results) do
        local itemID = result.itemKey and result.itemKey.itemID
        local price = tonumber(result.minPrice)
        local forSale = result.totalQuantity == nil or result.totalQuantity ~= 0
        if itemID and price and price > 0 and forSale and not items[tostring(itemID)] then
            items[tostring(itemID)] = { itemID = itemID, unitPrice = price, lastSeen = now }
            priced = priced + 1
        end
    end

    if priced == 0 then
        abortScan(self, "The Auction House scan found no prices. Try again in a moment (/fw scan).")
        return
    end

    local seconds = math.max(1, math.floor(GetTime() - scan.startedAt))
    local store = self:GetAuctionDataStore()
    store.items = items
    store.lastSyncTime = now
    store.lastSyncCount = priced
    store.lastScanSeconds = seconds
    store.lastScanLevel = scanLevel(self)

    scan.running = false
    if self.Emit then
        self:Emit("auctionScanFinished", items, now)
    end
    say(string.format("Auction House scan complete: %d items priced in %d seconds.", priced, seconds))

    playFinishedSound(getSettings(self))
    refreshPanels(self)
end

sendNextClassQuery = function(self, tries)
    if not scan.running then
        return
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady()
        and tries < MORE_RESULTS_RETRY_LIMIT then
        watch(self, BATCH_TIMEOUT_SECONDS)
        C_Timer.After(MORE_RESULTS_RETRY_SECONDS, function()
            sendNextClassQuery(FWR, tries + 1)
        end)
        return
    end
    sendQuery(self)
end

function FWR:FinishAuctionScanFromCollected()
    if scan.running then
        finishScan(self or FWR, scan.collected)
    end
end

local function handleBrowseResults(self)
    if not scan.running then
        return
    end

    local results = C_AuctionHouse.GetBrowseResults() or {}
    if not isExpectedList(self, results) then
        return
    end

    scan.gotResults = true
    scan.found = #scan.collected + #results

    if C_AuctionHouse.HasFullBrowseResults() then
        for _, result in ipairs(results) do
            scan.collected[#scan.collected + 1] = result
        end

        -- another class to read: ask for it (the game accepts the next query only when it says it is ready)
        if scan.classes and scan.classIndex < #scan.classes then
            scan.classIndex = scan.classIndex + 1
            scan.attempt = 1
            sendNextClassQuery(self, 1)
            refreshPanels(self)
            return
        end

        finishScan(self, scan.collected)
        return
    end

    watch(self, BATCH_TIMEOUT_SECONDS)
    requestMore(self, 1)
    refreshPanels(self)
end

-- The options of the Scanner page decide: a scan is due when "Scan automatically" is on and the prices are
-- older than the chosen interval (or there never was one). The AH Tab has nothing to do with it.
local function autoScanIsDue(self)
    if getSettings(self).autoScan == false then
        return false
    end
    local age = self:GetAuctionSyncAgeSeconds()
    return self:GetAuctionScanCooldownSeconds() == 0 and (age == nil or age >= self:GetAuctionFreshnessMinutes() * 60)
end

-- While the Auction House stays open the prices get old: as soon as they are older than the chosen interval
-- a new scan starts by itself, without waiting for the window to be opened again. Looked at
-- every few seconds; after an attempt that did not get to scan there is a pause before the next one.
local AUTO_CHECK_SECONDS = 5
local AUTO_RETRY_SECONDS = 30
local autoTicker
local lastAutoAttempt = -AUTO_RETRY_SECONDS

local function startAutoCheck()
    if autoTicker then
        return
    end
    autoTicker = C_Timer.NewTicker(AUTO_CHECK_SECONDS, function()
        if not auctionHouseOpen or scan.running or scan.pendingStart or not autoScanIsDue(FWR) then
            return
        end
        if GetTime() - lastAutoAttempt < AUTO_RETRY_SECONDS then
            return
        end
        lastAutoAttempt = GetTime()
        FWR:StartAuctionScan()
    end)
end

-- Single entry point for every Auction House event; the main file decides when it is called.
function FWR:HandleAuctionHouseEvent(event)
    if event == "AUCTION_HOUSE_SHOW" then
        auctionHouseOpen = true
        startAutoCheck()
        if autoScanIsDue(self) then
            C_Timer.After(START_DELAY_SECONDS, function()
                if auctionHouseOpen and not scan.running then
                    FWR:StartAuctionScan()
                end
            end)
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        auctionHouseOpen = false
        scan.pendingStart = false
        if scan.running then
            abortScan(self, "The Auction House was closed before the scan finished. Prices were not updated.")
            return
        end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        handleBrowseResults(self)
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        if scan.running then
            abortScan(self, "The Auction House scan failed. Prices were not updated.")
            return
        end
    end

    refreshPanels(self)
end
