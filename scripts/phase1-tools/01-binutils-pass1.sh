#!/bin/bash
# LFS 12.4 - 5.2. Binutils-2.45 - Pass 1
source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="binutils-pass1"
check_built "$PKG_NAME" && exit 0

# Smart extract finds the best match for 'binutils' automatically
extract "binutils"



log "PROCESS" "Compiling Binutils Pass 1..."
mkdir -v build
cd build

../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror    \
             --enable-new-dtags  \
             --enable-default-hash-style=gnu
             
make $MAKEFLAGS
make install

cd ../..
rm -rf "binutils-"*

mark_built "$PKG_NAME"
