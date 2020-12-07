template exportReadonly*(ty:typedesc,name:untyped) =
  template name*(obj:ty):auto = obj.name