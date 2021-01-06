import unittest
import logging
import nimluaint
import nimluaint/lua_api
import nimluaint/lua_from
import macros
import strformat

test "luajit_1":
  let lua = newLuaState()
  