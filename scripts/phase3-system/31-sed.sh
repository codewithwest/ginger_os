#!/bin/bash
# LFS 12.4 - 8.31. Sed-4.9
source "/scripts/common.sh"
PKG_NAME="sed"
ARCHIVE="sed-4.9.tar.xz"
DIR_NAME="sed-4.9"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
install -d -m755 /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
