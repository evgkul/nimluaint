import lua_api
import strformat
import strutils
import macros

type TypeID* = pointer
proc getTypeID*(t:typedesc):TypeID {.gcsafe.} =
  {.cast(gcsafe).}:
    let typeid {.global.} = $t
    return typeid.unsafeAddr.pointer

template protectStack*(L:PState,stack_top:untyped,code:untyped) =
  let stack_top = L.gettop()
  try:
    code
  finally:
    L.settop stack_top
template protectStack*(L:PState,code:untyped) = L.protectStack(stack_top,code)

template exportReadonly*(ty:typedesc,name:untyped) =
  template name*(obj:ty):auto = obj.name

proc buildErrorMsg*(e:ref Exception):string =
  var errmsg = ""
  errmsg.add e.name
  errmsg.add ": "
  errmsg.add e.msg
  when compileOption("stacktrace"):
    errmsg.add("\n  ")
    errmsg.add(e.getStackTrace().replace("\n","\n  "))
  return errmsg

#[proc extractTypedef*(node:NimNode):NimNode =
  result = node
  echo "STARTED EXTRACTION"
  while true:
    echo "STEP ",result.treeRepr
    if result.kind==nnkSym:
      result = result.getImpl
      continue
    break
  echo "EXTRACTED ",result.treeRepr]#

proc rewriteReturn*(node:var NimNode,rename_to:NimNode):bool {.compiletime,discardable.} =
  if node.kind==nnkReturnStmt:
    result = true
    let copy = node
    node = newCall rename_to
    #echo "TO: ",to.treeRepr
    for c in copy:
      if c.kind!=nnkEmpty:
        node.add c
  for i in 0..node.len-1:
    var c = node[i]
    if rewriteReturn(c,rename_to):
      node[i] = c