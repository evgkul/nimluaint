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
    toluajit(var (t.toluajitstore), x )
  t.getDefinition(LuajitToContext) is LuajitToDef
type SimpleToluajitStore*[T] = object
  val*: T
template init*(val:var SimpleToluajitStore) = discard

template toluajit_rawtype*(str:string):cstring =
  str

#[type ReferencedToluajitStore*[Nimtype,Rawtype] = object
  val*:Rawtype
  nimval*:ref Nimtype
template init*[Nimtype,Rawtype](val:var ReferencedToluajitStore[Nimtype,Rawtype]) = new val.nimval


template setvalue*[Nimtype,Rawtype](store:var ReferencedToluajitStore[Nimtype,Rawtype],value:Nimtype) =
  mixin toluajit_rawtype
  store.nimval[] = value
  store.val = store.nimval[].toluajit_rawtype]#



#[proc globalptr*(t:typedesc):ptr t =
  var val {.global,threadvar.}:t
  return val.addr]#

template implementSimpleToluajit*(ty:typedesc,to:typedesc,ctype:static[string]):untyped =
  template toluajitStore*(t:type ty):typedesc = SimpleToluajitStore[to]
  proc toluajit*(dataptr: var SimpleToluajitStore[to],val:ty) {.inline.}=
    dataptr.val = val.to
  proc getDefinition*(t:type ty,context:LuajitToContext):LuajitToDef =
    result.cdef = "struct {"&ctype&" val;} *"
    result.getvalue = context.getstruct&".val"

#[template implementReferencedToluajit*(ty:typedesc,to:typedesc,ctype:static[string],op_getval:untyped):untyped =
  template toluajitStore*(t:type ty):typedesc = ReferencedToluajitStore[ty,to]
  proc toluajit*(dataptr: var ReferencedToluajitStore[ty,to],val:ty) {.inline.}=
    dataptr.setvalue val
  proc getDefinition*(t:type ty,context{.inject.}:LuajitToContext):LuajitToDef =
    result.cdef = "struct {"&ctype&" val;} *"
    result.getvalue = op_getval]#

int.implementSimpleToluajit(cint,"int")

#string.implementReferencedToluajit(cstring,"char *","tostring("&context.getstruct&".val)")

type StringRet* = object
  str:cstring
  length:cint
  nimstr:ref string
template init*(val: var StringRet) = new(val.nimstr)
template toluajitStore*(t:type string):typedesc = StringRet
proc toluajit*(dataptr: var StringRet,val:string) {.inline.}=
  dataptr.length = val.len.cint
  dataptr.nimstr[]= val
  dataptr.str = dataptr.nimstr[]
proc getDefinition*(t:type string,context:LuajitToContext):LuajitToDef =
  result.cdef = "struct {char * str;int length;void * nimstr;} *"
  result.getvalue = &"ffi.string({context.getstruct}.str,{context.getstruct}.length)"

template toluajitStore*(t:type void):typedesc = SimpleToluajitStore[cint]
proc getDefinition*(t:type void,context:LuajitToContext):LuajitToDef =
  result.cdef = "struct {int val;} *"
  result.getvalue = "nil"

template checkToluajit*(t: type ToLuajitType) = discard
checkToLuajit int
checkToluajit void
checkToluajit string