local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Adds the Auction House price (from the last FarmWise scan) to item tooltips, on a line that says
-- "FarmWise" so it is clear where the number comes from.

local LABEL = "|cffd7be6aFarmWise|r AH"

local GOLD_ICON = "|TInterface/MoneyFrame/UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON = "|TInterface/MoneyFrame/UI-SilverIcon:0:0:2:0|t"
local COPPER_ICON = "|TInterface/MoneyFrame/UI-CopperIcon:0:0:2:0|t"

-- Full price like the game's own lines: gold is left out when there is none, but once the first
-- unit is shown every smaller unit follows, even when it is zero (1 46 00).
local function formatPrice(copper)
    copper = math.floor(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100

    if gold > 0 then
        return string.format("%d%s %02d%s %02d%s", gold, GOLD_ICON, silver, SILVER_ICON, rest, COPPER_ICON)
    elseif silver > 0 then
        return string.format("%d%s %02d%s", silver, SILVER_ICON, rest, COPPER_ICON)
    end
    return string.format("%d%s", rest, COPPER_ICON)
end

-- an item's class never changes, so it is asked of the game once
local materialCache = {}

-- Lowest Auction House price of one item from the last scan, or nil. Without the whole-Auction-House
-- option (or when materialsOnly is true) only trade materials have a price, so an old full scan never
-- leaves a stale price on another kind of item.
function FWR:GetAuctionPrice(itemID, materialsOnly)
    local settings = self.Settings and self.Settings.ah
    if not itemID then
        return nil
    end


    if materialsOnly or not (type(settings) == "table" and settings.fullScan == true) then
        local isMaterial = materialCache[itemID]
        if isMaterial == nil then
            local classID = select(6, GetItemInfoInstant(itemID))
            if classID == nil then
                return nil
            end
            isMaterial = classID == ((Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7)
            materialCache[itemID] = isMaterial
        end
        if not isMaterial then
            return nil
        end
    end

    local store = FarmWiseDB and FarmWiseDB._ah
    local record = type(store) == "table" and type(store.items) == "table" and store.items[tostring(itemID)] or nil
    local price = record and tonumber(record.unitPrice or record.price)
    if price and price > 0 then
        return price
    end
    return nil
end

local function addPriceLine(tooltip, data)
    local itemID = type(data) == "table" and tonumber(data.id) or nil
    if not itemID then
        return
    end

    local settings = FWR.Settings and FWR.Settings.ah
    if type(settings) == "table" and settings.tooltipPrice == false then
        return
    end

    local price = FWR:GetAuctionPrice(itemID)
    if price then
        tooltip:AddDoubleLine(LABEL, formatPrice(price), 1, 1, 1, 1, 1, 1)
    end
end

if type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and type(Enum) == "table" and type(Enum.TooltipDataType) == "table" then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        -- tooltip data can be restricted in some situations (for example in combat): never break a tooltip
        pcall(addPriceLine, tooltip, data)
    end)
end
