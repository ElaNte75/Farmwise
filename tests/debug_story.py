"""Runs a few random stories of tests/sim_auction.lua with details:  python tests/debug_story.py FROM COUNT"""
import os, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0]] + sys.argv[1:]
first = int(sys.argv[1]) if len(sys.argv) > 1 else 1
last = int(sys.argv[2]) if len(sys.argv) > 2 else first
src = open(os.path.join(here, "run_all.py"), encoding="utf-8").read().split('if __name__')[0]
src = src.replace("HERE = os.path.dirname(os.path.abspath(__file__))", "HERE = %r" % here)
exec(compile(src, "run_all", "exec"))
copy = prepare_copy()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('ROOT_PATH = "%s"' % copy.replace("\\", "/"))
lua.execute('HARNESS_PATH = "%s"' % os.path.join(here, "harness.lua").replace("\\", "/"))
lua.execute('VERBOSE = true; STORY_FROM = %d; STORY_COUNT = %d' % (first, last))
try:
    lua.execute(open(os.path.join(here, "sim_auction.lua"), encoding="utf-8").read())
except Exception as error:
    print("CRASHED:", error)
