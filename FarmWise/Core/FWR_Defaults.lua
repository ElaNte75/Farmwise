local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- The version comes from the "## Version:" line of FarmWise.toc, for example "3.0.1" or "3.0.1 beta".
-- The first word is the number; any words after it (like "beta") are the release stage, shown next to the
-- number in the main window. Remove them from the toc line and they disappear from the window too.
local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local rawVersion = type(getMetadata) == "function" and getMetadata("FarmWise", "Version") or ""
local versionNumber, versionStage = tostring(rawVersion):match("^%s*(%S+)%s*(.-)%s*$")
FWR.VERSION = versionNumber or "?"
FWR.RELEASE_STAGE = (versionStage and versionStage ~= "") and versionStage:upper() or nil
FWR.DB_VERSION = 1
FWR.BUILD_NAME = "FarmWise_" .. FWR.VERSION

FWR.DEFAULT_SETTINGS = {
    ui = {
        lockMainWindow = false,
        autoLockMainWindow = true,
        keepColumnWidths = true,
        mainWindowMinimized = false,
        minimizeCorner = "BOTTOMLEFT",   -- where the minimized window's button sits, on the window
        floatLootText = true,            -- while minimized: the looted items rise from the small button
        lootAlertGold = 100,             -- gold (50 to 1000): a loot worth this much or more comes bigger and with a sound
        lootAlertSound = true,           -- the sound of that alert
        showMainWindowOnGameLoad = true,
        mainWindowVisible = true,
        launcherMinimap = {
            hide = false,
            angle = 220,
        },
        hideMainWindowInCombat = false,
        restoreMainWindowAfterCombat = false,   -- after the fight the window opens again (off: it stays a small button)
        hideControlPanelsInCombat = true,
        restoreControlPanelsAfterCombat = true,
        mainFramePosition = nil,
        showTooltips = true,
        showMainFrameTooltips = true,
    },
    display = {
        visibleRows = 5,
        frameTransparency = 50,
        columnWidthMemory = {},   -- the widest width each column has needed (kept between sessions)
        optionalColumns = {
            quantity = true,
            total = true,
            itemPerHour = true,
            activity = true,
            itemType = false,
            classification = false,
            expansion = false,
            zone = false,
            subZone = false,
            character = false,
            price = false,
            value = false,
        },
        columnOrder = {
            quantity = 2,
            total = 3,
            itemPerHour = 4,
            activity = 5,
            itemType = 6,
            classification = 7,
            expansion = 8,
            zone = 9,
            subZone = 10,
            character = 11,
            price = 12,
            value = 13,
        },
    },
    displayFilters = {
        showSpecializedClassifications = false,
        onlySpecializedClassifications = false,
        showOldExpansions = false,
    },
    tracking = {
        combinedAllData = false,
        combinedCharacterAllZones = false,
        zoneData = false,
        subZoneData = true,
        gatheringWholeZone = true,   -- mining, herbalism, fishing and skinning count for the whole zone, not the sub-zone
    },
    ah = {
        autoScan = true,
        sound = true,
        tooltipPrice = true,
        fullScan = false,
        scanCommodities = true,    -- the scan also reads the commodities (everything else that is sold by amount)
        freshnessMinutes = 30,
        -- the FarmWise tab of the Auction House
        tabOnlyFarmed = false,      -- the list: only what you have farmed (off: everything that can be sold)
        tabShowTrade = true,        -- the list: trade materials
        tabShowConsumables = true,  -- the list: consumables (potions, flasks, food, runes)
        tabShowGems = true,         -- the list: gems and enhancements
        tabShowOther = true,        -- the list: any other commodity
        tabWheel = false,       -- the mouse wheel posts the next item, while the tab is open
        tabWheelShift = true,   -- ... but only while Shift is held (so a scroll by accident posts nothing)
        tabTooltips = true,     -- the tooltips of the tab
        tabPriceAutoFix = false,  -- the price check raises a price that is too low by itself (off: with the + button)
        tabPriceCheckLevel = 2,   -- how strict the price check is: 1 relaxed, 2 normal, 3 strict, 4 very strict
        tabVendorCoin = true,   -- a gold coin on the items in the bags that a vendor pays more for than the Auction House
        tabOpenFirst = true,    -- the FarmWise tab is the page that is shown when the Auction House opens
        tabEnabled = true,      -- the tab is there at all (off: none of what it brings is on)
        tabPostTime = 1,        -- 1 = 12 hours, 2 = 24 hours, 3 = 48 hours
        tabPriceCheck = false,  -- price check on for all items (an item can differ)
        tabAverageSales = 10,    -- the average price is made of this many of the last sales (5 to 30)
        tabAverageFloor = false, -- never post below the average price of your last sales (an item can differ)
        tabPriceStep = 5,       -- the "+" and "-" of the price change it by this many percent (1 to 20)
        tabShowTrend = true,    -- the Trend column (after a /reload)
        tabShowValue = true,    -- the Value column (after a /reload)
        tabHistory = true,      -- keep a history of the sales and show its page in the tab
    },
    engine = {
        sessionResetMode = "manual",
        localResetMinutes = 0,
        autoResetDelaySeconds = 30,
        rarityLevel = 1,
        rarityFilterEnabled = false,
    },
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nested in pairs(value) do
        copy[deepCopy(key)] = deepCopy(nested)
    end
    return copy
end

function FWR:DeepCopy(value)
    return deepCopy(value)
end

function FWR:MergeDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = self:MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function FWR:Now()
    return time()
end
