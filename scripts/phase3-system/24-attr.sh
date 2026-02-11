#!/bin/bash
# LFS 12.4 - 8.24. Attr-2.5.2
source "/scripts/lib/common.sh"
PKG_NAME="attr"
check_built "$PKG_NAME" && exit 0
extract "attr"

./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.5.2

make $MAKEFLAGS
make install

cd .. && rm -rf "attr-"*
mark_built "$PKG_NAME"
