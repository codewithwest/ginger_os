#!/bin/bash
# LFS 12.4 - 8.25. Acl-2.3.3
source "/scripts/common.sh"
PKG_NAME="acl"
check_built "$PKG_NAME" && exit 0
extract "acl"

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.3.2

make $MAKEFLAGS
make install

cd .. && rm -rf "acl-"*
mark_built "$PKG_NAME"
