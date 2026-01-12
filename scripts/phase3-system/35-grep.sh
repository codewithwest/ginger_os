#!/bin/bash
# LFS 12.4 - 8.35. Grep-3.12
source "/scripts/common.sh"
PKG_NAME="grep"
ARCHIVE="grep-3.12.tar.xz"
DIR_NAME="grep-3.12"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i "s/echo/& -e/" tests/unibyte-bracket-expr
sed -i "s/echo/& -e/" tests/instantiate-any-queries
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
