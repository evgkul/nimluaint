import lua_api
import lua_state
import lua_reference
import lua_userdata
import lua_to
import lua_from
import macros
import strutils
import strformat
import lua_metatable
import utils
var pincr {.compiletime.} = 0

type InnerClosure = proc(L:PState):cint {.closure,raises:[].}
type NimClosureWrapperInner = object
  inner: InnerClosure

type NimClosureWrapper = ref NimClosureWrapperInner

proc implementUserdata*(t:type NimClosureWrapper,lua:LuaState,meta:LuaReference) =
  discard nil

proc pushclosure(lua:LuaState,rawclosure:TCFunction,inner:InnerClosure):LuaReference =
  #echo "PUSHING"
  let L = lua.raw
  let wrapper = NimClosureWrapper(inner:inner)
  let env = inner.rawEnv
  GC_ref wrapper
  L.pushlightuserdata env
  L.pushcclosure(rawclosure,1)
  #echo "PUSHED"
  return lua.popReference()
proc force_keep[T](val:T) {.inline.} =
  ##Forces a value to be not removed by nim compiler
  {.emit: "/* Forcing to keep in code `val` */".}

macro implementClosure*(lua:LuaState,closure: untyped):LuaReference =
  var closure = closure
  if closure.kind==nnkStmtList:
    closure.expectLen 1
    closure = closure[0]
  if not (closure.kind in {nnkLambda,nnkProcDef}):
    error(&"Invalid expression type: {closure.kind}",closure)
  let i_renameto = ident "interceptReturn"
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
  #echo "INP: ",closure.treeRepr
  let params = closure.params
  #echo "PARAMS: ",params.treeRepr
  let ret = params[0]
  let args = params[1..^1]
  var body = closure.body
  rewriteReturn(body,i_renameto)
  #echo "RET: ",ret.treeRepr
  var fname_node = closure.name
  if fname_node.kind==nnkEmpty:
    fname_node = ident "unnamed"
  let fname = fname_node.strVal
  let cname = &"cfunction_{fname}_{pincr}"
  let inner_cname = &"inner_{fname}_{cname}"
  pincr+=1
  let ptrindex = upvalueindex(1)
  let cdecl = """int CFUNC(void* L){
    void* e = lua_touserdata(L,PTRINDEX);
    int rcode = INNERFUNC(L,e);
    //printf("HELLO FROM CLOSURE!\n");
    if(rcode==-2){
      lua_error(L);
    }
    return rcode;
  }""".replace("CFUNC",cname).replace("PTRINDEX",$ptrindex).replace("INNERFUNC",inner_cname)
  let cname_ident =ident cname
  let inner_proc = ident inner_cname
  let i_lua_args = genSym(nskVar,"lua_args")
  let i_gettop = bindSym "gettop"
  var args_tuple = quote do:
    tuple[]
  var args_bindings = newStmtList()
  for arg in args:
    let last = arg[^1]
    if last.kind!=nnkEmpty:
      error("Default values are not yet supported!",last)
    var ty = arg[^2]
    var isVar = false
    if ty.kind==nnkVarTy:
      isVar = true
      let copy = ty
      ty = newNimNode(nnkPtrTy,copy)
      for val in copy:
        ty.add val
    #echo "TY ",ty.treeRepr
    for def in arg[0..^3]:
      #echo "DEF ",def.treeRepr
      args_tuple.add newIdentDefs(def,ty)
      if isVar:
        args_bindings.add quote do:
          template `def`():untyped =
            `i_lua_args`.`def`[]
      else:
        args_bindings.add quote do:
          template `def`():`ty` =
            `i_lua_args`.`def`
  
  let rettype = if ret.kind == nnkEmpty:
    quote do:
      void
  else:
    ret

  res.add quote do:
    type RetType = `rettype`
    let lua {.cursor,inject.} = `lua`
    proc `inner_proc`(L:PState):cint {.closure, exportc: `inner_cname`,raises:[].} =
      let lua2 = lua
      let oldraw = lua.raw
      lua.update_raw(L)
      try:
        var `i_lua_args` = default `args_tuple`
        var lua_pos = 1.cint
        fromluaraw(`i_lua_args`,lua,lua_pos,`i_gettop`(L))
        `args_bindings`
        when RetType is not void:
          var lua_res:RetType = default RetType
        block nim_code:
          when RetType is not void:
            template result():untyped = lua_res
            template interceptReturn(a:untyped) =
              lua_res = a
              break nim_code
          else:
            template interceptReturn(a:untyped) =
              {.error: "This proc's return type is void!".}
            template interceptReturn() =
              break nim_code
          when RetType is not void and compiles(lua_res = `body`):
            lua_res = `body`
          else:
            `body`
        when RetType is not void:
          return toluaraw_multi(lua_res,lua)
        else:
          return 0
      except Exception as e:
        #echo "ERROR"
        let errmsg = buildErrorMsg(e)
        discard L.pushstring(errmsg)
        return -2
      finally:
        lua.update_raw oldraw
    proc `cname_ident`(L:`pstate`):cint {.cdecl, importc, codegenDecl: `cdecl`.}
    `pushc`(lua,`cname_ident`,`inner_proc`)
  return quote do:
    block:
      #{.warning[GcUnsafe]:off.}
      `res`
  #error("NIY",closure)


macro registerMethods*(r:LuaReference,methods:untyped) =
  #echo "METHODS ",methods.treeRepr
  let i_ref = genSym(nskLet,"meta")
  let i_lua = genSym(nskLet,"lua")
  var res = newStmtList quote do:
    let `i_ref`:LuaReference = `r`
    let `i_lua`:LuaState = `i_ref`.lua
  for m in methods:
    #echo "METHOD ",m.treeRepr
    m.expectKind nnkProcDef
    let name = m.name.strVal
    res.add quote do:
      block:
        let clos = `i_lua`.implementClosure `m`
        `i_ref`.rawset(`name`,clos)
        
  return quote do:
    block:
      `res`
    
  