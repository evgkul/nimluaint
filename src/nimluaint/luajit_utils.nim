import lua_api
import lua_userdata
import lua_reference
import lua_state
import macros
import strformat

type ToLuajitType* {.explain.} = concept x, type t
  t.nimSideType is typedesc
  t.luaSideType is string
  t.genLuaCode(string) is string
  x.toluajit() is t.nimSideType

template nimSideType*(t:type int):typedesc = cint
template luaSideType*(t:type int):string = "int"
proc genLuaCode*(argname:string):string = 
  return ""
proc toluajit*(val:int):cint = val.cint

template checkToluajit*(t: type ToLuajitType) = discard

var ids {.compiletime.}:int = 0

macro implementLuajitClosure*(lua:LuaState,closure:untyped) =
  let id = ids
  ids+=1
  var closure = closure
  if closure.kind==nnkStmtList:
    closure = closure[0]
  if not (closure.kind in {nnkLambda,nnkProcDef}):
    error(&"Invalid expression type: {closure.kind}",closure)
  let params = closure.params
  let ret = params[0]
  let args = params[1..^1]
  var body = closure.body
  echo "params ",params.treeRepr
  var closuredefs:seq[NimNode] = @[newEmptyNode()]
  for argdef in args:
    let ty = argdef[^2]
    for name in argdef[0..^3]:
      echo "ARG ",name.treeRepr,": ",ty.treeRepr
      let cty = quote do:
        `ty`.nimSideType
      closuredefs.add newIdentDefs(name,cty)
  let procbody = quote do:
    echo "TestBody"
  let procpragmas = quote do:
    {.exportc,cdecl.}
  let p = newProc(ident &"luajit_closure_{id}",closuredefs,procbody,pragmas=procpragmas)
  echo "PROC ",p.repr