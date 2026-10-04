# FarmWise 3.0 (dev)

Unified FarmWise: the Reforged engine (loot source routing, active-time tracking) plus the
original FarmWise Advisor and Auctionator price sync.

Install: copy this folder into `Interface/AddOns/` and rename it to **FarmWise**
(the folder name must match the original addon so saved data is found).

Commands: `/fw advisor`, `/fw sync`, `/fw ui`, `/fw options`, `/fw status`.

Data: old `FarmWiseDB` statistics are read as they are (no conversion). New loot is written to the
same format by the Reforged engine (`Core/FWR_AdvisorStore.lua`).
