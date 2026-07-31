#!/bin/bash
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

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
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/${GCC_VERSION}

make $MAKEFLAGS
make DESTDIR=$LFS install

# Remove interfering libtool files
rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la

cd ../..

cleanup

mark_built "$PKG_NAME"
