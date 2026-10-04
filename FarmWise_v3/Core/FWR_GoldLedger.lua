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

local function escapePattern(text)
    return (tostring(text or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function buildFormatPattern(formatText)
    if type(formatText) ~= "string" or formatText == "" then
        return nil
    end

    local pattern = escapePattern(formatText)
    pattern = pattern:gsub("%%%%d", "([%%d%%.,]+)")
    pattern = pattern:gsub("%%%%s", ".+")
    return pattern
end

local function buildAmountPattern(formatText)
    if type(formatText) ~= "string" or formatText == "" then
        return nil
    end

    local pattern = escapePattern(formatText)
    pattern = pattern:gsub("%%%%d", "([%%d%%.,]+)")
    return pattern
end

local function roundCopper(value)
    return math.max(0, math.floor((tonumber(value) or 0) + 0.5))
end

local function createMoneyIconMarkup(texturePath)
    return string.format("|T%s:12:12:2:0|t", texturePath)
end

local GOLD_ICON = createMoneyIconMarkup("Interface\\MoneyFrame\\UI-GoldIcon")
local SILVER_ICON = createMoneyIconMarkup("Interface\\MoneyFrame\\UI-SilverIcon")
local COPPER_ICON = createMoneyIconMarkup("Interface\\MoneyFrame\\UI-CopperIcon")

local function formatMoneyShort(copper)
    copper = roundCopper(copper)

    if type(GetCoinTextureString) == "function" then
        return GetCoinTextureString(copper)
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100

    if gold > 0 then
        return string.format("%d%s %d%s %d%s", gold, GOLD_ICON, silver, SILVER_ICON, copperOnly, COPPER_ICON)
    end

    if silver > 0 then
        return string.format("%d%s %d%s", silver, SILVER_ICON, copperOnly, COPPER_ICON)
    end

    return string.format("%d%s", copperOnly, COPPER_ICON)
end

local function buildBaseContextKey(self, zoneName, subZoneName)
    zoneName = normalizeText(zoneName) or ""
    subZoneName = normalizeText(subZoneName)

    if zoneName == "" then
        return ""
    end

    local useSubZone = self and self.IsSubZoneDataEnabled and self:IsSubZoneDataEnabled() or false
    if useSubZone and subZoneName and subZoneName ~= "" then
        return zoneName .. "::" .. subZoneName
    end

    return zoneName
end

local function getCurrentGoldContextInfo(self)
    local idleState = self.EnsureIdleSystemState and self:EnsureIdleSystemState() or nil
    local current = idleState and idleState.current or nil

    local zoneName = normalizeText(current and current.zone)
    local subZoneName = normalizeText(current and current.subzone)
    local contextKey = normalizeText(current and current.key)

    if not contextKey and zoneName then
        local baseContextKey = buildBaseContextKey(self, zoneName, subZoneName)
        local characterKey = self.GetCurrentCharacterKey and select(1, self:GetCurrentCharacterKey()) or ""
        contextKey = self.BuildCharacterScopedContextKey and self:BuildCharacterScopedContextKey(baseContextKey, characterKey) or baseContextKey
    end

    return contextKey or "__global", zoneName, subZoneName
end

local function ensureGoldLedger(db)
    db = type(db) == "table" and db or {}
    db.goldLedger = type(db.goldLedger) == "table" and db.goldLedger or {}

    local ledger = db.goldLedger
    ledger.byContextKey = type(ledger.byContextKey) == "table" and ledger.byContextKey or {}
    return ledger
end

local function ensureGoldContextBucket(ledger, contextKey, zoneName, subZoneName)
    contextKey = (type(contextKey) == "string" and contextKey ~= "") and contextKey or "__global"
    ledger.byContextKey[contextKey] = type(ledger.byContextKey[contextKey]) == "table" and ledger.byContextKey[contextKey] or {}

    local bucket = ledger.byContextKey[contextKey]
    bucket.contextKey = contextKey
    bucket.zoneName = zoneName
    bucket.subZoneName = subZoneName
    bucket.rawLootCopperTotal = tonumber(bucket.rawLootCopperTotal) or 0
    bucket.rawLootCopperSession = tonumber(bucket.rawLootCopperSession) or 0
    bucket.vendorSoldCopperTotal = tonumber(bucket.vendorSoldCopperTotal) or 0
    bucket.vendorSoldCopperSession = tonumber(bucket.vendorSoldCopperSession) or 0
    bucket.updatedAt = tonumber(bucket.updatedAt) or 0
    return bucket
end

local function getLootMoneyMessagePatterns()
    return {
        buildFormatPattern(_G and _G.YOU_LOOT_MONEY),
        buildFormatPattern(_G and _G.LOOT_MONEY),
        buildFormatPattern(_G and _G.LOOT_MONEY_SPLIT),
        buildFormatPattern(_G and _G.YOU_LOOT_MONEY_GUILD),
    }
end

local function messageLooksLikeLootMoney(message)
    if type(message) ~= "string" or message == "" then
        return false
    end

    local foundTemplate = false
    for _, pattern in ipairs(getLootMoneyMessagePatterns()) do
        if pattern and pattern ~= "" then
            foundTemplate = true
            if message:match("^" .. pattern .. "$") then
                return true
            end
        end
    end

    return not foundTemplate
end

local function parseMoneyAmountFromMessage(message)
    if type(message) ~= "string" or message == "" then
        return 0
    end

    local goldPattern = buildAmountPattern(_G and (_G.GOLD_AMOUNT or _G.GOLD_AMOUNT_SYMBOL))
    local silverPattern = buildAmountPattern(_G and (_G.SILVER_AMOUNT or _G.SILVER_AMOUNT_SYMBOL))
    local copperPattern = buildAmountPattern(_G and (_G.COPPER_AMOUNT or _G.COPPER_AMOUNT_SYMBOL))

    local function resolveAmount(pattern)
        local amountText = pattern and message:match(pattern) or nil
        if type(amountText) ~= "string" or amountText == "" then
            return 0
        end

        amountText = amountText:gsub("[^%d]", "")
        return tonumber(amountText) or 0
    end

    local gold = resolveAmount(goldPattern)
    local silver = resolveAmount(silverPattern)
    local copper = resolveAmount(copperPattern)

    return math.max(0, (gold * 10000) + (silver * 100) + copper)
end

local function getCurrentPendingVendorValue(self, contextKey)
    if not self.GetRejectedLootPendingVendorValueForContext then
        return 0
    end

    return math.max(0, tonumber(self:GetRejectedLootPendingVendorValueForContext(contextKey)) or 0)
end

function FWR:EnsureGoldLedger()
    self:EnsureDatabases()
    return ensureGoldLedger(self.DB)
end

function FWR:EnsureGoldContext(contextKey, zoneName, subZoneName)
    local ledger = self:EnsureGoldLedger()
    return ensureGoldContextBucket(ledger, contextKey, zoneName, subZoneName)
end

function FWR:GetGoldContextSummary(contextKey)
    local resolvedContextKey = contextKey
    local zoneName = nil
    local subZoneName = nil

    if type(resolvedContextKey) ~= "string" or resolvedContextKey == "" then
        resolvedContextKey, zoneName, subZoneName = getCurrentGoldContextInfo(self)
    end

    local context = self:EnsureGoldContext(resolvedContextKey, zoneName, subZoneName)
    local realizedTotalCopper = (tonumber(context.rawLootCopperTotal) or 0) + (tonumber(context.vendorSoldCopperTotal) or 0)
    local realizedSessionCopper = (tonumber(context.rawLootCopperSession) or 0) + (tonumber(context.vendorSoldCopperSession) or 0)
    local pendingVendorCopper = getCurrentPendingVendorValue(self, resolvedContextKey)
    local idleState = self.EnsureIdleSystemState and self:EnsureIdleSystemState() or nil
    local idleContext = idleState and idleState.timersByContext and idleState.timersByContext[resolvedContextKey] or nil
    local totalSeconds = tonumber(idleContext and idleContext.totalSeconds) or 0
    local estimatedCopperPerHour = 0

    if tonumber(totalSeconds) and totalSeconds > 0 then
        estimatedCopperPerHour = (realizedTotalCopper * 3600) / totalSeconds
    end

    return {
        contextKey = resolvedContextKey,
        zoneName = context.zoneName,
        subZoneName = context.subZoneName,
        rawLootCopperTotal = tonumber(context.rawLootCopperTotal) or 0,
        rawLootCopperSession = tonumber(context.rawLootCopperSession) or 0,
        vendorSoldCopperTotal = tonumber(context.vendorSoldCopperTotal) or 0,
        vendorSoldCopperSession = tonumber(context.vendorSoldCopperSession) or 0,
        realizedTotalCopper = realizedTotalCopper,
        realizedSessionCopper = realizedSessionCopper,
        pendingVendorCopper = pendingVendorCopper,
        totalSeconds = tonumber(totalSeconds) or 0,
        estimatedCopperPerHour = estimatedCopperPerHour,
    }
end

function FWR:GetLiveTotalGoldText()
    local summary = self:GetGoldContextSummary()
    return formatMoneyShort(summary.realizedTotalCopper)
end

function FWR:GetLiveEstimatedGoldPerHourText()
    local summary = self:GetGoldContextSummary()
    return formatMoneyShort(summary.estimatedCopperPerHour)
end

function FWR:GetMoneyBreakdownFromCopper(copper)
    copper = roundCopper(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100
    return gold, silver, copperOnly
end

function FWR:GetLiveTotalGoldBreakdown()
    local summary = self:GetGoldContextSummary()
    return self:GetMoneyBreakdownFromCopper(summary.realizedTotalCopper)
end

function FWR:GetLiveEstimatedGoldPerHourBreakdown()
    local summary = self:GetGoldContextSummary()
    return self:GetMoneyBreakdownFromCopper(summary.estimatedCopperPerHour)
end

function FWR:ResetCurrentSessionGoldContext()
    local contextKey, zoneName, subZoneName = getCurrentGoldContextInfo(self)
    local context = self:EnsureGoldContext(contextKey, zoneName, subZoneName)
    context.rawLootCopperSession = 0
    context.vendorSoldCopperSession = 0
    context.updatedAt = self:Now()
    self:TouchDatabase()
    return context
end

function FWR:RecordVendorSoldCopperForContext(contextKey, zoneName, subZoneName, copper)
    copper = roundCopper(copper)
    if copper <= 0 then
        return nil
    end

    local context = self:EnsureGoldContext(contextKey, zoneName, subZoneName)
    context.vendorSoldCopperTotal = (tonumber(context.vendorSoldCopperTotal) or 0) + copper
    context.vendorSoldCopperSession = (tonumber(context.vendorSoldCopperSession) or 0) + copper
    context.updatedAt = self:Now()

    self:TouchDatabase()
    if self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end

    return context, copper
end

function FWR:HandleLootMoneyChatMessage(message)
    if type(message) ~= "string" or message == "" then
        return nil
    end

    if type(MerchantFrame) == "table" and type(MerchantFrame.IsShown) == "function" and MerchantFrame:IsShown() then
        return nil
    end

    if not messageLooksLikeLootMoney(message) then
        return nil
    end

    local copper = parseMoneyAmountFromMessage(message)
    if copper <= 0 then
        return nil
    end

    local contextKey, zoneName, subZoneName = getCurrentGoldContextInfo(self)
    local context = self:EnsureGoldContext(contextKey, zoneName, subZoneName)
    context.rawLootCopperTotal = (tonumber(context.rawLootCopperTotal) or 0) + copper
    context.rawLootCopperSession = (tonumber(context.rawLootCopperSession) or 0) + copper
    context.updatedAt = self:Now()

    if self.RecordAdvisorGold then
        self:RecordAdvisorGold(copper)
    end

    self:TouchDatabase()
    if self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end

    return context, copper
end
