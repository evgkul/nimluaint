import lua_api

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
  