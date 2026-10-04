local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Advisor store.
-- Keeps farming statistics in the original FarmWise data format (FarmWiseDB) so that
-- statistics collected by older FarmWise versions keep working without any conversion.
--
--   FarmWiseDB["Zone - SubZone"] = {
--       items = { ["itemID|Qn"] = { id, name, count, quality, itemQuality, exp, prof } },
--       gold = copper, time = seconds,
--       daily = { date, items = { key = count }, gold, time },
--       zone = "Zone", subzone = "SubZone",   -- added by this version, absent in old entries
--   }
--   FarmWiseDB._ah       = Auctionator price snapshot (same shape as before)
--   FarmWiseDB._settings = old FarmWise settings (left untouched)
--   FarmWiseDB._advisor  = Advisor preferences (this version)
--
-- Every key starting with "_" is metadata and is never treated as a zone.

FWR.ADVISOR_MIN_SECONDS = 15 * 60

local DEFAULT_ADVISOR_SETTINGS = {
    aggregate = "zone",            -- "zone" or "subzone"
    currentExpansionOnly = true,   -- ignore items older than the current expansion
    professionFilter = true,       -- only show categories matching the character's professions
}

-- Profession skill line IDs.
local SKILL_TAILORING = 197
local SKILL_SKINNING = 393
local SKILL_MINING = 186
local SKILL_HERBALISM = 182
local SKILL_FISHING = 356

-- Trade goods (item class 7) subclass -> professions that can obtain it.
local SUBCLASS_PROFESSIONS = {
    [5] = { SKILL_TAILORING },                        -- Cloth
    [6] = { SKILL_SKINNING },                         -- Leather
    [7] = { SKILL_MINING },                           -- Metal & Stone
    [8] = { SKILL_FISHING, SKILL_SKINNING },          -- Cooking (fish and meat)
    [9] = { SKILL_HERBALISM },                        -- Herb
}

local todayKeyCache = nil
local todayKeyCheckedAt = 0

local function getTodayKey()
    local now = time()
    if not todayKeyCache or now - todayKeyCheckedAt >= 30 then
        todayKeyCache = date("%Y-%m-%d")
        todayKeyCheckedAt = now
    end
    return todayKeyCache
end

local function isMetaKey(key)
    return type(key) == "string" and key:sub(1, 1) == "_"
end

local function buildZoneKey(zone, subzone)
    if subzone and subzone ~= "" and subzone ~= zone then
        return zone .. " - " .. subzone
    end
    return zone
end

local function getLiveZone()
    local zone = type(GetZoneText) == "function" and GetZoneText() or ""
    local subzone = type(GetSubZoneText) == "function" and GetSubZoneText() or ""
    if zone == nil or zone == "" then
        zone = "Unknown"
    end
    return zone, subzone or ""
end

function FWR:EnsureAdvisorStore()
    if type(FarmWiseDB) ~= "table" then
        FarmWiseDB = {}
    end

    local settings = FarmWiseDB._advisor
    if type(settings) ~= "table" then
        settings = {}
        FarmWiseDB._advisor = settings
    end

    for key, value in pairs(DEFAULT_ADVISOR_SETTINGS) do
        if settings[key] == nil then
            settings[key] = value
        end
    end

    return FarmWiseDB, settings
end

function FWR:GetAdvisorSettings()
    local _, settings = self:EnsureAdvisorStore()
    return settings
end

local function ensureZoneData(zoneKey, zone, subzone)
    local db = FWR:EnsureAdvisorStore()
    local data = db[zoneKey]
    if type(data) ~= "table" then
        data = {}
        db[zoneKey] = data
    end

    data.items = data.items or {}
    data.gold = tonumber(data.gold) or 0
    data.time = tonumber(data.time) or 0
    data.daily = data.daily or {}
    if data.daily.date ~= getTodayKey() then
        data.daily = { date = getTodayKey(), items = {}, gold = 0, time = 0 }
    end
    data.daily.items = data.daily.items or {}
    data.daily.gold = tonumber(data.daily.gold) or 0
    data.daily.time = tonumber(data.daily.time) or 0

    if zone and not data.zone then
        data.zone = zone
        data.subzone = subzone or ""
    end

    return data
end

function FWR:GetAdvisorStatus()
    local db = self:EnsureAdvisorStore()
    local zones, items = 0, 0
    local seen = {}
    for key, data in pairs(db) do
        if not isMetaKey(key) and type(data) == "table" and type(data.items) == "table" then
            zones = zones + 1
            for _, info in pairs(data.items) do
                if info.id and not seen[info.id] then
                    seen[info.id] = true
                    items = items + 1
                end
            end
        end
    end
    return { zones = zones, items = items }
end

-- Erases every zone entry. Advisor preferences, old settings and the AH price snapshot stay.
function FWR:ClearAdvisorData()
    local db = self:EnsureAdvisorStore()
    for key in pairs(db) do
        if not isMetaKey(key) then
            db[key] = nil
        end
    end
end

-- Called for every loot entry that passed the Reforged filters.
function FWR:RecordAdvisorItem(entry, quantity)
    if type(entry) ~= "table" then
        return
    end

    local itemID = tonumber(entry.itemID)
    if not itemID then
        return
    end

    local amount = tonumber(quantity) or 1
    if amount < 1 then
        amount = 1
    end

    local zone, subzone = getLiveZone()
    local data = ensureZoneData(buildZoneKey(zone, subzone), zone, subzone)

    local tier = tonumber(entry.itemQuality)
    local label = "Q" .. ((tier and tier > 0) and tier or 1)
    local key = itemID .. "|" .. label

    local info = data.items[key]
    if not info then
        info = {
            id = itemID,
            name = entry.itemName,
            count = 0,
            quality = label,
            itemQuality = entry.itemRarity,
        }
        data.items[key] = info
    end

    info.name = entry.itemName or info.name
    info.exp = tonumber(entry.expansionID) or info.exp
    info.prof = entry.baseProfession or info.prof
    info.count = (tonumber(info.count) or 0) + amount
    data.daily.items[key] = (data.daily.items[key] or 0) + amount
end

-- Called with the number of seconds of active farming time.
function FWR:RecordAdvisorTime(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then
        return
    end

    local zone, subzone = getLiveZone()
    local data = ensureZoneData(buildZoneKey(zone, subzone), zone, subzone)
    data.time = data.time + seconds
    data.daily.time = data.daily.time + seconds
end

function FWR:RecordAdvisorGold(copper)
    copper = tonumber(copper) or 0
    if copper <= 0 then
        return
    end

    local zone, subzone = getLiveZone()
    local data = ensureZoneData(buildZoneKey(zone, subzone), zone, subzone)
    data.gold = data.gold + copper
    data.daily.gold = data.daily.gold + copper
end

------------------------------------------------------------
-- Item classification helpers
------------------------------------------------------------

local function getCurrentExpansion()
    if type(GetExpansionLevel) == "function" then
        return tonumber(GetExpansionLevel())
    end
    return nil
end

local function resolveItemExpansion(info)
    if info.exp ~= nil then
        return info.exp
    end

    local itemID = tonumber(info.id)
    if not itemID then
        return nil
    end

    local expansion = select(15, GetItemInfo(itemID))
    if expansion == nil then
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
        return nil
    end

    info.exp = expansion
    return expansion
end

local function getKnownProfessionSkillLines()
    local known = {}
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return nil
    end

    local indexes = { GetProfessions() }
    for slot = 1, 6 do
        local index = indexes[slot]
        if index then
            local skillLine = select(7, GetProfessionInfo(index))
            if skillLine then
                known[skillLine] = true
            end
        end
    end
    return known
end

local function itemMatchesProfessions(info, known)
    if not known then
        return true
    end

    local itemID = tonumber(info.id)
    if not itemID or type(GetItemInfoInstant) ~= "function" then
        return true
    end

    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    if classID ~= 7 then
        return true
    end

    local professions = SUBCLASS_PROFESSIONS[subClassID]
    if not professions then
        return true -- elementals, enchanting and other categories are always shown
    end

    for _, skillLine in ipairs(professions) do
        if known[skillLine] then
            return true
        end
    end
    return false
end

local function zoneOfKey(key, data)
    if type(data) == "table" and type(data.zone) == "string" and data.zone ~= "" then
        return data.zone
    end
    local zone = key:match("^(.-) %- ")
    return zone or key
end

------------------------------------------------------------
-- Queries
------------------------------------------------------------

-- Groups all stored data by zone or by subzone, according to the Advisor settings.
-- explicitItemID bypasses the expansion/profession filters for a specific item search.
local function buildGroups(explicitItemID)
    local db, settings = FWR:EnsureAdvisorStore()
    local currentExpansion = getCurrentExpansion()
    local known = settings.professionFilter and getKnownProfessionSkillLines() or nil
    local groups = {}

    for key, data in pairs(db) do
        if not isMetaKey(key) and type(data) == "table" and type(data.items) == "table" then
            local groupName = key
            if settings.aggregate == "zone" then
                groupName = zoneOfKey(key, data)
            end

            local group = groups[groupName]
            if not group then
                group = { name = groupName, time = 0, gold = 0, items = {} }
                groups[groupName] = group
            end

            group.time = group.time + (tonumber(data.time) or 0)
            group.gold = group.gold + (tonumber(data.gold) or 0)

            for itemKey, info in pairs(data.items) do
                local include = true
                if not explicitItemID then
                    if settings.currentExpansionOnly and currentExpansion then
                        local expansion = resolveItemExpansion(info)
                        include = expansion ~= nil and expansion >= currentExpansion
                    end
                    if include then
                        include = itemMatchesProfessions(info, known)
                    end
                end

                if include then
                    local merged = group.items[itemKey]
                    if not merged then
                        merged = { id = info.id, name = info.name, quality = info.quality, count = 0 }
                        group.items[itemKey] = merged
                    end
                    merged.count = merged.count + (tonumber(info.count) or 0)
                end
            end
        end
    end

    return groups
end

local function sortResults(results, valueField)
    table.sort(results, function(a, b)
        if a[valueField] == b[valueField] then
            return a.zone < b.zone
        end
        return a[valueField] > b[valueField]
    end)
    return results
end

local function cleanQueryText(text)
    local plain = tostring(text or "")
    plain = plain:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    plain = plain:gsub("|Hitem:.-|h(.-)|h", "%1")
    plain = plain:gsub("|h", ""):gsub("|A:.-|a", "")
    plain = plain:gsub("^%s*%[+", ""):gsub("%]+%s*$", "")
    plain = plain:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return plain
end

local function normalizeName(name)
    name = cleanQueryText(name)
    name = name:gsub("%s*%([Qq]%d+%)$", "")
    name = name:gsub("%s+[Qq]uality%s*%d+$", "")
    name = name:gsub("%s+[Qq]%d+$", "")
    return string.lower(name)
end

-- Returns itemID (may be nil), normalized name, quality label (may be nil).
function FWR:ParseAdvisorQuery(queryText)
    local raw = tostring(queryText or "")
    local itemID = tonumber(raw:match("item:(%d+)"))
    local plain = cleanQueryText(raw)

    local quality = plain:match("%(([Qq]%d+)%)$") or plain:match("%s([Qq]%d+)$")
    if quality then
        quality = string.upper(quality)
    end

    local name = normalizeName(plain)
    if itemID and type(GetItemInfo) == "function" then
        local resolved = GetItemInfo(itemID)
        if resolved then
            name = normalizeName(resolved)
        end
    end

    return itemID, name, quality
end

-- exactItemID / exactQuality come from a shift-clicked item link and take priority over
-- whatever can be parsed from the typed text.
function FWR:BuildAdvisorItemResults(queryText, exactItemID, exactQuality)
    local itemID, name, quality = self:ParseAdvisorQuery(queryText)
    itemID = exactItemID or itemID
    quality = exactQuality or quality
    if not itemID and (not name or name == "") then
        return {}
    end

    local results = {}
    for _, group in pairs(buildGroups(true)) do
        if group.time >= self.ADVISOR_MIN_SECONDS then
            local count = 0
            local matchedName = nil
            for _, info in pairs(group.items) do
                local matches
                if itemID then
                    matches = tonumber(info.id) == itemID
                else
                    matches = normalizeName(info.name) == name
                end
                if matches and quality then
                    matches = string.upper(info.quality or "") == quality
                end
                if matches then
                    count = count + info.count
                    matchedName = info.name
                end
            end

            if count > 0 then
                results[#results + 1] = {
                    zone = group.name,
                    totalTime = group.time,
                    count = count,
                    perHour = math.floor((count / group.time) * 3600),
                    itemName = matchedName,
                }
            end
        end
    end

    return sortResults(results, "perHour")
end

function FWR:BuildAdvisorGoldResults()
    local ahStore = FarmWiseDB and FarmWiseDB._ah
    local prices = type(ahStore) == "table" and ahStore.items or {}
    local results = {}

    for _, group in pairs(buildGroups(false)) do
        if group.time >= self.ADVISOR_MIN_SECONDS then
            local totalCopper, priced, tracked = 0, 0, 0
            for _, info in pairs(group.items) do
                local count = tonumber(info.count) or 0
                if count > 0 then
                    tracked = tracked + 1
                    local record = prices[tostring(info.id)]
                    local unitPrice = record and tonumber(record.unitPrice or record.price)
                    if unitPrice and unitPrice > 0 then
                        totalCopper = totalCopper + unitPrice * count
                        priced = priced + 1
                    end
                end
            end

            if priced > 0 then
                results[#results + 1] = {
                    zone = group.name,
                    totalTime = group.time,
                    goldPerHour = math.floor((totalCopper / group.time) * 3600),
                    pricedItems = priced,
                    trackedItems = tracked,
                }
            end
        end
    end

    return sortResults(results, "goldPerHour")
end

-- Item IDs that should be priced by the auction house sync.
function FWR:CollectAdvisorItemIDs()
    local ids, seen = {}, {}
    for _, group in pairs(buildGroups(false)) do
        for _, info in pairs(group.items) do
            local itemID = tonumber(info.id)
            if itemID and not seen[itemID] then
                seen[itemID] = true
                ids[#ids + 1] = itemID
            end
        end
    end
    table.sort(ids)
    return ids
end
