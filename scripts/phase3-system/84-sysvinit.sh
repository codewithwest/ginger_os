#!/bin/bash
# LFS 12.4 - 8.84. SysVinit-3.14
source "/scripts/common.sh"
PKG_NAME="sysvinit"
check_built "$PKG_NAME" && exit 0
extract "sysvinit"

# Apply patch if present
patch -Np1 -i /sources/sysvinit-3.14-consolidated-1.patch

make $MAKEFLAGS
make install

cd .. && rm -rf "sysvinit-"*
mark_built "$PKG_NAME"
