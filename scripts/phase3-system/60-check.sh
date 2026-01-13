#!/bin/bash
# LFS 12.4 - 8.60. Check-0.15.2
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="check"
check_built "$PKG_NAME" && exit 0
extract "check"
./configure --prefix=/usr --disable-static
make $MAKEFLAGS
make install
cd .. && rm -rf "check-"*
mark_built "$PKG_NAME"
