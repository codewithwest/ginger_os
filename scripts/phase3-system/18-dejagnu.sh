#!/bin/bash
# LFS 12.4 - 8.18. DejaGNU-1.6.3
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="dejagnu"
check_built "$PKG_NAME" && exit 0
extract "dejagnu"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "dejagnu-"*
mark_built "$PKG_NAME"
