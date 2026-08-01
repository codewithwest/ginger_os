#!/bin/bash
# LFS 13.0  - 8.11. File-5.46
source "/lfs/lib/common.sh"
PKG_NAME="file-final"

check_built "$PKG_NAME" && exit 0

extract "file"

./configure --prefix=/usr

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
