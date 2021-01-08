import lua_api
import lua_defines
import utils
import logging
import strformat
import tables
import logging

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
  on_unlock_handlers: seq[proc(L:PState):void {.closure,raises:[].}]

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
template withLockedState*(lua:LuaState,code:untyped) =
  let old = lua.raw
  lua.raw = nil
  try:
    code
  finally:
    lua.raw = old
    for act in lua.on_unlock_handlers:
      act(old)
    lua.on_unlock_handlers.setLen 0
template onUnlock*(lua:LuaState,i_L:untyped,code:untyped) =
  let l = lua
  let i_L = l.raw
  if i_l.pointer!=nil:
    code
  else:
    l.on_unlock_handlers.add proc(i_L:PState) {.closure,raises:[].} =
      code
proc newLuaState*(raw:PState,autodestroy:bool=false):LuaState =
  return LuaState(raw:raw,raw_orig:raw,autodestroy:autodestroy)
proc newLuaState*(openlibs:bool=true):LuaState =
  let L = newState()
  if openlibs:
    L.openlibs()
    when BuildLuaUTF8:
      proc luaopen_utf8(L: lua_State) {.importc,cdecl.}
      L.protectStack:
        L.luaopen_utf8()
        L.setglobal("utf8")
  return newLuaState(L,true)
