#!/bin/bash
# LFS 12.4 - 8.80. LFS-Bootscripts-20250827
source "/scripts/common.sh"
PKG_NAME="bootscripts"
check_built "$PKG_NAME" && exit 0
extract "lfs-bootscripts"
make install
cd .. && rm -rf "lfs-bootscripts-"*
mark_built "$PKG_NAME"
