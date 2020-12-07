import lua_api
import lua_state
import lua_reference
import utils

proc toluaraw*(value:int,lua:LuaState) =
  lua.raw.pushinteger(value)
