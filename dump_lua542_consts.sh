mkdir -p tmp
rm -rf tmp/dumpconsts_work
mkdir tmp/dumpconsts_work
cd tmp/dumpconsts_work
gcc -o dumpconst -I ../../src/nimluaint/lua-5.4.2/src ../../dumpconst.c
./dumpconst > ../../src/nimluaint/lua_5_4_2_consts.nim