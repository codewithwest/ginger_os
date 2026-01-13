#!/bin/bash
# LFS 12.4 - 8.15. Flex-2.6.4
source "/scripts/common.sh"
PKG_NAME="flex"
check_built "$PKG_NAME" && exit 0
extract "flex"

./configure --prefix=/usr \
            --docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static
make $MAKEFLAGS
make install

ln -sv flex   /usr/bin/lex
ln -sv flex.1 /usr/share/man/man1/lex.1

cd .. && rm -rf "flex-"*
mark_built "$PKG_NAME"
