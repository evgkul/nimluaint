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

type LuaStateInnerObj = object
  raw: PState
  autodestroy*: bool
  typemetatables*: Table[TypeID,LuaUserdataInfo]

proc `=destroy`(obj: var LuaStateInnerObj) =
  if obj.autodestroy:
    debug "Destroying lua state ",obj.raw.repr
    obj.raw.close()

type LuaStateInner* = ref LuaStateInnerObj
LuaStateInner.exportReadonly raw

type LuaState* = object
  raw: PState
  inner: LuaStateInner
LuaState.exportReadonly raw
LuaState.exportReadonly inner

proc newLuaState*(raw:PState,autodestroy:bool=false):LuaState =
  return LuaState(raw:raw,inner:LuaStateInner(raw:raw,autodestroy:autodestroy))
proc newLuaState*(openlibs:bool=true):LuaState =
  let L = newState()
  if openlibs:
    L.openlibs()
  return newLuaState(L,true)
