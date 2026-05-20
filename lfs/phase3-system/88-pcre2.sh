#!/bin/bash
# LFS 13.0 - ${PCRE2_VERSION} - PCRE2 (Placeholder)
# This script is a stub for the PCRE2 package. Implement actual build steps following LFS guidelines.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
PKG_NAME="pcre2-${PCRE2_VERSION}"
check_built "$PKG_NAME" && exit 0
extract "pcre2"
# Configure, make, install steps go here
./configure --prefix=/usr                       \
            --docdir=/usr/share/doc/pcre2-$PCRE2_VERSION \
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
