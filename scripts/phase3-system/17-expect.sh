#!/bin/bash
# LFS 12.4 - 8.17. Expect-5.45.4
source "/scripts/common.sh"
PKG_NAME="expect"
ARCHIVE="expect5.45.4.tar.gz"
DIR_NAME="expect5.45.4"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include
make $MAKEFLAGS
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
