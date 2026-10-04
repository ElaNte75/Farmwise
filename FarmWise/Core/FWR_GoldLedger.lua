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

local function getCurrentGoldContextInfo(self)
    local idleState = self.EnsureIdleSystemState and self:EnsureIdleSystemState() or nil
    local current = idleState and idleState.current or nil

    local zoneName = normalizeText(current and current.zone)
    local subZoneName = normalizeText(current and current.subzone)
    local contextKey = normalizeText(current and current.key)

    if not contextKey and zoneName then
        contextKey = self:BuildDetailedContextKey(zoneName, subZoneName)
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

function FWR:EnsureGoldLedger()
    self:EnsureDatabases()
    return ensureGoldLedger(self.DB)
end

function FWR:EnsureGoldContext(contextKey, zoneName, subZoneName)
    local ledger = self:EnsureGoldLedger()
    return ensureGoldContextBucket(ledger, contextKey, zoneName, subZoneName)
end

-- Looted money and estimated gold per hour for what the main window currently shows.
function FWR:GetGoldContextSummary()
    local scope = self:GetViewScope()
    local totalCopper, sessionCopper = self:SumViewScopeGold(scope)
    local totalSeconds = self:SumViewScopeSeconds(scope)
    local estimatedCopperPerHour = 0

    if totalSeconds > 0 then
        estimatedCopperPerHour = (totalCopper * 3600) / totalSeconds
    end

    return {
        totalCopper = totalCopper,
        sessionCopper = sessionCopper,
        totalSeconds = totalSeconds,
        estimatedCopperPerHour = estimatedCopperPerHour,
    }
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
    return self:GetMoneyBreakdownFromCopper(summary.totalCopper)
end

function FWR:GetLiveEstimatedGoldPerHourBreakdown()
    local summary = self:GetGoldContextSummary()
    return self:GetMoneyBreakdownFromCopper(summary.estimatedCopperPerHour)
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

    self:Emit("lootMoneyRecorded", copper)

    self:TouchDatabase()
    if self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end

    return context, copper
end
