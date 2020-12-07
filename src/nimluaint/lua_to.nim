import lua_api
import lua_state
import lua_reference
import utils

proc toluaraw*(value:int,lua:LuaState) =
  lua.raw.pushinteger(value)

template try_toluaraw_multi*(value:untyped,lua:LuaState):cint =
  when compiles(toluaraw_multi(value,lua).cint):
    toluaraw_multi(value,lua).cint
  else:
    toluaraw(value,lua)
    1.cint
