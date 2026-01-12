#!/bin/bash
# LFS 12.4 - 8.50. Elfutils-0.193 (Libelf)
source "/scripts/common.sh"
PKG_NAME="elfutils"
ARCHIVE="elfutils-0.193.tar.bz2"
DIR_NAME="elfutils-0.193"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr                \
            --disable-debuginfod         \
            --enable-libdebuginfod=dummy
make $MAKEFLAGS
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
