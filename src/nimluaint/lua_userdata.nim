import lua_api
import lua_state
import lua_from
import lua_to
import lua_reference
import lua_rawtable
import lua_metatable
import utils
import tables

type LuaUserdataImpl* = concept type t
  t.implementUserdata(LuaState,LuaMetatable)

proc pushUserdataMetatable*(lua:LuaState,ty:typedesc) =
  let id = getTypeID ty
  let L = lua.raw
  if lua.inner.typemetatables.contains id:
    let metainfo = lua.inner.typemetatables[id]
    L.rawgeti(LUA_REGISTRYINDEX,metainfo.luaref)
  else:
    L.newtable()
    L.pushvalue(-1)
    let metaptr = L.topointer(-1)
    let meta = lua.popReference()
    ty.implementUserdata(lua,meta.LuaMetatable)
    meta.autodestroy = false
    let metaid = meta.rawref
    lua.inner.typemetatables[id]=(metaid,metaptr)
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

proc toluaraw*[T:LuaUserdataImpl](value:T,lua:LuaState) =
  let L = lua.raw
  let size = sizeof T
  let p = lua.raw.newuserdata(size.csize_t)
  p.zeroMem(size)
  let store = cast[ptr T](p)
  store[]=value
  lua.pushUserdataMetatable T
  discard L.setmetatable(-2)
proc fromluaraw*[T:LuaUserdataImpl](to:var T,lua:LuaState,pos:var cint,max:cint) =
  let id = getTypeID T
  let L = lua.raw
  L.protectStack start:
    let ltype = L.luatype(pos).LUA_TYPE
    if ltype!=LUSERDATA:
      luaInvalidType($T,ltype)
    if L.getmetatable(pos)==0:
      luaInvalidType($T,"unknown userdata without metatable")
    let metaptr = L.topointer(start+1)
    let exp = lua.inner.typemetatables.getOrDefault id
    if metaptr!=exp.metaptr:
      luaInvalidType($T,"unknown userdata")
    let data = cast[ptr T](L.topointer pos)
    to = data[]

  pos+=1