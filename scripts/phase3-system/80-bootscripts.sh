#!/bin/bash
# LFS 12.2 - 7.2. LFS-Bootscripts-20240825
# Scripts to handle system startup/shutdown with SysVinit.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="lfs-bootscripts"
ARCHIVE="lfs-bootscripts-20250827.tar.xz"
DIR_NAME="lfs-bootscripts-20250827"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Installing LFS Bootscripts..."
make install

cd ..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
