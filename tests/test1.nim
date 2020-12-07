# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import logging
import nimluaint
import nimluaint/lua_api
#test "can add":
#  check add(5, 5) == 10

var logger = newConsoleLogger(fmtStr="[$time] - $levelname: ")
addHandler logger

test "lua_api":
  echo "Starting Lua"
  var L = newState()

  proc myPanic(L: PState): cint {.cdecl.} =
    echo "panic"

  #discard L.atpanic(myPanic)

  var regs = [
    luaL_Reg(name: "abc", fn: myPanic),
    luaL_Reg(name: nil, fn: nil)
  ]

  L.newlib(regs)
  L.setglobal("mylib")
  check L.dostring("mylib.abc()")==0

test "lua_state1":
  echo "Starting Lua"
  var lua = newLuaState()
  let L = lua.raw
  check L.dostring("return 100500")==0
  check L.gettop()==1
  check L.tonumber(1)==100500
  check L.tostring(1)=="100500"