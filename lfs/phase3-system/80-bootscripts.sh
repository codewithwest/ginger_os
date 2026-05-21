#!/bin/bash
# LFS 13.0  - 8.80. LFS-Bootscripts-20250827
source "/lfs/lib/common.sh"
PKG_NAME="bootscripts"
check_built "$PKG_NAME" && exit 0
extract "lfs-bootscripts"
make install
cleanup
mark_built "$PKG_NAME"
