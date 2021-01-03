import lua_api
import lua_state
import lua_reference
import utils
import macros
import options

proc toluaraw*(value:SomeInteger,lua:LuaState) =
  lua.raw.pushinteger(value.lua_Integer)
proc toluaraw*(value:string,lua:LuaState) =
  discard lua.raw.pushstring(value)
proc toluaraw*(value:SomeFloat,lua:LuaState) =
  lua.raw.pushnumber(value.lua_Number)
proc toluaraw*(value:bool,lua:LuaState) =
  lua.raw.pushboolean(value.cint)
proc toluaraw*(value:LuaReference,lua:LuaState) =
  assert value.lua==lua
  value.pushOnStack()

proc toluaraw*[T](value:Option[T],lua:LuaState) =
  if value.isSome:
    value.unsafeGet().toluaraw(lua)
  else:
    lua.raw.pushnil()

proc toluaraw_multi*[T:tuple](value:T,lua:LuaState):cint
template toluaraw_multi*(value:not tuple and not LuaMultivalue,lua:LuaState):cint =
  toluaraw value,lua
  1.cint

proc toluaraw_multi*[T](value: LuaMultivalue[T],lua:LuaState):cint =
  for v in value:
    v.toluaraw lua
  return value.len.cint

macro toluaraw_multi_tuple_impl(value:tuple,lua:LuaState) =
  result = newStmtList()
  let ty = value.getType()
  let fields_amount = ty.len-1
  for i in 0..fields_amount-1:
    result.add quote do:
      result+=toluaraw_multi(`value`[`i`],`lua`)



proc toluaraw_multi*[T:tuple](value:T,lua:LuaState):cint =
  result = 0
  value.toluaraw_multi_tuple_impl lua

