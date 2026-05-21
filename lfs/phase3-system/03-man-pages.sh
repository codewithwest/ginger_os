#!/bin/bash
# LFS 13.0  - 8.3. Man-pages-6.15
source "/lfs/lib/common.sh"
PKG_NAME="man-pages"
check_built "$PKG_NAME" && exit 0
extract "man-pages"

log "PROCESS" "Installing Man-pages..."

rm -v man3/crypt*

make -R GIT=false prefix=/usr install

cleanup
mark_built "$PKG_NAME"
