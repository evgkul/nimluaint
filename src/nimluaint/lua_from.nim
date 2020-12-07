import utils
import lua_api
import lua_state

template implementFromluaraw*(ty:typedesc,code:untyped) =
  proc fromluaraw*(to{.inject.}:var ty, lua{.inject.}:LuaState, pos{.inject.}:var cint,max{.inject.}:cint) =
    let L{.inject.} = lua.raw
    to=code
    pos+=1

int.implementFromluaraw L.tonumber(pos).int
string.implementFromluaraw L.tostring(pos)

proc fromluaraw_wrapped*(lua:LuaState,ty:typedesc,pos:cint,max:cint):ty =
  var pos = pos
  result.fromluaraw(lua,pos,max)