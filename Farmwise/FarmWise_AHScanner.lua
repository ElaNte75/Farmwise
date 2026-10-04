FarmWise = FarmWise or {}

local CALLER_ID = "FarmWise"

local function HasAuctionator()
    return Auctionator and Auctionator.API and Auctionator.API.v1 and type(Auctionator.API.v1.GetAuctionPriceByItemID) == "function"
end

local function GetDB()
    if FarmWise.GetAuctionDataStore then
        return FarmWise.GetAuctionDataStore()
    end
    FarmWiseDB = FarmWiseDB or {}
    FarmWiseDB._ah = FarmWiseDB._ah or { items = {}, lastSyncTime = nil, lastSyncCount = 0 }
    FarmWiseDB._ah.items = FarmWiseDB._ah.items or {}
    return FarmWiseDB._ah
end

local function SetButtonText(textValue)
    if FarmWise.SetAHScanButtonText then
        FarmWise.SetAHScanButtonText(textValue)
    end
end

local function ShowInfoPanel()
    if FarmWise.ShowInfoSidePanel then
        FarmWise.ShowInfoSidePanel(
            "Action House Synchronization",
            "Open the Action House and refresh Auctionator.",
            [[Steps:
1. Go to an Auction House NPC.
2. Open the Action House.
3. Open the Auctionator tab.
4. Run Auctionator Full Scan.
5. Return to FarmWise and click Action House Synchronization.]]
        )
    end
end

local function CollectTrackedItemIDs()
    local ids, seen = {}, {}
    FarmWiseDB = FarmWiseDB or {}
    for zoneName, zoneData in pairs(FarmWiseDB) do
        if type(zoneData) == "table" and zoneData.items then
            for _, info in pairs(zoneData.items) do
                local itemID = tonumber(info.id)
                if itemID and not seen[itemID] then
                    seen[itemID] = true
                    table.insert(ids, itemID)
                end
            end
        end
    end
    table.sort(ids)
    return ids
end

function FarmWise.RefreshAHSyncButtonState()
    SetButtonText("AH Sync")
    if not FarmWiseFrame or not FarmWiseFrame.utilityAHScanButton then
        return
    end
    if HasAuctionator() then
        FarmWiseFrame.utilityAHScanButton:Enable()
        FarmWiseFrame.utilityAHScanButton:SetAlpha(1)
    else
        FarmWiseFrame.utilityAHScanButton:Disable()
        FarmWiseFrame.utilityAHScanButton:SetAlpha(0.45)
    end
end

function FarmWise.StartAuctionHouseScan()
    if not HasAuctionator() then
        return
    end

    if not (FarmWise.IsAuctionHouseOpen and FarmWise.IsAuctionHouseOpen()) then
        ShowInfoPanel()
        return
    end

    if FarmWise.HideInfoSidePanel then
        FarmWise.HideInfoSidePanel()
    end

    local ids = CollectTrackedItemIDs()
    local db = GetDB()
    db.items = {}

    local imported, total = 0, #ids
    for _, itemID in ipairs(ids) do
        local price = Auctionator.API.v1.GetAuctionPriceByItemID(CALLER_ID, itemID)
        if price and price > 0 then
            db.items[tostring(itemID)] = { itemID = itemID, unitPrice = price, lastSeen = time() }
            imported = imported + 1
        end
    end

    db.lastSyncTime = time()
    db.lastSyncCount = imported
    db.lastSyncTotal = total
    db.lastTooltipMessage = string.format("Tracked item prices: %d/%d", imported, total)

    if FarmWise.UpdateAHFreshnessIndicator then
        FarmWise.UpdateAHFreshnessIndicator()
    end

    print(string.format("FarmWise: Synchronized %d/%d tracked items from Auctionator.", imported, total))
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if FarmWise.RefreshAHSyncButtonState then
        FarmWise.RefreshAHSyncButtonState()
    end
end)
