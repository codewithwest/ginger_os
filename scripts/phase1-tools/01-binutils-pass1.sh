#!/bin/bash
# LFS 12.2 - 5.2. Binutils-2.43.1 - Pass 1
# Binutils is the first package because GCC and Glibc perform various tests 
# on the assembler and linker to determine which features to enable.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="binutils-pass1"
PKG_VERSION="$BINUTILS_VERSION"
ARCHIVE="binutils-$BINUTILS_VERSION.tar.xz"
DIR_NAME="binutils-$BINUTILS_VERSION"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Compiling Binutils Pass 1..."

mkdir -v build
cd build

../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror

make $MAKEFLAGS
make install

cd ../..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
