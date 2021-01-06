import unittest
import logging
import nimluaint
import nimluaint/lua_api
import nimluaint/lua_from
import nimluaint/luajit_utils
import macros
import strformat

test "luajit_1":
  let lua = newLuaState()
  let tref = expandMacros:
    lua.implementLuajitFunction:
      proc test(a:string,b,c,d:int) =
        echo "HelloFromLuajit " & $(a,b,c,d)
  let raw = lua.load("return io.open('tmp/testtttt','w')").call((),LuaReference)
  tref.call(("EEEE",2,3,4),void)
  expect LuaCallError:
    tref.call((raw,2,3,4),void)
  let tref2 = expandMacros:
    lua.implementLuajitFunction:
      proc test2(a:string,b,c,d:int) =
        raise newException(Exception,"TestError")
        #echo "HelloFromLuajit " & $(a,b,c,d)
  expect LuaCallError:
    tref2.call(("E2",3,4,5),void)
test "luajit_speed":
  let lua = newLuaState()
  var test: ref int
  new test
  let fun1 = lua.implementClosure proc(val:int) =
    test[]+=val
  let fun2 = lua.implementLuajitFunction:
    proc testnative(val:int) =
      test[]+=val