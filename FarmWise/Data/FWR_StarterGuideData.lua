local FWR = FarmWiseReforged or {}
FarmWiseReforged = FWR

-- Starter guide: a few well-known farming suggestions for new users, until the Advisor has
-- farming data of their own. This is only data; Core/FWR_AdvisorStore.lua picks what fits the
-- character's professions. Edit this file when the game changes.
--
--   requires  professions the character needs, all of them (empty = any character):
--             herbalism, mining, skinning, tailoring, fishing
--   title     short heading
--   place     where to go
--   materials names of the materials gained (prices are shown when the Auction House was scanned;
--             every name needs its item IDs in STARTER_GUIDE.itemIds at the end of this file)
--   note      one short reason (keep it under about 65 characters)
--
-- Content comes from community guides for Midnight 12.1. Entries that no guide spells out are
-- marked "Our suggestion" in the note.

FWR.STARTER_GUIDE = {
    version = "Midnight 12.1, community guides",
    entries = {
        -- Herbalism + Mining
        {
            requires = { "herbalism", "mining" },
            title = "Herbs and ore together: Eversong Woods",
            place = "Eversong Woods, along the rivers and zone edges",
            materials = { "Mote of Light", "Refulgent Copper Ore", "Umbral Tin Ore", "Argentleaf" },
            note = "The beginner choice: both on one loop, few mobs.",
        },
        {
            requires = { "herbalism", "mining" },
            title = "Herbs and ore together: Harandar",
            place = "Harandar",
            materials = { "Mote of Primal Energy", "Mana Lily", "Brilliant Silver Ore" },
            note = "Plenty of both, but dense mobs near the nodes.",
        },
        {
            requires = { "herbalism", "mining" },
            title = "Herbs and ore together: Zul'Aman",
            place = "Zul'Aman",
            materials = { "Mote of Wild Magic", "Azeroot", "Umbral Tin Ore" },
            note = "Guides have dual routes here; ore is the stronger half.",
        },

        -- Mining + Skinning / Herbalism + Skinning (no guide spells these out)
        {
            requires = { "mining", "skinning" },
            title = "Ore and leather: Eversong Woods",
            place = "Eversong Woods: Tranquil Repose and Sunstrider Isle",
            materials = { "Void-Tempered Leather", "Refulgent Copper Ore" },
            note = "Our suggestion: beasts and cliff ore overlap here.",
        },
        {
            requires = { "herbalism", "skinning" },
            title = "Herbs and leather: Eversong Woods",
            place = "Eversong Woods: Tranquil Repose and the rivers",
            materials = { "Void-Tempered Leather", "Argentleaf" },
            note = "Our suggestion: beasts in the south, herbs along the rivers.",
        },

        -- Herbalism
        {
            requires = { "herbalism" },
            title = "Eversong Woods herb loop",
            place = "Eversong Woods, along the rivers",
            materials = { "Tranquility Bloom", "Argentleaf", "Azeroot", "Mote of Light" },
            note = "Beginner pick: one loop, few mobs, Lightfused nodes.",
        },
        {
            requires = { "herbalism" },
            title = "Harandar herbs",
            place = "Harandar",
            materials = { "Mana Lily", "Sanguithorn", "Mote of Primal Energy" },
            note = "The most herbs, but hard terrain and dense mobs.",
        },
        {
            requires = { "herbalism" },
            title = "Zul'Aman herbs",
            place = "Zul'Aman, near the zone edges",
            materials = { "Azeroot", "Mote of Wild Magic" },
            note = "Wild nodes; stay on the edges to avoid mobs.",
        },
        {
            requires = { "herbalism" },
            title = "Voidstorm herbs",
            place = "Voidstorm",
            materials = { "Mote of Pure Void" },
            note = "Dense nodes and mobs; needs the campaign completed.",
        },

        -- Mining
        {
            requires = { "mining" },
            title = "Zul'Aman ore",
            place = "Zul'Aman, along the mountains",
            materials = { "Refulgent Copper Ore", "Umbral Tin Ore", "Brilliant Silver Ore", "Mote of Wild Magic" },
            note = "Often called the best mining zone.",
        },
        {
            requires = { "mining" },
            title = "Eversong Woods ore",
            place = "Eversong Woods, rock formations and cliff bases",
            materials = { "Refulgent Copper Ore", "Umbral Tin Ore", "Mote of Light" },
            note = "Safest and simplest: few mobs.",
        },
        {
            requires = { "mining" },
            title = "Harandar ore",
            place = "Harandar",
            materials = { "Brilliant Silver Ore", "Mote of Primal Energy" },
            note = "Primal deposits hurt over time; mobs are dense.",
        },

        -- Skinning
        {
            requires = { "skinning" },
            title = "Leather in southern Eversong Woods",
            place = "Eversong Woods: Tranquil Repose",
            materials = { "Void-Tempered Leather" },
            note = "Beasts stand in clumps; a daily rare hawkstrider too.",
        },
        {
            requires = { "skinning" },
            title = "Scales on Sunstrider Isle",
            place = "Eversong Woods: Sunstrider Isle",
            materials = { "Void-Tempered Scales" },
            note = "Wyrms and dragonhawks; less crowded.",
        },
        {
            requires = { "skinning" },
            title = "Rare and tracked beasts",
            place = "Any Midnight zone",
            materials = { "Void-Tempered Hide", "Void-Tempered Plating" },
            note = "Rare beasts give 3-4 times the materials per skin.",
        },

        -- Tailoring
        {
            requires = { "tailoring" },
            title = "Cloth from humanoids",
            place = "Eversong Woods or Zul'Aman, humanoid mobs",
            materials = { "Bright Linen" },
            note = "Cloth only drops for tailors.",
        },
        {
            requires = { "tailoring" },
            title = "Rarer cloth",
            place = "Humanoid mobs in Eversong Woods and Zul'Aman",
            materials = { "Arcanoweave", "Sunfire Silk" },
            note = "Needs 20 points in Nimble Needlework to drop.",
        },

        -- Fishing
        {
            requires = { "fishing" },
            title = "Eversong Woods fishing",
            place = "Eversong Woods, central rivers and pools",
            materials = { "Arcane Wyrmfish", "Lynxfish", "Eversong Trout" },
            note = "Also used to make lures for skinners.",
        },
        {
            requires = { "fishing" },
            title = "Zul'Aman and Harandar fishing",
            place = "Zul'Aman and Harandar pools",
            materials = { "Gore Guppy", "Fungalskin Pike", "Tender Lumifin" },
            note = "Lure fish; check their Auction House prices.",
        },

        -- Any character
        {
            requires = {},
            title = "Tradable gear drops",
            place = "Mobs in any Midnight zone",
            materials = {},
            note = "Gear that drops can sell on the Auction House.",
        },
    },
}

-- Item IDs of the materials above (checked in the game, every quality rank). Prices are found by ID,
-- so the game never has to load item names.
FWR.STARTER_GUIDE.itemIds = {
    ["Arcane Wyrmfish"] = { 238371 },
    ["Arcanoweave"] = { 237017, 237018 },
    ["Argentleaf"] = { 236776, 236777 },
    ["Azeroot"] = { 236774, 236775 },
    ["Bright Linen"] = { 236963, 236965 },
    ["Brilliant Silver Ore"] = { 237364, 237365 },
    ["Eversong Trout"] = { 238383 },
    ["Fungalskin Pike"] = { 238375 },
    ["Gore Guppy"] = { 238382 },
    ["Lynxfish"] = { 238366 },
    ["Mana Lily"] = { 236778, 236779 },
    ["Mote of Light"] = { 236949 },
    ["Mote of Primal Energy"] = { 236950 },
    ["Mote of Pure Void"] = { 236952 },
    ["Mote of Wild Magic"] = { 236951 },
    ["Refulgent Copper Ore"] = { 237359, 237361 },
    ["Sanguithorn"] = { 236770, 236771 },
    ["Sunfire Silk"] = { 237015, 237016 },
    ["Tender Lumifin"] = { 238374 },
    ["Tranquility Bloom"] = { 236761, 236767 },
    ["Umbral Tin Ore"] = { 237362, 237363 },
    ["Void-Tempered Hide"] = { 238518, 238519 },
    ["Void-Tempered Leather"] = { 238511, 238512 },
    ["Void-Tempered Plating"] = { 238520, 238521 },
    ["Void-Tempered Scales"] = { 238513, 238514 },
}
