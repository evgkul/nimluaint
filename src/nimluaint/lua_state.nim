import lua_api
import utils
import logging

type LuaStateInnerObj = object
  raw: PState
  autodestroy*: bool

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
proc newLuaState*():LuaState =
  let L = newState()
  return newLuaState(L,true)
