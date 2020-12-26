import utils
import lua_api
import lua_state
import macros
import options

template implementFromluaraw*(ty:typedesc,code:untyped) =
  proc fromluaraw*(to{.inject.}:var ty, lua{.inject.}:LuaState, pos{.inject.}:var cint,max{.inject.}:cint) =
    let L{.inject.} = lua.raw
    to=code
    pos+=1

int.implementFromluaraw L.tointeger(pos).int
string.implementFromluaraw L.tostring(pos)
float.implementFromluaraw L.tonumber(pos).float
bool.implementFromluaraw L.toboolean(pos).bool

proc fromluaraw*[T](to:var Option[T],lua:LuaState,pos:var cint,max:cint) =
  let L = lua.raw
  if pos>max or L.luatype(pos).LUA_TYPE in {LNIL,LNONE}:
    to = none[T]()
  else:
    var v:T
    v.fromluaraw(lua,pos,max)
    to = some(v)

proc fromluaraw*[T](to:var LuaMultivalue[T],lua:LuaState,pos:var cint,max:cint) =
  type s = seq[T]
  let l = max-pos+1
  to.s.setLen(l)
  #echo "L ",l
  for i in 0..l-1:
    to.s[i].fromluaraw(lua,pos,max)


macro fromluaraw_tuple_impl*(to:var tuple, lua:LuaState, pos:var cint,max:cint) =
  result = newStmtList()
  let ty = to.getType()
  let fields_amount = ty.len-1
  for i in 0..fields_amount-1:
    result.add quote do:
      `to`[`i`].fromluaraw(`lua`,`pos`,`max`)
proc fromluaraw*[T:tuple](to:var T,lua:LuaState,pos:var cint,max:cint) =
  to.fromluaraw_tuple_impl(lua,pos,max)

proc fromluaraw_wrapped*(lua:LuaState,ty:typedesc,pos:cint,max:cint):ty =
  var pos = pos
  result.fromluaraw(lua,pos,max)