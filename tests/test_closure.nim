import unittest
import logging
import nimluaint
import nimluaint/lua_api
import nimluaint/lua_from
import macros
import strformat
#test "can add":
#  check add(5, 5) == 10

var logger = newConsoleLogger(fmtStr="[$time] - $levelname: ")
addHandler logger

#[test "lua_closure1":
  let lua = newLuaState()
  let L = lua.raw
  let tc = lua.implementClosure proc(a,b,c:int,d:float):string = return &"HELLOWORLD {a} {b} {c} {d}"
  check tc.call((1,2,3,4.5),string)=="HELLOWORLD 1 2 3 4.5"
  let tc2 = lua.implementClosure proc():string = raise newException(Exception,"TestException")
  expect LuaCallError:
    discard tc2.call((1),string)
  var t = 0
  let tc3 = lua.implementClosure proc(val:int) =
    t = val
    return
    t = 3
  tc3.call(2,void)
  check t==2
  let tc4 = lua.implementClosure proc():string = return "test"
  tc4.call(void)
  #discard tc.call(1,(int))]#

type TestUserdata2* = object
  val*:int
TestUserdata2.implementUserdata(l,meta):
  discard nil
  meta.registerMethods:
    proc testmethod(self:var TestUserdata2,a:int):int =
      let val = self.val+a
      self.val = val
      return val
    proc test2(self:var TestUserdata2,b:int):int = return b
  #let tc = l.implementClosure proc(self:var TestUserdata2,a:int):int =
  #  let val = self.val+a
  #  self.val = val
  #  return val
  #meta.setIndex("testmethod",tc)
  #[meta.setIndex("testmethod"):
    expandMacros meta.LuaReference.lua.implementClosure proc(self:var TestUserdata2,a:int):int =
      let val = self.val+a
      self.val = val
      return val]#
    
    
test "lua_userdata2":
  let lua = newLuaState()
  let L = lua.raw
  let udata = TestUserdata2(val:2)
  var tarr:ref array[1,bool]
  new tarr
  #let udata_wrong = TestUserdata(collref:tarr)
  let fn1 = lua.load("""
  local args = {...}
  local udata = args[1]
  local udata_wrong = args[2]
  print('UDATA', udata )
  --print('testmethod',udata:testmethod(1))
  --print('test2',udata.testmethod(udata_wrong,2))
  collectgarbage()
  """)
  fn1.call((udata),void)
  #GC_unref(lua.inner)
  #GC_unref(lua.inner)
  GC_runOrc()