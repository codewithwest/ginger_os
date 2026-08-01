#!/bin/bash
# LFS 13.0  - 8.20. Binutils-2.45
source "/lfs/lib/common.sh"
PKG_NAME="binutils-final"
check_built "$PKG_NAME" && exit 0
extract "binutils"

# Verify 64-bit build
mkdir -v build
cd       build

../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --enable-new-dtags  \
             --with-system-zlib  \
             --enable-default-hash-style=gnu

make $MAKEFLAGS tooldir=/usr
make tooldir=/usr install

rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
        /usr/share/doc/gprofng/

cd ../.. && cleanup
mark_built "$PKG_NAME"
