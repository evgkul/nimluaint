import lua_api
import lua_state
import lua_from
import utils

type LuaReferenceInner = object
  lua: LuaState
  rawref: cint
  ltype: LUA_TYPE
  autodestroy*: bool
proc `=destroy`(lref: var LuaReferenceInner)=
  if lref.autodestroy:
    lref.lua.raw.unref(LUA_REGISTRYINDEX,lref.rawref)
  reset lref.lua

type LuaReference* = ref LuaReferenceInner
LuaReference.exportReadonly lua
LuaReference.exportReadonly rawref
LuaReference.exportReadonly ltype

proc pushOnStack*(lref:LuaReference) =
  lref.lua.raw.rawgeti(LUA_REGISTRYINDEX,lref.rawref)

proc to*(lref:LuaReference,ty:typedesc):ty =
  let lua = lref.lua
  lua.raw.protectStack start:
    lref.pushOnStack()
    var pos = start+1
    result.fromluaraw(lua,pos,pos)

proc newLuaReference*(lua:LuaState,rawref:cint,ltype:LUA_TYPE,autodestroy:bool=false):LuaReference =
  return LuaReference(lua:lua,rawref:rawref,ltype:ltype,autodestroy:autodestroy)

proc popReference*(lua:LuaState):LuaReference =
  let ltype = lua.raw.luatype(-1).LUA_TYPE
  let rawref = lua.raw.luaref(LUA_REGISTRYINDEX)
  return newLuaReference(lua,rawref,ltype,true)

template checkType*(lref:LuaReference,expected:LUA_TYPE) =
  if lref.ltype!=expected:
    luaInvalidType(expected,lref.ltype)

LuaReference.implementFromluaraw:
  L.pushvalue pos
  lua.popReference()

proc newtable*(lua:LuaState):LuaReference =
  let L = lua.raw
  L.newtable()
  return lua.popReference()