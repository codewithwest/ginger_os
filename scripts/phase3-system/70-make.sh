#!/bin/bash
# LFS 12.4 - 8.70. Make-4.4.1
source "/scripts/common.sh"
PKG_NAME="make-final"
ARCHIVE="make-4.4.1.tar.gz"
DIR_NAME="make-4.4.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
# Fix to support glibc-2.42
sed -i 's/posix_spawn_file_actions_addchdir_np/posix_spawn_file_actions_addchdir/' configure
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
