import lua_api
import utils
import logging
import strformat
import tables

type LuaInvalidType* = object of CatchableError
type LuaLoadError* = object of CatchableError
template luaInvalidType*(expected:LUA_TYPE|string,got:LUA_TYPE|string) =
  raise newException(LuaInvalidType,"Invalid type: expected " & $expected & ", got " & $got)

type LuaMultivalue*[T] = distinct seq[T]
converter toseq*[T](vargs:LuaMultivalue[T]):seq[T] =
  (seq[T])(vargs)

type LuaUserdataInfo* = tuple[
  luaref:cint,
  metaptr:pointer
]

type LuaStateObj* = object
  raw: PState
  raw_orig:PState
  autodestroy*: bool
  typemetatables*: Table[TypeID,LuaUserdataInfo]

proc `=destroy`(obj: var LuaStateObj) =
  if obj.autodestroy:
    debug "Destroying lua state ",obj.raw.repr
    obj.raw_orig.close()
    reset obj.typemetatables

type LuaState* = ref LuaStateObj

#LuaState.exportReadonly raw
template raw*(state:LuaState):PState =
  state[].raw
template update_raw*(state:LuaState,r:PState) =
  state.raw = r
proc newLuaState*(raw:PState,autodestroy:bool=false):LuaState =
  return LuaState(raw:raw,raw_orig:raw,autodestroy:autodestroy)
proc newLuaState*(openlibs:bool=true):LuaState =
  let L = newState()
  if openlibs:
    L.openlibs()
  return newLuaState(L,true)
