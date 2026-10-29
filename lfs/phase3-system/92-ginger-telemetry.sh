#!/bin/bash
# GingerOS - Install the dependency-free read-only telemetry CLI.
source "/lfs/lib/common.sh"
PKG_NAME="ginger-telemetry"
check_built "$PKG_NAME" && exit 0

log "INFO" "Installing GingerOS telemetry CLI..."
install -D -m 0755 /lfs/phase3-system/ginger-telemetry.py /usr/bin/ginger-telemetry

mark_built "$PKG_NAME"
