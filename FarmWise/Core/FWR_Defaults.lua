local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Newer game versions removed the global GetItemInfoInstant and keep it in C_Item only; the rest of the addon
-- still calls the global one, so it is put back here (this file loads first).
if type(GetItemInfoInstant) ~= "function" and C_Item and type(C_Item.GetItemInfoInstant) == "function" then
    GetItemInfoInstant = C_Item.GetItemInfoInstant
end
if type(GetItemInfo) ~= "function" and C_Item and type(C_Item.GetItemInfo) == "function" then
    GetItemInfo = C_Item.GetItemInfo
end
-- the new spell call gives one table; the old one gave name, rank, icon, cast time, ranges, id
if type(GetSpellInfo) ~= "function" and C_Spell and type(C_Spell.GetSpellInfo) == "function" then
    GetSpellInfo = function(spell)
        local info = C_Spell.GetSpellInfo(spell)
        if type(info) ~= "table" then
            return nil
        end
        return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID, info.originalIconID
    end
end

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
        showMainWindowOnGameLoad = true,
        mainWindowVisible = true,
        launcherMinimap = {
            hide = false,
            angle = 220,
        },
        hideMainWindowInCombat = false,
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
