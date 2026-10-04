
local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

FWR.UI_CONFIG = FWR.UI_CONFIG or {}

FWR.UI_CONFIG.ControlPanelWindow = {
    window = {
        width = 590,
        height = 370,
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
            text = "Use the left menu to move between Interface, Display, Tracking, Engine, Data, and Info.",
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
                { key = "hideMainWindowInCombat", label = "Hide main window during combat", defaultValue = false },
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
                { key = "itemPerHour", label = "Item / Hour", defaultValue = true },
                { key = "activity", label = "Activity", defaultValue = true },
                { key = "itemType", label = "Reagent Type", defaultValue = false },
                { key = "classification", label = "Profession", defaultValue = false },
                { key = "expansion", label = "Expansion", defaultValue = false },
                { key = "zone", label = "Zone", defaultValue = false },
                { key = "subZone", label = "Sub-Zone", defaultValue = false },
                { key = "character", label = "Character", defaultValue = false },
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
                { key = "showSpecializedClassifications", label = "Show Processing / Crafting Reagents", settingPath = { "displayFilters", "showSpecializedClassifications" }, defaultValue = false },
                { key = "onlySpecializedClassifications", label = "Show Only Processing / Crafting Reagents", settingPath = { "displayFilters", "onlySpecializedClassifications" }, defaultValue = false },
                { key = "combinedAllData", label = "Combined All Character Data", settingPath = { "tracking", "combinedAllData" }, defaultValue = false },
                { key = "combinedCharacterAllZones", label = "All Current Character Data", settingPath = { "tracking", "combinedCharacterAllZones" }, defaultValue = false },
                { key = "zoneData", label = "Zone Data", settingPath = { "tracking", "zoneData" }, defaultValue = false },
                { key = "subZoneData", label = "Sub-Zone Data", settingPath = { "tracking", "subZoneData" }, defaultValue = true },
                { key = "showOldExpansions", label = "Show Old Expansion Items", settingPath = { "displayFilters", "showOldExpansions" }, defaultValue = false },
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
            manualReset = { label = "Manual Session Reset" },
            localReset = {
                label = "Local Session Reset",
                sliderX = 190,
                sliderY = -1,
                sliderWidth = 130,
                low = "00:00",
                high = "23:45",
                valueTextX = 8,
                valueTextWidth = 46,
            },
            rarity = {
                label = "Set Rarity Level",
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
                    .. "/fw sync - copy Auctionator prices for your tracked items (Auction House must be open)\n"
                    .. "/fw ui - show or hide the main frame\n"
                    .. "/fw options - open the options category\n"
                    .. "/fw status - print storage status in chat\n\n"
                    .. "The launcher icon can also show or hide the main frame.",
            },
        },
    },
}
