import lua_api

template protectStack*(L:PState,stack_top:untyped,code:untyped) =
  let stack_top = L.gettop()
  try:
    code
  finally:
    L.settop stack_top
template protectStack*(L:PState,code:untyped) = L.protectStack(stack_top,code)

template exportReadonly*(ty:typedesc,name:untyped) =
  template name*(obj:ty):auto = obj.name
  