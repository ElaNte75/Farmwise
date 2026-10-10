# FarmWise changelog

Version numbers are `major.minor.week`: the last number is the week of the year of the update, the middle
one grows when settings or behaviour change.

## 4.1.42 beta

**New**
- Lock button for the main window, with an optional auto-lock after a minute without moving
  (Options > Interface).
- Minimize button: the window turns into a small "FarmWise" button on one of its corners (or its center),
  chosen in Options > Interface. "Minimize main window during combat" now does this by itself.
- Columns keep the widest size they have needed, also after a reload, so the window does not jump left and
  right. Options > Interface: keep or not, and a button to start again from the smallest widths.
- The title area of the window is dark and does not follow the transparency, so it stays readable.

**Improved**
- Much lower CPU use: the window is redrawn only when something changed, bursts of loot are drawn once, and
  a hidden window does no work.
- Zone name starts exactly where "Total:" starts. Smaller IDLE text.
- Advisor: amounts use the game's gold and silver coin pictures and are rounded to whole gold. "Looted gold" and
  "Vendor items" are now one line, "Raw gold" (money from mobs plus scrap). In Item mode every result shows
  what the yield is worth per hour at the current Auction House prices.
- Advisor, Item mode: without "Include quality" all qualities of an item are now one line (before, each quality was a
  separate unlabeled line); with it, each quality shows separately with its own worth. "Include quality" is now on by default.
- Explanations (tooltips) for the new options.

## 4.0.0 beta

- Auction House prices in item tooltips ("FarmWise AH"), optional scan of the whole Auction House.
- Optional Price and Value columns; columns fit their content.
- Auto Session Reset (Options > Engine): when you leave a zone or sub-zone, after the fight and a delay you
  choose. The Reset button shows the active mode.
- Session gold in the footer = money from mobs + scrap (grey items) at vendor price + trade materials at their
  Auction House price (minus the 5% cut). The Advisor uses the same rule.
- More reliable Auction House scan, Advisor scrolling fixed, hover explanations for the options, main window
  alignment fixes, version and release stage shown in the title.
