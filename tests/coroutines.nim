import unittest
import logging
import nimluaint
import nimluaint/lua_api
import nimluaint/lua_from
import macros
import strformat
import options

test "lua_coroutines":
  let lua = newLuaState()
  let L = lua.raw
  let g = lua.globals
  g.registerMethods:
    proc testfn(args:LuaMultivalue[int]) =
      check args.seq == @[1,2,3]
  g.rawget("testfn",LuaReference).call((1,2,3),void)
  lua.load("""
print("Test1")
testfn(1,2,3)
local fn = function()
  testfn(1,2,3)
end
print("Test2")
fn()
print("Test3")
local coro = coroutine.create(fn)
coroutine.resume(coro)
  """).call((),void)