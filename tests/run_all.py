"""Runs the tests of FarmWise outside the game.

A pretend World of Warcraft (tests/harness.lua) is put around the real files of the addon (the folder FarmWise
of this repo), and each scenario file is run in it.

  python tests/run_all.py            runs everything
  python tests/run_all.py sim perf   runs the scenario files whose name has one of the words

Needs Python and the package lupa  (pip install lupa).
This folder is never part of the zip for CurseForge: the zip holds only the folder FarmWise.
"""
import io
import os
import re
import shutil
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ADDON = os.path.join(REPO, "FarmWise")

try:
    from lupa import LuaRuntime
except ImportError:
    print("The package lupa is missing:  pip install lupa")
    sys.exit(2)

SCENARIOS = [
    ("main", "scenarios_main.lua"),     # sales history, scan, prices, options window, slash commands
    ("tab", "scenarios_tab.lua"),       # the FarmWise AH tab: list, post, pages, options
    ("sim", "sim_auction.lua"),         # stories of posts, sales, expiry, mail (fixed and random)
    ("ui", "sim_ui.lua"),               # opening and closing, switching tabs, many times
    ("events", "sim_events.lua"),       # every kind of event, with odd arguments
    ("perf", "sim_perf.lua"),           # speed and memory of the whole addon
]


def prepare_copy():
    """A copy of the addon for the tests. The game's Lua (5.1) lets a loop variable be assigned to; the Lua of
    these tests (5.4+) does not: two lines are changed in the copy only."""
    target = os.path.join(tempfile.gettempdir(), "farmwise_tests", "FarmWise")
    if os.path.exists(os.path.dirname(target)):
        shutil.rmtree(os.path.dirname(target))
    shutil.copytree(ADDON, target)

    def patch(path, pattern, replacement):
        full = os.path.join(target, path)
        text = open(full, encoding="utf-8", newline="").read()
        new, count = re.subn(pattern, replacement, text, count=1)
        if count == 1:
            open(full, "w", encoding="utf-8", newline="").write(new)

    patch("Core/FWR_TooltipSystem.lua",
          r'for line in string\.gmatch\(text, "\[\^\\n\]\+"\) do(\r?\n)(\s+)line = ',
          r'for rawLine in string.gmatch(text, "[^\\n]+") do\1\2local line = rawLine and ')
    patch("Rendering/FWR_Rendering.lua",
          r'for profession in string\.gmatch\(base, "\[\^,\]\+"\) do(\r?\n)(\s+)profession = profession:',
          r'for rawProfession in string.gmatch(base, "[^,]+") do\1\2local profession = rawProfession:')
    return target


def run_one(name, filename, addon_copy):
    path = os.path.join(HERE, filename)
    if not os.path.exists(path):
        return None
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('ROOT_PATH = "%s"' % addon_copy.replace("\\", "/"))
    lua.execute('HARNESS_PATH = "%s"' % os.path.join(HERE, "harness.lua").replace("\\", "/"))
    # the output of print() is caught, to be counted
    captured = []
    lua.globals().print = lambda *args: captured.append("\t".join(str(a) for a in args))
    started = time.time()
    crashed = None
    try:
        lua.execute(open(path, encoding="utf-8").read())
    except Exception as error:  # noqa: BLE001
        crashed = str(error)
    seconds = time.time() - started
    text = "\n".join(captured)
    ok = len(re.findall(r"^\s+ok\s", text, re.M))
    fail = len(re.findall(r"^\s+FAIL\s", text, re.M))
    return {"name": name, "file": filename, "ok": ok, "fail": fail, "crashed": crashed, "seconds": seconds, "text": text}


def main():
    wanted = [word.lower() for word in sys.argv[1:]]
    addon_copy = prepare_copy()
    total_ok = total_fail = 0
    problems = []
    for name, filename in SCENARIOS:
        if wanted and not any(word in name or word in filename for word in wanted):
            continue
        result = run_one(name, filename, addon_copy)
        if result is None:
            print("%-8s (no file %s yet)" % (name, filename))
            continue
        total_ok += result["ok"]
        total_fail += result["fail"]
        status = "OK  " if result["fail"] == 0 and not result["crashed"] else "FAIL"
        print("%s %-8s %4d ok  %3d failed  %5.1fs  %s" % (status, name, result["ok"], result["fail"], result["seconds"], filename))
        if result["crashed"]:
            print("     CRASHED: " + result["crashed"][:300])
            problems.append(name)
        lines = result["text"].split("\n")
        for index, line in enumerate(lines):
            if re.match(r"^\s+FAIL\s", line):
                print("     " + line.strip()[:260])
                problems.append(name)
        if name == "perf":
            print("\n".join("     " + line for line in lines if line.strip()))
    print("\nTOTAL: %d ok, %d failed" % (total_ok, total_fail))
    return 1 if total_fail or problems else 0


if __name__ == "__main__":
    sys.exit(main())
