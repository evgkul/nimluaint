import strutils
import strformat
import macros

const CORE_O = "lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o ltm.o lundump.o lvm.o lzio.o"
const LIB_O = "lauxlib.o lbaselib.o lcorolib.o ldblib.o liolib.o lmathlib.o loadlib.o loslib.o lstrlib.o ltablib.o lutf8lib.o linit.o"

macro build_lua*() =
  let srcs = (&"{CORE_O} {LIB_O}").replace(".o",".c").split(" ")
  #echo &"SOURCES {srcs}"
  var stmts = newStmtList()
  for src in srcs:
    let path = &"nimluaint/lua-5.4.2/src/{src}"
    stmts.add quote do:
      {.compile: `path`.}
  result = quote do:
    #{.push passc:"-I nimluaint/lua-5.4.2/src".}
    `stmts`
    #{.pop.}
  #echo "COMPILE: ",result.repr
