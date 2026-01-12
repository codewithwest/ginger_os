#!/bin/bash
# LFS 12.4 - 8.29. GCC-15.2.0 (Final)
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="gcc-final"
check_built "$PKG_NAME" && exit 0
extract "gcc"

# Case-specific fix for 64-bit
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

mkdir -v build
cd build

../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --enable-default-pie     \
             --enable-default-ssp     \
             --disable-multilib       \
             --disable-bootstrap      \
             --with-system-zlib

make $MAKEFLAGS
make install
ln -sv ../usr/bin/cpp /usr/lib
ln -svf gcc /usr/bin/cc
ln -sfv g++ /usr/bin/c++

# Install headers
mkdir -pv /usr/lib/bfd-plugins
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/15.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/

cd ../.. && rm -rf "gcc-"*
mark_built "$PKG_NAME"
