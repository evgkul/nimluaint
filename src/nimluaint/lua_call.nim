import utils
import lua_api
import lua_state
import lua_reference
import lua_from

type LuaCallError* = object of CatchableError
  nil

proc call*(lref:LuaReference,rettype:typedesc):rettype =
  let lua = lref.lua
  let L = lua.raw
  L.protectStack start:
    lref.pushOnStack()
    let argscount = 0.cint
    if L.pcall(argscount,-1,0)!=0:
      let errmsg = L.tostring(start+1)
      raise newException(LuaCallError,errmsg)
    var pos = start+1
    result.fromluaraw(lua,pos,L.gettop)



  