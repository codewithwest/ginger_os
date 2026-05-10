#!/bin/bash
# LFS 12.4 - 8.4. Iana-Etc-20250807
source "/lfs/lib/common.sh"
PKG_NAME="iana-etc"
check_built "$PKG_NAME" && exit 0
extract "iana-etc"
log "PROCESS" "Installing Iana-Etc..."

cp -v services protocols /etc

cleanup
mark_built "$PKG_NAME"
