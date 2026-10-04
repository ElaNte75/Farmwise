local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

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

local function buildBaseContextKey(zoneName, subZoneName)
    zoneName = normalizeText(zoneName) or ""
    subZoneName = normalizeText(subZoneName)

    if zoneName == "" then
        return ""
    end

    if subZoneName and subZoneName ~= "" then
        return zoneName .. "||" .. subZoneName
    end

    return zoneName
end

local function resolveCurrentZoneContext()
    local zoneName = normalizeText(type(GetRealZoneText) == "function" and GetRealZoneText() or nil)
        or normalizeText(type(GetZoneText) == "function" and GetZoneText() or nil)
    local subZoneName = normalizeText(type(GetSubZoneText) == "function" and GetSubZoneText() or nil)

    if subZoneName == zoneName then
        subZoneName = nil
    end

    return zoneName, subZoneName
end

local function resolveCurrentCharacterContext()
    local characterName = nil
    local realmName = nil

    if type(UnitFullName) == "function" then
        local resolvedCharacterName, resolvedRealmName = UnitFullName("player")
        characterName = normalizeText(resolvedCharacterName)
        realmName = normalizeText(resolvedRealmName)
    end

    if not characterName and type(UnitName) == "function" then
        local resolvedCharacterName, resolvedRealmName = UnitName("player")
        characterName = normalizeText(resolvedCharacterName)
        realmName = realmName or normalizeText(resolvedRealmName)
    end

    return characterName, realmName
end

local function resolveVendorValue(itemInfo)
    if not itemInfo then
        return 0
    end

    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemInfo)
    return math.max(0, tonumber(sellPrice) or 0)
end

local function buildRejectedItemKey(itemID, itemLink, itemName)
    if tonumber(itemID) then
        return "item:" .. tostring(itemID)
    end

    if type(itemLink) == "string" and itemLink ~= "" then
        return "link:" .. itemLink
    end

    if type(itemName) == "string" and itemName ~= "" then
        return "name:" .. itemName
    end

    return nil
end

local function ensureRejectedLootLedger(db)
    db = type(db) == "table" and db or {}
    db.rejectedLoot = type(db.rejectedLoot) == "table" and db.rejectedLoot or {}

    local ledger = db.rejectedLoot
    ledger.nextID = tonumber(ledger.nextID) or 1
    ledger.byID = type(ledger.byID) == "table" and ledger.byID or {}
    ledger.pendingByItemKey = type(ledger.pendingByItemKey) == "table" and ledger.pendingByItemKey or {}
    ledger.pendingByContextKey = type(ledger.pendingByContextKey) == "table" and ledger.pendingByContextKey or {}
    return ledger
end

local function ensurePendingItemBucket(ledger, itemKey)
    ledger.pendingByItemKey[itemKey] = type(ledger.pendingByItemKey[itemKey]) == "table" and ledger.pendingByItemKey[itemKey] or {}
    local bucket = ledger.pendingByItemKey[itemKey]
    bucket.order = type(bucket.order) == "table" and bucket.order or {}
    bucket.pendingQuantity = tonumber(bucket.pendingQuantity) or 0
    bucket.pendingVendorValue = tonumber(bucket.pendingVendorValue) or 0
    return bucket
end

local function ensurePendingContextBucket(ledger, contextKey, zoneName, subZoneName)
    contextKey = contextKey ~= "" and contextKey or "__unknown"
    ledger.pendingByContextKey[contextKey] = type(ledger.pendingByContextKey[contextKey]) == "table" and ledger.pendingByContextKey[contextKey] or {}

    local bucket = ledger.pendingByContextKey[contextKey]
    bucket.contextKey = contextKey
    bucket.zoneName = zoneName
    bucket.subZoneName = subZoneName
    bucket.pendingQuantity = tonumber(bucket.pendingQuantity) or 0
    bucket.pendingVendorValue = tonumber(bucket.pendingVendorValue) or 0
    bucket.entryCount = tonumber(bucket.entryCount) or 0
    return bucket
end

local function resolveRejectedStageCandidate(stageResults)
    if type(stageResults) ~= "table" then
        return nil
    end

    local stageTwo = stageResults.stageTwo
    if type(stageTwo) == "table"
        and stageTwo.previousStagePassed
        and not stageTwo.passed
        and stageTwo.reason ~= "item_info_not_ready"
        and stageTwo.reason ~= "blocked_by_previous_stage"
    then
        return stageTwo
    end

    local stageThree = stageResults.stageThree
    if type(stageThree) == "table"
        and stageThree.previousStagePassed
        and not stageThree.passed
        and stageThree.reason ~= "item_info_not_ready"
        and stageThree.reason ~= "blocked_by_previous_stage"
    then
        return stageThree
    end

    return nil
end



local function roundCopper(value)
    return math.max(0, math.floor((tonumber(value) or 0) + 0.5))
end

local function getContainerNumSlotsCompat(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID)
    end

    if type(GetContainerNumSlots) == "function" then
        return GetContainerNumSlots(bagID)
    end

    return 0
end

local function getContainerItemLinkCompat(bagID, slotIndex)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagID, slotIndex)
    end

    if type(GetContainerItemLink) == "function" then
        return GetContainerItemLink(bagID, slotIndex)
    end

    return nil
end

local function getContainerItemCountCompat(bagID, slotIndex)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bagID, slotIndex)
        return tonumber(info and info.stackCount) or 0
    end

    if type(GetContainerItemInfo) == "function" then
        local _, count = GetContainerItemInfo(bagID, slotIndex)
        return tonumber(count) or 0
    end

    return 0
end

local function getVendorBagEndIndex()
    return tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or tonumber(NUM_BAG_SLOTS) or 4
end

local function buildPendingItemKeySet(ledger)
    local keySet = {}

    for itemKey, bucket in pairs(ledger.pendingByItemKey or {}) do
        if type(bucket) == "table"
            and tonumber(bucket.pendingQuantity) and tonumber(bucket.pendingQuantity) > 0
            and tonumber(bucket.pendingVendorValue) and tonumber(bucket.pendingVendorValue) > 0
        then
            keySet[itemKey] = true
        end
    end

    return keySet
end

local function buildPendingBagSnapshot(ledger)
    local snapshot = {
        byItemKey = {},
        capturedAt = type(GetTime) == "function" and GetTime() or 0,
    }

    local pendingKeySet = buildPendingItemKeySet(ledger)
    if next(pendingKeySet) == nil then
        return snapshot
    end

    for itemKey in pairs(pendingKeySet) do
        snapshot.byItemKey[itemKey] = 0
    end

    local startBag = tonumber(BACKPACK_CONTAINER) or 0
    local endBag = getVendorBagEndIndex()

    for bagID = startBag, endBag do
        local slotCount = tonumber(getContainerNumSlotsCompat(bagID)) or 0
        if slotCount > 0 then
            for slotIndex = 1, slotCount do
                local itemLink = getContainerItemLinkCompat(bagID, slotIndex)
                if itemLink then
                    local itemID = GetItemInfoInstant and GetItemInfoInstant(itemLink) or nil
                    local itemName = GetItemInfo and (select(1, GetItemInfo(itemLink))) or nil
                    local itemKey = buildRejectedItemKey(itemID, itemLink, itemName)
                    if itemKey and pendingKeySet[itemKey] then
                        snapshot.byItemKey[itemKey] = (tonumber(snapshot.byItemKey[itemKey]) or 0) + math.max(0, tonumber(getContainerItemCountCompat(bagID, slotIndex)) or 0)
                    end
                end
            end
        end
    end

    return snapshot
end

local function snapshotHasTrackedKeys(snapshot)
    return type(snapshot) == "table"
        and type(snapshot.byItemKey) == "table"
        and next(snapshot.byItemKey) ~= nil
end

local function ensureVendorMonitorState(self)
    self.VendorMonitorState = type(self.VendorMonitorState) == "table" and self.VendorMonitorState or {}
    local state = self.VendorMonitorState
    state.active = state.active == true
    state.snapshot = type(state.snapshot) == "table" and state.snapshot or { byItemKey = {} }
    state.lastKnownSnapshot = type(state.lastKnownSnapshot) == "table" and state.lastKnownSnapshot or { byItemKey = {} }
    state.lastSettledAt = tonumber(state.lastSettledAt) or 0
    return state
end

local function mergeContextSettlement(target, settlement)
    if type(target) ~= "table" or type(settlement) ~= "table" then
        return
    end

    local contextKey = settlement.contextKey or "__unknown"
    target[contextKey] = target[contextKey] or {
        contextKey = contextKey,
        zoneName = settlement.zoneName,
        subZoneName = settlement.subZoneName,
        copper = 0,
        quantity = 0,
    }

    local bucket = target[contextKey]
    bucket.zoneName = bucket.zoneName or settlement.zoneName
    bucket.subZoneName = bucket.subZoneName or settlement.subZoneName
    bucket.copper = (tonumber(bucket.copper) or 0) + (tonumber(settlement.copper) or 0)
    bucket.quantity = (tonumber(bucket.quantity) or 0) + (tonumber(settlement.quantity) or 0)
end

function FWR:EnsureRejectedLootLedger()
    self:EnsureDatabases()
    return ensureRejectedLootLedger(self.DB)
end

function FWR:TrackRejectedLootFromStageResults(stageResults, quantity)
    local rejectedCandidate = resolveRejectedStageCandidate(stageResults)
    if type(rejectedCandidate) ~= "table" then
        return nil
    end

    if rejectedCandidate.sourceType ~= "world" then
        return nil
    end

    quantity = math.max(1, math.floor(tonumber(quantity) or 1))

    local itemInfo = rejectedCandidate.itemInfo or rejectedCandidate.itemLink or rejectedCandidate.itemID
    local itemID = rejectedCandidate.itemID or (itemInfo and GetItemInfoInstant(itemInfo)) or nil
    local itemName = rejectedCandidate.itemName
    local itemLink = rejectedCandidate.itemLink or (itemInfo and select(2, GetItemInfo(itemInfo)) or nil)
    local unitVendorValue = resolveVendorValue(itemInfo or itemLink or itemID)

    if unitVendorValue <= 0 then
        return nil
    end

    local itemKey = buildRejectedItemKey(itemID, itemLink, itemName)
    if not itemKey then
        return nil
    end

    local zoneName, subZoneName = resolveCurrentZoneContext()
    local baseContextKey = buildBaseContextKey(zoneName, subZoneName)
    local characterName, realmName = resolveCurrentCharacterContext()
    local characterKey = (self.BuildCharacterKey and self:BuildCharacterKey(characterName, realmName)) or ""
    local contextKey = (self.BuildCharacterScopedContextKey and self:BuildCharacterScopedContextKey(baseContextKey, characterKey)) or baseContextKey

    local ledger = self:EnsureRejectedLootLedger()
    local entryID = ledger.nextID
    ledger.nextID = entryID + 1

    local totalVendorValue = unitVendorValue * quantity

    local entry = {
        entryID = entryID,
        itemKey = itemKey,
        itemID = itemID,
        itemName = itemName,
        itemLink = itemLink,
        itemRarity = rejectedCandidate.itemRarity,
        itemQuality = rejectedCandidate.itemQuality,
        itemType = rejectedCandidate.itemType,
        itemSubType = rejectedCandidate.itemSubType,
        bindType = rejectedCandidate.bindType,
        quantity = quantity,
        remainingQuantity = quantity,
        unitVendorValue = unitVendorValue,
        totalVendorValue = totalVendorValue,
        remainingVendorValue = totalVendorValue,
        sourceType = rejectedCandidate.sourceType,
        rejectedStage = rejectedCandidate.stage,
        rejectedReason = rejectedCandidate.reason,
        zoneName = zoneName,
        subZoneName = subZoneName,
        contextKey = contextKey,
        characterName = characterName,
        realmName = realmName,
        characterKey = characterKey,
        trackedAt = self:Now(),
    }

    ledger.byID[entryID] = entry

    local itemBucket = ensurePendingItemBucket(ledger, itemKey)
    table.insert(itemBucket.order, entryID)
    itemBucket.pendingQuantity = itemBucket.pendingQuantity + quantity
    itemBucket.pendingVendorValue = itemBucket.pendingVendorValue + totalVendorValue

    local contextBucket = ensurePendingContextBucket(ledger, contextKey, zoneName, subZoneName)
    contextBucket.pendingQuantity = contextBucket.pendingQuantity + quantity
    contextBucket.pendingVendorValue = contextBucket.pendingVendorValue + totalVendorValue
    contextBucket.entryCount = contextBucket.entryCount + 1

    self:TouchDatabase()
    if self.RefreshRejectedLootBagSnapshot then
        self:RefreshRejectedLootBagSnapshot()
    end
    return entry
end



function FWR:ResolveRejectedLootVendorSettlement(itemKey, quantity)
    if type(itemKey) ~= "string" or itemKey == "" then
        return nil
    end

    quantity = math.max(0, math.floor(tonumber(quantity) or 0))
    if quantity <= 0 then
        return nil
    end

    local ledger = self:EnsureRejectedLootLedger()
    local itemBucket = ledger.pendingByItemKey[itemKey]
    if type(itemBucket) ~= "table" then
        return nil
    end

    local now = self:Now()
    local settledQuantity = 0
    local settledCopper = 0
    local settlementsByContext = {}

    while quantity > 0 do
        local entryID = itemBucket.order and itemBucket.order[1] or nil
        if not entryID then
            break
        end

        local entry = ledger.byID and ledger.byID[entryID] or nil
        if type(entry) ~= "table" or (tonumber(entry.remainingQuantity) or 0) <= 0 then
            table.remove(itemBucket.order, 1)
        else
            local consumeQuantity = math.min(quantity, math.max(0, math.floor(tonumber(entry.remainingQuantity) or 0)))
            local unitVendorValue = math.max(0, roundCopper(entry.unitVendorValue))
            local consumedCopper = consumeQuantity * unitVendorValue

            entry.remainingQuantity = math.max(0, (tonumber(entry.remainingQuantity) or 0) - consumeQuantity)
            entry.remainingVendorValue = math.max(0, roundCopper((tonumber(entry.remainingVendorValue) or 0) - consumedCopper))
            entry.soldQuantity = (tonumber(entry.soldQuantity) or 0) + consumeQuantity
            entry.soldVendorValue = (tonumber(entry.soldVendorValue) or 0) + consumedCopper
            entry.lastSoldAt = now

            settledQuantity = settledQuantity + consumeQuantity
            settledCopper = settledCopper + consumedCopper
            quantity = quantity - consumeQuantity

            local contextKey = (type(entry.contextKey) == "string" and entry.contextKey ~= "") and entry.contextKey or "__unknown"
            mergeContextSettlement(settlementsByContext, {
                contextKey = contextKey,
                zoneName = entry.zoneName,
                subZoneName = entry.subZoneName,
                copper = consumedCopper,
                quantity = consumeQuantity,
            })

            local contextBucket = ensurePendingContextBucket(ledger, contextKey, entry.zoneName, entry.subZoneName)
            contextBucket.pendingQuantity = math.max(0, (tonumber(contextBucket.pendingQuantity) or 0) - consumeQuantity)
            contextBucket.pendingVendorValue = math.max(0, roundCopper((tonumber(contextBucket.pendingVendorValue) or 0) - consumedCopper))
            contextBucket.realizedQuantity = (tonumber(contextBucket.realizedQuantity) or 0) + consumeQuantity
            contextBucket.realizedVendorValue = (tonumber(contextBucket.realizedVendorValue) or 0) + consumedCopper
            contextBucket.updatedAt = now

            if (tonumber(entry.remainingQuantity) or 0) <= 0 or (tonumber(entry.remainingVendorValue) or 0) <= 0 then
                table.remove(itemBucket.order, 1)
            end
        end
    end

    itemBucket.pendingQuantity = math.max(0, (tonumber(itemBucket.pendingQuantity) or 0) - settledQuantity)
    itemBucket.pendingVendorValue = math.max(0, roundCopper((tonumber(itemBucket.pendingVendorValue) or 0) - settledCopper))
    itemBucket.realizedQuantity = (tonumber(itemBucket.realizedQuantity) or 0) + settledQuantity
    itemBucket.realizedVendorValue = (tonumber(itemBucket.realizedVendorValue) or 0) + settledCopper
    itemBucket.updatedAt = now

    if (tonumber(itemBucket.pendingQuantity) or 0) <= 0 or (tonumber(itemBucket.pendingVendorValue) or 0) <= 0 then
        ledger.pendingByItemKey[itemKey] = nil
    end

    for contextKey, contextBucket in pairs(ledger.pendingByContextKey or {}) do
        if type(contextBucket) == "table"
            and (tonumber(contextBucket.pendingQuantity) or 0) <= 0
            and (tonumber(contextBucket.pendingVendorValue) or 0) <= 0
        then
            ledger.pendingByContextKey[contextKey] = nil
        end
    end

    if settledQuantity <= 0 or settledCopper <= 0 then
        return nil
    end

    self:TouchDatabase()
    return {
        itemKey = itemKey,
        quantity = settledQuantity,
        copper = settledCopper,
        byContext = settlementsByContext,
    }
end

function FWR:RefreshRejectedLootBagSnapshot()
    local state = ensureVendorMonitorState(self)
    state.lastKnownSnapshot = buildPendingBagSnapshot(self:EnsureRejectedLootLedger())
    return state.lastKnownSnapshot
end

function FWR:HandleMerchantShow()
    local state = ensureVendorMonitorState(self)
    state.active = true
    state.snapshot = snapshotHasTrackedKeys(state.lastKnownSnapshot) and state.lastKnownSnapshot or buildPendingBagSnapshot(self:EnsureRejectedLootLedger())
    state.lastSettledAt = tonumber(state.lastSettledAt) or 0
end

function FWR:HandleMerchantClosed()
    local state = ensureVendorMonitorState(self)
    state.active = false
    state.snapshot = { byItemKey = {} }
    state.lastKnownSnapshot = buildPendingBagSnapshot(self:EnsureRejectedLootLedger())
end

function FWR:HandleVendorBagUpdateDelayed()
    local state = ensureVendorMonitorState(self)
    local ledger = self:EnsureRejectedLootLedger()
    local currentSnapshot = buildPendingBagSnapshot(ledger)

    if not state.active then
        state.lastKnownSnapshot = currentSnapshot
        return nil
    end

    local previousSnapshot = type(state.snapshot) == "table" and state.snapshot or state.lastKnownSnapshot or { byItemKey = {} }
    local settlementsByContext = {}
    local settledAnything = false

    for itemKey, previousCount in pairs(previousSnapshot.byItemKey or {}) do
        local currentCount = tonumber(currentSnapshot.byItemKey[itemKey]) or 0
        previousCount = tonumber(previousCount) or 0

        if previousCount > currentCount then
            local quantitySold = previousCount - currentCount
            local settlement = self:ResolveRejectedLootVendorSettlement(itemKey, quantitySold)
            if settlement and type(settlement.byContext) == "table" then
                settledAnything = true
                for _, contextSettlement in pairs(settlement.byContext) do
                    mergeContextSettlement(settlementsByContext, contextSettlement)
                end
            end
        end
    end

    state.snapshot = currentSnapshot
    state.lastKnownSnapshot = currentSnapshot
    state.lastSettledAt = self:Now()

    if not settledAnything then
        return nil
    end

    for _, contextSettlement in pairs(settlementsByContext) do
        if self.RecordVendorSoldCopperForContext then
            self:RecordVendorSoldCopperForContext(
                contextSettlement.contextKey,
                contextSettlement.zoneName,
                contextSettlement.subZoneName,
                contextSettlement.copper
            )
        end
    end

    if self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end

    return settlementsByContext
end

function FWR:GetRejectedLootSummary()
    local ledger = ensureRejectedLootLedger(self.DB or FarmWiseReforgedDB or {})

    local totalPendingQuantity = 0
    local totalPendingVendorValue = 0
    for _, bucket in pairs(ledger.pendingByContextKey) do
        totalPendingQuantity = totalPendingQuantity + (tonumber(bucket.pendingQuantity) or 0)
        totalPendingVendorValue = totalPendingVendorValue + (tonumber(bucket.pendingVendorValue) or 0)
    end

    local entryCount = 0
    for _ in pairs(ledger.byID) do
        entryCount = entryCount + 1
    end

    local contextBucketCount = 0
    for _ in pairs(ledger.pendingByContextKey) do
        contextBucketCount = contextBucketCount + 1
    end

    return {
        entries = entryCount,
        contexts = contextBucketCount,
        pendingQuantity = totalPendingQuantity,
        pendingVendorValue = totalPendingVendorValue,
    }
end

function FWR:GetRejectedLootPendingVendorValueForContext(contextKey)
    local ledger = ensureRejectedLootLedger(self.DB or FarmWiseReforgedDB or {})
    local resolvedContextKey = (type(contextKey) == "string" and contextKey ~= "") and contextKey or "__global"
    local bucket = ledger.pendingByContextKey[resolvedContextKey]
    return math.max(0, tonumber(bucket and bucket.pendingVendorValue) or 0)
end
