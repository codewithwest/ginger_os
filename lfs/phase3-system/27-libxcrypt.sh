#!/bin/bash
# LFS 13.0  - 8.27. Libxcrypt-4.4.38
source "/lfs/lib/common.sh"
PKG_NAME="libxcrypt"
check_built "$PKG_NAME" && exit 0
extract "libxcrypt"

# Prevent pedantic warnings from being treated as errors during build
# Some host toolchains or newer compiler versions make warnings into errors
# which breaks libxcrypt build; disable treating warnings as errors here.
export CFLAGS="${CFLAGS:-} -O2 -g -Wno-error"

./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no     \
            --disable-static             \
            --disable-failure-tokens

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
