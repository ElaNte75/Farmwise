# FarmWise tests

A pretend World of Warcraft (`harness.lua`: frames, timers, events, mailbox, Auction House) is put around the real
files of the addon, and the scenarios run in it. Nothing here is part of the zip for CurseForge (the zip holds only
the `FarmWise` folder).

Run: double-click `run_tests.bat`, or `python tests/run_all.py [words]` (needs Python and `pip install lupa`).

| name | file | what |
|---|---|---|
| main | `scenarios_main.lua` | sales history from real mail traces, scan levels, prices, trend, options window, slash commands |
| tab | `scenarios_tab.lua` | the FarmWise AH tab: list, post, pages, filters, average price, options page |
| sim | `sim_auction.lua` | a model of the server (posts, partial sales, expiry, cancel, mails an hour after a sale) with 8 fixed stories and 60 random ones; at the end the player "does everything" and the books must balance |
| ui | `sim_ui.lua` | opening/closing the Auction House 40 times, switching tabs and pages, every option on and off, the switches |
| events | `sim_events.lua` | every event the addon listens to, with several kinds of arguments, and with silent game functions |
| perf | `sim_perf.lua` | speed and memory of the whole addon, with a limit for each measure |

What they cannot show: what the real game does (taint, "blocked" messages, exact answers of the server). For
that there is the tape recorder (`FarmWiseDebug`, only in the game folder) and `Logs\taint.log`.

`debug_story.py FROM COUNT` runs random stories of `sim_auction.lua` with details.
