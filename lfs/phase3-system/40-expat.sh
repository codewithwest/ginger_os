#!/bin/bash
# LFS 13.0  - 8.40. Expat-2.7.1
source "/lfs/lib/common.sh"
PKG_NAME="expat"
check_built "$PKG_NAME" && exit 0
extract "expat"

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.7.1

make $MAKEFLAGS
make install

install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.1

cleanup
mark_built "$PKG_NAME"
