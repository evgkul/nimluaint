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
import luajit_from
import luajit_to

type LuaLastError = object
  cstr: cstring
  nimstr: ref string

type LuajitFunctionCustom* = object
  before_definitions*:string
  after_call*:string
  data*:LuaReference

var last_error {.threadvar.}:LuaLastError 
new(last_error.nimstr)

var ids {.compiletime.}:int = 0

proc bindLuajitFunction*(lua:LuaState,rawname:string,args:openarray[LuajitArgDef],retDef:LuajitToDef,retStore:pointer,custom:LuajitFunctionCustom):LuaReference =
  var datatable = custom.data
  if datatable==nil:
    datatable = lua.newtable()
  datatable.rawset("retstore",retStore)
  let cargs = args.mapIt(&"{it.typename} {it.name}").join(", ")
  let luaargs = args.mapIt(it.name).join(", ")
  let transforms = args.mapIt(&"--PROCESSING {it.name}\n{it.code}").join("\n")
  var load_metatables_seq:seq[string]
  for arg in args:
    if arg.metatable!=nil:
      let key = "metatable_"&arg.name
      datatable.rawset(key,arg.metatable)
      load_metatables_seq.add &"local {key} = data['{key}']"
  let load_metatables = load_metatables_seq.join("\n")

  var code = """local data = ({...})[1]
local ffi = require("ffi")
"""
  let structbody = """{
  char * cstr;
  void * nimstr;
  }"""
  code.add &"""
--LOADING METATABLES
{load_metatables}
--FINISHED LOADING METATABLES
--CUSTOM DEFINITIONS
{custom.before_definitions}
--FINISHED CUSTOM DEFINITIONS
ffi.cdef[[
typedef struct {structbody} {rawname}_lasterror;
bool {rawname}({cargs});
]]
local last_error = ffi.new("{rawname}_lasterror*",data.lastErrorPtr)
local retptr = data.retstore
--STARTED RETURN STRUCT
local retstruct = ffi.new([[{retDef.cdef}]],retptr)
--FINISHED RETURN STRUCT

return function({luaargs})
  local data = data --protecting from gc (not sure if needed)
{transforms}
--CALLING FUNCTION
  local callres = ffi.C.{rawname}({luaargs})
  --print("CALLRES",callres)
  if not callres then
    local errmsg = ffi.string(last_error.cstr)
    error(errmsg)
  end
  --AFTER CALL
  {custom.after_call}
  --RETURN
  return {retDef.getvalue}
end"""
  when defined dumpLuajitFunctionWrapper:
    var lines = code.split("\n")
    let nlen = len $(lines.len+1)
    echo "CODE:"
    var i = 1
    for l in lines:
      echo ($i).align(nlen),":",l
      i+=1
  datatable.rawset("lastErrorPtr",last_error.addr.pointer)
  return lua.load(code).call(datatable,LuaReference)

macro implementLuajitFunction*(lua:LuaState,closure:untyped,custom:LuajitFunctionCustom):LuaReference =
  #echo "PASS ",pass_values.treeRepr
  #pass_values.expectKind nnkBracket
  var closure = closure
  if closure.kind==nnkStmtList:
    closure = closure[0]
  if not (closure.kind in {nnkLambda,nnkProcDef}):
    error(&"Invalid expression type: {closure.kind}",closure)
  let i_buildErrorMsg = bindSym "buildErrorMsg"
  let i_lastError = bindSym "last_error"
  let i_lua = ident "lua"
  let i_ret = ident "RetType"
  let i_retstore = genSym(nskVar,"ret_store")
  var check_types = newStmtList()
  let id = ids
  ids+=1
  
  let pname = closure.name
  let params = closure.params
  var ret = params[0]
  if ret.kind==nnkEmpty:
    ret = ident "void"
  check_types.add quote do:
    checkToluajit `i_ret`
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
      check_types.add quote do:
        checkFromluajit(`ty`) {.explain.}
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
      when `i_ret` is void:
        template result():untyped = {.error:"Attempt to set result of void function!".}
      else:
        var lua_res:`i_ret`
        template result():untyped = lua_res
      
      block nim_code:
        `procbody`
      when `i_ret` is not void:
        `i_retstore`.toluajit(lua_res)
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
  result = quote do:
    block:
      type `i_ret` = `ret`
      `check_types`
      var `i_retstore` {.global,threadvar.}:toluajitStore `i_ret`
      init `i_retstore`
      `p`
      let `i_lua` = `lua`
      `i_lua`.bindLuajitFunction(`rawpname`,
        `argdefs`,
        `i_ret`.getDefinition(LuajitToContext(getstruct:"retstruct")),
        `i_retstore`.addr,
        `custom`)
  #echo "RESULT ",result.repr

template implementLuajitFunction*(lua:LuaState,closure:untyped):LuaReference =
  implementLuajitFunction(lua,closure,LuajitFunctionCustom())