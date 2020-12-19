import utils
import lua_api
import lua_state
import lua_reference
import lua_from
import lua_to

type LuaCallError* = object of CatchableError
  nil

proc call*[T](lref:LuaReference,args:T,rettype:typedesc):rettype =
  let lua = lref.lua
  let L = lua.raw
  L.protectStack start:
    lref.pushOnStack()
    let argscount = when T is not tuple[]:
      args.toluaraw_multi lua
    else:
      0.cint
    if L.pcall(argscount,-1,0)!=0:
      let errmsg = L.tostring(start+1)
      raise newException(LuaCallError,errmsg)
    var pos = start+1
    when rettype is not void:
      result.fromluaraw(lua,pos,L.gettop)
template call*(lref:LuaReference,rettype:typedesc):untyped =
  lref.call((),rettype)
proc load*(lua:LuaState,code:string,name:string = code):LuaReference =
  let L = lua.raw
  L.protectStack start:
    if L.loadbuffer(code,name)!=0:
      raise newException(LuaLoadError,L.tostring(start+1))
    else:
      return lua.popReference()