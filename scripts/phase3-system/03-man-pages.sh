#!/bin/bash
# LFS 12.4 - 8.3. Man-pages-6.15
# These are the standard manual pages for Linux.

source "/scripts/common.sh"

PKG_NAME="man-pages"
ARCHIVE="man-pages-6.15.tar.xz"
DIR_NAME="man-pages-6.15"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Installing Man-pages..."
rm -v man3/getspnam.3
make prefix=/usr install

cd ..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
