local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- How long an auction can stay up. The game gives three choices (1, 2, 3); what they mean differs by version:
-- retail 12 / 24 / 48 hours, WoW Forever 2 / 8 / 24 hours.

local function isForever()
    local camelot = _G.WOW_PROJECT_CAMELOT or 18
    if _G.WOW_PROJECT_ID and _G.WOW_PROJECT_ID == camelot then
        return true
    end
    local interface = select(4, GetBuildInfo())
    interface = tonumber(interface) or 0
    return interface >= 16000 and interface < 17000
end

FWR.IS_FOREVER = isForever()
FWR.POST_HOURS = FWR.IS_FOREVER and { 2, 8, 24 } or { 12, 24, 48 }
