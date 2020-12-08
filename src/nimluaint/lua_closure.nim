import lua_api
import lua_state
import lua_reference
import lua_userdata
import macros
import strutils
import strformat
var pincr {.compiletime.} = 0

proc pushclosure(lua:LuaState,rawclosure:TCFunction):LuaReference =
  let L = lua.raw
  L.pushcclosure(rawclosure,0)
  return lua.popReference()

macro implementClosure*(lua:LuaState,closure: proc):LuaReference =
  let pushc = bindSym "pushclosure"
  let pstate = bindSym "PState"
  #let ty = closure.getTypeImpl()
  #ty.expectKind nnkProcTy
  #let formal = ty[0]
  #formal.expectKind nnkFormalParams
  #echo "TYPE: ",formal.treeRepr
  var res = newStmtList()
  echo "INP: ",closure.treeRepr
  let params = closure.params
  echo "PARAMS: ",params.treeRepr
  let ret = params[0]
  let args = params[1..^1]
  echo "RET: ",ret.treeRepr
  let cname = &"cfunction_{pincr}"
  pincr+=1
  let cdecl = """int CFUNC(void* L){
    printf("HELLO FROM CLOSURE!\n");
    return 0;
  }""".replace("CFUNC",cname)
  let cname_ident =ident cname
  res.add quote do:
    proc `cname_ident`(L:`pstate`):cint {.cdecl, importc, codegenDecl: `cdecl`.}
    `pushc`(`lua`,`cname_ident`)
  return quote do:
    block:
      `res`
  #error("NIY",closure)