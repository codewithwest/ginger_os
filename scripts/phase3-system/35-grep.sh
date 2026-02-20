#!/bin/bash
# LFS 12.4 - 8.35. Grep-3.11
source "/scripts/lib/common.sh"
PKG_NAME="grep"
check_built "$PKG_NAME" && exit 0
extract "grep"

sed -i "s/echo/#echo/" src/egrep.sh

./configure --prefix=/usr

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
