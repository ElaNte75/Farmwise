local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

local function buildEmptyDatabase(now, dbVersion, buildName)
    return {
        meta = {
            dbVersion = dbVersion,
            build = buildName,
            createdAt = now,
            updatedAt = now,
            resets = 0,
        },

        schema = {
            notes = {
                "Core storage for FarmWise Reforged data.",
                "Characters are stored in characters.byKey.",
                "Items are stored in itemCatalog.byKey.",
                "Recorded entries are stored in records.byID.",
                "Summaries are stored in summaries.",
                "Rejected non-tracked loot candidates are stored in rejectedLoot.",
                "Gold summaries by source context are stored in goldLedger.",
            },
            characters = {
                root = "characters.byKey[characterKey]",
                purpose = "Character identity and character-linked tracking data.",
            },
            itemCatalog = {
                root = "itemCatalog.byKey[itemKey]",
                purpose = "Item identity catalog for tracked items.",
            },
            records = {
                root = "records.byID[recordID]",
                purpose = "Raw recorded entries.",
                nextIDField = "records.nextID",
            },
            summaries = {
                root = "summaries",
                purpose = "Rolled-up data for display and advisor use.",
            },
            rejectedLoot = {
                root = "rejectedLoot.byID[entryID]",
                purpose = "Rejected but vendor-relevant loot ledger keyed by source context.",
                nextIDField = "rejectedLoot.nextID",
            },
            goldLedger = {
                root = "goldLedger.byContextKey[contextKey]",
                purpose = "Gold summaries keyed by source context.",
            },
        },

        characters = {
            byKey = {},
        },
        itemCatalog = {
            byKey = {},
        },
        records = {
            nextID = 1,
            byID = {},
        },
        summaries = {
            characters = {},
            items = {},
            zones = {},
            professions = {},
        },
        rejectedLoot = {
            nextID = 1,
            byID = {},
            pendingByItemKey = {},
            pendingByContextKey = {},
        },
        goldLedger = {
            byContextKey = {},
        },

        renderState = {
            displayBasketByContext = {},
            currentContextKey = "__global",
            displayBasket = {
                order = {},
                byKey = {},
            },
        },
    }
end

local function buildEmptySettings()
    return {}
end


local function normalizeDisplayBasketAliases(renderState)
    renderState = type(renderState) == "table" and renderState or {}

    local displayBasket = type(renderState.displayBasket) == "table" and renderState.displayBasket or nil
    local legacyDisplayBasket = type(renderState.legacyDisplayBasket) == "table" and renderState.legacyDisplayBasket or nil
    local debugDisplayBasketAlias = type(renderState.debugAggregate) == "table" and renderState.debugAggregate or nil

    if not displayBasket then
        displayBasket = legacyDisplayBasket or debugDisplayBasketAlias
    end

    if not displayBasket then
        displayBasket = { order = {}, byKey = {} }
    end

    displayBasket.order = displayBasket.order or {}
    displayBasket.byKey = displayBasket.byKey or {}
    renderState.displayBasket = displayBasket
    return displayBasket
end

local function normalizeDisplayFilterAliases(settings, defaults)
    settings = type(settings) == "table" and settings or {}

    local displayFilters = type(settings.displayFilters) == "table" and settings.displayFilters or nil
    local legacyDisplayFilters = type(settings.legacyDisplayFilters) == "table" and settings.legacyDisplayFilters or nil
    local debugDisplayFilterAlias = type(settings.debugRender) == "table" and settings.debugRender or nil

    if not displayFilters then
        displayFilters = legacyDisplayFilters or debugDisplayFilterAlias
    end

    if not displayFilters then
        displayFilters = FWR:DeepCopy((defaults and defaults.displayFilters) or {})
    end

    settings.displayFilters = displayFilters or {}
    return settings.displayFilters
end

function FWR:EnsureDatabases()
    local now = self:Now()

    if type(FarmWiseReforgedDB) ~= "table" then
        FarmWiseReforgedDB = buildEmptyDatabase(now, self.DB_VERSION, self.BUILD_NAME)
    end

    if type(FarmWiseReforgedSettingsDB) ~= "table" then
        FarmWiseReforgedSettingsDB = buildEmptySettings()
    end

    FarmWiseReforgedDB.meta = FarmWiseReforgedDB.meta or {}
    FarmWiseReforgedDB.meta.dbVersion = self.DB_VERSION
    FarmWiseReforgedDB.meta.build = self.BUILD_NAME
    FarmWiseReforgedDB.meta.createdAt = FarmWiseReforgedDB.meta.createdAt or now
    FarmWiseReforgedDB.meta.updatedAt = now
    FarmWiseReforgedDB.meta.resets = tonumber(FarmWiseReforgedDB.meta.resets) or 0

    FarmWiseReforgedDB.schema = FarmWiseReforgedDB.schema or buildEmptyDatabase(now, self.DB_VERSION, self.BUILD_NAME).schema
    FarmWiseReforgedDB.schema.rejectedLoot = FarmWiseReforgedDB.schema.rejectedLoot or {
        root = "rejectedLoot.byID[entryID]",
        purpose = "Rejected but vendor-relevant loot ledger keyed by source context.",
        nextIDField = "rejectedLoot.nextID",
    }
    FarmWiseReforgedDB.schema.goldLedger = FarmWiseReforgedDB.schema.goldLedger or {
        root = "goldLedger.byContextKey[contextKey]",
        purpose = "Gold summaries keyed by source context.",
    }
    FarmWiseReforgedDB.characters = FarmWiseReforgedDB.characters or { byKey = {} }
    FarmWiseReforgedDB.characters.byKey = FarmWiseReforgedDB.characters.byKey or {}
    FarmWiseReforgedDB.itemCatalog = FarmWiseReforgedDB.itemCatalog or { byKey = {} }
    FarmWiseReforgedDB.itemCatalog.byKey = FarmWiseReforgedDB.itemCatalog.byKey or {}
    FarmWiseReforgedDB.records = FarmWiseReforgedDB.records or { nextID = 1, byID = {} }
    FarmWiseReforgedDB.records.nextID = tonumber(FarmWiseReforgedDB.records.nextID) or 1
    FarmWiseReforgedDB.records.byID = FarmWiseReforgedDB.records.byID or {}
    FarmWiseReforgedDB.summaries = FarmWiseReforgedDB.summaries or {}
    FarmWiseReforgedDB.summaries.characters = FarmWiseReforgedDB.summaries.characters or {}
    FarmWiseReforgedDB.summaries.items = FarmWiseReforgedDB.summaries.items or {}
    FarmWiseReforgedDB.summaries.zones = FarmWiseReforgedDB.summaries.zones or {}
    FarmWiseReforgedDB.summaries.professions = FarmWiseReforgedDB.summaries.professions or {}
    FarmWiseReforgedDB.rejectedLoot = FarmWiseReforgedDB.rejectedLoot or { nextID = 1, byID = {}, pendingByItemKey = {}, pendingByContextKey = {} }
    FarmWiseReforgedDB.rejectedLoot.nextID = tonumber(FarmWiseReforgedDB.rejectedLoot.nextID) or 1
    FarmWiseReforgedDB.rejectedLoot.byID = FarmWiseReforgedDB.rejectedLoot.byID or {}
    FarmWiseReforgedDB.rejectedLoot.pendingByItemKey = FarmWiseReforgedDB.rejectedLoot.pendingByItemKey or {}
    FarmWiseReforgedDB.rejectedLoot.pendingByContextKey = FarmWiseReforgedDB.rejectedLoot.pendingByContextKey or {}
    FarmWiseReforgedDB.goldLedger = FarmWiseReforgedDB.goldLedger or { byContextKey = {} }
    FarmWiseReforgedDB.goldLedger.byContextKey = FarmWiseReforgedDB.goldLedger.byContextKey or {}
    FarmWiseReforgedDB.renderState = FarmWiseReforgedDB.renderState or {}
    FarmWiseReforgedDB.renderState.displayBasketByContext = FarmWiseReforgedDB.renderState.displayBasketByContext or {}
    FarmWiseReforgedDB.renderState.currentContextKey = FarmWiseReforgedDB.renderState.currentContextKey or "__global"

    local displayBasket = normalizeDisplayBasketAliases(FarmWiseReforgedDB.renderState)

    FarmWiseReforgedSettingsDB = FWR:MergeDefaults(FarmWiseReforgedSettingsDB, FWR.DEFAULT_SETTINGS)

    local displayFilters = normalizeDisplayFilterAliases(FarmWiseReforgedSettingsDB, FWR.DEFAULT_SETTINGS)

    self.DB = FarmWiseReforgedDB
    self.Settings = FarmWiseReforgedSettingsDB
    return self.DB, self.Settings
end

function FWR:TouchDatabase()
    if self.DB and self.DB.meta then
        self.DB.meta.updatedAt = self:Now()
    end
end

function FWR:ClearAllSavedData()
    local now = self:Now()
    local previousResets = tonumber(FarmWiseReforgedDB and FarmWiseReforgedDB.meta and FarmWiseReforgedDB.meta.resets) or 0

    FarmWiseReforgedDB = buildEmptyDatabase(now, self.DB_VERSION, self.BUILD_NAME)
    FarmWiseReforgedDB.meta.resets = previousResets + 1
    FarmWiseReforgedDB.meta.updatedAt = now

    self.DB = FarmWiseReforgedDB

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

    if self.RefreshDisplayLiveMetrics then
        self:RefreshDisplayLiveMetrics(true)
    end

    return self.DB
end

local function countKeys(root)
    local total = 0
    if type(root) ~= "table" then
        return total
    end
    for _ in pairs(root) do
        total = total + 1
    end
    return total
end

function FWR:GetStorageStatusSummary()
    local db = self.DB or FarmWiseReforgedDB or {}
    return {
        characters = countKeys(db.characters and db.characters.byKey or nil),
        items = countKeys(db.itemCatalog and db.itemCatalog.byKey or nil),
        records = countKeys(db.records and db.records.byID or nil),
        summaries = countKeys(db.summaries and db.summaries.items or nil)
            + countKeys(db.summaries and db.summaries.characters or nil)
            + countKeys(db.summaries and db.summaries.zones or nil)
            + countKeys(db.summaries and db.summaries.professions or nil),
        rejectedEntries = countKeys(db.rejectedLoot and db.rejectedLoot.byID or nil),
        rejectedContexts = countKeys(db.rejectedLoot and db.rejectedLoot.pendingByContextKey or nil),
    }
end
