# FarmWise changelog

Version numbers are `major.minor.week`: the last number is the week of the year of the update, the middle
one grows when settings or behaviour change.

## 4.5.43

**New**
- Loot text while the window is minimized: every item you loot rises from the small FarmWise button, in the colour
  of its rarity ("Bright Linen x3"), and fades away. It comes from the corner of the button towards the middle of
  the screen. Options > Interface.
- Valuable loot: an item worth at least the value you choose (a slider from 10g to 1000g) comes in bigger letters
  and with a sound. The worth is the Auction House price of your last scan, or what a vendor pays.
- Options > Interface: "Open it again after combat" (off by default). The window that was minimized by the fight
  stays a small button until you click it, unless this is on. A window you minimized yourself is never opened for
  you.
- Price check: you choose how strict it is - Relaxed, Normal, Strict or Very strict. Each has its own explanation.
- Price check: "Set the right price by itself" - a price that is unusually low is raised at once to the lowest
  usual price, without pressing + on every item. The corrected prices are written in green in the Sell list.
- History: the line under the table tells what the price check brought you ("The price check brought you an
  extra 9g 70s 90c on 76 pieces sold (3 different items)"). Point at it to see each item and what it brought, with
  the gold, silver and copper in columns.
- Gathering (mining, herbalism, fishing, skinning) is counted for the whole zone, not for the sub-zone of the
  node. What you gather adds up in the zone, the automatic session reset does not start over when you walk into
  another sub-zone (only when you leave the zone), and the Advisor tells you the zone to go to. A switch in
  Options > Tracking ("Count gathering for the whole zone", on by default) turns it off.
- The tooltip lines of the vendor and the Auction House price stand in columns.
- The FarmWise icon (a gold coin) shows in the list of AddOns. The game versions 12.1.0, 12.1.5 and 12.1.7 are
  listed.

**Changed**
- The coins in the Price and Value columns of the main window are drawn in a cell of their own: the copper, the
  silver and the gold of every row stand exactly under each other, and the gold digits grow to the left.

**Fixed**
- Auctions: one mail for several posts (a buyer of 13 pieces from a post of 6 and one of 7) no longer leaves the
  posts as "Ended".
- The gold coin on the bag items stands closer to the corner of the item, and the options page of the tab no
  longer runs out of its cards.

## 4.4.42

**New**
- The Auction House tab has a new page, **Options**, with all the settings of the tab in one place: posting, average
  price, the Sell list, what is shown, and the history. In the main FarmWise window only the scanner and the
  on/off switch of the tab are left.
- The tab can open by itself when you open the Auction House (switch in Options > Display, on by default). If the
  prices are old it waits until the scan is finished, so the two do not get in each other's way.
- The page **Actions** is now called **Auctions**, like the game's own tab.
- Auctions: a post that is sold shows as sold even when the Auction House is closed - the chat message that the
  game gives is used. When you open the Auction House again, the page checks itself against the game's list.
- Auctions: when only a part of a stack is sold, the sold pieces are one line that grows, and the rest stays active.
- Auctions: the page asks the Auction House again every 30 seconds while it is open. The round arrow in the corner
  also asks again.
- Auctions: the bottom line says what is sure: "4 active - 4 sold for 10g 37s 50c". Posts that are not known yet
  are counted in between ("unknown").
- Auctions: posts that ran out or were cancelled are not shown any more. A post that disappeared while you were away
  and is not known yet ("Ended") goes away as soon as the mailbox has been read.
- History: a sale gets the day it really happened, not the day you took the gold from the mailbox. "Today" and
  "Yesterday" follow the clock of the realm.
- The lists (Sell, Auctions, History) have the game's own scroll bar, thin, at the right.
- Dungeons, raids, delves and other places you enter through a portal (and battlegrounds and arenas) are recorded
  as one whole area, not by sub-zone. The open world works as before.
- History: the line under the table now says what the price check made you earn (after the 5%), counted only on
  what was sold. The old totals line is gone.
- Bags: a small gold coin on the items that the Sell list leaves out because a vendor pays more than the Auction
  House. The tooltip of the item tells the prices. It stays while the item is in your bags. A switch in
  Options > Display turns it off.
- The tooltip lines of FarmWise have a stronger colour and a space before the prices.
- The FarmWise tab stands after the tabs of other addons (like Auctionator) and hides its page when you choose
  theirs, and the other way round.
- The quality marks next to the item names are a little bigger (the silver one) and centred on each other.

**Fixed**
- Auctions: when you take the mail before opening the Auction House, the posts it belongs to are no longer left
  as "Ended".
- Auctions: no more error when the game hides the text of a chat message after a fight.
- The FarmWise tab no longer makes the game say "FarmWise has been blocked" when you right-click an item in your
  bags. The tab now lives in a frame of its own and does not write into the Auction House of the game.
- FarmWise no longer writes its own copies of the game's item and spell functions.
- A sale could be lost from the books if the mailbox was closed a moment after the gold was taken.
- The tab button stands where the game's own tabs stand.
- The chat message that tells about a sale was never recognised before; now it is.

## 4.3.42

**New**
- Auction House tab, page "Actions" (between Sell and History): one line for each of your posts - active (with the
  time it has left), sold, expired or cancelled - until you take the gold or the items from the mailbox. A
  button takes an active post back (it asks first). The columns stand where those of the History page stand.
- History: the names have the colour of their rarity.
- Lock button for the main window, with an optional auto-lock after a minute without moving
  (Options > Interface).
- Minimize button: the window turns into a small "FarmWise" button on one of its corners (or its center),
  chosen in Options > Interface. "Minimize main window during combat" now does this by itself.
- Columns keep the widest size they have needed, also after a reload, so the window does not jump left and
  right. Options > Interface: keep or not, and a button to start again from the smallest widths.
- The title area of the window is dark and does not follow the transparency, so it stays readable.

- Experimental: a "FarmWise" tab next to the tabs of the Auction House lists the materials you farmed and carry,
  with the lowest price now, a price you can raise or lower, an amount, and a Post button.
- Right-click an item of that list opens the game's own menu: do not show it, or keep a number of it in your
  bags. Items a vendor pays more for than the Auction House (after its 5%) are left out of the list, and
  their tooltip says so. "Show hidden items" at the bottom switches to the list of everything left out, where
  a right-click shows an item again or changes its filters.
- The list of the tab holds everything of your bags that the Auction House sells by amount (materials, potions,
  food, runes, gems...), not only what you farmed. Options "AH Tab List": only what you farmed, and which groups
  to show. Gear is not in it.
- Price check (right-click an item, "Turn on price check"): when the price to post is unusually low against
  where most of the listings are, Post waits and the first "+" goes straight to the lowest usual price. FarmWise
  also starts to keep a short daily price history of the materials you farm.
- Scan levels (Options > Scanner): trade materials are always scanned; "Also scan everything else sold
  by amount" adds consumables, gems and enhancements; "Scan the whole Auction House" reads everything.
- The tooltip of an item that the AH Tab leaves out because a vendor pays more now has its own "FarmWise Info"
  block with both prices.
- All Options pages were re-arranged: sections with small titles, tighter spacing, nothing outside the frame,
  and a scrollbar when a page is taller than the window.
- Sales history: a "History" page next to "Sell" in the FarmWise tab. It counts what you sell when you take
  the gold of a sale (and the items of an expired auction) from your mailbox: pieces sold, gold earned after the
  5% cut, price of one, returned unsold and the share that was sold. Every column title sorts the list.
  Switch it off in Options > Auction House ("Keep a sales history").
- Manual: a new "Manual" page in the options (under Info) with a list of chapters. A click opens the chapter,
  "Back" (next to Close) returns to the list.
- Price step: Options > Auction House has a slider (1% to 20%, 5% by default) for how much one click of + or -
  changes the price in the FarmWise tab.
- Never below my average price: an option for all items (Options > Auction House) and for one item (right-click).
  The price starts at the higher of the lowest price now and the average of your last sales, and "-" and Post stop
  at that average. It needs at least 3 sales and 20 pieces in the History.

**Improved**
- The item column is the same in the Sell, Actions and History pages, and never changes size: a long name is cut
  with "..." and the quality mark is always seen (it has its own place at the end of the column, a little smaller).
- History: the numbers of Sold, Returned and Success end on the same line (units under units).
- Sell tab: grey items are never listed; the right-click menu of an item that is left out can change how many to
  keep in the bags.
- Much lower CPU use: the window is redrawn only when something changed, bursts of loot are drawn once, and
  a hidden window does no work.
- Zone name starts exactly where "Total:" starts. Smaller IDLE text.
- Advisor: amounts use the game's gold and silver coin pictures and are rounded to whole gold. "Looted gold" and
  "Vendor items" are now one line, "Raw gold" (money from mobs plus scrap). In Item mode every result shows
  the price of one item at the Auction House and, in brackets, what the whole hourly yield is worth.
- Advisor, Item mode: without "Include quality" all qualities of an item are now one line (before, each quality was a
  separate unlabeled line); with it, each quality shows separately with its own worth. "Include quality" is now on by default.
- Advisor, Item mode: what disenchanting, milling and prospecting give is shown on its own rows ("Processing"):
  how many times you used it, what you got in total and per use, and the price of each result. These results are
  no longer listed as "best place" items, since a place does not matter for them.
- Explanations (tooltips) for the new options.

**Fixed**
- Errors after the game update that removed older game functions (item and spell information): they are now
  found where the game keeps them.

## 4.0.0 beta

- Auction House prices in item tooltips ("FarmWise AH"), optional scan of the whole Auction House.
- Optional Price and Value columns; columns fit their content.
- Auto Session Reset (Options > Engine): when you leave a zone or sub-zone, after the fight and a delay you
  choose. The Reset button shows the active mode.
- Session gold in the footer = money from mobs + scrap (grey items) at vendor price + trade materials at their
  Auction House price (minus the 5% cut). The Advisor uses the same rule.
- More reliable Auction House scan, Advisor scrolling fixed, hover explanations for the options, main window
  alignment fixes, version and release stage shown in the title.
