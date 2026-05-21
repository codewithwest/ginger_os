#!/bin/bash
# LFS 13.0  - 8.84. SysVinit-3.14
source "/lfs/lib/common.sh"
PKG_NAME="sysvinit"
check_built "$PKG_NAME" && exit 0
extract "sysvinit"

# Apply patch if present
apply_patch "sysvinit" "consolidated"

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
