#!/bin/bash
# LFS 12.4 - 8.32. Psmisc-23.8
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="psmisc"
check_built "$PKG_NAME" && exit 0
extract "psmisc"

./configure --prefix=/usr
make $MAKEFLAGS
make install

cd .. && rm -rf "psmisc-"*
mark_built "$PKG_NAME"
