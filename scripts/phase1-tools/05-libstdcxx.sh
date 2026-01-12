#!/bin/bash
# LFS 12.2 - 5.6. Libstdc++ from GCC-14.2.0
# The standard C++ library, built separately using the cross-compiler.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="libstdcxx-pass1"
PKG_VERSION="$GCC_VERSION"
ARCHIVE="gcc-$GCC_VERSION.tar.xz"
DIR_NAME="gcc-$GCC_VERSION"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

mkdir -v build
cd build

log "PROCESS" "Compiling Libstdc++..."

../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/$GCC_VERSION

make $MAKEFLAGS
make DESTDIR=$LFS install

# Remove libtool files that interfere with cross-compilation
rm -v $LFS/usr/lib/lib{stdc++,stdc++fs,supc++}.la

cd ../..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
