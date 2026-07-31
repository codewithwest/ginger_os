#!/bin/bash
source "/lfs/lib/common.sh"
PKG_NAME="elfutils"
check_built "$PKG_NAME" && exit 0
extract "elfutils"

# LFS 13.0: Build only libelf, not the full package (avoids broken riscv_disasm)
./configure --prefix=/usr        \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy

make -C lib
make -C libelf
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a

cleanup
mark_built "$PKG_NAME"
