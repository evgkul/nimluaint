import lua_api
import lua_state
import lua_from
import lua_to
import utils

proc toluaraw*[T](value:T,lua:LuaState) =
  let id = getTypeID T
  let size = sizeof T
  let p = lua.raw.newuserdata(size.csize_t)
  p.zeroMem(size)
  let store = cast[ptr T](p)
  store[]=value