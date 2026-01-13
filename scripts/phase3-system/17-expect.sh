#!/bin/bash
# LFS 12.4 - 8.17. Expect-5.45.4
source "/scripts/common.sh"
PKG_NAME="expect"
check_built "$PKG_NAME" && exit 0
extract "expect"

python3 -c 'from pty import spawn; spawn(["echo", "ok"])'

# Patch for GCC 15
patch -Np1 -i ../expect-5.45.4-gcc15-1.patch

./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include

make $MAKEFLAGS
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib

cd .. && rm -rf "expect"*
mark_built "$PKG_NAME"
