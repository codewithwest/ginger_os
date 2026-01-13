#!/bin/bash
# LFS 12.4 - 8.35. Grep-3.11
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="grep"
check_built "$PKG_NAME" && exit 0
extract "grep"

sed -i "s/echo/#echo/" src/egrep.sh

./configure --prefix=/usr

make $MAKEFLAGS
make install

cd .. && rm -rf "grep-"*
mark_built "$PKG_NAME"
