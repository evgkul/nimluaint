import lua_api
import lua_userdata
import lua_call
import lua_reference
import lua_state
import macros
import strformat
import strutils
import sequtils
type LuajitArgDef* = object
  name*: string
  typename*: string
  code*: string

type ToLuajitType* {.explain.} = concept x, type t
  t.nimSideType is typedesc
  #t.luaSideType is string
  t.genLuaDef(string) is LuajitArgDef
  #t.genLuaCheck(string) is string
  #x.toluajit() is t.nimSideType
  t.tonim(t.nimSideType) is t

proc genTCheck(argname:string,ty:string):string =
  return &"""
  if type({argname})~="{ty}" then
    error("Invalid type: expected {ty}, got "..type({argname}))
  end
"""

template nimSideType*(t:type int):typedesc = cint
#template luaSideType*(t:type int):string = "int"
proc genLuaDef*(t:type int,argname:string):LuajitArgDef = 
  return LuajitArgDef(name:argname,typename:"int",code:genTCheck(argname,"number"))
#template toluajit*(val:int):cint = val.cint
template tonim*(t:type int,val:cint):int = val.int

template nimSideType*(t:type string):typedesc = cstring
#template luaSideType*(t:type string):string = "const char *"
proc genLuaDef*(t:type string,argname:string):LuajitArgDef = 
  return LuajitArgDef(name:argname,typename:"const char *",code:genTCheck(argname,"string"))
#template toluajit*(val:string):cint = val.cint
template tonim*(t:type string,val:cstring):string = $val


template checkToluajit*(t: type ToLuajitType) = discard

var ids {.compiletime.}:int = 0

proc bindLuajitFunction*(lua:LuaState,rawname:string,args:openarray[LuajitArgDef]):LuaReference =
  var cargs = args.mapIt(&"{it.typename} {it.name}").join(", ")

  
  #[let code = """local data = ({...})[0]
  local ffi = require("ffi")
  ffi.cdef([[
    void FNAME(ARGS);
  ]])
  local cfun = ffi.C.FNAME
  return function(LUAARGS)
    TRANSFORMARGS
    cfun()
  end
""".replace("FNAME",rawname).replace("ARGS",cargs.join(", "))]#
  var code = """local data = ({...})[1]
local ffi = require("ffi")
"""
  code.add &"""ffi.cdef[[
void {rawname}({cargs});
]]
local cfun = ffi.C.{rawname}
"""
  let luaargs = args.mapIt(it.name).join(", ")
  let transforms = args.mapIt(&"--TRANSFORMING {it.name}\n{it.code}").join("\n")
  code.add &"""return function({luaargs})
{transforms}
--CALLING FUNCTION
  cfun({luaargs})
end"""
  echo "LUACODE ",code
  let datatable = lua.newtable()
  return lua.load(code).call(datatable,LuaReference)

macro implementLuajitFunction*(lua:LuaState,closure:untyped):LuaReference =
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
  procbody.add body
  let codegen = &"$# $#$#"
  let procpragmas = quote do:
    {.exportc: `rawpname`,codegenDecl: `codegen`.}
  let p = newProc(ident rawpname,closuredefs,procbody,pragmas=procpragmas)
  echo "PROC ",p.repr
  
  
  echo "ARGDEF ",argdefs.treeRepr
  return quote do:
    block:
      `res`
      `p`
      `lua`.bindLuajitFunction(`rawpname`,`argdefs`)