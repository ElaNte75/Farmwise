
local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

FWR.UI_CONFIG = FWR.UI_CONFIG or {}

FWR.UI_CONFIG.ControlPanelWindow = {
    window = {
        width = 590,
        height = 490,
        sidebarWidth = 150,
        footerHeight = 52,
        headerHeight = 56,
        contentPadding = 18,
        framePoint = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    },

    colors = {
        frameBg = { 0.04, 0.03, 0.02, 0.94 },
        frameBorder = { 0.85, 0.65, 0.15, 0.55 },
        headerBg = { 0.10, 0.08, 0.05, 0.95 },
        footerBg = { 0.10, 0.08, 0.05, 0.95 },
        sidebarBg = { 0.08, 0.06, 0.04, 0.90 },
        contentBg = { 0.06, 0.05, 0.03, 0.82 },
        divider = { 1.0, 1.0, 1.0, 0.10 },
        navText = { 0.96, 0.96, 0.96, 1.0 },
        navSelectedText = { 1.0, 0.90, 0.55, 1.0 },
        navSelectedBg = { 1.0, 0.82, 0.02, 0.12 },
        navHighlightBg = { 1.0, 1.0, 1.0, 0.05 },
        title = { 0.95, 0.82, 0.42, 1.0 },
        titleAccent = { 0.96, 0.96, 0.96, 1.0 },
        subtitle = { 0.80, 0.80, 0.80, 1.0 },
        footerNote = { 0.72, 0.72, 0.72, 1.0 },
    },

    header = {
        title = { text = "FarmWise", x = 18, y = -12 },
        titleAccent = { text = "Control Panel", x = 6, y = 0 },
        subtitle = { x = 0, y = -6 },
    },

    footer = {
        closeButton = { text = "Close", width = 84, height = 24, x = -18, y = 0 },
        note = {
            text = "Use the left menu to move between pages.",
            x = 18,
            y = 0,
        },
    },

    categories = {
        order = {
            { key = "interface", label = "Interface" },
            { key = "display", label = "Display" },
            { key = "tracking", label = "Tracking" },
            { key = "engine", label = "Engine" },
            { key = "auction", label = "Auction House" },
            { key = "data", label = "Data" },
            { key = "info", label = "Info" },
        },
        button = {
            width = 126,
            height = 28,
            startX = 12,
            startY = -18,
            spacing = 4,
            textX = 10,
        },
        notes = {
            interface = "Main window startup and control panel behavior.",
            display = "Display columns, rows, and main background transparency.",
            tracking = "Tracking filters, combined views, and current data scope.",
            engine = "Internal timers, reset behavior, and rarity filter settings.",
            auction = "Automatic price scan of trade materials, used by the Advisor.",
            data = "Saved data tools.",
            info = "Addon commands, main window controls, and quick usage notes.",
        },
    },

    pages = {
        interface = {
            checkbox = {
                startX = 0,
                startY = -2,
                spacing = 6,
                textOffsetX = 0,
                textOffsetY = 1,
            },
            options = {
                { key = "showMainWindowOnGameLoad", label = "Show main window when the game loads", defaultValue = true },
                { key = "hideMainWindowInCombat", label = "Minimize main window during combat", defaultValue = false },
                { key = "autoLockMainWindow", label = "Auto-lock the main window after a minute", defaultValue = true,
                  tooltip = "An unlocked window locks itself when it has not been moved for a minute, so it cannot be dragged by accident." },
                { key = "keepColumnWidths", label = "Keep the column widths (the window does not shrink)", defaultValue = true,
                  tooltip = "Each column keeps the widest size it has needed, also after a reload or after closing the game, so the window never jumps around. Turn it off and the columns always fit what they show. Use the button below to start again from the smallest widths." },
                { key = "hideControlPanelsInCombat", label = "Hide control panels during combat", defaultValue = true },
                { key = "restoreControlPanelsAfterCombat", label = "Restore control panels after combat", defaultValue = true },
                { key = "showMainFrameTooltips", label = "Show Main Frame Tooltips", defaultValue = true },
            },
        },

        display = {
            rowSlider = {
                title = "Set Visible Rows",
                titleX = 0,
                titleY = -2,
                sliderX = 180,
                sliderY = -1,
                sliderWidth = 140,
                min = 5,
                max = 20,
                low = "5",
                high = "20",
                lowOffsetX = -2,
                highOffsetX = 2,
            },
            transparencySlider = {
                title = "Frame Transparency",
                titleX = 0,
                titleY = -26,
                sliderX = 180,
                sliderY = -25,
                sliderWidth = 140,
                min = 0,
                max = 100,
                low = "0",
                high = "100",
                lowOffsetX = -2,
                highOffsetX = 2,
            },
            divider = {
                x = 0,
                y = -64,
                rightInset = 18,
                height = 1,
                color = { 1, 1, 1, 0.18 },
            },
            headers = {
                visibility = { text = "Enable / Disable Columns", x = 0, y = -80 },
                order = { text = "Reorder Columns", x = 180, y = -80 },
            },
            scroll = {
                left = 0,
                top = -102,
                right = -24,
                bottom = 0,
            },
            list = {
                checkboxX = 0,
                sliderX = 180,
                startY = -8,
                rowSpacing = 34,
                sliderWidth = 140,
                sliderOffsetY = -4,
                lowOffsetX = -2,
                highOffsetX = 2,
            },
            controls = {
                { key = "item", label = "Item Name", locked = true, defaultValue = true, fixedOrder = 1 },
                { key = "quantity", label = "Session", defaultValue = true },
                { key = "total", label = "Total", defaultValue = true },
                { key = "itemPerHour", label = "Item / Hour", tooltip = "How many of this item you get per hour of active farming.", defaultValue = true },
                { key = "activity", label = "Activity", tooltip = "Where the item came from: looting, skinning, mining, fishing and so on.", defaultValue = true },
                { key = "itemType", label = "Reagent Type", tooltip = "The kind of reagent, for example ore, herb, cloth or leather.", defaultValue = false },
                { key = "classification", label = "Profession", tooltip = "The profession the item belongs to.", defaultValue = false },
                { key = "expansion", label = "Expansion", tooltip = "The expansion the item comes from.", defaultValue = false },
                { key = "zone", label = "Zone", defaultValue = false },
                { key = "subZone", label = "Sub-Zone", defaultValue = false },
                { key = "character", label = "Character", tooltip = "The character that collected the item.", defaultValue = false },
                { key = "price", label = "Price", tooltip = "The lowest Auction House price of one item, from the last FarmWise scan.", defaultValue = false },
                { key = "value", label = "Value", tooltip = "Price multiplied by the Session quantity: what the items collected since the last reset are worth.", defaultValue = false },
            },
        },

        tracking = {
            checkbox = {
                startX = 0,
                startY = -2,
                spacing = 6,
                textOffsetX = 0,
                textOffsetY = 1,
            },
            options = {
                { key = "showSpecializedClassifications", label = "Show Processing / Crafting Reagents", tooltip = "Also lists processing and crafting products (dust, essence, shards, pigments, ink, gems, bolts) in the main window. Off by default, so the list shows only what you gather. This only changes what is shown; the data is always saved.", settingPath = { "displayFilters", "showSpecializedClassifications" }, defaultValue = false },
                { key = "onlySpecializedClassifications", label = "Show Only Processing / Crafting Reagents", tooltip = "Shows only processing and crafting products and hides everything else. Turns off the option above while it is on. Only changes what is shown.", settingPath = { "displayFilters", "onlySpecializedClassifications" }, defaultValue = false },
                { key = "combinedAllData", label = "Combined All Character Data", tooltip = "Adds up the data of all your characters, in every zone, in one view. While on, the Zone and Sub-Zone options below are switched off. Only changes what is shown.", settingPath = { "tracking", "combinedAllData" }, defaultValue = false },
                { key = "combinedCharacterAllZones", label = "All Current Character Data", tooltip = "Adds up the data of the current character over all zones, in one view. While on, the Zone and Sub-Zone options below are switched off. Only changes what is shown.", settingPath = { "tracking", "combinedCharacterAllZones" }, defaultValue = false },
                { key = "zoneData", label = "Zone Data", tooltip = "Shows the data of the zone you are in, with all its sub-zones added together. Only changes what is shown; the data is always saved per sub-zone.", settingPath = { "tracking", "zoneData" }, defaultValue = false },
                { key = "subZoneData", label = "Sub-Zone Data", tooltip = "Shows only the data of the exact sub-zone you are in (the default). The Advisor always works per sub-zone, whatever you choose here.", settingPath = { "tracking", "subZoneData" }, defaultValue = true },
                { key = "showOldExpansions", label = "Show Old Expansion Items", tooltip = "Also shows items from earlier expansions. Off by default, so only items of the current expansion are listed. Only changes what is shown.", settingPath = { "displayFilters", "showOldExpansions" }, defaultValue = false },
            },
        },

        engine = {
            checkbox = {
                startX = 0,
                startY = -2,
                spacing = 6,
                textOffsetX = 0,
                textOffsetY = 1,
            },
            manualReset = {
                label = "Manual Session Reset",
                tooltip = "The session in the main window (and its per-hour figures) starts over only when you press the Reset button.",
            },
            localReset = {
                label = "Local Session Reset",
                tooltip = "The session starts over by itself every day at the time you choose with the slider. The Total column and the saved data are not touched.",
                sliderX = 190,
                sliderY = -1,
                sliderWidth = 130,
                low = "00:00",
                high = "23:45",
                valueTextX = 8,
                valueTextWidth = 46,
            },
            autoReset = {
                label = "Auto Session Reset",
                tooltip = "The session of an area starts over when you have left it. It follows the Tracking setting (Zone or Sub-Zone). While you are still fighting nothing happens; after the fight, coming back within the chosen time keeps the session. Not used with the Combined views.",
                sliderX = 190,
                sliderY = -1,
                sliderWidth = 130,
                low = "15s",
                high = "2m",
                valueTextX = 8,
                valueTextWidth = 46,
            },
            rarity = {
                label = "Set Rarity Level",
                tooltip = "Hides items below the chosen quality from the main window. They are still saved and still count for the Advisor.",
                sliderX = 190,
                sliderY = -1,
                sliderWidth = 130,
                valueTextX = 8,
                valueTextWidth = 62,
            },
            rarityLevels = {
                { value = 0, label = "Poor+" },
                { value = 1, label = "Common+" },
                { value = 2, label = "Uncommon+" },
                { value = 3, label = "Rare+" },
                { value = 4, label = "Epic+" },
            },
        },

        auction = {
            note = "Prices from the Auction House. The Advisor uses them to estimate gold per hour.",
            autoScan = {
                label = "Scan automatically when the Auction House opens",
                tooltip = "When you open the Auction House, FarmWise scans by itself if the prices are older than the interval chosen below.",
            },
            sound = {
                label = "Play a sound when the scan finishes",
                tooltip = "Plays a short sound when a scan completes, so you know you can use the Auction House normally again.",
            },
            tooltipPrice = {
                label = "Show FarmWise Auction House price in item tooltips",
                tooltip = "Adds a \"FarmWise AH\" line with the lowest Auction House price from the last scan to item tooltips. Without the whole-Auction-House scan it is shown only for trade materials.",
            },
            fullScan = {
                label = "Scan the whole Auction House (not only trade materials)",
                tooltip = "Scans every category, so prices can be shown for any item. It takes noticeably longer than the normal scan and may make the game stutter for a moment.",
                note = "Gives a price in the tooltip for every item that is sold there. It takes noticeably longer than the normal scan, because the whole Auction House is read.",
            },
            intervalTitle = "Scan again only when the prices are older than:",
            intervals = {
                { minutes = 15, label = "15 minutes" },
                { minutes = 30, label = "30 minutes" },
                { minutes = 60, label = "1 hour" },
                { minutes = 120, label = "2 hours" },
            },
        },

        data = {
            erase = {
                note = "Erase all saved FarmWise data: the main window data and the statistics the Advisor uses. Settings stay as they are. This cannot be undone.",
                noteX = 0,
                noteY = -2,
                label = "Erase Data",
                labelOffsetY = -16,
                buttonText = "Erase",
                buttonWidth = 110,
                buttonHeight = 24,
                buttonOffsetX = 36,
            },
        },

        info = {
            title = { text = "Quick Commands", x = 0, y = -2 },
            body = {
                x = 0,
                y = -10,
                rightInset = 18,
                text = "/fw advisor - open the Advisor (best zones for an item or for gold)\n"
                    .. "/fw scan - scan the Auction House prices now (Auction House must be open)\n"
                    .. "/fw ui - show or hide the main frame\n"
                    .. "/fw options - open the control panel\n"
                    .. "/fw status - print storage status in chat\n\n"
                    .. "The launcher icon can also show or hide the main frame.",
            },
        },
    },
}
