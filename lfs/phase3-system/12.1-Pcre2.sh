#!/bin/bash
# LFS 13.0 - 8.13. Pcre2-10.47
source "/lfs/lib/common.sh"
PKG_NAME="pcre2"
check_built "$PKG_NAME" && exit 0
extract "pcre2"

./configure --prefix=/usr                       \
            --docdir=/usr/share/doc/pcre2-${PCRE2_VERSION} \
            --enable-unicode                    \
            --enable-jit                        \
            --enable-pcre2-16                   \
            --enable-pcre2-32                   \
            --enable-pcre2grep-libz             \
            --enable-pcre2grep-libbz2           \
            --enable-pcre2test-libreadline      \
            --disable-static

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
