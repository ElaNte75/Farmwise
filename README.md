# FarmWise

Farm smarter, zone by zone. FarmWise tracks your own farming (materials, time, gold) per zone and
sub-zone, and its **Advisor** tells you where to go for the most of an item or the most gold per hour,
based on how *you* play and on current Auction House prices.

For World of Warcraft Retail (Midnight, interface 120100).

## Install
1. Download this repository as ZIP (Code > Download ZIP) and unzip it.
2. Copy the inner **FarmWise** folder into `World of Warcraft/_retail_/Interface/AddOns/`.

Upgrading from an older FarmWise: your saved statistics are kept and read as they are.

## Features
- **Main window:** items gathered this session and in total, items per hour, active farming time, looted gold.
  Shows sub-zone, zone, all zones of a character, or everything (Control Panel > Tracking). Data is always
  stored in full detail; these settings only change what you see.
- **Advisor** (`Advisor` button or `/fw advisor`):
  - *Gold:* places ranked by estimated gold per hour (looted gold + vendor value of scrap (grey items) +
    Auction House value of materials, minus the 5% cut). The main window's session gold uses the same rule.
  - *Item:* your best yields so far, or the best places for one item (type, shift-click, or drag and drop).
  - Each result shows its confidence (Low from 15 minutes of farming in a place, High from 60).
  - New users see a **starter guide** for their professions until they have data of their own.
- **Auction House scan:** reads trade material prices by itself when you open the Auction House
  (Control Panel > Auction House), with a 15 minute safety lock between scans. Optionally scans the whole
  Auction House. Prices appear in item tooltips ("FarmWise AH") and in the optional Price / Value columns.
- **Session reset** (Control Panel > Engine): Manual (the Reset button), Local (daily at a chosen time) or Auto
  (when you leave a zone or sub-zone for a chosen time). The Reset button shows which mode is active.
- **Window controls:** a lock (with an optional auto-lock after a minute) and a minimize button that turns
  the window into a small "FarmWise" button on the corner you choose; optionally it minimizes by itself in
  combat. Columns keep the widest size they needed, so the window does not jump around.
- **Control Panel** (`Options` button): window behaviour, display columns, tracking, session reset, rarity filter,
  Auction House scan, data erase.

## Commands
`/fw advisor` - open the Advisor | `/fw scan` - scan Auction House prices now | `/fw ui` - show or hide the main window |
`/fw options` - open the Control Panel | `/fw status` - show what is stored

## Notes
- The starter guide (`Data/FWR_StarterGuideData.lua`) comes from community guides and is English only.
- Item names are matched in English for the guide's price lookup.
