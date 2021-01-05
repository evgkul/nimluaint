import os

const UseLuaVersion* {.strdefine.} = "lua5.4"
const EmbedLua* {.booldefine.} = UseLuaVersion=="lua5.4"
const BuildLuaUTF8* {.booldefine.} = UseLuaVersion=="luajit"
const LuaIncludesPath* {.strdefine.} =
  if UseLuaVersion=="lua5.4":
    currentSourcePath().parentDir()/"lua-5.4.2"
  else:
    currentSourcePath().parentDir()/"luajit2_3_beta1_includes"