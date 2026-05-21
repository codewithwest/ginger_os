#!/bin/bash
# LFS 13.0  - 8.64. Groff-1.23.0
source "/lfs/lib/common.sh"
PKG_NAME="groff"
check_built "$PKG_NAME" && exit 0
extract "groff"

PAGE=A4 ./configure --prefix=/usr

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
