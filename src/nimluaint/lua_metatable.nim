import lua_state
import lua_reference
import lua_rawtable
import lua_api

type LuaMetatable* = distinct LuaReference

proc getOrNewTable*(meta:LuaMetatable,key:string):LuaReference =
  let t = meta.LuaReference
  let val = t.rawget(key,LuaReference)
  if val.ltype!=LNIL:
    return val
  else:
    let val = t.lua.newtable()
    t.rawset(key,val)
    return val

proc index*(meta:LuaMetatable):LuaReference =
  meta.getOrNewTable "__index"

proc setIndex*[T](meta:LuaMetatable,key:string,value:T) =
  meta.index.rawset(key,value)

template registerMethods*(meta:LuaMetatable,methods:untyped) =
  meta.getOrNewTable("__index").registerMethods methods

template registerJITMethods*(meta:LuaMetatable,methods:untyped) =
  meta.getOrNewTable("__index").registerJITMethods methods