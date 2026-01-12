#!/bin/bash
# LFS 12.4 - 8.15. Flex-2.6.4
source "/scripts/common.sh"
PKG_NAME="flex"
ARCHIVE="flex-2.6.4.tar.gz"
DIR_NAME="flex-2.6.4"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr \
            --docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static
make $MAKEFLAGS
make install
ln -sv flex /usr/bin/lex
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
