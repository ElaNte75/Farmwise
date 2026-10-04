local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

local rebuildState = {
    running = false,
    processed = 0,
    total = 0,
    updated = 0,
    removed = 0,
    statusText = "",
    entries = nil,
    index = 1,
}

local PROCESS_PER_TICK = 40
local UPDATE_INTERVAL = 0.05
local tickerFrame

local ITEM_TYPE_TO_PROFESSION = {
    ["Cloth"] = "Tailoring",
    ["Leather"] = "Leatherworking",
    ["Scale"] = "Leatherworking",
    ["Ore"] = "Mining",
    ["Stone"] = "Mining",
    ["Gem"] = "Jewelcrafting",
    ["Herb"] = "Herbalism",
    ["Pigment"] = "Inscription",
    ["Ink"] = "Inscription",
    ["Card"] = "Inscription",
    ["Darkmoon"] = "Inscription",
    ["Dust"] = "Enchanting",
    ["Essence"] = "Enchanting",
    ["Shard"] = "Enchanting",
    ["Fish"] = "Fishing",
    ["Meat"] = "Cooking",
}

local function normalizeText(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function lowerText(value)
    value = normalizeText(value)
    if not value then
        return ""
    end
    return string.lower(value)
end

local ITEM_NAME_NUMBER_WORDS = {
    ["ace"] = true,
    ["one"] = true,
    ["two"] = true,
    ["three"] = true,
    ["four"] = true,
    ["five"] = true,
    ["six"] = true,
    ["seven"] = true,
    ["eight"] = true,
}

local function collectTooltipText(itemReference)
    if not itemReference or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then
        return ""
    end

    local hyperlink = itemReference
    if type(itemReference) == "number" then
        hyperlink = "item:" .. tostring(itemReference)
    end
    if type(hyperlink) ~= "string" or hyperlink == "" then
        return ""
    end

    local chunks = {}
    local info = C_TooltipInfo.GetHyperlink(hyperlink)
    if type(info) ~= "table" or type(info.lines) ~= "table" then
        return ""
    end

    for _, line in ipairs(info.lines) do
        if type(line) == "table" then
            if type(line.leftText) == "string" and line.leftText ~= "" then
                chunks[#chunks + 1] = line.leftText
            end
            if type(line.rightText) == "string" and line.rightText ~= "" then
                chunks[#chunks + 1] = line.rightText
            end
        end
    end

    return table.concat(chunks, " ")
end

local function buildSearchText(entry)
    local parts = {}
    local liveTooltipText = collectTooltipText(entry.itemLink or entry.itemID)
    local fields = {
        entry.itemName,
        entry.itemLink,
        entry.itemTypeContext,
        entry.profession,
        entry.baseProfession,
        entry.professionTooltipText,
        entry.activityTooltipText,
        liveTooltipText,
    }

    for _, value in ipairs(fields) do
        local normalized = normalizeText(value)
        if normalized then
            parts[#parts + 1] = string.lower(normalized)
        end
    end

    return table.concat(parts, " ")
end

local function inferItemTypeContext(entry)
    local currentType = normalizeText(entry.itemTypeContext)
    local text = buildSearchText(entry)
    local itemName = lowerText(entry.itemName)

    local firstWord = itemName:match("^(%a+)%s+of%s+")
    if currentType == "Card" or currentType == "Darkmoon"
        or itemName:find("^ace of ")
        or itemName:find("^%d+ of ")
        or (firstWord and ITEM_NAME_NUMBER_WORDS[firstWord])
        or text:find("darkmoon")
        or text:find("combine the ace through 8")
        or text:find("combine the ace through eight") then
        return "Darkmoon"
    end

    if currentType == "Crafting Reagent" or currentType == "Finishing Reagent" then
        return "Reagent"
    end

    if currentType == "Elemental Reagent"
        or text:find("mote")
        or text:find("primal")
        or text:find("volatile")
        or text:find("eternal")
        or text:find("crystallized")
        or text:find("elemental") then
        return "Elemental Reagent"
    end

    if currentType and currentType ~= "" then
        return currentType
    end

    local _, _, _, _, _, itemClass, itemSubClass = GetItemInfoInstant(entry.itemLink or entry.itemID or 0)
    local classText = lowerText(itemClass)
    local subClassText = lowerText(itemSubClass)

    if subClassText:find("cloth") then
        return "Cloth"
    elseif subClassText:find("leather") then
        return "Leather"
    elseif subClassText:find("metal") or subClassText:find("ore") then
        return "Ore"
    elseif subClassText:find("stone") then
        return "Stone"
    elseif subClassText:find("herb") then
        return "Herb"
    elseif subClassText:find("gem") then
        return "Gem"
    elseif subClassText:find("fish") then
        return "Fish"
    elseif classText:find("reagent") then
        return "Reagent"
    end

    return entry.itemTypeContext or "General"
end

local function inferProfession(entry, itemTypeContext)
    local currentProfession = normalizeText(entry.profession)
    local currentBaseProfession = normalizeText(entry.baseProfession)

    if currentProfession and currentProfession ~= "General" and currentProfession ~= "" then
        return currentProfession, currentBaseProfession or currentProfession
    end

    local inferred = ITEM_TYPE_TO_PROFESSION[itemTypeContext]
    if inferred and inferred ~= "" then
        return inferred, inferred
    end

    return currentProfession or "General", currentBaseProfession or currentProfession or "General"
end

local function inferActivity(entry, itemTypeContext)
    local activityKey = lowerText(entry.activityKey)
    local activityContext = normalizeText(entry.activityContext)
    local observed = type(entry.observedSourceOrder) == "table" and entry.observedSourceOrder or nil

    if activityKey == "processing" or lowerText(activityContext) == "processing" then
        return "processing", "Processing"
    end

    if observed then
        for _, label in ipairs(observed) do
            if lowerText(label) == "processing" then
                return "processing", "Processing"
            end
        end
    end

    if itemTypeContext == "Pigment" or itemTypeContext == "Ink" or itemTypeContext == "Dust"
        or itemTypeContext == "Essence" or itemTypeContext == "Shard" then
        if activityKey == "loot" or activityKey == "combat" or activityKey == "" then
            return "processing", "Processing"
        end
    end

    return entry.activityKey, entry.activityContext
end

local function entryHasObservedSource(entry, needle)
    local observed = type(entry and entry.observedSourceOrder) == "table" and entry.observedSourceOrder or nil
    local wanted = lowerText(needle)
    if wanted == "" or not observed then
        return false
    end

    for _, label in ipairs(observed) do
        if lowerText(label) == wanted then
            return true
        end
    end

    return false
end

local function shouldRemoveDerivedOutputEntry(entry)
    if type(entry) ~= "table" then
        return false
    end

    local itemTypeContext = normalizeText(entry.itemTypeContext)
    local activityKey = lowerText(entry.activityKey)
    local activityContext = lowerText(entry.activityContext)
    local observedCrafting = entryHasObservedSource(entry, "Crafting")
    local observedProcessing = entryHasObservedSource(entry, "Processing")

    if activityKey == "crafting" or activityContext == "crafting" or observedCrafting then
        return true
    end

    if activityKey == "processing" or activityContext == "processing" or observedProcessing then
        return true
    end

    if itemTypeContext == "Bolt" or itemTypeContext == "Ink" then
        return true
    end

    return false
end

local function rebuildEntry(entry)
    if type(entry) ~= "table" then
        return false, false
    end

    if shouldRemoveDerivedOutputEntry(entry) then
        return false, true
    end

    local changed = false
    local newItemType = inferItemTypeContext(entry)
    if normalizeText(newItemType) ~= normalizeText(entry.itemTypeContext) then
        entry.itemTypeContext = newItemType
        changed = true
    end

    local newProfession, newBaseProfession = inferProfession(entry, entry.itemTypeContext)
    if normalizeText(newProfession) ~= normalizeText(entry.profession) then
        entry.profession = newProfession
        changed = true
    end
    if normalizeText(newBaseProfession) ~= normalizeText(entry.baseProfession) then
        entry.baseProfession = newBaseProfession
        changed = true
    end

    local newActivityKey, newActivityContext = inferActivity(entry, entry.itemTypeContext)
    if normalizeText(newActivityKey) ~= normalizeText(entry.activityKey) then
        entry.activityKey = newActivityKey
        changed = true
    end
    if normalizeText(newActivityContext) ~= normalizeText(entry.activityContext) then
        entry.activityContext = newActivityContext
        changed = true
    end

    return changed, false
end

local function removeOrderKey(order, targetKey)
    if type(order) ~= "table" or targetKey == nil then
        return
    end

    for index = #order, 1, -1 do
        if order[index] == targetKey then
            table.remove(order, index)
        end
    end
end

local function collectEntriesFromBasket(basket, seen, entries)
    if type(basket) ~= "table" or type(basket.byKey) ~= "table" then
        return
    end

    local order = type(basket.order) == "table" and basket.order or nil
    for key, entry in pairs(basket.byKey) do
        if type(entry) == "table" then
            local identity = tostring(basket) .. "::" .. tostring(key)
            if not seen[identity] then
                seen[identity] = true
                entries[#entries + 1] = {
                    basket = basket,
                    key = key,
                    order = order,
                    entry = entry,
                }
            end
        end
    end
end

local function buildWorkList(self)
    local entries = {}
    local seen = {}
    local db = self and self.DB or nil
    local renderState = db and db.renderState or nil

    if type(renderState) == "table" then
        collectEntriesFromBasket(renderState.displayBasket, seen, entries)
        if type(renderState.displayBasketByContext) == "table" then
            for _, basket in pairs(renderState.displayBasketByContext) do
                collectEntriesFromBasket(basket, seen, entries)
            end
        end
    end

    return entries
end

local function removeEntryLocation(workItem)
    if type(workItem) ~= "table" then
        return false
    end

    local basket = workItem.basket
    local key = workItem.key
    if type(basket) ~= "table" or type(basket.byKey) ~= "table" or key == nil then
        return false
    end

    if basket.byKey[key] == nil then
        return false
    end

    basket.byKey[key] = nil
    removeOrderKey(workItem.order or basket.order, key)
    return true
end

local function finishRebuild(self)
    rebuildState.running = false
    rebuildState.entries = nil
    rebuildState.index = 1
    rebuildState.statusText = string.format("Rebuild complete. Updated %d rows. Removed %d derived rows.", rebuildState.updated or 0, rebuildState.removed or 0)

    if tickerFrame then
        tickerFrame:SetScript("OnUpdate", nil)
        tickerFrame:Hide()
    end

    if self.TouchDatabase then
        self:TouchDatabase()
    end
    if self.ApplyDisplaySettings then
        self:ApplyDisplaySettings()
    elseif self.RefreshDisplayText then
        self:RefreshDisplayText()
    end
    if self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end
end

local function processChunk(self)
    local entries = rebuildState.entries or {}
    local total = rebuildState.total or 0
    local lastIndex = math.min(rebuildState.index + PROCESS_PER_TICK - 1, total)

    for idx = rebuildState.index, lastIndex do
        local workItem = entries[idx]
        local entry = workItem and workItem.entry or nil
        local changed, removed = rebuildEntry(entry)
        if removed == true then
            if removeEntryLocation(workItem) then
                rebuildState.removed = (rebuildState.removed or 0) + 1
            end
        elseif changed == true then
            rebuildState.updated = (rebuildState.updated or 0) + 1
        end
        rebuildState.processed = idx
    end

    rebuildState.index = lastIndex + 1

    local percent = 0
    if total > 0 then
        percent = math.floor((rebuildState.processed / total) * 100)
    end
    rebuildState.statusText = string.format("Processing... %d%% (%d / %d)", percent, rebuildState.processed or 0, total)

    if rebuildState.processed >= total then
        finishRebuild(self)
    end
end

local function bindTickerFrame(frame, self)
    frame:SetScript("OnUpdate", function(innerFrame, elapsed)
        innerFrame.accumulated = (innerFrame.accumulated or 0) + (elapsed or 0)
        if innerFrame.accumulated < UPDATE_INTERVAL then
            return
        end
        innerFrame.accumulated = 0
        processChunk(self)
    end)
end

local function ensureTickerFrame(self)
    if not tickerFrame then
        tickerFrame = CreateFrame("Frame")
        tickerFrame:Hide()
    end

    tickerFrame.accumulated = 0
    bindTickerFrame(tickerFrame, self)
    return tickerFrame
end

function FWR:StartSavedDataRebuild()
    if rebuildState.running then
        return false
    end

    local entries = buildWorkList(self)
    rebuildState.running = true
    rebuildState.entries = entries
    rebuildState.index = 1
    rebuildState.processed = 0
    rebuildState.updated = 0
    rebuildState.removed = 0
    rebuildState.total = #entries
    rebuildState.statusText = "Preparing rebuild..."

    if rebuildState.total == 0 then
        finishRebuild(self)
        return true
    end

    local frame = ensureTickerFrame(self)
    frame.accumulated = 0
    frame:Show()
    return true
end

function FWR:IsSavedDataRebuildRunning()
    return rebuildState.running == true
end

function FWR:GetSavedDataRebuildStatus()
    local total = tonumber(rebuildState.total) or 0
    local processed = tonumber(rebuildState.processed) or 0
    local percent = 0
    if total > 0 then
        percent = math.floor((processed / total) * 100)
    end

    return {
        running = rebuildState.running == true,
        processed = processed,
        total = total,
        updated = tonumber(rebuildState.updated) or 0,
        removed = tonumber(rebuildState.removed) or 0,
        percent = percent,
        text = rebuildState.statusText or "",
    }
end
