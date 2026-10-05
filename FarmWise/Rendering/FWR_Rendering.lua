local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

local SHARED_REAGENT_PROFESSION_TOOLTIP = table.concat({
    "Crafting Reagent",
    "A crafting reagent used primarily by crafting professions to create high-level gear and items.",
}, "\n")

local function normalizeObservedSourceLabel(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end

    local lowered = string.lower(value)
    if lowered == "herbalism" then
        return "Herbalism"
    elseif lowered == "mining" then
        return "Mining"
    elseif lowered == "fishing" then
        return "Fishing"
    elseif lowered == "skinning" then
        return "Skinning"
    end

    return value
end

local function ensureObservedSourceTables(entry)
    if type(entry) ~= "table" then
        return {}, {}
    end

    entry.observedSourceOrder = type(entry.observedSourceOrder) == "table" and entry.observedSourceOrder or {}
    entry.observedSourceSet = type(entry.observedSourceSet) == "table" and entry.observedSourceSet or {}
    return entry.observedSourceOrder, entry.observedSourceSet
end

local function addObservedSource(entry, sourceLabel)
    sourceLabel = normalizeObservedSourceLabel(sourceLabel)
    if not sourceLabel then
        return false
    end

    local order, sourceSet = ensureObservedSourceTables(entry)
    if sourceSet[sourceLabel] then
        return false
    end

    sourceSet[sourceLabel] = true
    table.insert(order, sourceLabel)
    return true
end

local function buildObservedSourceTooltip(entry)
    local order = type(entry) == "table" and entry.observedSourceOrder or nil
    if type(order) ~= "table" or #order == 0 then
        return nil
    end

    local lines = { #order > 1 and "Observed sources for this reagent:" or "Observed source for this reagent:" }
    for _, label in ipairs(order) do
        table.insert(lines, "- " .. tostring(label))
    end
    return table.concat(lines, "\n")
end

local function applyDynamicSharedReagentState(entry)
    if type(entry) ~= "table" or entry.isDynamicSharedReagent ~= true then
        return
    end

    entry.itemTypeContext = "Reagent"
    entry.profession = "Multiple"
    entry.professionTooltipText = SHARED_REAGENT_PROFESSION_TOOLTIP
    entry.baseProfession = entry.baseProfession or "Multiple"

    local order = type(entry.observedSourceOrder) == "table" and entry.observedSourceOrder or nil
    local count = order and #order or 0
    entry.activityTooltipText = buildObservedSourceTooltip(entry)

    if count >= 2 then
        entry.activityKey = "multiple"
        entry.activityContext = "Multiple"
        entry.activitySource = "dynamic_shared_reagent_multiple"
        return
    end

    local firstSource = order and order[1] or nil
    if firstSource then
        entry.activityKey = string.lower(firstSource)
        entry.activityContext = firstSource
        entry.activitySource = "dynamic_shared_reagent_single"
    end
end

local function getClassColorValues(classFile)
    if type(classFile) ~= "string" or classFile == "" then
        return 0.85, 0.85, 0.85, 1
    end

    local colorTable = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if colorTable then
        return colorTable.r or 0.85, colorTable.g or 0.85, colorTable.b or 0.85, colorTable.a or 1
    end

    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFile)
        if color then
            if color.GetRGBA then
                return color:GetRGBA()
            end
            return color.r or 0.85, color.g or 0.85, color.b or 0.85, color.a or 1
        end
    end

    return 0.85, 0.85, 0.85, 1
end

local ROW_HEIGHT = 16
local DEFAULT_MAIN_VISIBLE_ROWS = 5
local DEFAULT_MAIN_TOP_PADDING = 2
local DEFAULT_MAIN_BOTTOM_PADDING = 4
local MAIN_SCROLL_TRAILING_PADDING = 10
local QUALITY_ONE_X_OFFSET = 0

local ESTIMATED_CHAR_WIDTH = 7
local MAIN_FRAME_SIDE_INSET = 8

local function estimateTextWidth(textValue)
    local text = tostring(textValue or "")
    if text == "" then
        return 0
    end
    return (string.len(text) * ESTIMATED_CHAR_WIDTH) + 8
end

local FULL_COLUMN_CONFIG = {
    item = { label = "Item Name", width = 130, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 0, dataInsetRight = 0 },
    quality = { label = "", width = 20, headerAlign = "CENTER", dataAlign = "CENTER", dataInsetLeft = 0, dataInsetRight = 0 },
    quantity = { label = "Quantity", width = 50, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 2 },
    total = { label = "Total", width = 50, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 2 },
    itemPerHour = { label = "Item / Hour", width = 78, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 2 },
    itemType = { label = "Reagent Type", width = 96, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    classification = { label = "Profession", width = 96, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    activity = { label = "Activity", width = 84, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    expansion = { label = "Expansion", width = 96, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    zone = { label = "Zone", width = 110, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    subZone = { label = "Sub-Zone", width = 110, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    character = { label = "Character", width = 128, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    price = { label = "Price", width = 84, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 4 },
    value = { label = "Value", width = 96, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 4 },
    gap = 2,
}



local DEFAULT_MAIN_COLUMN_CONFIG = {
    item = { label = "Item Name", width = 206, visible = true, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 0, dataInsetRight = 0 },
    quality = { label = "", width = 20, visible = true, headerAlign = "CENTER", dataAlign = "CENTER", dataInsetLeft = 0, dataInsetRight = 0 },
    quantity = { label = "Quantity", width = 54, visible = true, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 2 },
    total = { label = "Total", width = 54, visible = true, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 2 },
    itemPerHour = { label = "Item / Hour", width = 0, visible = false, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 2 },
    itemType = { label = "Reagent Type", width = 0, visible = false, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    classification = { label = "Profession", width = 0, visible = false, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    activity = { label = "Activity", width = 0, visible = false, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    expansion = { label = "Expansion", width = 0, visible = false, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    zone = { label = "Zone", width = 0, visible = false, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    subZone = { label = "Sub-Zone", width = 0, visible = false, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    character = { label = "Character", width = 0, visible = false, headerAlign = "LEFT", dataAlign = "LEFT", dataInsetLeft = 3, dataInsetRight = 3 },
    price = { label = "Price", width = 0, visible = false, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 4 },
    value = { label = "Value", width = 0, visible = false, headerAlign = "CENTER", dataAlign = "RIGHT", dataInsetLeft = 0, dataInsetRight = 4 },
    gap = 2,
}

local COLUMN_KEYS = {
    "item",
    "quality",
    "quantity",
    "total",
    "itemPerHour",
    "itemType",
    "classification",
    "activity",
    "expansion",
    "zone",
    "subZone",
    "character",
    "price",
    "value",
}

local function normalizeHeaderAlign(value, fallback)
    local align = type(value) == "string" and string.upper(value) or nil
    if align == "LEFT" or align == "CENTER" or align == "RIGHT" then
        return align
    end
    return fallback or "LEFT"
end

local function normalizeDataAlign(value, fallback)
    local align = type(value) == "string" and string.upper(value) or nil
    if align == "LEFT" or align == "CENTER" or align == "RIGHT" then
        return align
    end
    return fallback or "LEFT"
end

local function cloneColumnConfig(source)
    local result = { gap = tonumber(source and source.gap) or tonumber(DEFAULT_MAIN_COLUMN_CONFIG.gap) or 2 }
    for _, key in ipairs(COLUMN_KEYS) do
        local sourceColumn = type(source) == "table" and source[key] or nil
        local defaultColumn = DEFAULT_MAIN_COLUMN_CONFIG[key] or {}
        local visible = defaultColumn.visible
        if type(sourceColumn) == "table" and sourceColumn.visible ~= nil then
            visible = not not sourceColumn.visible
        end
        local width = tonumber(type(sourceColumn) == "table" and sourceColumn.width)
        if width == nil then
            width = tonumber(defaultColumn.width) or 0
        end
        if not visible then
            width = 0
        end
        result[key] = {
            label = (type(sourceColumn) == "table" and sourceColumn.label) or defaultColumn.label or "",
            width = width,
            visible = visible,
            headerAlign = normalizeHeaderAlign(type(sourceColumn) == "table" and (sourceColumn.headerAlign or sourceColumn.align) or defaultColumn.headerAlign, defaultColumn.headerAlign or "LEFT"),
            dataAlign = normalizeDataAlign(type(sourceColumn) == "table" and sourceColumn.dataAlign or defaultColumn.dataAlign, defaultColumn.dataAlign or "LEFT"),
            dataInsetLeft = math.max(0, tonumber(type(sourceColumn) == "table" and sourceColumn.dataInsetLeft) or tonumber(defaultColumn.dataInsetLeft) or 0),
            dataInsetRight = math.max(0, tonumber(type(sourceColumn) == "table" and sourceColumn.dataInsetRight) or tonumber(defaultColumn.dataInsetRight) or 0),
        }
    end
    return result
end

local function cloneMainLayoutConfig(source)
    local layout = type(source) == "table" and source or {}
    return {
        visibleRows = math.max(1, math.floor(tonumber(layout.visibleRows) or DEFAULT_MAIN_VISIBLE_ROWS)),
        rowHeight = math.max(12, math.floor(tonumber(layout.rowHeight) or ROW_HEIGHT)),
        topPadding = math.max(0, math.floor(tonumber(layout.topPadding) or DEFAULT_MAIN_TOP_PADDING)),
        bottomPadding = math.max(0, math.floor(tonumber(layout.bottomPadding) or DEFAULT_MAIN_BOTTOM_PADDING)),
    }
end

local function getRowHeight(frame)
    if type(frame) == "table" and type(frame.renderLayoutConfig) == "table" then
        return math.max(12, tonumber(frame.renderLayoutConfig.rowHeight) or ROW_HEIGHT)
    end
    return ROW_HEIGHT
end

local function getVerticalPadding(frame)
    local layout = type(frame) == "table" and type(frame.renderLayoutConfig) == "table" and frame.renderLayoutConfig or nil
    return math.max(0, tonumber(layout and layout.topPadding) or DEFAULT_MAIN_TOP_PADDING), math.max(0, tonumber(layout and layout.bottomPadding) or DEFAULT_MAIN_BOTTOM_PADDING)
end

local function getColumnHeaderAlign(config, key, fallback)
    local column = type(config) == "table" and config[key] or nil
    if type(column) == "table" then
        return normalizeHeaderAlign(column.headerAlign or column.align, fallback)
    end
    return fallback or "LEFT"
end

local function getColumnDataAlign(config, key, fallback)
    local column = type(config) == "table" and config[key] or nil
    if type(column) == "table" then
        return normalizeDataAlign(column.dataAlign, fallback)
    end
    return fallback or "LEFT"
end

local function getColumnDataInset(config, key, side)
    local column = type(config) == "table" and config[key] or nil
    if type(column) ~= "table" then
        return 0
    end
    if side == "RIGHT" then
        return math.max(0, tonumber(column.dataInsetRight) or 0)
    end
    return math.max(0, tonumber(column.dataInsetLeft) or 0)
end

-- Copper as "12 34 56" followed by the gold, silver and copper coin icons; gold is left out when there
-- is none, and once the first unit is shown every smaller unit follows (same rule as the tooltip price).
local function formatCopperText(copper)
    if not copper then
        return "-"
    end
    copper = math.floor(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100
    local g = "|TInterface/MoneyFrame/UI-GoldIcon:12:12:2:0|t"
    local s = "|TInterface/MoneyFrame/UI-SilverIcon:12:12:2:0|t"
    local c = "|TInterface/MoneyFrame/UI-CopperIcon:12:12:2:0|t"

    if gold > 0 then
        return string.format("%d%s %02d%s %02d%s", gold, g, silver, s, rest, c)
    elseif silver > 0 then
        return string.format("%d%s %02d%s", silver, s, rest, c)
    end
    return string.format("%d%s", rest, c)
end

-- The price text and the value text (price x session quantity) of a row.
local function getEntryPriceTexts(entry)
    local price = FWR.GetAuctionPrice and FWR:GetAuctionPrice(entry.itemID) or nil
    return formatCopperText(price), formatCopperText(price and price * (tonumber(entry.quantityCount) or 0) or nil)
end

local function getRenderConfigForFrame(frame)
    if type(frame) == "table" and type(frame.renderColumnConfig) == "table" then
        return frame.renderColumnConfig
    end
    return FULL_COLUMN_CONFIG
end

local DEFAULT_COLUMN_ORDER_KEYS = {
    "item",
    "quality",
    "quantity",
    "total",
    "itemPerHour",
    "itemType",
    "classification",
    "activity",
    "expansion",
    "zone",
    "subZone",
    "character",
    "price",
    "value",
}

local COLUMN_WIDTH_KEY_BY_KEY = {
    item = "name",
    quality = "quality",
    quantity = "quantity",
    total = "total",
    itemPerHour = "itemPerHour",
    itemType = "itemType",
    classification = "classification",
    activity = "activity",
    expansion = "expansion",
    zone = "zone",
    subZone = "subZone",
    character = "character",
    price = "price",
    value = "value",
}

local function getColumnOrderKeysForFrame(frame)
    if type(frame) == "table" and type(frame.columnOrderKeys) == "table" and #frame.columnOrderKeys > 0 then
        return frame.columnOrderKeys
    end
    if type(frame) == "table" and type(frame.renderColumnOrderKeys) == "table" and #frame.renderColumnOrderKeys > 0 then
        return frame.renderColumnOrderKeys
    end
    return DEFAULT_COLUMN_ORDER_KEYS
end

local function buildResolvedColumnLayout(widths)
    local gap = tonumber(widths and widths.gap) or 0
    local positions = {}
    local orderKeys = type(widths) == "table" and widths.orderKeys or nil
    if type(orderKeys) ~= "table" or #orderKeys == 0 then
        orderKeys = DEFAULT_COLUMN_ORDER_KEYS
    end

    local cursor = 0
    local hadVisibleColumn = false
    for _, key in ipairs(orderKeys) do
        local widthKey = COLUMN_WIDTH_KEY_BY_KEY[key]
        local width = math.max(0, tonumber(widthKey and widths and widths[widthKey]) or 0)
        if width > 0 then
            if hadVisibleColumn then
                cursor = cursor + gap
            end
            positions[key] = cursor
            cursor = cursor + width
            hadVisibleColumn = true
        else
            positions[key] = nil
        end
    end

    positions.content = cursor
    return positions
end

local function buildVisibleDividerSpecs(widths, positions, orderKeys)
    local visible = {}
    local activeOrder = type(orderKeys) == "table" and orderKeys or DEFAULT_COLUMN_ORDER_KEYS
    for _, key in ipairs(activeOrder) do
        local widthKey = COLUMN_WIDTH_KEY_BY_KEY[key]
        local width = math.max(0, tonumber(widthKey and widths and widths[widthKey]) or 0)
        local leftX = positions and positions[key]
        if width > 0 and leftX ~= nil then
            visible[#visible + 1] = {
                key = key,
                rightX = leftX + width,
            }
        end
    end

    local specs = {}
    for index = 1, #visible - 1 do
        local column = visible[index]
        if column.key ~= "item" then
            specs[#specs + 1] = {
                key = column.key,
                rightX = column.rightX,
                show = true,
            }
        end
    end
    return specs
end

local function syncDisplayBasketAliases(self, basket)
    if type(basket) ~= "table" then
        basket = {
            order = {},
            byKey = {},
        }
    end

    basket.order = basket.order or {}
    basket.byKey = basket.byKey or {}
    self.DisplayBasket = basket
    return basket
end

local function ensureState(self)
    if self.GetDisplayBasket then
        return self:GetDisplayBasket()
    end

    if self.EnsureRenderState then
        return self:EnsureRenderState()
    end

    local basket = self.DisplayBasket
    return syncDisplayBasketAliases(self, basket)
end

local function getRowDisplayFrame(row)
    if type(row) ~= "table" then
        return nil
    end

    return row.displayFrame
end

local function getResolvedSecondaryDisplayHost(self)
    if type(self) ~= "table" then
        return nil
    end

    return self.SecondaryDisplayHost
end

local function getSecondaryDisplayTimerState(self, now)
    return 0, false
end

local EXPANSION_NAME_FALLBACKS = {
    [0] = "Classic",
    [1] = "The Burning Crusade",
    [2] = "Wrath of the Lich King",
    [3] = "Cataclysm",
    [4] = "Mists of Pandaria",
    [5] = "Warlords of Draenor",
    [6] = "Legion",
    [7] = "Battle for Azeroth",
    [8] = "Shadowlands",
    [9] = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
    [12] = "The Last Titan",
}

local function resolveCurrentExpansionID(entry)
    if type(entry) == "table" then
        local currentExpansionID = tonumber(entry.currentExpansionID)
        if currentExpansionID ~= nil then
            return currentExpansionID
        end
    end

    if type(GetExpansionLevel) == "function" then
        local value = tonumber(GetExpansionLevel())
        if value ~= nil then
            return value
        end
    end

    if _G and _G.Enum and _G.Enum.ExpansionLevel then
        local enumCurrent = tonumber(_G.Enum.ExpansionLevel.CurrentExpansion)
        if enumCurrent ~= nil then
            return enumCurrent
        end
    end

    local value = tonumber(_G and _G.LE_EXPANSION_LEVEL_CURRENT)
    if value ~= nil then
        return value
    end

    local numLevels = tonumber(_G and _G.NUM_LE_EXPANSION_LEVELS)
    if numLevels ~= nil and numLevels > 0 then
        return numLevels - 1
    end

    return nil
end

local function resolveExpansionName(expansionID)
    expansionID = tonumber(expansionID)
    if expansionID == nil then
        return nil
    end

    local globalName = _G and _G["EXPANSION_NAME" .. tostring(expansionID)]
    if type(globalName) == "string" and globalName ~= "" then
        return globalName
    end

    local fallback = EXPANSION_NAME_FALLBACKS[expansionID]
    if type(fallback) == "string" and fallback ~= "" then
        return fallback
    end

    return string.format("Expansion %d", expansionID)
end

local function buildEntryKey(itemName, itemQuality, itemLink, characterKey)
    local safeName = itemName or itemLink or "unknown item"
    local safeQuality = itemQuality ~= nil and tostring(itemQuality) or "0"
    return safeName .. "||" .. safeQuality
end

local function resolveEntryExpansionCategory(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if entry.expansionCategory == "old" or entry.expansionCategory == "current" then
        return entry.expansionCategory
    end

    local expansionID = tonumber(entry.expansionID)
    local currentExpansionID = resolveCurrentExpansionID(entry)

    if expansionID and currentExpansionID then
        return expansionID >= currentExpansionID and "current" or "old"
    end

    return entry.expansionCategory
end

local function getEntryItemTypeLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end

    if type(entry.itemTypeContext) == "string" and entry.itemTypeContext ~= "" then
        if entry.itemTypeContext == "Crafting Reagent" or entry.itemTypeContext == "Finishing Reagent" then
            return "Reagent"
        elseif entry.itemTypeContext == "Elemental Reagent" then
            return "Elemental"
        elseif entry.itemTypeContext == "Card" then
            return "Darkmoon"
        end
        return entry.itemTypeContext
    end

    return ""
end

local function getEntryClassificationLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end

    if type(entry.profession) == "string" and entry.profession ~= "" then
        return entry.profession
    end

    if type(entry.baseProfession) == "string" and entry.baseProfession ~= "" then
        return entry.baseProfession
    end

    return ""
end

local function getEntryProfessionTooltipText(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if type(entry.professionTooltipText) == "string" and entry.professionTooltipText ~= "" then
        return entry.professionTooltipText
    end

    local label = getEntryClassificationLabel(entry)
    local base = type(entry.baseProfession) == "string" and entry.baseProfession or nil
    if not label or label == "" or not base or base == "" then
        return nil
    end

    local normalized = string.lower(label)
    if normalized ~= "multiple" then
        return nil
    end

    local lines = {
        "Multiple Professions",
        "Main usage professions:",
    }

    for profession in string.gmatch(base, "[^,]+") do
        profession = profession:gsub("^%s+", ""):gsub("%s+$", "")
        if profession ~= "" then
            table.insert(lines, "- " .. profession)
        end
    end

    return table.concat(lines, "\n")
end

local isSpecializedDisplayEntry

local function isProcessingDisplayEntry(entry)
    if type(entry) ~= "table" then
        return false
    end

    local activityKey = type(entry.activityKey) == "string" and entry.activityKey:lower() or ""
    local activityContext = type(entry.activityContext) == "string" and entry.activityContext:lower() or ""
    if activityKey == "processing" or activityContext == "processing" then
        return true
    end

    if activityKey == "loot" or activityContext == "loot" or activityKey == "drop" or activityContext == "drop" or activityContext == "multiple" then
        return isSpecializedDisplayEntry(entry)
    end

    return false
end

local function getEntryActivityLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end

    if isProcessingDisplayEntry(entry) then
        return "Processing"
    end

    if type(entry.activityContext) == "string" and entry.activityContext ~= "" then
        return entry.activityContext
    end

    if type(entry.activityKey) == "string" and entry.activityKey ~= "" then
        return entry.activityKey
    end

    return ""
end

local function getEntryActivityTooltipText(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if isProcessingDisplayEntry(entry) then
        return "Processing\nThis item was recorded as a processing-derived result, such as disenchanting, prospecting, milling, or a similar profession transform."
    end

    if type(entry.activityTooltipText) == "string" and entry.activityTooltipText ~= "" then
        return entry.activityTooltipText
    end

    return nil
end


local function getEntryExpansionFullName(entry)
    if type(entry) ~= "table" then
        return ""
    end

    if type(entry.expansionName) == "string" and entry.expansionName ~= "" then
        return entry.expansionName
    end

    local expansionName = resolveExpansionName(entry.expansionID)
    if expansionName ~= nil and expansionName ~= "" then
        return expansionName
    end

    return ""
end

local function getEntryExpansionLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end

    local fullName = getEntryExpansionFullName(entry)
    if FWR.GetExpansionDisplayLabel then
        local displayLabel = FWR:GetExpansionDisplayLabel(fullName, entry.expansionID)
        if type(displayLabel) == "string" and displayLabel ~= "" then
            return displayLabel
        end
    end

    if fullName ~= "" then
        return fullName
    end

    local category = resolveEntryExpansionCategory(entry)
    if category == "current" then
        local currentExpansionID = resolveCurrentExpansionID(entry)
        local currentExpansionName = resolveExpansionName(currentExpansionID)
        if currentExpansionName ~= nil and currentExpansionName ~= "" then
            if FWR.GetExpansionDisplayLabel then
                return FWR:GetExpansionDisplayLabel(currentExpansionName, currentExpansionID)
            end
            return currentExpansionName
        end
    end

    if category == "current" or category == "old" or category == "known" or category == "unknown" then
        return category
    end

    if entry.expansionID ~= nil then
        return tostring(entry.expansionID)
    end

    return ""
end


local function getEntryZoneLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end

    if type(entry.zoneName) == "string" and entry.zoneName ~= "" then
        return entry.zoneName
    end

    if type(entry.zoneContext) == "string" and entry.zoneContext ~= "" then
        return entry.zoneContext
    end

    return ""
end

local function getEntrySubZoneLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end

    if type(entry.subZoneName) == "string" and entry.subZoneName ~= "" then
        return entry.subZoneName
    end

    if type(entry.subZoneContext) == "string" and entry.subZoneContext ~= "" then
        return entry.subZoneContext
    end

    return ""
end

local function getEntryCharacterLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end

    if type(entry.characterName) == "string" and entry.characterName ~= "" then
        return entry.characterName
    end

    if type(entry.characterContext) == "string" and entry.characterContext ~= "" then
        return entry.characterContext
    end

    return ""
end


local function normalizeDisplayText(value)
    if type(value) ~= "string" then
        return nil
    end

    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end

    return value
end

local function entryMatchesCharacter(self, entry, currentCharacterKey)
    if currentCharacterKey == "" then
        return true
    end

    if type(entry) ~= "table" then
        return false
    end

    local entryCharacterKey = entry.characterKey
    if (type(entryCharacterKey) ~= "string" or entryCharacterKey == "") and self.BuildCharacterKey then
        entryCharacterKey = self:BuildCharacterKey(entry.characterName, entry.realmName)
    end

    if type(entryCharacterKey) ~= "string" or entryCharacterKey == "" then
        return false
    end

    return entryCharacterKey == currentCharacterKey
end
local SPECIALIZED_ITEM_TYPES = {
    ["dust"] = true,
    ["essence"] = true,
    ["shard"] = true,
    ["pigment"] = true,
    ["ink"] = true,
    ["gem"] = true,
    ["bolt"] = true,
}

local SPECIALIZED_PROFESSIONS = {
    ["enchanting"] = true,
    ["inscription"] = true,
    ["jewelcrafting"] = true,
    ["tailoring"] = true,
}

isSpecializedDisplayEntry = function(entry)
    if type(entry) ~= "table" then
        return false
    end

    local activityKey = type(entry.activityKey) == "string" and entry.activityKey:lower() or ""
    local activityContext = type(entry.activityContext) == "string" and entry.activityContext:lower() or ""
    if activityKey == "processing" or activityKey == "crafting"
        or activityContext == "processing" or activityContext == "crafting" then
        return true
    end

    local itemTypeContext = type(entry.itemTypeContext) == "string" and entry.itemTypeContext:lower() or ""
    local profession = type(entry.profession) == "string" and entry.profession:lower() or ""
    local baseProfession = type(entry.baseProfession) == "string" and entry.baseProfession:lower() or ""

    if SPECIALIZED_ITEM_TYPES[itemTypeContext] then
        if SPECIALIZED_PROFESSIONS[profession] or SPECIALIZED_PROFESSIONS[baseProfession] then
            return true
        end

        if itemTypeContext == "dust" or itemTypeContext == "essence" or itemTypeContext == "shard"
            or itemTypeContext == "pigment" or itemTypeContext == "ink" then
            return true
        end
    end

    return false
end

local function shouldHideEntryFromDisplayFilters(self, entry)
    if type(entry) ~= "table" then
        return false
    end

    local hideEntry = false
    local isSpecialized = isSpecializedDisplayEntry(entry)
    local showOnlySpecialized = self.IsOnlySpecializedClassificationVisible and self:IsOnlySpecializedClassificationVisible() or false
    local showSpecialized = self.IsSpecializedClassificationVisible and self:IsSpecializedClassificationVisible() or false

    if showOnlySpecialized then
        if not isSpecialized then
            hideEntry = true
        end
    elseif isSpecialized and not showSpecialized then
        hideEntry = true
    end

    local expansionCategory = resolveEntryExpansionCategory(entry)
    if expansionCategory == "old" and not (self.IsOldExpansionVisible and self:IsOldExpansionVisible()) then
        hideEntry = true
    end

    if self.IsEntryBelowRarityFilter and self:IsEntryBelowRarityFilter(entry) then
        hideEntry = true
    end

    return hideEntry
end

local function mergeObservedSources(target, source)
    local order = type(source) == "table" and source.observedSourceOrder or nil
    if type(order) ~= "table" then
        return
    end
    for _, label in ipairs(order) do
        addObservedSource(target, label)
    end
end

local function mergeAggregateField(target, fieldName, incomingValue, multipleLabel)
    if incomingValue == nil or incomingValue == "" then
        return
    end

    local currentValue = target[fieldName]
    if currentValue == nil or currentValue == "" then
        target[fieldName] = incomingValue
        return
    end

    if currentValue ~= incomingValue then
        target[fieldName] = multipleLabel or "Multiple"
    end
end

-- Merges every stored basket that belongs to the view scope into one list of rows.
-- requireSession: only rows with items gathered this session (zone / sub-zone views).
local function buildScopedDisplayEntries(self, scope, requireSession)
    local renderState = self and self.DB and self.DB.renderState or nil
    local basketsByContext = renderState and renderState.displayBasketByContext or nil
    if type(basketsByContext) ~= "table" then
        return {}
    end

    local combinedByKey = {}
    local combinedOrder = {}

    for contextKey, basket in pairs(basketsByContext) do
        local order = type(basket) == "table" and basket.order or nil
        local byKey = type(basket) == "table" and basket.byKey or nil
        if type(order) == "table" and type(byKey) == "table" and self:ContextMatchesViewScope(contextKey, scope) then
            for _, entryKey in ipairs(order) do
                local entry = byKey[entryKey]
                if type(entry) == "table" and (tonumber(entry.totalCount) or 0) > 0 then
                    local combinedKey = buildEntryKey(entry.itemName, entry.itemQuality, entry.itemLink)
                    local aggregate = combinedByKey[combinedKey]
                    if not aggregate then
                        aggregate = {
                            key = combinedKey,
                            itemName = entry.itemName,
                            itemQuality = entry.itemQuality,
                            itemLink = entry.itemLink,
                            itemID = entry.itemID,
                            itemRarity = entry.itemRarity,
                            itemTypeContext = entry.itemTypeContext,
                            profession = entry.profession,
                            baseProfession = entry.baseProfession,
                            professionTooltipText = entry.professionTooltipText,
                            activityTooltipText = entry.activityTooltipText,
                            activityKey = entry.activityKey,
                            activityContext = entry.activityContext,
                            activitySource = entry.activitySource,
                            expansionID = entry.expansionID,
                            expansionName = entry.expansionName,
                            expansionCategory = entry.expansionCategory,
                            currentExpansionID = entry.currentExpansionID,
                            zoneContext = entry.zoneContext,
                            zoneName = entry.zoneName,
                            subZoneContext = entry.subZoneContext,
                            subZoneName = entry.subZoneName,
                            characterContext = entry.characterContext,
                            characterName = entry.characterName,
                            characterKey = entry.characterKey,
                            characterClassName = entry.characterClassName,
                            characterClassFile = entry.characterClassFile,
                            realmName = entry.realmName,
                            isDynamicSharedReagent = entry.isDynamicSharedReagent == true,
                            observedSourceOrder = {},
                            observedSourceSet = {},
                            quantityCount = 0,
                            totalCount = 0,
                        }
                        combinedByKey[combinedKey] = aggregate
                        table.insert(combinedOrder, combinedKey)
                    end

                    aggregate.totalCount = (tonumber(aggregate.totalCount) or 0) + (tonumber(entry.totalCount) or 0)
                    aggregate.quantityCount = (tonumber(aggregate.quantityCount) or 0) + (tonumber(entry.quantityCount) or 0)
                    aggregate.itemRarity = tonumber(entry.itemRarity) or aggregate.itemRarity
                    aggregate.itemID = entry.itemID or aggregate.itemID
                    aggregate.itemLink = entry.itemLink or aggregate.itemLink
                    aggregate.isDynamicSharedReagent = entry.isDynamicSharedReagent == true or aggregate.isDynamicSharedReagent == true
                    mergeObservedSources(aggregate, entry)
                    mergeAggregateField(aggregate, "itemTypeContext", entry.itemTypeContext)
                    mergeAggregateField(aggregate, "profession", entry.profession)
                    mergeAggregateField(aggregate, "baseProfession", entry.baseProfession)
                    mergeAggregateField(aggregate, "professionTooltipText", entry.professionTooltipText)
                    mergeAggregateField(aggregate, "activityKey", entry.activityKey)
                    mergeAggregateField(aggregate, "activityContext", entry.activityContext)
                    mergeAggregateField(aggregate, "activitySource", entry.activitySource)
                    mergeAggregateField(aggregate, "activityTooltipText", entry.activityTooltipText)
                    mergeAggregateField(aggregate, "expansionName", entry.expansionName)
                    mergeAggregateField(aggregate, "expansionCategory", resolveEntryExpansionCategory(entry) or entry.expansionCategory)
                    mergeAggregateField(aggregate, "zoneContext", entry.zoneContext)
                    mergeAggregateField(aggregate, "zoneName", entry.zoneName)
                    mergeAggregateField(aggregate, "subZoneContext", entry.subZoneContext)
                    mergeAggregateField(aggregate, "subZoneName", entry.subZoneName)
                    mergeAggregateField(aggregate, "characterContext", entry.characterContext)
                    mergeAggregateField(aggregate, "characterName", entry.characterName)
                    mergeAggregateField(aggregate, "characterKey", entry.characterKey)
                    mergeAggregateField(aggregate, "characterClassName", entry.characterClassName)
                    mergeAggregateField(aggregate, "characterClassFile", entry.characterClassFile)
                    mergeAggregateField(aggregate, "realmName", entry.realmName)
                end
            end
        end
    end

    local entries = {}
    for _, combinedKey in ipairs(combinedOrder) do
        local entry = combinedByKey[combinedKey]
        local hasCount = requireSession and (tonumber(entry.quantityCount) or 0) > 0
            or (not requireSession and (tonumber(entry.totalCount) or 0) > 0)
        if entry and hasCount and not shouldHideEntryFromDisplayFilters(self, entry) then
            applyDynamicSharedReagentState(entry)
            table.insert(entries, entry)
        end
    end

    return entries
end

local function sortDisplayedEntries(entries)
    table.sort(entries, function(a, b)
        local aName = string.lower(tostring(a.itemName or a.itemLink or ""))
        local bName = string.lower(tostring(b.itemName or b.itemLink or ""))
        if aName ~= bName then
            return aName < bName
        end

        local aQuality = tonumber(a.itemQuality) or 0
        local bQuality = tonumber(b.itemQuality) or 0
        if aQuality ~= bQuality then
            return aQuality > bQuality
        end

        local aRarity = tonumber(a.itemRarity) or 0
        local bRarity = tonumber(b.itemRarity) or 0
        if aRarity ~= bRarity then
            return aRarity > bRarity
        end

        return (tonumber(a.itemID) or 0) < (tonumber(b.itemID) or 0)
    end)
end

local function getDisplayElapsedSeconds(self)
    return (self:SumViewScopeSeconds())
end

local function getDisplayedEntries(self)
    local scope = self:GetViewScope()
    local requireSession = scope.mode == "zone" or scope.mode == "subzone"
    local entries = buildScopedDisplayEntries(self, scope, requireSession)
    sortDisplayedEntries(entries)
    return entries
end

local function getQualityAtlas(quality)
    quality = tonumber(quality) or 0
    if quality == 1 then
        return "Professions-ChatIcon-Quality-12-Tier1"
    elseif quality == 2 then
        return "Professions-ChatIcon-Quality-12-Tier2"
    elseif quality == 3 then
        return "Professions-ChatIcon-Quality-12-Tier3"
    end
    return nil
end

local function applyQualityDisplay(row, quality)
    quality = tonumber(quality) or 0
    local atlas = getQualityAtlas(quality)

    row.qualityText:SetText("")
    row.qualityText:Hide()
    row.qualityIcon:Hide()

    if quality <= 0 then
        return
    end

    local iconOffset = 0
    if quality == 1 then
        row.qualityIcon:SetSize(15, 15)
        iconOffset = QUALITY_ONE_X_OFFSET
    elseif quality == 2 then
        row.qualityIcon:SetSize(12, 12)
    else
        row.qualityIcon:SetSize(14, 14)
    end

    row.qualityIcon:ClearAllPoints()
    if row.qualityIcon.SetPoint and row.GetWidth then
        local rowFrame = getRowDisplayFrame(row)
        local columnWidths = rowFrame and rowFrame.columnWidths
        local qualityWidth = columnWidths and columnWidths.quality or 20
        local gapX = (columnWidths and columnWidths.name or 0) + (columnWidths and columnWidths.gap or 0) + math.floor(qualityWidth / 2) + iconOffset
        row.qualityIcon:SetPoint("CENTER", row, "LEFT", gapX, 0)
    end

    if atlas and row.qualityIcon.SetAtlas then
        row.qualityIcon:SetAtlas(atlas)
        row.qualityIcon:Show()
        return
    end

    row.qualityText:SetText(tostring(quality))
    row.qualityText:Show()
end

local function getRarityColor(quality)
    quality = tonumber(quality)
    if quality ~= nil and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        return c.r or 1, c.g or 1, c.b or 1
    end
    return 1, 1, 1
end

local function truncateTextToWidth(fontString, textValue, maxWidth)
    if not fontString then
        return textValue or ""
    end

    local text = tostring(textValue or "")
    if text == "" then
        return ""
    end

    fontString:SetWordWrap(false)
    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end

    fontString:SetText(text)
    if fontString:GetStringWidth() <= maxWidth then
        return text
    end

    local ellipsis = "..."
    fontString:SetText(ellipsis)
    if fontString:GetStringWidth() >= maxWidth then
        return ellipsis
    end

    local low, high = 0, #text
    while low < high do
        local mid = math.floor((low + high + 1) / 2)
        local candidate = string.sub(text, 1, mid) .. ellipsis
        fontString:SetText(candidate)
        if fontString:GetStringWidth() <= maxWidth then
            low = mid
        else
            high = mid - 1
        end
    end

    if low <= 0 then
        return ellipsis
    end

    return string.sub(text, 1, low) .. ellipsis
end

local function formatSecondsAsClock(totalSeconds)
    totalSeconds = math.max(0, math.floor((tonumber(totalSeconds) or 0) + 0.5))
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

local function getItemPerHourValue(totalCount, elapsedSeconds)
    totalCount = tonumber(totalCount) or 0
    elapsedSeconds = tonumber(elapsedSeconds) or 0
    if totalCount <= 0 or elapsedSeconds <= 0 then
        return 0
    end
    return totalCount * 3600 / elapsedSeconds
end

local function formatItemPerHour(totalCount, elapsedSeconds)
    local value = getItemPerHourValue(totalCount, elapsedSeconds)
    if value <= 0 then
        return "0"
    end
    return tostring(math.floor(value + 0.5))
end

local function getDigitCount(value)
    local numericValue = math.abs(math.floor(tonumber(value) or 0))
    if numericValue <= 0 then
        return 1
    end
    return string.len(tostring(numericValue))
end

local function ensureMeasureFontString(frame)
    if not frame then
        return nil
    end

    if frame.measureFontString then
        return frame.measureFontString
    end

    local owner = frame
    if type(owner.CreateFontString) ~= "function" then
        owner = frame.columnsHeader or frame.scrollChild or frame.scrollFrame or nil
    end
    if not owner or type(owner.CreateFontString) ~= "function" then
        return nil
    end

    local fs = owner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:Hide()
    fs:SetWordWrap(false)
    if fs.SetMaxLines then
        fs:SetMaxLines(1)
    end
    frame.measureFontString = fs
    return fs
end

local function getDigitSlotWidth(frame)
    local measure = ensureMeasureFontString(frame)
    if not measure then
        return 7
    end

    measure:SetText("0000")
    local width = measure:GetStringWidth() or 0
    if width <= 0 then
        return 7
    end

    return math.max(6, width / 4)
end

local function getNumericColumnMeta(frame, entries, elapsedSeconds)
    local meta = {
        quantity = { maxDigits = 1 },
        total = { maxDigits = 1 },
        itemPerHour = { maxDigits = 1 },
    }

    for _, entry in ipairs(entries or {}) do
        meta.quantity.maxDigits = math.max(meta.quantity.maxDigits, getDigitCount(entry.quantityCount))
        meta.total.maxDigits = math.max(meta.total.maxDigits, getDigitCount(entry.totalCount))
        meta.itemPerHour.maxDigits = math.max(meta.itemPerHour.maxDigits, getDigitCount(getItemPerHourValue(entry.totalCount, elapsedSeconds)))
    end

    local digitSlotWidth = getDigitSlotWidth(frame)
    for _, column in pairs(meta) do
        column.laneWidth = (column.maxDigits * digitSlotWidth) + 6
    end

    return meta
end


-- The width each visible text column needs: its header or its widest text, whichever is wider, plus
-- the column's insets. Only visible columns are measured.
local TEXT_COLUMN_LABELS = {
    itemType = function(entry) return getEntryItemTypeLabel(entry) end,
    classification = function(entry) return getEntryClassificationLabel(entry) end,
    activity = function(entry) return getEntryActivityLabel(entry) end,
    expansion = function(entry) return getEntryExpansionLabel(entry) end,
    zone = function(entry) return getEntryZoneLabel(entry) end,
    subZone = function(entry) return getEntrySubZoneLabel(entry) end,
    character = function(entry) return getEntryCharacterLabel(entry) end,
}

local function getTextColumnMeta(frame, entries, config)
    local measure = ensureMeasureFontString(frame)
    local needed = {}
    if not measure then
        return needed
    end

    local function measureText(text)
        measure:SetText(text or "")
        return measure:GetStringWidth() or 0
    end

    local function isVisible(key)
        local column = type(config) == "table" and config[key] or nil
        return type(column) == "table" and column.visible ~= false
    end

    local keys = { "itemType", "classification", "activity", "expansion", "zone", "subZone", "character", "price", "value" }
    for _, key in ipairs(keys) do
        if isVisible(key) then
            needed[key] = measureText(config[key].label)
        end
    end

    for _, entry in ipairs(entries or {}) do
        for key, getLabel in pairs(TEXT_COLUMN_LABELS) do
            if needed[key] then
                needed[key] = math.max(needed[key], measureText(getLabel(entry)))
            end
        end
        if needed.price or needed.value then
            local priceText, valueText = getEntryPriceTexts(entry)
            if needed.price then needed.price = math.max(needed.price, measureText(priceText)) end
            if needed.value then needed.value = math.max(needed.value, measureText(valueText)) end
        end
    end

    return needed
end

local DIVIDER_COLOR = { 0.54, 0.54, 0.58, 0.50 }

local function ensureDividerTexture(owner, key, layer)
    if not owner then
        return nil
    end
    owner.columnDividers = owner.columnDividers or {}
    if owner.columnDividers[key] then
        return owner.columnDividers[key]
    end
    if type(owner.CreateTexture) ~= "function" then
        return nil
    end
    local tex = owner:CreateTexture(nil, layer or "BORDER")
    tex:SetColorTexture(DIVIDER_COLOR[1], DIVIDER_COLOR[2], DIVIDER_COLOR[3], DIVIDER_COLOR[4])
    owner.columnDividers[key] = tex
    return tex
end

local function hideAllColumnDividers(owner)
    if not owner or type(owner.columnDividers) ~= "table" then
        return
    end
    for _, tex in pairs(owner.columnDividers) do
        if tex and tex.Hide then
            tex:Hide()
        end
    end
end

local function layoutScrollChildDivider(frame, key, rightX, isVisible)
    if not frame or not frame.scrollChild then
        return
    end
    local divider = ensureDividerTexture(frame.scrollChild, key, "ARTWORK")
    local oldTop = ensureDividerTexture(frame.scrollChild, key .. "_top", "ARTWORK")
    local oldBottom = ensureDividerTexture(frame.scrollChild, key .. "_bottom", "ARTWORK")
    if oldTop then oldTop:Hide() end
    if oldBottom then oldBottom:Hide() end
    if not divider then
        return
    end
    if not isVisible then
        divider:Hide()
        return
    end

    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", rightX, 0)
    divider:SetPoint("BOTTOMLEFT", frame.scrollChild, "BOTTOMLEFT", rightX, 0)
    divider:SetWidth(1)
    divider:Show()
end

local function layoutDivider(owner, key, rightX, isVisible, topInset, bottomInset)
    local divider = ensureDividerTexture(owner, key, "BORDER")
    if not divider then
        return
    end
    if not isVisible then
        divider:Hide()
        return
    end
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", owner, "TOPLEFT", rightX, topInset or 1)
    divider:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", rightX, bottomInset or -1)
    divider:SetWidth(1)
    divider:Show()
end

local function getContentHeight(frame)
    local entryCount = #(getDisplayedEntries(FWR) or {})
    if entryCount == 0 then
        entryCount = 1
    end
    local rowHeight = getRowHeight(frame)
    local topPadding, bottomPadding = getVerticalPadding(frame)
    return (entryCount * rowHeight) + topPadding + bottomPadding + MAIN_SCROLL_TRAILING_PADDING
end

local function applyTextColumnLayout(fontString, row, startX, width, align, insetLeft, insetRight)
    if not fontString or not row then
        return
    end

    local columnWidth = math.max(0, tonumber(width) or 0)
    if columnWidth <= 0 then
        fontString:Hide()
        return
    end

    local leftInset = math.max(0, tonumber(insetLeft) or 0)
    local rightInset = math.max(0, tonumber(insetRight) or 0)
    local usableWidth = math.max(1, columnWidth - leftInset - rightInset)
    local normalizedAlign = normalizeDataAlign(align, "LEFT")

    if fontString.SetJustifyH then
        fontString:SetJustifyH(normalizedAlign)
    end

    fontString:ClearAllPoints()
    fontString:SetPoint("LEFT", row, "LEFT", startX + leftInset, 0)
    fontString:SetWidth(usableWidth)
    fontString:Show()
end

local function applyRowColumnLayout(row, frame)
    if not row or not frame then
        return
    end

    local columnWidths = frame.columnWidths or {}
    local nameWidth = columnWidths.name or 130
    local qualityWidth = columnWidths.quality or 20
    local quantityWidth = columnWidths.quantity or 50
    local totalWidth = columnWidths.total or 50
    local itemPerHourWidth = columnWidths.itemPerHour or 78
    local itemTypeWidth = columnWidths.itemType or 96
    local classificationWidth = columnWidths.classification or 96
    local activityWidth = columnWidths.activity or 84
    local expansionWidth = columnWidths.expansion or 96
    local zoneWidth = columnWidths.zone or 110
    local subZoneWidth = columnWidths.subZone or 110
    local characterWidth = columnWidths.character or 128
    local priceWidth = columnWidths.price or 0
    local valueWidth = columnWidths.value or 0
    local gap = columnWidths.gap or 2
    local itemTextWidth = columnWidths.itemText or nameWidth
    local numericMeta = columnWidths.numericMeta or {}

    local positions = frame.columnPositions or buildResolvedColumnLayout({
        name = columnWidths.name,
        quality = columnWidths.quality,
        quantity = columnWidths.quantity,
        total = columnWidths.total,
        itemPerHour = columnWidths.itemPerHour,
        itemType = columnWidths.itemType,
        classification = columnWidths.classification,
        activity = columnWidths.activity,
        expansion = columnWidths.expansion,
        zone = columnWidths.zone,
        subZone = columnWidths.subZone,
        character = columnWidths.character,
        price = columnWidths.price,
        value = columnWidths.value,
        gap = columnWidths.gap,
        orderKeys = getColumnOrderKeysForFrame(frame),
    })
    local x1 = positions.item or 0
    local xQuality = positions.quality or (x1 + nameWidth)
    local x2 = positions.quantity or xQuality
    local x3 = positions.total or x2
    local x4 = positions.itemPerHour or x3
    local x5 = positions.itemType or x4
    local x6 = positions.classification or x5
    local x7 = positions.activity or x6
    local x8 = positions.expansion or x7
    local x9 = positions.zone or x8
    local x10 = positions.subZone or x9
    local x11 = positions.character or x10
    local x12 = positions.price or x11
    local x13 = positions.value or x12

    local quantityLaneWidth = math.min(quantityWidth, math.max(18, (numericMeta.quantity and numericMeta.quantity.laneWidth) or quantityWidth))
    local totalLaneWidth = math.min(totalWidth, math.max(18, (numericMeta.total and numericMeta.total.laneWidth) or totalWidth))
    local itemPerHourLaneWidth = math.min(itemPerHourWidth, math.max(18, (numericMeta.itemPerHour and numericMeta.itemPerHour.laneWidth) or itemPerHourWidth))

    local quantityLaneX = x2 + math.floor((quantityWidth - quantityLaneWidth) / 2)
    local totalLaneX = x3 + math.floor((totalWidth - totalLaneWidth) / 2)
    local itemPerHourLaneX = x4 + math.floor((itemPerHourWidth - itemPerHourLaneWidth) / 2)

    applyTextColumnLayout(row.itemName, row, x1, itemTextWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "item", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "item", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "item", "RIGHT"))
    if nameWidth <= 0 then row.itemName:Hide() end

    row.qualityIcon:ClearAllPoints()
    row.qualityIcon:SetPoint("CENTER", row, "LEFT", xQuality + math.floor(qualityWidth / 2), 0)
    row.qualityText:ClearAllPoints()
    row.qualityText:SetPoint("LEFT", row, "LEFT", xQuality, 0)
    row.qualityText:SetWidth(qualityWidth)
    if qualityWidth > 0 then
        row.qualityText:Show()
    else
        row.qualityIcon:Hide()
        row.qualityText:Hide()
    end

    row.quantity:ClearAllPoints()
    row.quantity:SetPoint("LEFT", row, "LEFT", quantityLaneX, 0)
    row.quantity:SetWidth(quantityLaneWidth)
    if quantityWidth > 0 then row.quantity:Show() else row.quantity:Hide() end

    row.total:ClearAllPoints()
    row.total:SetPoint("LEFT", row, "LEFT", totalLaneX, 0)
    row.total:SetWidth(totalLaneWidth)
    if totalWidth > 0 then row.total:Show() else row.total:Hide() end

    row.itemPerHour:ClearAllPoints()
    row.itemPerHour:SetPoint("LEFT", row, "LEFT", itemPerHourLaneX, 0)
    row.itemPerHour:SetWidth(itemPerHourLaneWidth)
    if itemPerHourWidth > 0 then row.itemPerHour:Show() else row.itemPerHour:Hide() end

    applyTextColumnLayout(row.itemType, row, x5, itemTypeWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "itemType", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "itemType", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "itemType", "RIGHT"))
    if itemTypeWidth <= 0 then row.itemType:Hide() end

    applyTextColumnLayout(row.classification, row, x6, classificationWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "classification", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "classification", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "classification", "RIGHT"))
    if row.classificationHitbox then
        row.classificationHitbox:ClearAllPoints()
        if classificationWidth > 0 then
            row.classificationHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", x6, 0)
            row.classificationHitbox:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", x6 + classificationWidth, -getRowHeight(frame))
            row.classificationHitbox:Show()
        else
            row.classificationHitbox:Hide()
        end
    end
    if classificationWidth <= 0 then row.classification:Hide() end

    applyTextColumnLayout(row.activity, row, x7, activityWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "activity", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "activity", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "activity", "RIGHT"))
    if row.activityHitbox then
        row.activityHitbox:ClearAllPoints()
        if activityWidth > 0 then
            row.activityHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", x7, 0)
            row.activityHitbox:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", x7 + activityWidth, -getRowHeight(frame))
            row.activityHitbox:Show()
        else
            row.activityHitbox:Hide()
        end
    end
    if activityWidth <= 0 then row.activity:Hide() end

    applyTextColumnLayout(row.expansion, row, x8, expansionWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "expansion", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "expansion", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "expansion", "RIGHT"))
    if row.expansionHitbox then
        row.expansionHitbox:ClearAllPoints()
        if expansionWidth > 0 then
            row.expansionHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", x8, 0)
            row.expansionHitbox:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", x8 + expansionWidth, -getRowHeight(frame))
            row.expansionHitbox:Show()
        else
            row.expansionHitbox:Hide()
        end
    end
    if expansionWidth <= 0 then row.expansion:Hide() end

    applyTextColumnLayout(row.zone, row, x9, zoneWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "zone", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "zone", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "zone", "RIGHT"))
    if zoneWidth <= 0 then row.zone:Hide() end

    applyTextColumnLayout(row.subZone, row, x10, subZoneWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "subZone", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "subZone", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "subZone", "RIGHT"))
    if subZoneWidth <= 0 then row.subZone:Hide() end

    applyTextColumnLayout(row.character, row, x11, characterWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "character", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "character", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "character", "RIGHT"))
    if characterWidth <= 0 then row.character:Hide() end

    applyTextColumnLayout(row.price, row, x12, priceWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "price", "RIGHT"), getColumnDataInset(getRenderConfigForFrame(frame), "price", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "price", "RIGHT"))
    if priceWidth <= 0 then row.price:Hide() end
    if row.priceHitbox then
        row.priceHitbox:ClearAllPoints()
        if priceWidth > 0 then
            row.priceHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", x12, 0)
            row.priceHitbox:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", x12 + priceWidth, -getRowHeight(frame))
            row.priceHitbox:Show()
        else
            row.priceHitbox:Hide()
        end
    end

    applyTextColumnLayout(row.value, row, x13, valueWidth, getColumnDataAlign(getRenderConfigForFrame(frame), "value", "RIGHT"), getColumnDataInset(getRenderConfigForFrame(frame), "value", "LEFT"), getColumnDataInset(getRenderConfigForFrame(frame), "value", "RIGHT"))
    if valueWidth <= 0 then row.value:Hide() end
    if row.valueHitbox then
        row.valueHitbox:ClearAllPoints()
        if valueWidth > 0 then
            row.valueHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", x13, 0)
            row.valueHitbox:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", x13 + valueWidth, -getRowHeight(frame))
            row.valueHitbox:Show()
        else
            row.valueHitbox:Hide()
        end
    end

    hideAllColumnDividers(row)
end

local function ensureRow(frame, index)
    frame.rows = frame.rows or {}
    if frame.rows[index] then
        return frame.rows[index]
    end

    local row = CreateFrame("Frame", nil, frame.scrollChild)
    row:SetHeight(getRowHeight(frame))
    row.displayFrame = frame

    row.qualityIcon = row:CreateTexture(nil, "ARTWORK")
    row.qualityIcon:SetSize(14, 14)

    row.itemName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.itemName:SetJustifyH("LEFT")
    row.itemName:SetWordWrap(false)
    if row.itemName.SetMaxLines then
        row.itemName:SetMaxLines(1)
    end

    row.qualityText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.qualityText:SetJustifyH("CENTER")
    row.qualityText:SetTextColor(0.85, 0.85, 0.85, 1)

    row.quantity = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.quantity:SetJustifyH("RIGHT")
    row.quantity:SetTextColor(0.9, 0.9, 0.9, 1)

    row.total = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.total:SetJustifyH("RIGHT")
    row.total:SetTextColor(0.9, 0.9, 0.9, 1)

    row.itemPerHour = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.itemPerHour:SetJustifyH("RIGHT")
    row.itemPerHour:SetTextColor(0.9, 0.9, 0.9, 1)

    row.itemType = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.itemType:SetJustifyH("LEFT")
    row.itemType:SetTextColor(0.85, 0.85, 0.85, 1)
    row.itemType:SetWordWrap(false)
    if row.itemType.SetMaxLines then
        row.itemType:SetMaxLines(1)
    end

    row.classification = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.classification:SetJustifyH("LEFT")
    row.classification:SetTextColor(0.85, 0.85, 0.85, 1)
    row.classification:SetWordWrap(false)
    if row.classification.SetMaxLines then
        row.classification:SetMaxLines(1)
    end

    row.classificationHitbox = CreateFrame("Frame", nil, row)
    row.classificationHitbox:SetFrameLevel(row:GetFrameLevel() + 5)
    row.classificationHitbox:EnableMouse(true)
    row.classificationHitbox:SetScript("OnEnter", function(hitbox)
        local tooltipText = hitbox.tooltipText
        if tooltipText and FWR.ShowSimpleTooltip then
            FWR:ShowSimpleTooltip(hitbox, tooltipText)
        end
    end)
    row.classificationHitbox:SetScript("OnLeave", function()
        if FWR.HideSimpleTooltip then
            FWR:HideSimpleTooltip()
        end
    end)

    row.activity = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.activity:SetJustifyH("LEFT")
    row.activity:SetTextColor(0.85, 0.85, 0.85, 1)
    row.activity:SetWordWrap(false)
    if row.activity.SetMaxLines then
        row.activity:SetMaxLines(1)
    end

    row.activityHitbox = CreateFrame("Frame", nil, row)
    row.activityHitbox:SetFrameLevel(row:GetFrameLevel() + 5)
    row.activityHitbox:EnableMouse(true)
    row.activityHitbox:SetScript("OnEnter", function(hitbox)
        local tooltipText = hitbox.tooltipText
        if tooltipText and FWR.ShowSimpleTooltip then
            FWR:ShowSimpleTooltip(hitbox, tooltipText)
        end
    end)
    row.activityHitbox:SetScript("OnLeave", function()
        if FWR.HideSimpleTooltip then
            FWR:HideSimpleTooltip()
        end
    end)

    row.expansion = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.expansion:SetJustifyH("LEFT")
    row.expansion:SetTextColor(1.0, 0.82, 0.0, 1)
    row.expansion:SetWordWrap(false)
    if row.expansion.SetMaxLines then
        row.expansion:SetMaxLines(1)
    end

    row.expansionHitbox = CreateFrame("Frame", nil, row)
    row.expansionHitbox:SetFrameLevel(row:GetFrameLevel() + 5)
    row.expansionHitbox:EnableMouse(true)
    row.expansionHitbox:SetScript("OnEnter", function(hitbox)
        local tooltipText = hitbox.tooltipText
        if tooltipText and FWR.ShowSimpleTooltip then
            FWR:ShowSimpleTooltip(hitbox, tooltipText)
        end
    end)
    row.expansionHitbox:SetScript("OnLeave", function()
        if FWR.HideSimpleTooltip then
            FWR:HideSimpleTooltip()
        end
    end)

    row.zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.zone:SetJustifyH("LEFT")
    row.zone:SetTextColor(0.85, 0.85, 0.85, 1)
    row.zone:SetWordWrap(false)
    if row.zone.SetMaxLines then
        row.zone:SetMaxLines(1)
    end

    row.subZone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.subZone:SetJustifyH("LEFT")
    row.subZone:SetTextColor(0.85, 0.85, 0.85, 1)
    row.subZone:SetWordWrap(false)
    if row.subZone.SetMaxLines then
        row.subZone:SetMaxLines(1)
    end

    row.character = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.character:SetJustifyH("LEFT")
    row.character:SetTextColor(0.85, 0.85, 0.85, 1)
    row.character:SetWordWrap(false)
    if row.character.SetMaxLines then
        row.character:SetMaxLines(1)
    end

    for _, key in ipairs({ "price", "value" }) do
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetJustifyH("RIGHT")
        text:SetTextColor(0.9, 0.9, 0.9, 1)
        text:SetWordWrap(false)
        if text.SetMaxLines then
            text:SetMaxLines(1)
        end
        row[key] = text

        local hitbox = CreateFrame("Frame", nil, row)
        hitbox:SetFrameLevel(row:GetFrameLevel() + 5)
        hitbox:EnableMouse(true)
        hitbox:SetScript("OnEnter", function(box)
            if box.tooltipText and FWR.ShowSimpleTooltip then
                FWR:ShowSimpleTooltip(box, box.tooltipText)
            end
        end)
        hitbox:SetScript("OnLeave", function()
            if FWR.HideSimpleTooltip then
                FWR:HideSimpleTooltip()
            end
        end)
        row[key .. "Hitbox"] = hitbox
    end

    frame.rows[index] = row
    applyRowColumnLayout(row, frame)
    return row
end

function FWR:UpdateDisplayColumnLayout(frame)
    if not frame then
        return
    end

    local config = getRenderConfigForFrame(frame)
    local entries = getDisplayedEntries(FWR)
    local elapsedSeconds = getDisplayElapsedSeconds(FWR)
    local numericMeta = getNumericColumnMeta(frame, entries, elapsedSeconds)
    local textMeta = getTextColumnMeta(frame, entries, config)

    local function resolveColumnWidth(key, columnConfig, fallbackWidth)
        local visible = true
        if type(columnConfig) == "table" and columnConfig.visible ~= nil then
            visible = not not columnConfig.visible
        end
        if not visible then
            return 0
        end

        -- these columns are exactly as wide as their content (with a little room around it); the price
        -- columns grow without limit, the other text columns never get wider than their set width
        if textMeta[key] then
            local insets = (tonumber(columnConfig.dataInsetLeft) or 0) + (tonumber(columnConfig.dataInsetRight) or 0)
            local fitted = math.ceil(textMeta[key] + insets + 8)
            if key ~= "price" and key ~= "value" then
                fitted = math.min(fitted, tonumber(columnConfig.width) or tonumber(fallbackWidth) or fitted)
            end
            return math.max(18, fitted)
        end

        local baseWidth = tonumber(type(columnConfig) == "table" and columnConfig.width)
        if baseWidth == nil then
            baseWidth = tonumber(fallbackWidth) or 0
        end
        local minWidth = tonumber(type(columnConfig) == "table" and columnConfig.minWidth)
        if minWidth == nil then
            minWidth = baseWidth
        end
        minWidth = math.max(0, tonumber(minWidth) or 0)
        local width = math.max(0, tonumber(baseWidth) or 0)
        local autoWidth = type(columnConfig) == "table" and columnConfig.autoWidth == true

        if autoWidth then
            local measuredWidth = estimateTextWidth(type(columnConfig) == "table" and columnConfig.label or "")
            if key == "quality" then
                local maxVisualWidth = 0
                for _, entry in ipairs(entries or {}) do
                    local quality = tonumber(entry.quality) or 0
                    if quality >= 3 then
                        maxVisualWidth = math.max(maxVisualWidth, 22)
                    elseif quality == 2 then
                        maxVisualWidth = math.max(maxVisualWidth, 20)
                    elseif quality == 1 then
                        maxVisualWidth = math.max(maxVisualWidth, 19)
                    end
                end
                measuredWidth = math.max(measuredWidth, maxVisualWidth)
            elseif key == "quantity" then
                measuredWidth = math.max(measuredWidth, math.max(18, (numericMeta.quantity and numericMeta.quantity.laneWidth) or 0) + 8)
            elseif key == "total" then
                measuredWidth = math.max(measuredWidth, math.max(18, (numericMeta.total and numericMeta.total.laneWidth) or 0) + 8)
            elseif key == "itemPerHour" then
                measuredWidth = math.max(measuredWidth, math.max(18, (numericMeta.itemPerHour and numericMeta.itemPerHour.laneWidth) or 0) + 8)
            end
            width = math.max(width, minWidth, measuredWidth)
        else
            width = math.max(width, minWidth)
        end

        if width <= 0 then
            return 0
        end
        return width
    end

    local qualityWidth = resolveColumnWidth("quality", config.quality, 18)
    local quantityWidth = resolveColumnWidth("quantity", config.quantity, 56)
    local totalWidth = resolveColumnWidth("total", config.total, 56)
    local itemPerHourWidth = resolveColumnWidth("itemPerHour", config.itemPerHour, 78)
    local itemTypeWidth = resolveColumnWidth("itemType", config.itemType, 96)
    local classificationWidth = resolveColumnWidth("classification", config.classification, 96)
    local activityWidth = resolveColumnWidth("activity", config.activity, 84)
    local expansionWidth = resolveColumnWidth("expansion", config.expansion, 96)
    local zoneWidth = resolveColumnWidth("zone", config.zone, 110)
    local subZoneWidth = resolveColumnWidth("subZone", config.subZone, 110)
    local characterWidth = resolveColumnWidth("character", config.character, 128)
    local priceWidth = resolveColumnWidth("price", config.price, 84)
    local valueWidth = resolveColumnWidth("value", config.value, 96)
    local gap = math.max(0, tonumber(config.gap) or 6)
    local nameWidth = resolveColumnWidth("item", config.item, 250)
    local itemTextWidth = math.max(20, nameWidth)
    local resolvedLayout = buildResolvedColumnLayout({
        name = nameWidth,
        quality = qualityWidth,
        quantity = quantityWidth,
        total = totalWidth,
        itemPerHour = itemPerHourWidth,
        itemType = itemTypeWidth,
        classification = classificationWidth,
        activity = activityWidth,
        expansion = expansionWidth,
        zone = zoneWidth,
        subZone = subZoneWidth,
        character = characterWidth,
        price = priceWidth,
        value = valueWidth,
        gap = gap,
        orderKeys = getColumnOrderKeysForFrame(frame),
    })
    local minimumContentWidth = resolvedLayout.content
    local contentWidth = minimumContentWidth

    frame.columnWidths = {
        name = nameWidth,
        quality = qualityWidth,
        quantity = quantityWidth,
        total = totalWidth,
        itemPerHour = itemPerHourWidth,
        itemType = itemTypeWidth,
        classification = classificationWidth,
        activity = activityWidth,
        expansion = expansionWidth,
        zone = zoneWidth,
        subZone = subZoneWidth,
        character = characterWidth,
        price = priceWidth,
        value = valueWidth,
        gap = gap,
        itemText = itemTextWidth,
        content = contentWidth,
        minimumContent = minimumContentWidth,
        numericMeta = numericMeta,
    }
    frame.columnPositions = resolvedLayout

    local x1 = resolvedLayout.item or 0
    local xQuality = resolvedLayout.quality or (x1 + nameWidth)
    local x2 = resolvedLayout.quantity or xQuality
    local x3 = resolvedLayout.total or x2
    local x4 = resolvedLayout.itemPerHour or x3
    local x5 = resolvedLayout.itemType or x4
    local x6 = resolvedLayout.classification or x5
    local x7 = resolvedLayout.activity or x6
    local x8 = resolvedLayout.expansion or x7
    local x9 = resolvedLayout.zone or x8
    local x10 = resolvedLayout.subZone or x9
    local x11 = resolvedLayout.character or x10
    local x12 = resolvedLayout.price or x11
    local x13 = resolvedLayout.value or x12

    local quantityLaneWidth = math.min(quantityWidth, math.max(18, numericMeta.quantity.laneWidth or quantityWidth))
    local totalLaneWidth = math.min(totalWidth, math.max(18, numericMeta.total.laneWidth or totalWidth))
    local itemPerHourLaneWidth = math.min(itemPerHourWidth, math.max(18, numericMeta.itemPerHour.laneWidth or itemPerHourWidth))

    local quantityLaneX = x2 + math.floor((quantityWidth - quantityLaneWidth) / 2)
    local totalLaneX = x3 + math.floor((totalWidth - totalLaneWidth) / 2)
    local itemPerHourLaneX = x4 + math.floor((itemPerHourWidth - itemPerHourLaneWidth) / 2)



local function layoutColumnHeaderTooltipHitbox(frame, key, leftX, width, isVisible)
    if not frame or not frame.columnsHeader then
        return
    end

    local hitboxes = frame.columnHeaderHitboxes or {}
    local hitbox = hitboxes[key]
    if not hitbox then
        return
    end

    hitbox:ClearAllPoints()
    hitbox:SetPoint("TOPLEFT", frame.columnsHeader, "TOPLEFT", tonumber(leftX) or 0, 2)
    hitbox:SetSize(math.max(0, tonumber(width) or 0), math.max(14, (frame.columnsHeader:GetHeight() or 22) + 2))

    if isVisible and (tonumber(width) or 0) > 0 then
        hitbox:Show()
    else
        hitbox:Hide()
    end
end

    local headers = frame.columnHeaders or {}
    if headers.name then
        if headers.name.SetJustifyH then headers.name:SetJustifyH(getColumnHeaderAlign(config, "item", "LEFT")) end
        if headers.quality and headers.quality.SetJustifyH then headers.quality:SetJustifyH(getColumnHeaderAlign(config, "quality", "CENTER")) end
        if headers.quantity and headers.quantity.SetJustifyH then headers.quantity:SetJustifyH(getColumnHeaderAlign(config, "quantity", "CENTER")) end
        if headers.total and headers.total.SetJustifyH then headers.total:SetJustifyH(getColumnHeaderAlign(config, "total", "CENTER")) end
        if headers.itemPerHour and headers.itemPerHour.SetJustifyH then headers.itemPerHour:SetJustifyH(getColumnHeaderAlign(config, "itemPerHour", "CENTER")) end
        if headers.itemType and headers.itemType.SetJustifyH then headers.itemType:SetJustifyH(getColumnHeaderAlign(config, "itemType", "LEFT")) end
        if headers.classification and headers.classification.SetJustifyH then headers.classification:SetJustifyH(getColumnHeaderAlign(config, "classification", "LEFT")) end
        if headers.activity and headers.activity.SetJustifyH then headers.activity:SetJustifyH(getColumnHeaderAlign(config, "activity", "LEFT")) end
        if headers.expansion and headers.expansion.SetJustifyH then headers.expansion:SetJustifyH(getColumnHeaderAlign(config, "expansion", "LEFT")) end
        if headers.zone and headers.zone.SetJustifyH then headers.zone:SetJustifyH(getColumnHeaderAlign(config, "zone", "LEFT")) end
        if headers.subZone and headers.subZone.SetJustifyH then headers.subZone:SetJustifyH(getColumnHeaderAlign(config, "subZone", "LEFT")) end
        if headers.character and headers.character.SetJustifyH then headers.character:SetJustifyH(getColumnHeaderAlign(config, "character", "LEFT")) end
        if headers.price and headers.price.SetJustifyH then headers.price:SetJustifyH(getColumnHeaderAlign(config, "price", "CENTER")) end
        if headers.value and headers.value.SetJustifyH then headers.value:SetJustifyH(getColumnHeaderAlign(config, "value", "CENTER")) end

        headers.name:ClearAllPoints()
        headers.name:SetPoint("LEFT", frame.columnsHeader, "LEFT", x1, 0)
        headers.name:SetWidth(nameWidth)
        if nameWidth > 0 then headers.name:Show() else headers.name:Hide() end
        layoutColumnHeaderTooltipHitbox(frame, "name", x1, nameWidth, nameWidth > 0)

        headers.quality:ClearAllPoints()
        headers.quality:SetPoint("LEFT", frame.columnsHeader, "LEFT", xQuality, 0)
        headers.quality:SetWidth(qualityWidth)
        headers.quality:SetText("")
        if qualityWidth > 0 then headers.quality:Show() else headers.quality:Hide() end

        headers.quantity:ClearAllPoints()
        headers.quantity:SetPoint("LEFT", frame.columnsHeader, "LEFT", x2, 0)
        headers.quantity:SetWidth(quantityWidth)
        if quantityWidth > 0 then headers.quantity:Show() else headers.quantity:Hide() end
        layoutColumnHeaderTooltipHitbox(frame, "quantity", x2, quantityWidth, quantityWidth > 0)

        headers.total:ClearAllPoints()
        headers.total:SetPoint("LEFT", frame.columnsHeader, "LEFT", x3, 0)
        headers.total:SetWidth(totalWidth)
        if totalWidth > 0 then headers.total:Show() else headers.total:Hide() end
        layoutColumnHeaderTooltipHitbox(frame, "total", x3, totalWidth, totalWidth > 0)

        headers.itemPerHour:ClearAllPoints()
        headers.itemPerHour:SetPoint("LEFT", frame.columnsHeader, "LEFT", x4, 0)
        headers.itemPerHour:SetWidth(itemPerHourWidth)
        if itemPerHourWidth > 0 then headers.itemPerHour:Show() else headers.itemPerHour:Hide() end
        layoutColumnHeaderTooltipHitbox(frame, "itemPerHour", x4, itemPerHourWidth, itemPerHourWidth > 0)

        if headers.itemType then
            headers.itemType:ClearAllPoints()
            headers.itemType:SetPoint("LEFT", frame.columnsHeader, "LEFT", x5, 0)
            headers.itemType:SetWidth(itemTypeWidth)
            if itemTypeWidth > 0 then headers.itemType:Show() else headers.itemType:Hide() end
            layoutColumnHeaderTooltipHitbox(frame, "itemType", x5, itemTypeWidth, itemTypeWidth > 0)
        end

        if headers.classification then
            headers.classification:ClearAllPoints()
            headers.classification:SetPoint("LEFT", frame.columnsHeader, "LEFT", x6, 0)
            headers.classification:SetWidth(classificationWidth)
            if classificationWidth > 0 then headers.classification:Show() else headers.classification:Hide() end
            layoutColumnHeaderTooltipHitbox(frame, "classification", x6, classificationWidth, classificationWidth > 0)
        end

        if headers.activity then
            headers.activity:ClearAllPoints()
            headers.activity:SetPoint("LEFT", frame.columnsHeader, "LEFT", x7, 0)
            headers.activity:SetWidth(activityWidth)
            if activityWidth > 0 then headers.activity:Show() else headers.activity:Hide() end
            layoutColumnHeaderTooltipHitbox(frame, "activity", x7, activityWidth, activityWidth > 0)
        end

        if headers.expansion then
            headers.expansion:ClearAllPoints()
            headers.expansion:SetPoint("LEFT", frame.columnsHeader, "LEFT", x8, 0)
            headers.expansion:SetWidth(expansionWidth)
            if expansionWidth > 0 then headers.expansion:Show() else headers.expansion:Hide() end
            layoutColumnHeaderTooltipHitbox(frame, "expansion", x8, expansionWidth, expansionWidth > 0)
        end

        if headers.zone then
            headers.zone:ClearAllPoints()
            headers.zone:SetPoint("LEFT", frame.columnsHeader, "LEFT", x9, 0)
            headers.zone:SetWidth(zoneWidth)
            if zoneWidth > 0 then headers.zone:Show() else headers.zone:Hide() end
            layoutColumnHeaderTooltipHitbox(frame, "zone", x9, zoneWidth, zoneWidth > 0)
        end

        if headers.subZone then
            headers.subZone:ClearAllPoints()
            headers.subZone:SetPoint("LEFT", frame.columnsHeader, "LEFT", x10, 0)
            headers.subZone:SetWidth(subZoneWidth)
            if subZoneWidth > 0 then headers.subZone:Show() else headers.subZone:Hide() end
            layoutColumnHeaderTooltipHitbox(frame, "subZone", x10, subZoneWidth, subZoneWidth > 0)
        end

        if headers.character then
            headers.character:ClearAllPoints()
            headers.character:SetPoint("LEFT", frame.columnsHeader, "LEFT", x11, 0)
            headers.character:SetWidth(characterWidth)
            if characterWidth > 0 then headers.character:Show() else headers.character:Hide() end
            layoutColumnHeaderTooltipHitbox(frame, "character", x11, characterWidth, characterWidth > 0)
        end

        if headers.price then
            headers.price:ClearAllPoints()
            headers.price:SetPoint("LEFT", frame.columnsHeader, "LEFT", x12, 0)
            headers.price:SetWidth(priceWidth)
            if priceWidth > 0 then headers.price:Show() else headers.price:Hide() end
            layoutColumnHeaderTooltipHitbox(frame, "price", x12, priceWidth, priceWidth > 0)
        end

        if headers.value then
            headers.value:ClearAllPoints()
            headers.value:SetPoint("LEFT", frame.columnsHeader, "LEFT", x13, 0)
            headers.value:SetWidth(valueWidth)
            if valueWidth > 0 then headers.value:Show() else headers.value:Hide() end
            layoutColumnHeaderTooltipHitbox(frame, "value", x13, valueWidth, valueWidth > 0)
        end

        local dividerSpecs = buildVisibleDividerSpecs({
            name = nameWidth,
            quality = qualityWidth,
            quantity = quantityWidth,
            total = totalWidth,
            itemPerHour = itemPerHourWidth,
            itemType = itemTypeWidth,
            classification = classificationWidth,
            activity = activityWidth,
            expansion = expansionWidth,
            zone = zoneWidth,
            subZone = subZoneWidth,
            character = characterWidth,
            price = priceWidth,
            value = valueWidth,
        }, resolvedLayout, getColumnOrderKeysForFrame(frame))

        hideAllColumnDividers(frame.columnsHeader)
        for _, spec in ipairs(dividerSpecs) do
            layoutDivider(frame.columnsHeader, spec.key, spec.rightX + math.floor(gap / 2), spec.show, 1, -1)
        end

        hideAllColumnDividers(frame.scrollChild)
        for _, spec in ipairs(dividerSpecs) do
            layoutScrollChildDivider(frame, spec.key, spec.rightX + math.floor(gap / 2), spec.show)
        end
    end

    if FWR.ApplyResolvedMainFrameLayout and FWR.MainFrame and FWR.MainFrame.renderHost == frame then
        FWR:ApplyResolvedMainFrameLayout({
            contentWidth = minimumContentWidth,
            gap = gap,
        })
    end

    if frame.rows then
        for _, row in ipairs(frame.rows) do
            applyRowColumnLayout(row, frame)
        end
    end
end

local function updateRowLiveMetrics(frame, row, entry, elapsedSeconds)
    if not frame or not row or not entry then
        return
    end

    row.itemPerHour:SetText(formatItemPerHour(entry.totalCount, elapsedSeconds))
end

local function updateSecondaryTimerText(frame, elapsedSeconds, isRunning)
    if not frame or not frame.timerText then
        return
    end

    local statusText = isRunning and "LIVE" or "STOP"
    frame.timerText:SetText(string.format("Combat Timer: %s  |  %s", formatSecondsAsClock(elapsedSeconds), statusText))
end

local function clearHiddenRow(row)
    if not row then
        return
    end

    if row.itemName then
        row.itemName:SetText("")
    end
    if row.quantity then
        row.quantity:SetText("")
    end
    if row.total then
        row.total:SetText("")
    end
    if row.itemPerHour then
        row.itemPerHour:SetText("")
    end
    if row.itemType then
        row.itemType:SetText("")
    end
    if row.classification then
        row.classification:SetText("")
        row.classification:SetTextColor(0.85, 0.85, 0.85, 1)
    end
    if row.classificationHitbox then
        row.classificationHitbox.tooltipText = nil
        row.classificationHitbox:Hide()
    end
    if row.activity then
        row.activity:SetText("")
    end
    if row.activityHitbox then
        row.activityHitbox.tooltipText = nil
        row.activityHitbox:Hide()
    end
    if row.expansion then
        row.expansion:SetText("")
    end
    if row.expansionHitbox then
        row.expansionHitbox.tooltipText = nil
        row.expansionHitbox:Hide()
    end
    if row.zone then
        row.zone:SetText("")
    end
    if row.subZone then
        row.subZone:SetText("")
    end
    if row.character then
        row.character:SetText("")
    end
    if row.price then
        row.price:SetText("")
    end
    if row.value then
        row.value:SetText("")
    end
    for _, hitbox in ipairs({ row.priceHitbox, row.valueHitbox }) do
        hitbox.tooltipText = nil
        hitbox:Hide()
    end
    if row.qualityText then
        row.qualityText:SetText("")
        row.qualityText:Hide()
    end
    if row.qualityIcon then
        row.qualityIcon:Hide()
        if row.qualityIcon.SetTexture then
            row.qualityIcon:SetTexture(nil)
        end
    end
end

function FWR:RenderDisplayRows(frame)
    if not frame or not frame.scrollChild then
        return
    end

    self:UpdateDisplayColumnLayout(frame)

    local entries = getDisplayedEntries(FWR)
    local contentHeight = getContentHeight(frame)
    local contentWidth = (frame.columnWidths and frame.columnWidths.content) or math.max(420, (frame.scrollFrame:GetWidth() or 520) - 6)

    frame.scrollChild:SetSize(contentWidth, contentHeight)

    if #entries == 0 then
        frame.emptyText:Show()
        frame.emptyText:SetText("No object loaded yet.")
    else
        frame.emptyText:Hide()
    end

    for index, entry in ipairs(entries) do
        local row = ensureRow(frame, index)
        row:Show()
        row:ClearAllPoints()
        local rowHeight = getRowHeight(frame)
        local topPadding = getVerticalPadding(frame)
        local rowTop = topPadding or 0
        row:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, -(rowTop + ((index - 1) * rowHeight)))
        row:SetPoint("TOPRIGHT", frame.scrollChild, "TOPLEFT", contentWidth, -(rowTop + ((index - 1) * rowHeight)))

        local itemLabel = entry.itemName or entry.itemLink or (entry.itemID and ("item:" .. tostring(entry.itemID))) or "unknown item"
        local r, g, b = getRarityColor(entry.itemRarity)
        local itemTextWidth = (frame.columnWidths and frame.columnWidths.itemText) or 80
        local maxNameWidth = math.max(16, itemTextWidth)
        local displayLabel = truncateTextToWidth(row.itemName, itemLabel, maxNameWidth)

        row.itemName:SetText(displayLabel)
        row.itemName:SetTextColor(r, g, b, 1)
        row.quantity:SetText(tostring(tonumber(entry.quantityCount) or 0))
        row.total:SetText(tostring(tonumber(entry.totalCount) or 0))
        updateRowLiveMetrics(frame, row, entry, getDisplayElapsedSeconds(FWR))

        if row.itemType then
            local itemTypeLabel = truncateTextToWidth(row.itemType, getEntryItemTypeLabel(entry), (frame.columnWidths and frame.columnWidths.itemType) or 96)
            row.itemType:SetText(itemTypeLabel)
        end

        if row.classification then
            local rawClassificationLabel = getEntryClassificationLabel(entry)
            local classificationLabel = truncateTextToWidth(row.classification, rawClassificationLabel, (frame.columnWidths and frame.columnWidths.classification) or 96)
            row.classification:SetText(classificationLabel)
            if string.lower(rawClassificationLabel or "") == "multiple" then
                local red, green, blue, alpha
                if FWR.GetAccentGoldColor then
                    red, green, blue, alpha = FWR:GetAccentGoldColor()
                else
                    red, green, blue, alpha = 1.0, 0.82, 0.0, 1.0
                end
                row.classification:SetTextColor(red or 1.0, green or 0.82, blue or 0.0, alpha or 1.0)
            else
                row.classification:SetTextColor(0.85, 0.85, 0.85, 1)
            end
        end
        if row.classificationHitbox then
            row.classificationHitbox.tooltipText = getEntryProfessionTooltipText(entry)
            if row.classificationHitbox.tooltipText then
                row.classificationHitbox:Show()
            else
                row.classificationHitbox:Hide()
            end
        end

        if row.activity then
            local rawActivityLabel = getEntryActivityLabel(entry)
            local activityLabel = truncateTextToWidth(row.activity, rawActivityLabel, (frame.columnWidths and frame.columnWidths.activity) or 84)
            row.activity:SetText(activityLabel)
            if string.lower(rawActivityLabel or "") == "multiple" then
                local red, green, blue, alpha
                if FWR.GetAccentGoldColor then
                    red, green, blue, alpha = FWR:GetAccentGoldColor()
                else
                    red, green, blue, alpha = 1.0, 0.82, 0.0, 1.0
                end
                row.activity:SetTextColor(red or 1.0, green or 0.82, blue or 0.0, alpha or 1.0)
            else
                row.activity:SetTextColor(0.85, 0.85, 0.85, 1)
            end
        end
        if row.activityHitbox then
            row.activityHitbox.tooltipText = getEntryActivityTooltipText(entry)
            if row.activityHitbox.tooltipText then
                row.activityHitbox:Show()
            else
                row.activityHitbox:Hide()
            end
        end

        if row.expansion then
            local expansionLabel = truncateTextToWidth(row.expansion, getEntryExpansionLabel(entry), (frame.columnWidths and frame.columnWidths.expansion) or 96)
            row.expansion:SetText(expansionLabel)
        end
        if row.expansionHitbox then
            local expansionFullName = getEntryExpansionFullName(entry)
            row.expansionHitbox.tooltipText = FWR.GetExpansionTooltipText and FWR:GetExpansionTooltipText(expansionFullName, entry.expansionID) or nil
        end

        if row.zone then
            local zoneLabel = truncateTextToWidth(row.zone, getEntryZoneLabel(entry), (frame.columnWidths and frame.columnWidths.zone) or 110)
            row.zone:SetText(zoneLabel)
        end

        if row.subZone then
            local subZoneLabel = truncateTextToWidth(row.subZone, getEntrySubZoneLabel(entry), (frame.columnWidths and frame.columnWidths.subZone) or 110)
            row.subZone:SetText(subZoneLabel)
        end

        if row.character then
            local characterLabel = truncateTextToWidth(row.character, getEntryCharacterLabel(entry), (frame.columnWidths and frame.columnWidths.character) or 128)
            row.character:SetText(characterLabel)
            local classRed, classGreen, classBlue, classAlpha = getClassColorValues(entry.characterClassFile)
            row.character:SetTextColor(classRed, classGreen, classBlue, classAlpha or 1)
        end

        if row.price and row.value then
            -- the Auction House price of one item, and its worth for what was collected this session
            local priceText, valueText = getEntryPriceTexts(entry)
            row.price:SetText(priceText)
            row.value:SetText(valueText)

            -- each cell shows what the other one is: the price cell the total value, the value cell the price of one item
            local hasPrice = priceText ~= "-"
            local quantity = tonumber(entry.quantityCount) or 0
            row.priceHitbox.tooltipText = hasPrice and (valueText .. "\nWhat the " .. quantity .. " collected this session are worth: the quantity times this price.") or nil
            row.valueHitbox.tooltipText = hasPrice and ("Price per item\n" .. priceText .. " each\nThe value is this price times the session quantity (" .. quantity .. ").") or nil
        end

        applyQualityDisplay(row, entry.itemQuality)
    end

    if frame.rows then
        for index = #entries + 1, #frame.rows do
            clearHiddenRow(frame.rows[index])
            frame.rows[index]:Hide()
        end
    end

    frame.scrollFrame:UpdateScrollChildRect()
end

function FWR:RefreshDisplayScrollMetrics(frame, keepScroll)
    if not frame or not frame.scrollFrame or not frame.scrollChild then
        return
    end

    self:UpdateDisplayColumnLayout(frame)
    self:RenderDisplayRows(frame)

    local childHeight = frame.scrollChild:GetHeight() or 0
    local visibleHeight = math.max(100, frame.scrollFrame:GetHeight() or 100)
    local maxScroll = math.max(0, childHeight - visibleHeight)
    local nextScroll = keepScroll and (frame.scrollFrame:GetVerticalScroll() or 0) or 0
    if nextScroll < 0 then
        nextScroll = 0
    elseif nextScroll > maxScroll then
        nextScroll = maxScroll
    end
    frame.scrollFrame:SetVerticalScroll(nextScroll)
end

function FWR:RefreshDisplayText()
    local secondaryHost = getResolvedSecondaryDisplayHost(self)
    if secondaryHost then
        self:RefreshDisplayScrollMetrics(secondaryHost, true)
    end
    if self.MainFrame and self.MainFrame.renderHost and self.MainFrame.renderHost ~= secondaryHost then
        self:RefreshDisplayScrollMetrics(self.MainFrame.renderHost, true)
    end
end

function FWR:RefreshDisplayLiveMetrics(forceUpdate)
    local secondaryHost = getResolvedSecondaryDisplayHost(self)
    if not secondaryHost or not secondaryHost.IsShown or not secondaryHost:IsShown() then
        return
    end

    local now = GetTime()
    local elapsedSeconds, isRunning = getSecondaryDisplayTimerState(self, now)

    local roundedElapsed = math.floor((elapsedSeconds or 0) + 0.5)
    if forceUpdate or secondaryHost.lastTimerSecond ~= roundedElapsed or secondaryHost.lastTimerRunning ~= isRunning then
        secondaryHost.lastTimerSecond = roundedElapsed
        secondaryHost.lastTimerRunning = isRunning
        updateSecondaryTimerText(secondaryHost, elapsedSeconds, isRunning)
        self:UpdateDisplayColumnLayout(secondaryHost)

        local entries = getDisplayedEntries(self)
        if secondaryHost.rows then
            for index, row in ipairs(secondaryHost.rows) do
                local entry = entries[index]
                if row:IsShown() and entry then
                    updateRowLiveMetrics(secondaryHost, row, entry, elapsedSeconds)
                end
            end
        end
    end
end

function FWR:AddToDisplayBasket(classifiedEntry, quantity)
    if type(classifiedEntry) ~= "table" or not classifiedEntry.passed then
        return
    end

    local state = ensureState(self)
    local amount = tonumber(quantity) or 1
    if amount < 1 then
        amount = 1
    end

    self:ApplyContextZoneFields(classifiedEntry)

    local itemName = classifiedEntry.itemName
    local itemQuality = classifiedEntry.itemQuality
    local itemLink = classifiedEntry.itemLink
    local itemID = classifiedEntry.itemID
    local key = buildEntryKey(itemName, itemQuality, itemLink, classifiedEntry.characterKey)

    local entry = state.byKey[key]
    if not entry then
        entry = {
            key = key,
            itemName = itemName,
            itemQuality = itemQuality,
            itemLink = itemLink,
            itemID = itemID,
            itemRarity = classifiedEntry.itemRarity,
            itemTypeContext = classifiedEntry.itemTypeContext,
            profession = classifiedEntry.profession,
            baseProfession = classifiedEntry.baseProfession,
            professionTooltipText = classifiedEntry.professionTooltipText,
            activityTooltipText = classifiedEntry.activityTooltipText,
            activityKey = classifiedEntry.activityKey,
            activityContext = classifiedEntry.activityContext,
            activitySource = classifiedEntry.activitySource,
            expansionID = classifiedEntry.expansionID,
            expansionName = classifiedEntry.expansionName,
            expansionCategory = resolveEntryExpansionCategory(classifiedEntry) or classifiedEntry.expansionCategory,
            currentExpansionID = classifiedEntry.currentExpansionID,
            zoneContext = classifiedEntry.zoneContext,
            zoneName = classifiedEntry.zoneName,
            subZoneContext = classifiedEntry.subZoneContext,
            subZoneName = classifiedEntry.subZoneName,
            characterContext = classifiedEntry.characterContext,
            characterName = classifiedEntry.characterName,
            characterKey = classifiedEntry.characterKey,
            characterClassName = classifiedEntry.characterClassName,
            characterClassFile = classifiedEntry.characterClassFile,
            realmName = classifiedEntry.realmName,
            isDynamicSharedReagent = classifiedEntry.isDynamicSharedReagent == true,
            observedSourceOrder = {},
            observedSourceSet = {},
            quantityCount = 0,
            totalCount = 0,
        }
        state.byKey[key] = entry
        table.insert(state.order, key)
    end

    entry.itemName = itemName or entry.itemName
    entry.itemQuality = itemQuality
    entry.itemLink = itemLink or entry.itemLink
    entry.itemID = itemID or entry.itemID
    entry.itemRarity = classifiedEntry.itemRarity or entry.itemRarity
    entry.itemTypeContext = classifiedEntry.itemTypeContext or entry.itemTypeContext
    entry.profession = classifiedEntry.profession or entry.profession
    entry.baseProfession = classifiedEntry.baseProfession or entry.baseProfession
    entry.professionTooltipText = classifiedEntry.professionTooltipText or entry.professionTooltipText
    entry.activityTooltipText = classifiedEntry.activityTooltipText or entry.activityTooltipText
    entry.activityKey = classifiedEntry.activityKey or entry.activityKey
    entry.activityContext = classifiedEntry.activityContext or entry.activityContext
    entry.activitySource = classifiedEntry.activitySource or entry.activitySource
    entry.expansionID = classifiedEntry.expansionID or entry.expansionID
    entry.expansionName = classifiedEntry.expansionName or entry.expansionName
    entry.expansionCategory = resolveEntryExpansionCategory(classifiedEntry) or classifiedEntry.expansionCategory or entry.expansionCategory
    entry.currentExpansionID = classifiedEntry.currentExpansionID or entry.currentExpansionID
    entry.zoneContext = classifiedEntry.zoneContext or entry.zoneContext
    entry.zoneName = classifiedEntry.zoneName or entry.zoneName
    entry.subZoneContext = classifiedEntry.subZoneContext or entry.subZoneContext
    entry.subZoneName = classifiedEntry.subZoneName or entry.subZoneName
    entry.characterContext = classifiedEntry.characterContext or entry.characterContext
    entry.characterName = classifiedEntry.characterName or entry.characterName
    entry.characterKey = classifiedEntry.characterKey or entry.characterKey
    entry.characterClassName = classifiedEntry.characterClassName or entry.characterClassName
    entry.characterClassFile = classifiedEntry.characterClassFile or entry.characterClassFile
    entry.realmName = classifiedEntry.realmName or entry.realmName
    entry.isDynamicSharedReagent = classifiedEntry.isDynamicSharedReagent == true or entry.isDynamicSharedReagent == true

    local observedSourceLabel = classifiedEntry.observedSourceLabel or classifiedEntry.activityContext or classifiedEntry.triggerSource or classifiedEntry.sourceType
    if isProcessingDisplayEntry(classifiedEntry) then
        observedSourceLabel = "Processing"
    end
    addObservedSource(entry, observedSourceLabel)
    applyDynamicSharedReagentState(entry)

    entry.quantityCount = (entry.quantityCount or 0) + amount
    entry.totalCount = (entry.totalCount or 0) + amount

    self:Emit("lootRecorded", classifiedEntry, amount)

    if self.TouchDatabase then
        self:TouchDatabase()
    end
    self:RefreshDisplayText()
end

function FWR:QueueDisplayRefreshes()
    self:RefreshDisplayText()
    self:RefreshDisplayLiveMetrics(true)
    if not C_Timer or not C_Timer.After then
        return
    end

    C_Timer.After(0, function()
        if FarmWiseReforged and FarmWiseReforged.RefreshDisplayText then
            FarmWiseReforged:RefreshDisplayText()
            FarmWiseReforged:RefreshDisplayLiveMetrics(true)
        end
    end)

    C_Timer.After(0.15, function()
        if FarmWiseReforged and FarmWiseReforged.RefreshDisplayText then
            FarmWiseReforged:RefreshDisplayText()
            FarmWiseReforged:RefreshDisplayLiveMetrics(true)
        end
    end)

    C_Timer.After(0.75, function()
        if FarmWiseReforged and FarmWiseReforged.RefreshDisplayText then
            FarmWiseReforged:RefreshDisplayText()
            FarmWiseReforged:RefreshDisplayLiveMetrics(true)
        end
    end)
end

function FWR:GetResolvedMainFrameContentWidth()
    local config = self:GetMainRenderConfig() or {}
    local function resolveStaticWidth(columnConfig, fallbackWidth)
        local visible = true
        if type(columnConfig) == "table" and columnConfig.visible ~= nil then
            visible = not not columnConfig.visible
        end
        if not visible then
            return 0
        end
        local width = tonumber(type(columnConfig) == "table" and columnConfig.width) or tonumber(fallbackWidth) or 0
        local minWidth = tonumber(type(columnConfig) == "table" and columnConfig.minWidth)
        if minWidth ~= nil then
            width = math.max(width, minWidth)
        end
        return math.max(0, width)
    end

    local widths = {
        name = resolveStaticWidth(config.item, 125),
        quality = resolveStaticWidth(config.quality, 15),
        quantity = resolveStaticWidth(config.quantity, 50),
        total = resolveStaticWidth(config.total, 50),
        itemPerHour = resolveStaticWidth(config.itemPerHour, 50),
        itemType = resolveStaticWidth(config.itemType, 85),
        classification = resolveStaticWidth(config.classification, 0),
        activity = resolveStaticWidth(config.activity, 0),
        expansion = resolveStaticWidth(config.expansion, 0),
        zone = resolveStaticWidth(config.zone, 0),
        subZone = resolveStaticWidth(config.subZone, 0),
        character = resolveStaticWidth(config.character, 0),
        price = resolveStaticWidth(config.price, 0),
        value = resolveStaticWidth(config.value, 0),
        gap = math.max(0, tonumber(config.gap) or 1),
    }
    return buildResolvedColumnLayout(widths).content
end

function FWR:GetMinimumMainFrameContentWidth()
    local config = self:GetMainRenderConfig() or {}
    local function resolveWidth(columnConfig, fallbackWidth, hardMinimum)
        local width = tonumber(type(columnConfig) == "table" and columnConfig.width) or tonumber(fallbackWidth) or 0
        local minWidth = tonumber(type(columnConfig) == "table" and columnConfig.minWidth)
        if minWidth ~= nil then
            width = math.max(width, minWidth)
        end
        if hardMinimum ~= nil then
            width = math.max(width, tonumber(hardMinimum) or 0)
        end
        return math.max(0, width)
    end

    local widths = {
        name = resolveWidth(config.item, 125, 125),
        quality = resolveWidth(config.quality, 15, 15),
        quantity = resolveWidth(config.quantity, 50, 50),
        total = resolveWidth(config.total, 50, 50),
        itemPerHour = resolveWidth(config.itemPerHour, 50, 50),
        itemType = 0,
        classification = 0,
        activity = 0,
        expansion = 0,
        zone = 0,
        subZone = 0,
        character = 0,
        price = 0,
        value = 0,
        gap = math.max(0, tonumber(config.gap) or 1),
    }
    return buildResolvedColumnLayout(widths).content
end

function FWR:GetResolvedMainFrameShellWidth(contentWidth)
    local mainFrameConfig = self.UI_CONFIG and self.UI_CONFIG.MainFrame or {}
    local scrollConfig = type(mainFrameConfig.scroll) == "table" and mainFrameConfig.scroll or {}
    local content = math.max(0, tonumber(contentWidth) or 0)
    local scrollBarWidth = math.max(6, 10 + (tonumber(scrollConfig.width) or 0))
    local gapBefore = 2
    local gapAfter = 2
    return content + (MAIN_FRAME_SIDE_INSET * 2) + gapBefore + scrollBarWidth + gapAfter
end

function FWR:GetDisplayRenderConfig()
    return FULL_COLUMN_CONFIG
end

local REORDERABLE_MAIN_COLUMNS = { "quantity", "total", "itemPerHour", "activity", "itemType", "classification", "expansion", "zone", "subZone", "character", "price", "value" }
local OPTIONAL_MAIN_COLUMNS = { "quantity", "total", "itemPerHour", "activity", "itemType", "classification", "expansion", "zone", "subZone", "character", "price", "value" }
local DEFAULT_MAIN_COLUMN_ORDER = {
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
}

function FWR:NormalizeDisplayColumnSettings()
    self.Settings = self.Settings or {}
    local display = self.Settings.display or {}
    self.Settings.display = display
    local optionalColumns = type(display.optionalColumns) == "table" and display.optionalColumns or {}
    display.optionalColumns = optionalColumns
    local columnOrder = type(display.columnOrder) == "table" and display.columnOrder or {}
    display.columnOrder = columnOrder

    local enabledOrdered = {}
    for _, key in ipairs(REORDERABLE_MAIN_COLUMNS) do
        if optionalColumns[key] == nil then
            optionalColumns[key] = (key == "quantity" or key == "total" or key == "itemPerHour")
        end

        if optionalColumns[key] == true then
            local defaultPos = DEFAULT_MAIN_COLUMN_ORDER[key] or 99
            local currentPos = math.floor(tonumber(columnOrder[key]) or defaultPos)
            if currentPos < 2 then
                currentPos = defaultPos
            end
            columnOrder[key] = currentPos
            enabledOrdered[#enabledOrdered + 1] = key
        else
            columnOrder[key] = 0
        end
    end

    table.sort(enabledOrdered, function(a, b)
        local aPos = math.floor(tonumber(columnOrder[a]) or DEFAULT_MAIN_COLUMN_ORDER[a] or 99)
        local bPos = math.floor(tonumber(columnOrder[b]) or DEFAULT_MAIN_COLUMN_ORDER[b] or 99)
        if aPos == bPos then
            return tostring(a) < tostring(b)
        end
        return aPos < bPos
    end)

    local position = 2
    for _, key in ipairs(enabledOrdered) do
        columnOrder[key] = position
        position = position + 1
    end

    return display
end

function FWR:SetOptionalMainColumnEnabled(columnKey, enabled)
    if type(columnKey) ~= "string" or columnKey == "item" or columnKey == "quality" then
        return self:NormalizeDisplayColumnSettings()
    end

    local display = self:NormalizeDisplayColumnSettings()
    local optionalColumns = display.optionalColumns or {}
    local columnOrder = display.columnOrder or {}
    local isEnabled = enabled == true

    if isEnabled then
        local enabledCount = 0
        for _, key in ipairs(REORDERABLE_MAIN_COLUMNS) do
            if key ~= columnKey and optionalColumns[key] == true then
                enabledCount = enabledCount + 1
            end
        end
        optionalColumns[columnKey] = true
        columnOrder[columnKey] = enabledCount + 2
    else
        optionalColumns[columnKey] = false
        columnOrder[columnKey] = 0
    end

    return self:NormalizeDisplayColumnSettings()
end

function FWR:GetEnabledReorderableMainColumnCount()
    local display = self:NormalizeDisplayColumnSettings()
    local optionalColumns = display.optionalColumns or {}
    local count = 0
    for _, key in ipairs(REORDERABLE_MAIN_COLUMNS) do
        if optionalColumns[key] == true then
            count = count + 1
        end
    end
    return count
end

function FWR:GetOrderedMainColumnKeys()
    local display = self:NormalizeDisplayColumnSettings()
    local columnOrder = display.columnOrder or {}
    local optionalColumns = display.optionalColumns or {}
    local ordered = { "item", "quality" }
    local sortable = {}
    for _, key in ipairs(REORDERABLE_MAIN_COLUMNS) do
        if optionalColumns[key] == true then
            sortable[#sortable + 1] = key
        end
    end
    table.sort(sortable, function(a, b)
        local aPos = tonumber(columnOrder[a]) or DEFAULT_MAIN_COLUMN_ORDER[a] or 99
        local bPos = tonumber(columnOrder[b]) or DEFAULT_MAIN_COLUMN_ORDER[b] or 99
        if aPos == bPos then
            return tostring(a) < tostring(b)
        end
        return aPos < bPos
    end)
    for _, key in ipairs(sortable) do
        table.insert(ordered, key)
    end
    return ordered
end

function FWR:IsOptionalMainColumnEnabled(columnKey)
    local settings = self.Settings or {}
    local display = settings.display or {}
    local optionalColumns = display.optionalColumns or {}

    if optionalColumns[columnKey] ~= nil then
        return optionalColumns[columnKey] == true
    end

    local renderingConfig = FWR.UI_CONFIG and FWR.UI_CONFIG.Rendering
    local columns = renderingConfig and renderingConfig.columns or {}
    local columnConfig = columns[columnKey]
    if type(columnConfig) == "table" then
        return columnConfig.visible == true
    end

    return false
end

function FWR:GetMainRenderConfig()
    if self.NormalizeDisplayColumnSettings then
        self:NormalizeDisplayColumnSettings()
    end
    local renderingConfig = FWR.UI_CONFIG and FWR.UI_CONFIG.Rendering
    local sourceColumns = renderingConfig and renderingConfig.columns or nil
    local config = cloneColumnConfig(sourceColumns)

    for _, key in ipairs(OPTIONAL_MAIN_COLUMNS) do
        if type(config[key]) == "table" then
            local enabled = self:IsOptionalMainColumnEnabled(key)
            config[key].visible = enabled
            if enabled then
                local sourceColumn = type(sourceColumns) == "table" and sourceColumns[key] or nil
                local width = tonumber(type(sourceColumn) == "table" and sourceColumn.width)
                if width == nil or width <= 0 then
                    width = tonumber((FULL_COLUMN_CONFIG[key] or {}).width) or tonumber((DEFAULT_MAIN_COLUMN_CONFIG[key] or {}).width) or 0
                end
                local minWidth = tonumber(type(sourceColumn) == "table" and sourceColumn.minWidth)
                if minWidth ~= nil then
                    width = math.max(width, minWidth)
                end
                config[key].width = math.max(0, width)
            else
                config[key].width = 0
            end
        end
    end

    return config
end

function FWR:ApplyDisplaySettings()
    local host = self.MainFrame and self.MainFrame.renderHost or nil
    if host then
        host.renderColumnConfig = self:GetMainRenderConfig()
        host.renderLayoutConfig = self:GetMainRenderLayoutConfig()
        host.renderColumnOrderKeys = self:GetOrderedMainColumnKeys()
        host.columnOrderKeys = host.renderColumnOrderKeys

        if host.columnHeaders then
            local config = host.renderColumnConfig or {}
            if host.columnHeaders.name then host.columnHeaders.name:SetText((config.item and config.item.label) or "Item Name") end
            if host.columnHeaders.quality then host.columnHeaders.quality:SetText((config.quality and config.quality.label) or "") end
            if host.columnHeaders.quantity then host.columnHeaders.quantity:SetText((config.quantity and config.quantity.label) or "Quantity") end
            if host.columnHeaders.total then host.columnHeaders.total:SetText((config.total and config.total.label) or "Total") end
            if host.columnHeaders.itemPerHour then host.columnHeaders.itemPerHour:SetText((config.itemPerHour and config.itemPerHour.label) or "Item / Hour") end
            if host.columnHeaders.itemType then host.columnHeaders.itemType:SetText((config.itemType and config.itemType.label) or "Reagent Type") end
            if host.columnHeaders.classification then host.columnHeaders.classification:SetText((config.classification and config.classification.label) or "Profession") end
            if host.columnHeaders.activity then host.columnHeaders.activity:SetText((config.activity and config.activity.label) or "Activity") end
            if host.columnHeaders.expansion then host.columnHeaders.expansion:SetText((config.expansion and config.expansion.label) or "Expansion") end
            if host.columnHeaders.zone then host.columnHeaders.zone:SetText((config.zone and config.zone.label) or "Zone") end
            if host.columnHeaders.subZone then host.columnHeaders.subZone:SetText((config.subZone and config.subZone.label) or "Sub-Zone") end
            if host.columnHeaders.character then host.columnHeaders.character:SetText((config.character and config.character.label) or "Character") end
            if host.columnHeaders.price then host.columnHeaders.price:SetText((config.price and config.price.label) or "Price") end
            if host.columnHeaders.value then host.columnHeaders.value:SetText((config.value and config.value.label) or "Value") end
        end

        if self.UpdateDisplayColumnLayout then
            self:UpdateDisplayColumnLayout(host)
        end
        if self.RefreshDisplayScrollMetrics then
            self:RefreshDisplayScrollMetrics(host, true)
        end
    end

    if self.MainFrame and self.ApplyMainFrameBackdropTransparency then
        self:ApplyMainFrameBackdropTransparency()
    end

    if self.QueueMainWindowRefreshes then
        self:QueueMainWindowRefreshes()
    elseif self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end

    if self.RefreshDisplayLiveMetrics then
        self:RefreshDisplayLiveMetrics(true)
    end
end

function FWR:GetMainRenderLayoutConfig()
    local renderingConfig = FWR.UI_CONFIG and FWR.UI_CONFIG.Rendering
    local layout = cloneMainLayoutConfig(renderingConfig and renderingConfig.layout)
    local settings = self.Settings and self.Settings.display or nil
    local configuredRows = math.floor(tonumber(settings and settings.visibleRows) or layout.visibleRows or DEFAULT_MAIN_VISIBLE_ROWS)
    layout.visibleRows = math.max(5, math.min(20, configuredRows))
    return layout
end

function FWR:QueueMainWindowRefreshes()
    self:RefreshMainWindowText()
    if not C_Timer or not C_Timer.After then
        return
    end

    C_Timer.After(0, function()
        if FarmWiseReforged and FarmWiseReforged.RefreshMainWindowText then
            FarmWiseReforged:RefreshMainWindowText()
        end
    end)

    C_Timer.After(0.15, function()
        if FarmWiseReforged and FarmWiseReforged.RefreshMainWindowText then
            FarmWiseReforged:RefreshMainWindowText()
        end
    end)
end

function FWR:RefreshDisplayFilterButtonStates()
    local secondaryHost = getResolvedSecondaryDisplayHost(self)
    if not secondaryHost then
        return
    end

    if secondaryHost.specializedToggleButton then
        local isVisible = self.IsSpecializedClassificationVisible and self:IsSpecializedClassificationVisible()
        secondaryHost.specializedToggleButton:SetText(isVisible and "Show P/C: ON" or "Show P/C: OFF")
    end

    if secondaryHost.oldExpansionToggleButton then
        local isVisible = self.IsOldExpansionVisible and self:IsOldExpansionVisible()
        secondaryHost.oldExpansionToggleButton:SetText(isVisible and "Show Old: ON" or "Show Old: OFF")
    end
end
