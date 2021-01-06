import lua_api
import lua_userdata
import lua_reference
import lua_state
import macros
import strformat
import strutils
type LuajitArgDef* = object
  name*: string
  typename*: string
  code*: string

type ToLuajitType* {.explain.} = concept x, type t
  t.nimSideType is typedesc
  t.luaSideType is string
  t.genLuaDef(string) is LuajitArgDef
  x.toluajit() is t.nimSideType
  t.tonim(t.nimSideType) is t

template nimSideType*(t:type int):typedesc = cint
template luaSideType*(t:type int):string = "int"
proc genLuaDef*(t:type int,argname:string):LuajitArgDef = 
  return LuajitArgDef(name:argname,typename:"int")
template toluajit*(val:int):cint = val.cint
template tonim*(t:type int,val:cint):int = val.int

template checkToluajit*(t: type ToLuajitType) = discard

var ids {.compiletime.}:int = 0

proc bindLuajitClosure*(lua:LuaState,rawname:string,args:openarray[LuajitArgDef]) =
  var cargs:seq[string] = @[]
  for arg in args:
    cargs.add &"{arg.typename} {arg.name}"
  
  let code = """local data = ({...})[0]
  local ffi = require("ffi")
  ffi.cdef([[
    void FNAME(ARGS);
  ]])
""".replace("FNAME",rawname).replace("ARGS",cargs.join(", "))
  echo "LUACODE ",code

macro implementLuajitClosure*(lua:LuaState,closure:untyped) =
  var res = newStmtList()
  let id = ids
  ids+=1
  var closure = closure
  if closure.kind==nnkStmtList:
    closure = closure[0]
  if not (closure.kind in {nnkLambda,nnkProcDef}):
    error(&"Invalid expression type: {closure.kind}",closure)
  let pname = closure.name
  let params = closure.params
  let ret = params[0]
  let args = params[1..^1]
  var body = closure.body
  let rawpname = &"luajit_closure_{pname}_{id}"
  #echo "params ",params.treeRepr
  var closuredefs:seq[NimNode] = @[newEmptyNode()]
  var procbody = newStmtList()
  var argdefs = quote do:
    []
  for argdef in args:
    let ty = argdef[^2]
    for name in argdef[0..^3]:
      #echo "ARG ",name.treeRepr,": ",ty.treeRepr
      let cty = quote do:
        `ty`.nimSideType
      res.add quote do:
        checkToluajit(`ty`) {.explain.}
      closuredefs.add newIdentDefs(name,cty)
      procbody.add quote do:
        let `name`:`ty` = `ty`.tonim(`name`)
      let namestr = name.strVal
      argdefs.add quote do:
        `ty`.genLuaDef(`namestr`)
  
  let procpragmas = quote do:
    {.exportc,cdecl.}
  let p = newProc(ident rawpname,closuredefs,procbody,pragmas=procpragmas)
  echo "PROC ",p.repr
  
  
  echo "ARGDEF ",argdefs.treeRepr
  return quote do:
    block:
      `res`
      `p`
      `lua`.bindLuajitClosure(`rawpname`,`argdefs`)