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
    lua.implementLuajitClosure:
      proc test(a:int,b,c,d:int) =
        echo "HelloFromLuajit"