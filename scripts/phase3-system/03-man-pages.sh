#!/bin/bash
# LFS 12.4 - 8.3. Man-pages-6.15
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="man-pages"
check_built "$PKG_NAME" && exit 0
extract "man-pages"
log "PROCESS" "Installing Man-pages..."
make -R GIT=false prefix=/usr install

cd .. && rm -rf "man-pages-"*
mark_built "$PKG_NAME"
