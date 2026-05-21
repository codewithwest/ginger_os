#!/bin/bash
# LFS 13.0  - 5.4. Linux-6.16.1 Headers
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

PKG_NAME="linux-headers"
check_built "$PKG_NAME" && exit 0

extract "linux"

log "PROCESS" "Installing Linux Headers..."
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr

cd ..
cleanup

mark_built "$PKG_NAME"
