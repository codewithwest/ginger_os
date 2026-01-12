#!/bin/bash
# LFS 12.4 - 8.68. Kbd-2.8.0
source "/scripts/common.sh"
PKG_NAME="kbd"
ARCHIVE="kbd-2.8.0.tar.xz"
DIR_NAME="kbd-2.8.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
patch -Np1 -i /sources/kbd-2.8.0-backspace-1.patch
sed -i 's/\(RU .*\)7/\1/' data/keymaps/i386/qwerty/ru.map
./configure --prefix=/usr --disable-vlock
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
