import lua_api
import lua_state
import lua_reference
import utils
import macros

proc toluaraw*(value:int,lua:LuaState) =
  lua.raw.pushinteger(value)

proc toluaraw_multi*[T:tuple](value:T,lua:LuaState):cint
template toluaraw_multi*(value:not tuple and not LuaMultivalue,lua:LuaState):cint =
  toluaraw value,lua
  1.cint

macro toluaraw_multi_tuple_impl(value:tuple,lua:LuaState) =
  result = newStmtList()
  let ty = value.getType()
  let fields_amount = ty.len-1
  for i in 0..fields_amount-1:
    result.add quote do:
      result+=toluaraw_multi(`value`[`i`],`lua`)



proc toluaraw_multi*[T:tuple](value:T,lua:LuaState):cint =
  value.toluaraw_multi_tuple_impl lua

