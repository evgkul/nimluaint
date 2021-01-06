import nimluaint/[
  lua_api,
  lua_builder,
  lua_state,
  lua_reference,
  lua_call,
  lua_to,
  lua_rawtable,
  lua_userdata,
  lua_closure,
  lua_metatable,
  lua_defines,
  luajit_from,
  luajit_function
]
import macros
when EmbedLua:
  build_lua()
when BuildLuaUTF8:
  {.passc:"-I nimluaint/luautf8 -I "&LuaIncludesPath.}
  {.compile:"nimluaint/luautf8/lutf8lib.c".}
export lua_api
export lua_state
export lua_reference
export lua_call
export lua_rawtable
export lua_userdata
export lua_closure
export lua_metatable
export luajit_from
export luajit_function
export LUA_TYPE