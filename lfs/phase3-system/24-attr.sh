#!/bin/bash
# LFS 13.0  - 8.24. Attr-2.5.2
source "/lfs/lib/common.sh"
PKG_NAME="attr"
check_built "$PKG_NAME" && exit 0
extract "attr"

./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-${ATTR_VERSION}

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
