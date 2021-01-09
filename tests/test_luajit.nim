import unittest
import logging
import nimluaint
import nimluaint/lua_api
import nimluaint/lua_from
import nimluaint/lua_defines
import macros
import strformat

var logger = newConsoleLogger(fmtStr="[$time] - $levelname: ")
addHandler logger

test "luajit_1":
  let lua = newLuaState()
  let tref = block:# expandMacros:
    lua.implementFFIClosure:
      proc test(a:string,b,c,d:int) =
        echo "HelloFromLuajit " & $(a,b,c,d)
  let raw = lua.load("return io.open('tmp/testtttt','w')").call((),LuaReference)
  tref.call(("EEEE",2,3,4),void)
  when UseLuaVersion=="luajit":
    expect LuaCallError:
      tref.call((raw,2,3,4),void)
  let tref2 = expandMacros:
    lua.implementFFIClosure:
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
  let fun2 = lua.implementFFIClosure:
    proc testnative(val:int) =
      test[]+=val
  let g = lua.globals()
  g.rawset("fun1",fun1)
  g.rawset("fun2",fun2)
  let i1 = lua.load("""
    function test1()
      local b = os.clock()
      for i = 1,1000000 do
        fun1(1)
      end
      local a = os.clock()
      print("LUA API time",a-b)
    end

    function test2()
      local b = os.clock()
      for i = 1,1000000 do
        fun2(-1)
      end
      local a = os.clock()
      print("FFI time",a-b)
    end
    test1()
    test2()
  """)
  i1.call((),void)

type TestUserdata = ref object
  a*:int
TestUserdata.implementUserdata(lua,meta):
  discard
test "luajit_udata":
  let lua = newLuaState()
  let globals = lua.globals
  let u1 = TestUserdata(a:100500)
  let t1 = lua.implementFFIClosure:
    proc test(u:ptr TestUserdata) =
      echo "UDATA_VALUE ",u.a
  t1.call(u1,void)

#[test "luajt_custom":
  let lua = newLuaState()
  let globals = lua.globals
  type TestRet = object
    val:cint
  var tret {.global,threadvar.}:TestRet
  let t1_data = lua.newtable()
  t1_data.rawset("retptr",tret.addr.pointer)
  let t1_custom = LuajitFunctionCustom(
    before_definitions:"""
local ret = ffi.new([[struct {int val;} *]],data.retptr)
--print("CustomDefinitions",ret)

    """,
    after_call: "return ret.val",
    data:t1_data
  )
  let t1 = lua.implementFFIClosure:
    proc test(a:int) =
      tret.val = (a+1).cint
  do:
    t1_custom
  check t1.call(100499,int)==100500]#

test "luajit_ret":
  let lua = newLuaState()
  let globals = lua.globals
  let t1 = lua.implementFFIClosure:
    proc test(a:int):int =
      return a+2
  check t1.call(100498,int)==100500
  let t2 = lua.implementFFIClosure:
    proc test2(a:string):string =
      return "foo"&a
  check t2.call("bar",string)=="foobar"
test "luajit_closure":
  let lua = newLuaState()
  let globals = lua.globals
  proc tproc(ival:int):LuaReference =
    var a = ival
    return lua.implementFFIClosure:
      proc test(b:int):int =
        return a+b
  let t1 = tproc(100499)
  let t2 = tproc(100498)
  check t1.call(1,int)==100500
  check t2.call(1,int)==100499
test "luajit_tuplereturn":
  let lua = newLuaState()
  let t1 = lua.implementFFIClosure:
    proc test(a:int):(int,string) =
      return (a+2,"TESTSTRING")
  check t1.call(5,(int,string))==(7,"TESTSTRING")

test "luajit_registermethods":
  let lua = newLuaState()
  let t = lua.newtable()
  t.registerJITMethods:
    proc test1():int = return 100500
    proc test2():string = return "teststring"
  check t.rawget("test1",LuaReference).call((),int)==100500
  check t.rawget("test2",LuaReference).call((),string)=="teststring"