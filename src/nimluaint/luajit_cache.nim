import tables

type LuajitCache* = object
  closure_wrappers*:Table[pointer,cint]
