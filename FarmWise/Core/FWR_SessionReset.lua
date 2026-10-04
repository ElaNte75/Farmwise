local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Session reset (Engine page). In "manual" mode sessions only reset when the user asks.
-- In "local" mode every session counter is reset once per day at the chosen local time.
-- Totals and the Advisor statistics are never touched.

local CHECK_INTERVAL_SECONDS = 30

local function forEachTable(root, callback)
    if type(root) ~= "table" then
        return
    end
    for _, value in pairs(root) do
        if type(value) == "table" then
            callback(value)
        end
    end
end

function FWR:ResetAllSessions()
    local db = self.DB
    if type(db) ~= "table" then
        return
    end

    forEachTable(db.idleSystem and db.idleSystem.timersByContext, function(timer)
        timer.sessionSeconds = 0
    end)

    forEachTable(db.goldLedger and db.goldLedger.byContextKey, function(bucket)
        bucket.rawLootCopperSession = 0
    end)

    forEachTable(db.renderState and db.renderState.displayBasketByContext, function(basket)
        forEachTable(basket.byKey, function(entry)
            entry.quantityCount = 0
        end)
    end)

    if self.TouchDatabase then
        self:TouchDatabase()
    end
    if self.RefreshMainWindowText then
        self:RefreshMainWindowText()
    end
    if self.RefreshDisplayLiveMetrics then
        self:RefreshDisplayLiveMetrics(true)
    end
end

local function getScheduledTimestamp(minutesOfDay, nowTimestamp)
    local today = date("*t", nowTimestamp)
    return time({
        year = today.year,
        month = today.month,
        day = today.day,
        hour = math.floor(minutesOfDay / 60),
        min = minutesOfDay % 60,
        sec = 0,
    })
end

-- Cheap enough to call every frame: it only does work every CHECK_INTERVAL_SECONDS.
function FWR:TickSessionReset()
    local engine = self.Settings and self.Settings.engine
    if type(engine) ~= "table" or engine.sessionResetMode ~= "local" then
        return
    end

    local now = time()
    if now - (self.__fwrSessionResetCheckedAt or 0) < CHECK_INTERVAL_SECONDS then
        return
    end
    self.__fwrSessionResetCheckedAt = now

    local meta = self.DB and self.DB.meta
    if type(meta) ~= "table" then
        return
    end

    local scheduled = getScheduledTimestamp(tonumber(engine.localResetMinutes) or 0, now)
    if now < scheduled then
        return
    end

    local lastReset = tonumber(meta.lastScheduledSessionReset)
    if lastReset and lastReset >= scheduled then
        return
    end

    meta.lastScheduledSessionReset = now

    -- The first time the schedule is seen only records the moment; it never resets retroactively.
    if lastReset then
        self:ResetAllSessions()
    end
end
