import lua_api
import lua_state
import lua_from
import lua_to
import lua_reference
import lua_rawtable
import lua_metatable
import utils
import tables
import macros

type LuaUserdataImpl* = concept type t
  t.buildMetatable(LuaState,LuaMetatable)

proc pushUserdataMetatable*(lua:LuaState,ty:typedesc) =
  let id = getTypeID ty
  let L = lua.raw
  if lua.typemetatables.contains id:
    let metainfo = lua.typemetatables[id]
    L.rawgeti(LUA_REGISTRYINDEX,metainfo.luaref)
  else:
    L.newtable()
    L.pushvalue(-1)
    let metaptr = L.topointer(-1)
    let meta = lua.popReference()
    ty.buildMetatable(lua,LuaMetatable meta)
    meta.autodestroy = false
    let metaid = meta.rawref
    lua.typemetatables[id]=(metaid,metaptr)
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

proc getUserdataMetatable*(lua:LuaState,ty:typedesc):LuaMetatable =
  lua.pushUserdataMetatable ty
  return lua.popReference().LuaMetatable

proc toluaraw*[T:LuaUserdataImpl](value:T,lua:LuaState) =
  let L = lua.raw
  let size = sizeof T
  let p = lua.raw.newuserdata(size.csize_t)
  p.zeroMem(size)
  let store = cast[ptr T](p)
  store[]=value
  lua.pushUserdataMetatable T
  discard L.setmetatable(-2)
proc fromluaraw*[T:LuaUserdataImpl](to:var ptr T,lua:LuaState,pos:var cint,max:cint) =
  let id = getTypeID T
  let L = lua.raw
  L.protectStack start:
    let ltype = L.luatype(pos).LUA_TYPE
    if ltype!=LUSERDATA:
      luaInvalidType($T,ltype)
    if L.getmetatable(pos)==0:
      luaInvalidType($T,"unknown userdata without metatable")
    let metaptr = L.topointer(start+1)
    let exp = lua.typemetatables.getOrDefault id
    if metaptr!=exp.metaptr:
      luaInvalidType($T,"unknown userdata")
    to = cast[ptr T](L.topointer pos)

  pos+=1
proc fromluaraw*[T:LuaUserdataImpl](to:var T,lua:LuaState,pos:var cint,max:cint) =
  var p:ptr T
  p.fromluaraw(lua,pos,max)
  to = p[]

macro implementUserdata*(ty: typedesc,lua:untyped,meta:untyped,code:untyped) =
  #proc buildMetatableRaw(lua:LuaState,meta:LuaMetatable) =
  #  code
  #proc buildMetatable*(t: type ty,lua:LuaState,meta:LuaMetatable) =
  #  #buildMetatableRaw(lua,meta)
  #  code
  #echo "R ",ty.treeRepr
  let test = genSym(nskProc,"testfn")
  result = quote do:
    proc buildMetatable*(t: type `ty`,`lua`:LuaState,`meta`:LuaMetatable) =
      `code`
    proc `test`() =
      `ty`.buildMetatable(default LuaState,default LuaMetatable)

type UnknownUserdata* = distinct ref RootObj
UnknownUserdata.implementUserdata(lua,meta):
  discard