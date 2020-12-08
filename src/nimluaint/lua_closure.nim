import lua_api
import lua_state
import lua_reference
import lua_userdata
import macros
import strutils
import strformat
var pincr {.compiletime.} = 0

type InnerClosure = proc():cint {.closure,raises:[].}
type NimClosureWrapper = ref object
  inner: InnerClosure
proc implementUserdata*(t:type NimClosureWrapper,lua:LuaState,meta:LuaReference) =
  discard nil

proc pushclosure(lua:LuaState,rawclosure:TCFunction,inner:InnerClosure):LuaReference =
  let L = lua.raw
  let wrapper = NimClosureWrapper(inner:inner)
  let env = inner.rawEnv
  GC_ref wrapper
  L.pushlightuserdata env
  L.pushcclosure(rawclosure,1)
  return lua.popReference()
proc force_keep[T](val:T) {.inline.} =
  ##Forces a value to be not removed by nim compiler
  {.emit: "/* Forcing to keep in code `val` */".}

proc rewriteReturn(node:var NimNode,rename_to:NimNode):bool {.compiletime,discardable.} =
  if node.kind==nnkReturnStmt:
    result = true
    let copy = node
    node = newCall(rename_to)
    #echo "TO: ",to.treeRepr
    for c in copy:
      node.add c
  for i in 0..node.len-1:
    var c = node[i]
    if rewriteReturn(c,rename_to):
      node[i] = c

template buildInnerClosure*(body:untyped,interceptReturn:untyped):untyped =
  #bind rewriteReturn
  try:
    var lua_res:string
    template result():untyped = lua_res
    block lua_code:
      template interceptReturn(a:untyped) =
        lua_res = a
        break lua_code
      body
  except Exception as e:
    echo "ERROR"
    return -2

macro implementClosure*(lua:LuaState,closure: untyped):LuaReference =
  closure.expectKind nnkLambda
  let i_renameto = genSym(nskTemplate,"interceptReturn")
  let pushc = bindSym "pushclosure"
  let pstate = bindSym "PState"
  #let ty = closure.getTypeImpl()
  #ty.expectKind nnkProcTy
  #let formal = ty[0]
  #formal.expectKind nnkFormalParams
  #echo "TYPE: ",formal.treeRepr
  var res = newStmtList()
  block add_function_keep:
    let i_touserdata = bindSym "touserdata"
    let i_settop = bindSym "settop"
    let i_error = bindSym "error"
    let i_force_keep = bindSym "force_keep"
    res.add quote do:
      proc keep_functions(l:`pstate`) =
        discard `i_touserdata`(l,-1)
        `i_settop`(l,-1)
        discard `i_error`(l)
      `i_force_keep`(keep_functions)
  echo "INP: ",closure.treeRepr
  let params = closure.params
  echo "PARAMS: ",params.treeRepr
  let ret = params[0]
  let args = params[1..^1]
  var body = closure.body
  rewriteReturn(body,i_renameto)
  echo "RET: ",ret.treeRepr
  let cname = &"cfunction_{pincr}"
  let inner_cname = &"inner_{cname}"
  pincr+=1
  let ptrindex = upvalueindex(1)
  let cdecl = """int CFUNC(void* L){
    void* e = lua_touserdata(L,PTRINDEX);
    int rcode = INNERFUNC(e);
    printf("HELLO FROM CLOSURE!\n");
    return 0;
  }""".replace("CFUNC",cname).replace("PTRINDEX",$ptrindex).replace("INNERFUNC",inner_cname)
  let cname_ident =ident cname
  let inner_proc = ident inner_cname

  res.add quote do:
    proc `inner_proc`():cint {.closure, exportc: `inner_cname`,raises:[].} =
      buildInnerClosure(`body`,`i_renameto`)
    proc `cname_ident`(L:`pstate`):cint {.cdecl, importc, codegenDecl: `cdecl`.}
    `pushc`(`lua`,`cname_ident`,`inner_proc`)
  return quote do:
    block:
      `res`
  #error("NIY",closure)