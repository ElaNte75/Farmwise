local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

local function buildEmptyDisplayBasket()
    return {
        order = {},
        byKey = {},
    }
end

local function normalizeBasket(root)
    root = type(root) == "table" and root or buildEmptyDisplayBasket()
    root.order = root.order or {}
    root.byKey = root.byKey or {}
    return root
end

local function getResolvedRenderContextKey(self)
    local idleState = self.EnsureIdleSystemState and self:EnsureIdleSystemState() or nil
    local currentKey = idleState and idleState.current and idleState.current.key or nil
    if type(currentKey) == "string" and currentKey ~= "" then
        return currentKey
    end
    return "__global"
end


local function syncDisplayBasketAliases(self, basket)
    basket = normalizeBasket(basket)

    self.DisplayBasket = basket

    if self.DB and self.DB.renderState then
        self.DB.renderState.displayBasket = basket
    end

    return basket
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
function FWR:EnsureRenderStateForContext(contextKey)
    self:EnsureDatabases()

    self.DB.renderState = self.DB.renderState or {}
    local renderState = self.DB.renderState
    renderState.displayBasketByContext = renderState.displayBasketByContext or {}

    local resolvedKey = (type(contextKey) == "string" and contextKey ~= "") and contextKey or getResolvedRenderContextKey(self)
    local primaryBasket = renderState.displayBasket or renderState.legacyDisplayBasket or renderState.debugAggregate
    if next(renderState.displayBasketByContext) == nil and type(primaryBasket) == "table" then
        renderState.displayBasketByContext[resolvedKey] = normalizeBasket(primaryBasket)
    end

    renderState.displayBasketByContext[resolvedKey] = normalizeBasket(renderState.displayBasketByContext[resolvedKey])
    renderState.currentContextKey = resolvedKey
    return syncDisplayBasketAliases(self, renderState.displayBasketByContext[resolvedKey])
end

function FWR:EnsureRenderState()
    return self:EnsureRenderStateForContext()
end

function FWR:SyncRenderStateToCurrentContext()
    return self:EnsureRenderStateForContext(getResolvedRenderContextKey(self))
end

function FWR:GetDisplayBasket()
    return self:EnsureRenderState()
end


function FWR:ResetRenderStateQuantities()
    local basket = self:EnsureRenderState()
    local currentCharacterKey = self.GetCurrentCharacterKey and select(1, self:GetCurrentCharacterKey()) or ""
    for _, entry in pairs(basket.byKey) do
        if entryMatchesCharacter(self, entry, currentCharacterKey) then
            entry.quantityCount = 0
        end
    end
    self:TouchDatabase()
end

function FWR:ClearRenderState()
    local basket = self:EnsureRenderState()
    basket.order = {}
    basket.byKey = {}
    syncDisplayBasketAliases(self, basket)
    self:TouchDatabase()
    return basket
end
