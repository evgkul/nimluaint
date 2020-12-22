mkdir -p tmp
rm -rf tmp/dumpconsts_work
mkdir tmp/dumpconsts_work
cd tmp/dumpconsts_work
gcc -o dumpconst -D LUAJIT -I ../../src/nimluaint/luajit2_3_beta1_includes ../../dumpconst.c
./dumpconst > ../../src/nimluaint/luajit_consts.nim