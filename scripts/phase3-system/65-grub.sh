#!/bin/bash
# LFS 12.4 - 8.65. GRUB-2.12
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="grub"
check_built "$PKG_NAME" && exit 0
extract "grub"
unset {C,CPP,CXX,LD}FLAGS
echo "DEPENDENCIES_CHECK = " > grub-core/Makefile.gc
./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror
make $MAKEFLAGS
make install
cd .. && rm -rf "grub-"*
mark_built "$PKG_NAME"
