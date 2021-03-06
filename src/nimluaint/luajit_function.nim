import lua_api
import lua_userdata
import lua_call
import lua_reference
import lua_state
import lua_rawtable
import lua_to
import macros
import strformat
import strutils
import sequtils
import utils
import luajit_from
import luajit_to
import lua_defines
import lua_closure
import tables
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

type LuajitProcHolder*[T:proc] = ref object of RootObj
  val*: T

proc bindLuajitFunction*(lua:LuaState,rawptr:pointer,rawname:string,args:openarray[LuajitArgDef],retDef:LuajitToDef,retStore:pointer,custom:LuajitFunctionCustom):LuaReference =
  var datatable = custom.data
  if datatable==nil:
    datatable = lua.newtable()
  datatable.rawset("retstore",retStore)
  let cargs = args.mapIt(&"{it.typename} {it.name}").concat(@["void * envptr"]).join(", ")
  let luaargs = args.mapIt(it.name).join(", ")
  let luacallargs = args.mapIt(it.name).concat(@["__internal_envptr"]).join(", ")
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
local retstruct = ffi.new([[{retDef.cdef} *]],retptr)
--FINISHED RETURN STRUCT
return function(__internal_envptr,keep)
return function({luaargs})

  local data = data --protecting from gc (not sure if needed)
  local keep = keep
{transforms}
--CALLING FUNCTION
  local callres = ffi.C.{rawname}({luacallargs})
  --print("CALLRES",callres)
  if not callres then
    local errmsg = ffi.string(last_error.cstr)
    error(errmsg)
  end
  --AFTER CALL
  {custom.after_call}
  --RETURN
  return {retDef.getvalue}
end
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

proc prepareClosure*(lua:NimNode,closure:NimNode):tuple[checktypes,closure:NimNode] {.compiletime.}=
  var closure = closure
  if closure.kind==nnkStmtList:
    closure.expectLen 1
    closure = closure[0]
  if not (closure.kind in {nnkLambda,nnkProcDef}):
    error(&"Invalid expression type: {closure.kind}",closure)
  var checktypes = newStmtList()
  let params = closure.params
  var ret = params[0]
  if ret.kind==nnkEmpty:
    ret = ident "void"
  check_types.add quote do:
    checkToluajit `ret`
  let args = params[1..^1]
  var body = closure.body
  for argdef in args:
    let ty = argdef[^2]
    for name in argdef[0..^3]:
      check_types.add quote do:
        checkFromluajit(`ty`) {.explain.}
  closure.body = quote do:
    `lua`.withLockedState:
      `body`
  return (checktypes,closure)
  
template getOrCreateLuajitWrapper*(lua:LuaState,funptr:pointer,code:LuaReference):LuaReference =
  if lua.luajit_cache.closure_wrappers.contains funptr:
    let rawref = lua.luajit_cache.closure_wrappers[funptr]
    newLuaReference(lua,rawref,LFUNCTION)
  else:
    let r = code
    let rawref = r.toraw
    lua.luajit_cache.closure_wrappers[funptr] = rawref
    r

macro implementFFIClosure*(lua:LuaState,closure:untyped,custom:LuajitFunctionCustom):LuaReference =
  when UseLuaVersion!="luajit":
    error("Attempt to create luajit function with custom parameters without luajit",closure)
  #echo "PASS ",pass_values.treeRepr
  #pass_values.expectKind nnkBracket
  let i_buildErrorMsg = bindSym "buildErrorMsg"
  let i_lastError = bindSym "last_error"
  let i_lua = ident "lua"
  let i_ret = ident "RetType"
  let i_retstore = genSym(nskVar,"ret_store")
  let i_return = ident "interceptReturn"
  let (check_types,closure) = i_lua.prepareClosure closure

  #var check_types = newStmtList()
  let id = ids
  ids+=1
  
  var fname_node = closure.name
  if fname_node.kind==nnkEmpty:
    fname_node = ident "unnamed"
  let fname = fname_node.strVal
  let params = closure.params
  var ret = params[0]
  if ret.kind==nnkEmpty:
    ret = ident "void"
  let args = params[1..^1]
  var body = closure.body
  body.rewriteReturn i_return
  let rawpname = &"luajit_closure_{fname}_{id}"
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
        when `i_ret` is void:
          template `i_return`() = break nim_code
          template `i_return`(val:untyped) = {.error:"Function's return type is void!".}
        else:
          template `i_return`(val:`i_ret`) = 
            lua_res = val
            break nim_code
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
  let i_rawpname = ident rawpname
  let procpragmas = quote do:
    {.exportc: `rawpname`,codegenDecl: `codegen`,raises:[],closure.}
  let p = newProc(i_rawpname,closuredefs,procbody_wrapped,pragmas=procpragmas)
  #echo "PROC ",p.repr
  #echo "ARGDEF ",argdefs.treeRepr
  result = quote do:
    block:
      let `i_lua` = `lua`
      type `i_ret` = `ret`
      `check_types`
      var `i_retstore` {.global,threadvar.}:toluajitStore `i_ret`
      luajit_store_init `i_retstore`
      `p`
      let holder = LuajitProcHolder[typeof `i_rawpname`](val: `i_rawpname`)
      let procptr = holder.val.rawProc
      let factory = `i_lua`.getOrCreateLuajitWrapper(procptr):
        `i_lua`.bindLuajitFunction(
          procptr,
          `rawpname`,
          `argdefs`,
          `i_ret`.getDefinition(LuajitToContext(getstruct:"retstruct")),
          `i_retstore`.addr,
          `custom`
        )
      factory.call((holder.val.rawEnv,holder.UnknownUserdata),LuaReference)
  #echo "RESULT ",result.repr
macro emulateFFIClosure(lua:LuaState,closure:untyped):LuaReference =
  let (checktypes,closure) = lua.prepareClosure closure
  return quote do:
    `checktypes`
    implementClosure(`lua`,`closure`)
template implementFFIClosure*(lua:LuaState,closure:untyped):LuaReference =
  when UseLuaVersion=="luajit":
    implementFFIClosure(lua,closure,LuajitFunctionCustom())
  else:
    let l = lua
    emulateFFIClosure(l,closure)

macro registerJITMethods*(r:LuaReference,methods:untyped) =
  methods.expectKind nnkStmtList
  let i_ref = ident "r"
  let i_lua = ident "lua"
  var res = newStmtList quote do:
    let `i_ref` = `r`
    let `i_lua` = `i_ref`.lua
  for m in methods:
    m.expectKind nnkProcDef
    let name = m.name.strVal
    res.add quote do:
      block:
        let clos = `i_lua`.implementFFIClosure `m`
        `i_ref`.rawset(`name`,clos)
  result = quote do:
    block:
      `res`
  