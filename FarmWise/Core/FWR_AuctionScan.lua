local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Auction House scan.
-- Reads the lowest price of every trade good (current expansion only when the game supports that
-- filter) straight from the Auction House and stores it in FarmWiseDB._ah, which the Advisor
-- uses for gold per hour. It runs automatically when the Auction House opens and the last scan
-- is older than the update interval chosen in the Auction House settings.

local PREFIX = "|cffd7be6aFarmWise|r "
local TRADEGOODS_CLASS_ID = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7

local START_DELAY_SECONDS = 0.5
local MIN_SECONDS_BETWEEN_SCANS = 15 * 60
local RESULT_TIMEOUT_SECONDS = 8
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
    gotResults = false,  -- real trade material results arrived
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

-- All trade materials of every expansion. The game returns nothing when the "current expansion"
-- filter is combined with an item class, so the Advisor filters by expansion itself.
local function buildQuery()
    local sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0

    return {
        searchString = "",
        sorts = { { sortOrder = sortOrder, reverseSort = false } },
        filters = {},
        itemClassFilters = { { classID = TRADEGOODS_CLASS_ID } },
        separateOwnerItems = false,
    }
end

local function refreshPanels(self)
    if self.RefreshAdvisorPanel then
        self:RefreshAdvisorPanel()
    end
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

-- The game also sends its own queries when the Auction House opens. Only a list made purely of
-- trade materials can be the answer to our query; anything else is ignored.
local function isTradeGoodsList(results)
    if #results == 0 then
        return false
    end

    for _, result in ipairs(results) do
        local itemID = result.itemKey and result.itemKey.itemID
        if not itemID then
            return false
        end
        local classID = select(6, GetItemInfoInstant(itemID))
        if classID ~= TRADEGOODS_CLASS_ID then
            return false
        end
    end
    return true
end

local sendQuery

-- Watchdog: every sign of life re-arms it. If nothing happens for RESULT_TIMEOUT_SECONDS the query is
-- repeated once (another addon may have replaced it) and then the scan gives up with a message.
local function watch(self)
    scan.activity = scan.activity + 1
    local seen = scan.activity

    C_Timer.After(RESULT_TIMEOUT_SECONDS, function()
        if not scan.running or scan.activity ~= seen then
            return
        end

        if not scan.gotResults and scan.attempt < 2 then
            scan.attempt = scan.attempt + 1
            sendQuery(FWR)
        elseif scan.gotResults then
            abortScan(FWR, "The Auction House stopped answering before the scan finished. Prices were not updated.")
        else
            abortScan(FWR, "The Auction House returned no trade materials. Try again in a moment (/fw scan).")
        end
    end)
end

sendQuery = function(self)
    scan.gotResults = false

    local ok, err = pcall(C_AuctionHouse.SendBrowseQuery, buildQuery())
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

    if sendQuery(self) then
        say("Auction House scan started (trade materials only). Keep the Auction House open until it finishes. " .. self:GetAuctionScanEstimateText())
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

    scan.running = false
    say(string.format("Auction House scan complete: %d materials priced in %d seconds.", priced, seconds))

    playFinishedSound(getSettings(self))
    refreshPanels(self)
end

local function handleBrowseResults(self)
    if not scan.running then
        return
    end

    local results = C_AuctionHouse.GetBrowseResults() or {}
    if not isTradeGoodsList(results) then
        return
    end

    scan.gotResults = true
    scan.found = #results

    if C_AuctionHouse.HasFullBrowseResults() then
        finishScan(self, results)
        return
    end

    watch(self)
    requestMore(self, 1)
    refreshPanels(self)
end

local function autoScanIsDue(self)
    local settings = getSettings(self)
    if settings.autoScan == false then
        return false
    end

    local age = self:GetAuctionSyncAgeSeconds()
    return self:GetAuctionScanCooldownSeconds() == 0 and (age == nil or age >= self:GetAuctionFreshnessMinutes() * 60)
end

-- Single entry point for every Auction House event; the main file decides when it is called.
function FWR:HandleAuctionHouseEvent(event)
    if event == "AUCTION_HOUSE_SHOW" then
        auctionHouseOpen = true
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
