#!/bin/bash
# LFS 12.4 - 5.6. Libstdc++ from GCC-15.2.0
source "$(dirname "$(readlink -f "$0")")/common.sh"

PKG_NAME="libstdcxx"
check_built "$PKG_NAME" && exit 0

extract "gcc"

log "PROCESS" "Compiling Libstdc++..."
mkdir -v build
cd build

../libstdc++-v3/configure      \
    --host=$LFS_TGT            \
    --build=$(../config.guess) \
    --prefix=/usr              \
    --disable-multilib         \
    --disable-nls              \
    --disable-libstdcxx-pch    \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0

make $MAKEFLAGS
make DESTDIR=$LFS install

# Remove interfering libtool files
rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la

cd ../..
rm -rf "gcc-"*

mark_built "$PKG_NAME"
