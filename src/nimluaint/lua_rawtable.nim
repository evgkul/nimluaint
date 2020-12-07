import lua_api
import lua_state
import lua_reference
import lua_from
import lua_to
import utils

proc rawget*[K](lref:LuaReference,key:K,to:typedesc):to =
  lref.checkType LTABLE
  let lua = lref.lua
  let L = lua.raw
  L.protectStack start:
    lref.pushOnStack()
    key.toluaraw lua
    L.rawget(start+1)
    var pos = start+2
    result.fromluaraw(lua,pos,pos)

