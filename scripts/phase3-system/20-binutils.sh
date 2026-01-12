#!/bin/bash
# LFS 12.4 - 8.20. Binutils-2.45
source "/scripts/common.sh"
PKG_NAME="binutils-final"
ARCHIVE="binutils-2.45.tar.xz"
DIR_NAME="binutils-2.45"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
mkdir -v build
cd build
../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib  \
             --enable-gprofng=no
make tooldir=/usr $MAKEFLAGS
make tooldir=/usr install
rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a
cd ../.. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
