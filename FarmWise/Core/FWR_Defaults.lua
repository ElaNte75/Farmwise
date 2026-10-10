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
        freshnessMinutes = 30,
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
