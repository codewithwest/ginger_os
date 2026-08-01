#!/bin/bash
# GingerOS - Final System cleanup
source "/lfs/lib/common.sh"
log "INFO" "Cleaning up system..."

rm -rf /tmp/{*,.*}

find /usr/lib /usr/libexec -name \*.la -delete

find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
