-- A test bench for FarmWise outside the game: a pretend World of Warcraft (frames, timers, events, mailbox,
-- Auction House) around the real files of the addon.

local ROOT = ROOT_PATH
local results = { pass = 0, fail = 0, errors = {} }

local function check(name, condition, detail)
    if condition then
        results.pass = results.pass + 1
        print("  ok    " .. name)
    else
        results.fail = results.fail + 1
        print("  FAIL  " .. name .. (detail and ("   -> " .. tostring(detail)) or ""))
    end
end

------------------------------------------------------------
-- the clock and the timers
------------------------------------------------------------
local now = 1000
local timers = {}
function GetTime() return now end
local baseTime = os.time()
function time() return baseTime + math.floor(now) end
date = os.date

local function runDue()
    local ran = true
    while ran do
        ran = false
        table.sort(timers, function(a, b) return a.due < b.due end)
        for index, timer in ipairs(timers) do
            if not timer.cancelled and timer.due <= now then
                if timer.interval then
                    timer.due = timer.due + timer.interval
                else
                    timer.cancelled = true
                end
                local ok, err = xpcall(timer.fn, debug.traceback, timer)
                if not ok then results.errors[#results.errors + 1] = "timer: " .. tostring(err) end
                ran = true
                break
            end
        end
        for index = #timers, 1, -1 do
            if timers[index].cancelled then table.remove(timers, index) end
        end
    end
end

C_Timer = {
    After = function(delay, fn) timers[#timers + 1] = { due = now + (delay or 0), fn = fn } end,
    NewTicker = function(interval, fn)
        local timer = { due = now + interval, interval = interval, fn = fn }
        timer.Cancel = function(self) self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}

------------------------------------------------------------
-- frames
------------------------------------------------------------
local allFrames = {}
local Frame = {}
local METHOD_PREFIXES = { "Set", "Get", "Is", "Has", "Register", "Unregister", "Create", "Clear", "Enable", "Disable", "Show", "Hide",
    "Raise", "Lower", "Stop", "Start", "Click", "Can", "Apply", "Add", "Update", "Fade", "Play", "Animate", "Highlight",
    "Lock", "Unlock", "Insert", "Toggle", "Reset", "Select", "Deselect", "Move", "Rotate", "Run", "Make", "Cancel", "Close",
    "Open", "Refresh", "Format", "Render", "Sync", "Stack", "Measure", "Layout", "Preview" }
Frame.__index = function(t, k)
    local v = Frame[k]
    if v ~= nil then return v end
    if type(k) == "string" then
        for _, prefix in ipairs(METHOD_PREFIXES) do
            if k:sub(1, #prefix) == prefix then return function() return nil end end
        end
    end
    return nil
end

local function newFrame(kind, name, parent)
    local f = setmetatable({ __kind = kind or "Frame", __name = name, __parent = parent, __scripts = {}, __events = {}, __shown = true, __w = 100, __h = 20, __text = "" }, Frame)
    allFrames[#allFrames + 1] = f
    if parent then
        parent.__children = parent.__children or {}
        parent.__children[#parent.__children + 1] = f
    end
    if name then _G[name] = f end
    return f
end

function Frame:SetScript(name, fn) self.__scripts[name] = fn end
function Frame:GetScript(name) return self.__scripts[name] end
function Frame:HookScript(name, fn)
    local old = self.__scripts[name]
    self.__scripts[name] = function(...)
        if old then old(...) end
        fn(...)
    end
end
function Frame:RegisterEvent(e) self.__events[e] = true end
function Frame:RegisterUnitEvent(e) self.__events[e] = true end
function Frame:UnregisterEvent(e) self.__events[e] = nil end
function Frame:GetName() return self.__name end
function Frame:GetParent() return self.__parent end
function Frame:GetObjectType() return self.__kind end
function Frame:Show()
    if not self.__shown then
        self.__shown = true
        if self.__scripts.OnShow then self.__scripts.OnShow(self) end
    end
end
function Frame:Hide()
    if self.__shown then
        self.__shown = false
        if self.__scripts.OnHide then self.__scripts.OnHide(self) end
    end
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self.__shown end
function Frame:IsVisible() return self.__shown end
function Frame:SetSize(w, h) self.__w, self.__h = w, h end
function Frame:SetWidth(w) self.__w = w end
function Frame:SetHeight(h) self.__h = h end
function Frame:GetWidth() return self.__w end
function Frame:GetHeight() return self.__h end
function Frame:GetLeft() return 100 end
function Frame:GetRight() return 100 + self.__w end
function Frame:GetTop() return 500 end
function Frame:GetBottom() return 500 - self.__h end
function Frame:GetCenter() return 100, 100 end
function Frame:GetStringWidth() return (#(self.__text or "")) * 6 end
function Frame:GetStringHeight() return 12 end
function Frame:GetTextWidth() return (#(self.__text or "")) * 6 end
function Frame:SetText(t) self.__text = t end
function Frame:GetText() return self.__text end
function Frame:GetAlpha() return 1 end
function Frame:GetScale() return 1 end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetFrameLevel() return 5 end
function Frame:GetFrameStrata() return "MEDIUM" end
function Frame:GetNumPoints() return 1 end
function Frame:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Frame:IsEnabled() return self.__enabled ~= false end
function Frame:Enable() self.__enabled = true end
function Frame:Disable() self.__enabled = false end
function Frame:SetEnabled(v) self.__enabled = v and true or false end
function Frame:SetChecked(v) self.__checked = v end
function Frame:GetChecked() return self.__checked end
function Frame:SetValue(v) self.__value = v end
function Frame:GetValue() return self.__value or 0 end
function Frame:GetMinMaxValues() return 0, 100 end
function Frame:HasFocus() return false end
function Frame:IsMouseOver() return false end
function Frame:GetNumber() return tonumber(self.__text) or 0 end
function Frame:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Frame:SetFont() return true end
function Frame:GetFontString() return newFrame("FontString") end
function Frame:CreateFontString(name) return newFrame("FontString", name, self) end
function Frame:CreateTexture(name) return newFrame("Texture", name, self) end
function Frame:GetRegions() return end
function Frame:GetChildren() return end
function Frame:IsMovable() return true end
function Frame:GetThumbTexture() return newFrame("Texture") end
function Frame:GetNormalTexture() return newFrame("Texture") end
function Frame:GetHighlightTexture() return newFrame("Texture") end
function Frame:GetAtlas() return nil end
function Frame:GetTexture() return nil end
function Frame:Click()
    if self.__scripts.OnClick then self.__scripts.OnClick(self, "LeftButton") end
end

function CreateFrame(kind, name, parent, template)
    local f = newFrame(kind, name, parent)
    if template and (template:find("CheckButton") or kind == "CheckButton") then
        f.Text = newFrame("FontString")
    end
    if kind == "Slider" then
        f.Low, f.High, f.Text = newFrame("FontString"), newFrame("FontString"), newFrame("FontString")
    end
    if kind == "ScrollFrame" then f.ScrollBar = newFrame("Slider") end
    return f
end

UIParent = newFrame("Frame", "UIParent")
Minimap = newFrame("Frame", "Minimap")
GameTooltip = newFrame("GameTooltip", "GameTooltip")
function GameTooltip_Hide() end
function GetAppropriateTooltip() return GameTooltip end

local function fire(event, ...)
    for _, frame in ipairs(allFrames) do
        if frame.__events[event] and frame.__scripts.OnEvent then
            local ok, err = xpcall(frame.__scripts.OnEvent, debug.traceback, frame, event, ...)
            if not ok then results.errors[#results.errors + 1] = event .. ": " .. tostring(err) end
        end
    end
end

local function advance(seconds, step)
    step = step or 0.05
    local target = now + seconds
    while now < target do
        now = math.min(target, now + step)
        for _, frame in ipairs(allFrames) do
            local onUpdate = frame.__scripts.OnUpdate
            if onUpdate and frame.__shown then
                local ok, err = xpcall(onUpdate, debug.traceback, frame, step)
                if not ok then results.errors[#results.errors + 1] = "OnUpdate: " .. tostring(err) end
            end
        end
        runDue()
    end
end

------------------------------------------------------------
-- the rest of the game's API that the addon uses
------------------------------------------------------------
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
unpack = unpack or table.unpack
function geterrorhandler() return function(e) results.errors[#results.errors + 1] = "handler: " .. tostring(e) end end
function hooksecurefunc(a, b, c)
    local tbl, name, fn = _G, a, b
    if type(a) == "table" then tbl, name, fn = a, b, c end
    local original = tbl[name]
    if type(original) ~= "function" then error("hooksecurefunc: " .. tostring(name) .. " is not a function") end
    tbl[name] = function(...)
        local r = { original(...) }
        fn(...)
        return unpack(r)
    end
end
SlashCmdList = {}
UISpecialFrames = {}
StaticPopupDialogs = {}
STATICPOPUP_NUMDIALOGS = 4
YES, CANCEL, OKAY = "Yes", "Cancel", "OK"
BackdropTemplateMixin = {}
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function GetNormalizedRealmName() return "TestRealm" end
function GetRealmName() return "Test Realm" end
function UnitName() return "Tester" end
function UnitFullName() return "Tester", "TestRealm" end
function UnitClass() return "Mage", "MAGE" end
function GetZoneText() return "Isle of Dorn" end
function GetRealZoneText() return "Isle of Dorn" end
function GetSubZoneText() return "The Waking Shores" end
function GetExpansionLevel() return 10 end
function GetServerExpansionLevel() return 10 end
function GetMinimapShape() return "ROUND" end
function GetCursorPosition() return 0, 0 end
function GetCursorInfo() return nil end
function IsShiftKeyDown() return false end
function IsModifiedClick() return false end
function PlaySound() end
SOUNDKIT = { READY_CHECK = 1 }
function PanelTemplates_TabResize() end
function PanelTemplates_SelectTab() end
function PanelTemplates_DeselectTab() end
function PanelTemplates_GetSelectedTab() return 1 end
function SetOverrideBindingClick() end
function ClearOverrideBindings() end
function CreateColor() return {} end
function GetCoinText(c) return tostring(c) end
function GetItemIcon() return 1 end
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
ITEM_QUALITY_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, hex = "|cffffffff" } end })
NineSliceUtil = { ApplyLayoutByName = function() end }
MenuUtil = { CreateContextMenu = function() end }
TooltipDataProcessor = { AddTooltipPostCall = function() end }
Enum = {
    ItemClass = { Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5, Tradegoods = 7, ItemEnhancement = 8, Recipe = 9, Miscellaneous = 15 },
    AuctionHouseSortOrder = { Price = 0 },
    ItemCommodityStatus = { Unknown = 0, Item = 1, Commodity = 2 },
    TooltipDataType = { Item = 0 },
}
ATTACHMENTS_MAX_RECEIVE = 16
NUM_BAG_SLOTS, NUM_REAGENTBAG_SLOTS = 4, 1
AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired: %s"
AUCTION_REMOVED_MAIL_SUBJECT = "Auction cancelled: %s"
AUCTION_SOLD_MAIL_SUBJECT = "Auction successful: %s"
LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %s.", "You receive loot: %sx%d."
LOOT_ITEM, LOOT_ITEM_MULTIPLE = "%s receives loot: %s.", "%s receives loot: %sx%d."
LOOT_ITEM_PUSHED, LOOT_ITEM_PUSHED_MULTIPLE = "You receive item: %s.", "You receive item: %sx%d."

local items = {}
function defineItem(id, name, class, stack, vendor)
    items[id] = { name = name, class = class or 7, stack = stack or 200, vendor = vendor or 0 }
end
function GetItemInfoInstant(arg)
    if type(arg) == "string" then
        for id, info in pairs(items) do if info.name == arg then arg = id break end end
    end
    local info = items[tonumber(arg)]
    if not info then return nil end
    return arg, "type", "subtype", "loc", 1, info.class
end
local function itemInfo(arg)
    local info = items[tonumber(arg)]
    if not info then return nil end
    return info.name, "|cffffffff|Hitem:" .. arg .. "|h[" .. info.name .. "]|h|r", 1, 1, 1, "type", "sub", info.stack, "", 1, info.vendor, info.class
end
GetItemInfo = itemInfo
C_Item = setmetatable({
    GetItemInfo = itemInfo,
    GetItemNameByID = function(id) local i = items[tonumber(id)] return i and i.name end,
    GetItemIconByID = function() return 1 end,
    GetItemMaxStackSizeByID = function(id) local i = items[tonumber(id)] return i and i.stack end,
    GetItemQualityColor = function() return 1, 1, 1 end,
    GetItemID = function() return nil end,
    DoesItemExist = function() return true end,
}, { __index = function() return function() return nil end end })
C_Container = setmetatable({
    GetContainerNumSlots = function() return 0 end,
}, { __index = function() return function() return nil end end })
C_Spell = setmetatable({}, { __index = function() return function() return nil end end })
C_AddOns = { GetAddOnMetadata = function() return "4.1.42 beta" end }
C_ClassColor = { GetClassColor = function() return { r = 1, g = 1, b = 1 } end }
C_TooltipInfo = setmetatable({}, { __index = function() return function() return nil end end })
C_TradeSkillUI = setmetatable({}, { __index = function() return function() return nil end end })
C_Texture = { GetAtlasInfo = function() return nil end }
ItemLocation = { CreateFromBagAndSlot = function() return {} end }
Item = { CreateFromItemID = function() return { ContinueOnItemLoad = function() end } end }

------------------------------------------------------------
-- the mailbox
------------------------------------------------------------
inbox = {}
removeLog = {}
local function removeMail(mail)
    for index, other in ipairs(inbox) do
        if other == mail then table.remove(inbox, index) return end
    end
end
function GetInboxNumItems() return #inbox, #inbox end
function GetInboxHeaderInfo(i)
    local m = inbox[i]
    if not m then return end
    return nil, nil, m.sender or "Auction House", m.subject, m.money or 0, 0, m.daysLeft or 30, m.items and #m.items or nil, nil, nil, nil, m.canReply
end
function GetInboxInvoiceInfo(i)
    local m = inbox[i]
    if not m or not m.invoice then return nil end
    local v = m.invoice
    return v.type or "seller", v.name, v.buyer, v.bid, v.buyout, v.deposit, v.cut, 0, 0, 0, v.count
end
function GetInboxItem(i, a)
    local m = inbox[i]
    local it = m and m.items and m.items[a]
    if not it then return nil end
    return it.name, it.id, nil, it.count
end
serverDelay = 0.3
local function takeLater(mail, what)
    -- like the real game: a moment after the take the mail shows with no gold (and no items), a little later it is gone
    timers[#timers + 1] = { due = now + serverDelay * 0.4, fn = function()
        if mail.removed or mail.blockTake or mail.emptied then return end
        mail.emptied = true
        mail.money = 0
        mail.items = nil
        fire("MAIL_INBOX_UPDATE")
    end }
    timers[#timers + 1] = { due = now + serverDelay, fn = function()
        if mail.removed then return end
        if mail.blockTake then return end
        mail.removed = true
        removeMail(mail)
        removeLog[#removeLog + 1] = what
        fire("MAIL_INBOX_UPDATE")
    end }
end
function TakeInboxMoney(i) local m = inbox[i] if m then takeLater(m, "money") end end
function TakeInboxItem(i) local m = inbox[i] if m then takeLater(m, "item") end end
function AutoLootMailItem(i) local m = inbox[i] if m then takeLater(m, "auto") end end

------------------------------------------------------------
-- the Auction House
------------------------------------------------------------
ah = { queries = {}, results = {}, full = true, throttled = false }
C_AuctionHouse = setmetatable({
    SendBrowseQuery = function(q)
        ah.queries[#ah.queries + 1] = q
        local class = q.itemClassFilters and q.itemClassFilters[1] and q.itemClassFilters[1].classID
        ah.current = {}
        for id, info in pairs(ah.market or {}) do
            if class == nil or info.class == class then
                ah.current[#ah.current + 1] = { itemKey = { itemID = id }, minPrice = info.price, totalQuantity = info.qty }
            end
        end
        C_Timer.After(0.2, function() fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end)
    end,
    GetBrowseResults = function() return ah.current or {} end,
    HasFullBrowseResults = function() return true end,
    RequestMoreBrowseResults = function() end,
    IsThrottledMessageSystemReady = function() return not ah.throttled end,
    PostCommodity = function() return false end,
}, { __index = function() return function() return nil end end })

------------------------------------------------------------
-- loading the addon
------------------------------------------------------------
function loadAddon()
    local toc = io.open(ROOT .. "/FarmWise.toc", "r"):read("*a")
    local loaded = 0
    for line in toc:gmatch("[^\r\n]+") do
        if line:match("%.lua%s*$") then
            local path = ROOT .. "/" .. line:gsub("%s+$", "")
            local chunk, err = loadfile(path)
            if not chunk then
                results.errors[#results.errors + 1] = "SYNTAX " .. path .. ": " .. tostring(err)
            else
                local ok, runErr = xpcall(chunk, debug.traceback, "FarmWise", {})
                if not ok then
                    results.errors[#results.errors + 1] = "LOAD " .. line .. ": " .. tostring(runErr):sub(1, 400)
                else
                    loaded = loaded + 1
                end
            end
        end
    end
    return loaded
end

return {
    check = check, results = results, fire = fire, advance = advance, allFrames = allFrames,
    loadAddon = loadAddon, defineItem = defineItem,
    nowFn = function() return now end,
}
