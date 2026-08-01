#!/bin/bash
# LFS 13.0  - 8.32. Psmisc-23.8
source "/lfs/lib/common.sh"
PKG_NAME="psmisc"
check_built "$PKG_NAME" && exit 0
extract "psmisc"

./configure --prefix=/usr
make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
