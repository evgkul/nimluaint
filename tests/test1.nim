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
import nimluaint/lua_from
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
test "lua_fromluaraw1":
  echo "Starting Lua"
  var lua = newLuaState()
  let L = lua.raw
  check L.dostring("return 100500,'teststring'")==0
  check L.gettop()==2
  check L.tonumber(1)==100500
  check L.tostring(2)=="teststring"
  let test1 = lua.fromluaraw_wrapped(int,1,1)
  check test1==100500
  let test2 = lua.fromluaraw_wrapped(string,1,1)
  check test2=="100500"
  let test3 = lua.fromluaraw_wrapped(string,2,2)
  check test3=="teststring"
test "lua_fromluaraw2":
  echo "Starting Lua"
  var lua = newLuaState()
  let L = lua.raw
  check L.dostring("return 100500,'teststring'")==0
  check L.gettop()==2
  check L.tonumber(1)==100500
  check L.tostring(2)=="teststring"
  let test1 = lua.fromluaraw_wrapped((int,string),1,2)
  check test1==(100500,"teststring")
  let test2 = lua.fromluaraw_wrapped((string,string),1,2)
  check test2==("100500","teststring")
test "lua_fromluaraw3":
  echo "Starting Lua"
  var lua = newLuaState()
  let L = lua.raw
  check L.dostring("return 1,2,3,4,5,6")==0
  check L.gettop()==6
  type TestTuple = tuple[x,y,z:int]
  let test1 = lua.fromluaraw_wrapped((TestTuple,TestTuple),1,2)
  check test1==((1,2,3),(4,5,6))
  let test2:seq[int] = lua.fromluaraw_wrapped(LuaVarargs[int],1,6)
  check test2 == @[1,2,3,4,5,6]
  

test "lua_reference1":
  let lua = newLuaState()
  let L = lua.raw
  check L.dostring("return 'teststring',100500")==0
  let r1 = lua.popReference()
  let r2 = lua.popReference()
  check r1.to(int)==100500
  check r1.to(string)=="100500"
  check r2.to(string)=="teststring"
  check L.gettop()==0
  check L.dostring("return 'teststring',100500")==0
  let r3 = lua.fromluaraw_wrapped(LuaReference,1,1)
  let r4 = lua.fromluaraw_wrapped(LuaReference,2,2)
  check L.gettop()==2
  check r3.to(string)=="teststring"
  check r4.to(int)==100500
  