#!/bin/bash
# LFS 13.0 - 8.84. SysVinit-3.14
# This build uses the systemd branch and does not install SysVinit.
source "/lfs/lib/common.sh"
PKG_NAME="sysvinit"
check_built "$PKG_NAME" && exit 0

log "INFO" "Skipping SysVinit installation on systemd-enabled GingerOS."
mark_built "$PKG_NAME"
