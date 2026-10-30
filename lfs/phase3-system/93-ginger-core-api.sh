#!/bin/bash
# GingerOS - Install the local-only, read-only core status API.
source "/lfs/lib/common.sh"
PKG_NAME="ginger-core-api"
check_built "$PKG_NAME" && exit 0

log "INFO" "Installing GingerOS local core API..."
install -D -m 0755 /lfs/phase3-system/ginger-core-api.py /usr/bin/ginger-core-api-server
install -D -m 0755 /lfs/phase3-system/ginger-core.py /usr/bin/ginger-core
install -D -m 0644 /lfs/phase3-system/ginger-core-api.service /usr/lib/systemd/system/ginger-core-api.service
systemctl enable ginger-core-api.service

mark_built "$PKG_NAME"
