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
  let test2:seq[int] = lua.fromluaraw_wrapped(LuaMultivalue[int],1,6)
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

test "lua_call1":
  let lua = newLuaState()
  let L = lua.raw
  check L.loadstring("local a={...}; return 1,2,3,4,5,6*a[1]")==0
  let r1 = lua.popReference()
  check r1.ltype==LFUNCTION
  let test1 = r1.call(2,(int,int,int,int,int,int))
  check test1==(1,2,3,4,5,6*2)
  let r2 = r1.call(2,LuaReference)
  check r2.ltype==LNUMBER
  expect LuaCallError:
    discard r2.call(1,int)
  check L.gettop()==0
  check L.loadstring("local a={...}; return a[1]+a[2]")==0
  let r3 = lua.popReference()
  check r3.call((2,4),int)==2+4

test "lua_rawgetset":
  let lua = newLuaState()
  let L = lua.raw
  check L.dostring("""
  return {
    [10]=123456,
    a=100500,
    b="teststring"
  }
  """)==0
  let t1 = lua.popReference()
  check t1.ltype==LTABLE
  check t1.rawget(10,int)==123456
  check t1.rawget("a",int)==100500
  check t1.rawget("b",string)=="teststring"
  t1.rawset("t1",654321)
  check t1.rawget("t1",int)==654321
  t1.rawset(9,"testvalue")
  check t1.rawget(9,string)=="testvalue"

test "lua_load":
  let lua = newLuaState()
  let L = lua.raw
  let fn1 = lua.load("return 100500","test1")
  check fn1.call(1,int)==100500
  expect LuaLoadError:
    let fn2 = lua.load("local 1 = 2","test2")

type TestUserdata = object
  collref: ref array[1,bool]
proc `=destroy`(obj: var TestUserdata) =
  debug "Destroying TestUserdata"
  obj.collref[0] = true
proc implementUserdata*(t:type TestUserdata,lua:LuaState,meta:LuaReference) =
  echo "IMPLEMENT"

test "lua_userdata1":
  let lua = newLuaState()
  let L = lua.raw
  var a:ref array[1,bool]
  new a
  a[0] = false
  
  let fn1 = lua.load("print('UDATA', ({...})[1] )")
  discard fn1.call(TestUserdata(collref:a),int)
  L.dostring("collectgarbage()")
  check a[0] == true