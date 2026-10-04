local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

FWR.VERSION = "2.1.3-engine-display-pass"
FWR.DB_VERSION = 1
FWR.BUILD_NAME = "FarmWiseReforged_2.1.3"

FWR.DEFAULT_SETTINGS = {
    ui = {
        lockMainWindow = false,
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
    engine = {
        sessionResetMode = "manual",
        localResetMinutes = 0,
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
