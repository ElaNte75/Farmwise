local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Auction house price sync. Prices come from Auctionator's last scan and are stored in
-- FarmWiseDB._ah (same shape as the original FarmWise) for the Advisor gold mode.

local CALLER_ID = "FarmWise"

FWR.AH_FRESHNESS_FRESH_SECONDS = 60 * 60
FWR.AH_FRESHNESS_STALE_SECONDS = 6 * 60 * 60

local auctionHouseOpen = false

local function hasAuctionator()
    return type(Auctionator) == "table"
        and type(Auctionator.API) == "table"
        and type(Auctionator.API.v1) == "table"
        and type(Auctionator.API.v1.GetAuctionPriceByItemID) == "function"
end

function FWR:HasAuctionator()
    return hasAuctionator()
end

function FWR:IsAuctionHouseOpen()
    return auctionHouseOpen == true
end

function FWR:GetAuctionDataStore()
    local db = self:EnsureAdvisorStore()
    db._ah = type(db._ah) == "table" and db._ah or {}
    db._ah.items = type(db._ah.items) == "table" and db._ah.items or {}
    return db._ah
end

-- Returns seconds since the last sync, or nil when never synced.
function FWR:GetAuctionSyncAgeSeconds()
    local store = self:GetAuctionDataStore()
    local lastSync = tonumber(store.lastSyncTime)
    if not lastSync then
        return nil
    end
    return math.max(0, time() - lastSync)
end

function FWR:GetAuctionSyncAgeText()
    local age = self:GetAuctionSyncAgeSeconds()
    if not age then
        return "AH prices: never synced", 1, 0.3, 0.3
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

    if age <= self.AH_FRESHNESS_FRESH_SECONDS then
        return text, 0.3, 1, 0.3
    elseif age <= self.AH_FRESHNESS_STALE_SECONDS then
        return text, 1, 0.85, 0.2
    end
    return text, 1, 0.3, 0.3
end

-- Copies prices from Auctionator for every tracked item. Requires the auction house
-- to be open, so the user has just refreshed Auctionator's data.
function FWR:SyncAuctionPrices()
    if not hasAuctionator() then
        print("|cffd7be6aFarmWise|r Auctionator is not installed or enabled.")
        return false
    end

    if not self:IsAuctionHouseOpen() then
        print("|cffd7be6aFarmWise|r Open the Auction House, run an Auctionator scan, then sync again.")
        return false
    end

    local ids = self:CollectAdvisorItemIDs()
    local store = self:GetAuctionDataStore()
    local items = {}
    local imported = 0

    for _, itemID in ipairs(ids) do
        local price = Auctionator.API.v1.GetAuctionPriceByItemID(CALLER_ID, itemID)
        if price and price > 0 then
            items[tostring(itemID)] = { itemID = itemID, unitPrice = price, lastSeen = time() }
            imported = imported + 1
        end
    end

    store.items = items
    store.lastSyncTime = time()
    store.lastSyncCount = imported
    store.lastSyncTotal = #ids

    print(string.format("|cffd7be6aFarmWise|r Synchronized %d/%d tracked item prices from Auctionator.", imported, #ids))

    if self.RefreshAdvisorPanel then
        self:RefreshAdvisorPanel()
    end
    return true
end

-- Called by the main file when the auction house window opens or closes.
function FWR:SetAuctionHouseOpen(isOpen)
    auctionHouseOpen = isOpen == true
end
