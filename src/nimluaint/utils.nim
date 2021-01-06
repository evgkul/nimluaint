import lua_api
import strformat
import strutils

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
