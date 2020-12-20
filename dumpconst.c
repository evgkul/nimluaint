/**
 * Task of this file is to dump constants from lua headers
 * 
 */
#include "stdio.h"
#include "lua.h"
#include "lauxlib.h"

#define dumpConst(name) printf("const %s* = %d\n",#name,name)
#define dumpComment(val) printf("#[\n%s\n]#\n",val)

/*void dumpDef(const char* name, int value){
    printf("const %s* = %d\n",name,value);
}*/

int main(){
    dumpConst(LUA_MULTRET);
    dumpConst(LUA_REGISTRYINDEX);
    dumpComment("Type consts");
    dumpConst(LUA_TNONE);
    dumpConst(LUA_TNIL);
    dumpConst(LUA_TBOOLEAN);
    dumpConst(LUA_TLIGHTUSERDATA);
    dumpConst(LUA_TNUMBER);
    dumpConst(LUA_TSTRING);
    dumpConst(LUA_TTABLE);
    dumpConst(LUA_TFUNCTION);
    dumpConst(LUA_TUSERDATA);
    dumpConst(LUA_TTHREAD);
    #ifndef LUAJIT
    dumpConst(LUA_NUMTAGS);
    #endif
    dumpComment("Predefined register positions");
    dumpConst(LUA_NOREF);
    dumpConst(LUA_REFNIL);
    dumpComment("Globals position");
    #ifdef LUAJIT
    dumpConst(LUA_GLOBALSINDEX);
    #else
    dumpConst(LUA_RIDX_GLOBALS);
    #endif

}