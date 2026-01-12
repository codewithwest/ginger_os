#!/bin/bash
# LFS 12.4 - 8.12. Readline-8.3
source "/scripts/common.sh"
PKG_NAME="readline"
ARCHIVE="readline-8.3.tar.gz"
DIR_NAME="readline-8.3"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
sed -i '/RPATH/s/^/#/' support/shlib-install
./configure --prefix=/usr    \
            --disable-static \
            --with-curses    \
            --docdir=/usr/share/doc/readline-8.3
make SHLIB_LIBS="-lncursesw" $MAKEFLAGS
make SHLIB_LIBS="-lncursesw" install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
