#!/bin/bash
# LFS 12.4 - 8.50. Elfutils-0.193
source "/scripts/common.sh"
PKG_NAME="elfutils"
check_built "$PKG_NAME" && exit 0
extract "elfutils"

./configure --prefix=/usr        \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy

make $MAKEFLAGS
make -C libelf install

make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a

cd .. && rm -rf "elfutils-"*
mark_built "$PKG_NAME"
