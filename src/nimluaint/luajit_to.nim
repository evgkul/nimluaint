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
import typetraits

type LuajitToDef* = object
  cdef*:string
  getvalue*:string

type LuajitToContext* = object
  getstruct*:string

type ToLuajitType* = concept x,type t
  t.toluajitStore is typedesc
  when t is not void and t is not tuple:
    toluajit(var (t.toluajitstore), x )
  t.getDefinition(LuajitToContext) is LuajitToDef
type SimpleToluajitStore*[T] = object
  val*: T
template luajit_store_init*(val:var SimpleToluajitStore) = discard

template toluajit_rawtype*(str:string):cstring =
  str

#[type ReferencedToluajitStore*[Nimtype,Rawtype] = object
  val*:Rawtype
  nimval*:ref Nimtype
template luajit_store_init*[Nimtype,Rawtype](val:var ReferencedToluajitStore[Nimtype,Rawtype]) = new val.nimval


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
    result.cdef = "struct {"&ctype&" val;}"
    result.getvalue = context.getstruct&".val"
template implementSimpleToluajit*(ty:typedesc,ctype:static[string]):untyped =
  implementSimpleToluajit(ty,ty,ctype)
#[template implementReferencedToluajit*(ty:typedesc,to:typedesc,ctype:static[string],op_getval:untyped):untyped =
  template toluajitStore*(t:type ty):typedesc = ReferencedToluajitStore[ty,to]
  proc toluajit*(dataptr: var ReferencedToluajitStore[ty,to],val:ty) {.inline.}=
    dataptr.setvalue val
  proc getDefinition*(t:type ty,context{.inject.}:LuajitToContext):LuajitToDef =
    result.cdef = "struct {"&ctype&" val;} *"
    result.getvalue = op_getval]#

int.implementSimpleToluajit(cint,"int")
float.implementSimpleToluajit(cdouble,"double")
float64.implementSimpleToluajit(cdouble,"double")
float32.implementSimpleToluajit(cfloat,"float")
uint.implementSimpleToluajit(cuint,"unsigned int")

int64.implementSimpleToluajit "int64_t"
int32.implementSimpleToluajit "int32_t"
int16.implementSimpleToluajit "int16_t"
int8.implementSimpleToluajit "int8_t"
uint64.implementSimpleToluajit "uint64_t"
uint32.implementSimpleToluajit "uint32_t"
uint16.implementSimpleToluajit "uint16_t"
uint8.implementSimpleToluajit "uint8_t"


#string.implementReferencedToluajit(cstring,"char *","tostring("&context.getstruct&".val)")

type StringRet* = object
  str:cstring
  length:cint
  nimstr:ref string
template luajit_store_init*(val: var StringRet) = new(val.nimstr)
template toluajitStore*(t:type string):typedesc = StringRet
proc toluajit*(dataptr: var StringRet,val:string) {.inline.}=
  dataptr.length = val.len.cint
  dataptr.nimstr[]= val
  dataptr.str = dataptr.nimstr[]
proc getDefinition*(t:type string,context:LuajitToContext):LuajitToDef =
  result.cdef = "struct {char * str;int length;void * nimstr;}"
  result.getvalue = &"ffi.string({context.getstruct}.str,{context.getstruct}.length)"

template toluajitStore*(t:type void):typedesc = SimpleToluajitStore[cint]
proc getDefinition*(t:type void,context:LuajitToContext):LuajitToDef =
  result.cdef = "struct {int val;}"
  result.getvalue = "nil"

macro toluajitStore_tuple_impl*(t:tuple ):typedesc =
  let ty = t.getTypeImpl 
  #ty.expectKind nnkTupleTy
  var res = quote do:
    ()
  #echo "I ",t.treeRepr
  #echo "TY ",ty.treeRepr
  proc handleArg(argty:NimNode) =
    let i = ident argty.strVal
    let store_ty = quote do:
      `i`.toluajitStore
    res.add store_ty#newIdentDefs(ident fname,store_ty)
  for arg in ty:
    if arg.kind==nnkIdentDefs:
      let argty = arg[^2]
      for name in arg[0..^3]:
        handleArg argty
    else:
      handleArg arg
  result = res
  #echo "RES ",result.treeRepr

macro init_tuplewrapper_impl[T](v: var T,l: static[int]) =
  #let ty = tuplesample.getType
  result = newStmtList()
  for i in 0..l-1:
    result.add quote do:
      luajit_store_init `v`[`i`]

proc luajit_store_init*[T:tuple](v: var T) =
  bind init_tuplewrapper_impl
  init_tuplewrapper_impl(v,arity typeof(v))
template toluajitStore*(t:type tuple):typedesc = 
  (default t).toluajitStore_tuple_impl #Ugly, I know
macro toluajit_tuple_impl[T:tuple](o: var tuple,tlen:static[int],val:T) =
  result = newStmtList()
  for i in 0..tlen-1:
    result.add quote do:
      `o`[`i`].toluajit(`val`[`i`])
  
proc toluajit*[A:tuple,B:tuple](o:var A,val:B) = 
  bind toluajit_tuple_impl
  toluajit_tuple_impl(o,tupleLen val,val)

macro getDefinition_tuple_macro(t:tuple,tlen:static[int],context:LuajitToContext) =
  let i_cdef = ident "cdef"
  let i_getvalue = ident "getvalue"
  result = newStmtList()
  result.add quote do:
    var `i_cdef` = "struct { "
    var `i_getvalue`:seq[string]
  for i in 0..tlen-1:
    let fname = "arg_" & $i
    result.add quote do:
      block:
        let faccess = `context`.getstruct & "." & `fname`
        let idef = getDefinition(typeof(`t`[`i`]),LuajitToContext(getstruct:faccess))
        cdef.add idef.cdef
        cdef.add " "
        cdef.add `fname`
        cdef.add "; "
        getvalue.add idef.getvalue
  result.add quote do:
    cdef.add "}"
    return LuajitToDef(cdef:cdef,getvalue:getvalue.join(", "))
  

proc getDefinition*[T:tuple](t:type T,context:LuajitToContext):LuajitToDef =
  getDefinition_tuple_macro(default T,tupleLen T,context)

type TTuple = tuple[t1:int,t2:int]

static: 
  assert toluajitStore( tuple[a,b:int] ) is (int.toluajitStore,int.toluajitStore)
  assert toluajitStore( (int,int) ) is (int.toluajitStore,int.toluajitStore)
  assert toluajitStore( TTuple ) is (int.toluajitStore,int.toluajitStore)

template checkToluajit*(t: type ToLuajitType) = discard
checkToLuajit int
checkToluajit void
checkToluajit string
checkToluajit (int,int) {.explain.}