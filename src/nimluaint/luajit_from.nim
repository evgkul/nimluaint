import lua_api
import lua_userdata
import lua_call
import lua_reference
import lua_state
import lua_rawtable
import macros
import strformat
import strutils
import sequtils
import utils

type LuajitArgDef* = object
  name*: string
  typename*: string
  code*: string
  metatable*: LuaReference

type FromLuajitType* {.explain.} = concept x, type t
  t.nimSideType is typedesc
  t.genLuaDef(LuaState,string) is LuajitArgDef
  #t.tonim(t.nimSideType) is typedesc # Not working

proc genTCheck(argname:string,ty:string):string =
  return &"""
  if type({argname})~="{ty}" then
    error("Invalid type: expected {ty}, got "..type({argname}))
  end
"""
template implementNumber*(ty:typedesc,extty:typedesc,ctype:static[string]):untyped =
  template nimSideType*(t:type ty):typedesc = extty
  #template luaSideType*(t:type int):string = "int"
  proc genLuaDef*(t:type ty,lua:LuaState,argname:string):LuajitArgDef = 
    return LuajitArgDef(name:argname,typename:"int",code:genTCheck(argname,"number"))
  #template toluajit*(val:int):cint = val.cint
  template tonim*(t:type ty,val:extty):ty = val.ty

template implementNumber*(ty:typedesc,ctype:static[string]):untyped =
  implementNumber(ty,ty,ctype)

int.implementNumber(cint,"int")
float.implementNumber(cdouble,"double")
float64.implementNumber(cdouble,"double")
float32.implementNumber(cfloat,"float")
uint.implementNumber(cuint,"unsigned int")

int64.implementNumber "int64_t"
int32.implementNumber "int32_t"
int16.implementNumber "int16_t"
int8.implementNumber "int8_t"
uint64.implementNumber "uint64_t"
uint32.implementNumber "uint32_t"
uint16.implementNumber "uint16_t"
uint8.implementNumber "uint8_t"

template nimSideType*(t:type string):typedesc = cstring
#template luaSideType*(t:type string):string = "const char *"
proc genLuaDef*(t:type string,lua:LuaState,argname:string):LuajitArgDef = 
  return LuajitArgDef(name:argname,typename:"const char *",code:genTCheck(argname,"string"))
#template toluajit*(val:string):cint = val.cint
template tonim*(t:type string,val:cstring):string = $val


template nimSideType*[T:LuaUserdataImpl](t: type T):typedesc = ptr T
template nimSideType*[T:ptr LuaUserdataImpl](t: type T):typedesc = T

proc genLuaDef*[T:LuaUserdataImpl|ptr LuaUserdataImpl](t: type T,lua:LuaState,argname:string):LuajitArgDef =
  when T is ptr:
    let meta = lua.getUserdataMetatable typeof( (default T)[] )
  else:
    let meta = lua.getUserdataMetatable T
  let code = &"""if debug.getmetatable({argname})~=metatable_{argname} then
  error("Invalid userdata type!")
end"""
  return LuajitArgDef(name:argname,typename:"void *",code:code,metatable:meta.LuaReference)
template tonim*[T:LuaUserdataImpl](t:type T,val:ptr T):T = val[]
template tonim*[T:ptr LuaUserdataImpl](t:type T,val:T):T = val

template checkFromluajit*(t: type FromLuajitType) = discard