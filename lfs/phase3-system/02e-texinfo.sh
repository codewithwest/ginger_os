#!/bin/bash
# LFS 12.4 - 7.11. Texinfo-7.2 (Temporary)
source "/lfs/lib/common.sh"
PKG_NAME="texinfo-bridge"
check_built "$PKG_NAME" && exit 0
extract "texinfo"

./configure --prefix=/usr

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
