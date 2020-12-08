import lua_api
import lua_state
import lua_from
import lua_to
import lua_reference
import lua_rawtable
import utils
import tables

proc pushUserdataMetatable*(lua:LuaState,ty:typedesc) =
  let id = getTypeID ty
  let L = lua.raw
  if lua.inner.typemetatables.contains id:
    let metaid = lua.inner.typemetatables[id]
    L.rawgeti(LUA_REGISTRYINDEX,metaid)
  else:
    L.newtable()
    L.pushvalue(-1)
    let meta = lua.popReference()
    ty.implementUserdata(lua,meta)
    meta.autodestroy = false
    let metaid = meta.rawref
    lua.inner.typemetatables[id]=metaid
    let metapos = L.gettop()
    proc destroy_udata(L:PState):cint {.cdecl.} =
      #echo "METATABLE: DESTROYING ",$ty
      let udata = L.topointer(-1)
      let p = cast[ptr ty](udata)
      reset p[]
      return 0
    toluaraw("__gc",lua)
    L.pushcfunction destroy_udata
    L.rawset metapos
proc toluaraw*[T](value:T,lua:LuaState) =
  let L = lua.raw
  let size = sizeof T
  let p = lua.raw.newuserdata(size.csize_t)
  p.zeroMem(size)
  let store = cast[ptr T](p)
  store[]=value
  lua.pushUserdataMetatable T
  discard L.setmetatable(-2)