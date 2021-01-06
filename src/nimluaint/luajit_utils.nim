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


type LuaLastError = object
  cstr: cstring
  nimstr: ref string

var last_error {.threadvar.}:LuaLastError 
new(last_error.nimstr)

type LuajitArgDef* = object
  name*: string
  typename*: string
  code*: string
  metatable*: LuaReference

type ToLuajitType* {.explain.} = concept x, type t
  t.nimSideType is typedesc
  #t.luaSideType is string
  t.genLuaDef(LuaState,string) is LuajitArgDef
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
proc genLuaDef*(t:type int,lua:LuaState,argname:string):LuajitArgDef = 
  return LuajitArgDef(name:argname,typename:"int",code:genTCheck(argname,"number"))
#template toluajit*(val:int):cint = val.cint
template tonim*(t:type int,val:cint):int = val.int

template nimSideType*(t:type string):typedesc = cstring
#template luaSideType*(t:type string):string = "const char *"
proc genLuaDef*(t:type string,lua:LuaState,argname:string):LuajitArgDef = 
  return LuajitArgDef(name:argname,typename:"const char *",code:genTCheck(argname,"string"))
#template toluajit*(val:string):cint = val.cint
template tonim*(t:type string,val:cstring):string = $val


template checkToluajit*(t: type ToLuajitType) = discard

var ids {.compiletime.}:int = 0

proc bindLuajitFunction*(lua:LuaState,rawname:string,args:openarray[LuajitArgDef]):LuaReference =
  let datatable = lua.newtable()
  var cargs = args.mapIt(&"{it.typename} {it.name}").join(", ")
  var code = """local data = ({...})[1]
local ffi = require("ffi")
"""
  let structbody = """{
  char * cstr;
  void * nimstr;
  }"""
  code.add &"""ffi.cdef[[
typedef struct {structbody} {rawname}_lasterror;
bool {rawname}({cargs});
]]
local last_error = ffi.new("{rawname}_lasterror*",data.lastErrorPtr)
"""
  let luaargs = args.mapIt(it.name).join(", ")
  let transforms = args.mapIt(&"--TRANSFORMING {it.name}\n{it.code}").join("\n")
  code.add &"""return function({luaargs})
{transforms}
--CALLING FUNCTION
  local callres = ffi.C.{rawname}({luaargs})
  --print("CALLRES",callres)
  if not callres then
    local errmsg = ffi.string(last_error.cstr)
    error(errmsg)
  end
end"""
  #echo "LUACODE ",code
  datatable.rawset("lastErrorPtr",last_error.addr.pointer)
  return lua.load(code).call(datatable,LuaReference)

macro implementLuajitFunction*(lua:LuaState,closure:untyped):LuaReference =
  let i_buildErrorMsg = bindSym "buildErrorMsg"
  let i_lastError = bindSym "last_error"
  let i_lua = ident "lua"
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
  var closuredefs:seq[NimNode] = @[ident "cint"]
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
        `ty`.genLuaDef(`i_lua`,`namestr`)
  procbody.add body
  let procbody_wrapped = quote do:
    result = 1
    try:
      `procbody`
    except Exception as e:
      result = 0
      let msg = `i_buildErrorMsg`(e)
      `i_lastError`.nimstr[] = msg
      `i_lastError`.cstr = `i_lastError`.nimstr[]
      #echo msg
  let codegen = &"$# $#$#"
  let procpragmas = quote do:
    {.exportc: `rawpname`,codegenDecl: `codegen`,raises:[].}
  let p = newProc(ident rawpname,closuredefs,procbody_wrapped,pragmas=procpragmas)
  #echo "PROC ",p.repr
  #echo "ARGDEF ",argdefs.treeRepr
  return quote do:
    block:
      `res`
      `p`
      let `i_lua` = `lua`
      `i_lua`.bindLuajitFunction(`rawpname`,`argdefs`)