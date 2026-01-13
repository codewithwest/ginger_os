#!/bin/bash
# LFS 12.4 - 8.17. Expect-5.45.4
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="expect"
check_built "$PKG_NAME" && exit 0
extract "expect"

# Patch for GCC 15
if [ -f "$GINGER_SOURCES/expect-5.45.4-gcc15-1.patch" ]; then
    patch -Np1 -i "$GINGER_SOURCES/expect-5.45.4-gcc15-1.patch"
fi

./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include

make $MAKEFLAGS
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib

cd .. && rm -rf "expect"*
mark_built "$PKG_NAME"
