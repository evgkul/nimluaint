import lua_api
import lua_userdata
import lua_call
import lua_reference
import lua_state
import lua_rawtable
import macros
import strformat
import strutils
import sequtils
import utils

type LuajitToDef* = object
  cdef*:string
  getvalue*:string

type LuajitToContext* = object
  getstruct*:string

type ToLuajitType* = concept x,type t
  t.toluajitStore is typedesc
  when t is not void:
    toluajit(ptr (t.toluajitstore), x )
  t.getDefinition(LuajitToContext) is LuajitToDef
type SimpleToluajitStore*[T] = object
  val*: T

proc globalptr*(t:typedesc):ptr t =
  var val {.global,threadvar.}:t
  return val.addr

template toluajitStore*(t:type int):typedesc = SimpleToluajitStore[cint]
proc toluajit*(dataptr: ptr SimpleToluajitStore[cint],val:int) {.inline.}=
  dataptr.val = val.cint
proc getDefinition*(t:type int,context:LuajitToContext):LuajitToDef =
  result.cdef = "struct {int val;} *"
  result.getvalue = &"{context.getstruct}.val"

template toluajitStore*(t:type void):typedesc = SimpleToluajitStore[cint]
proc toluajit*(dataptr: ptr SimpleToluajitStore[cint],val:void) {.inline.}=
  #dataptr.val = val.cint
  discard
proc getDefinition*(t:type void,context:LuajitToContext):LuajitToDef =
  result.cdef = "struct {int val;} *"
  result.getvalue = "nil"

template checkToluajit*(t: type ToLuajitType) = discard
checkToLuajit int
checkToluajit void