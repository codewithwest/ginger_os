#!/bin/bash
# LFS 13.0  - 8.25. Acl-2.3.3
source "/lfs/lib/common.sh"
PKG_NAME="acl"
check_built "$PKG_NAME" && exit 0
extract "acl"

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.3.2

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
