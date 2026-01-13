#!/bin/bash
# GingerOS - Final System cleanup
source "/scripts/../common.sh"
log "INFO" "Cleaning up system..."
rm -rf /tmp/*
# Remove static libraries if any remain
rm -f /usr/lib/*.a
# Strip debug symbols from binaries to save space (Standard LFS)
find /usr/lib /usr/bin /usr/sbin -type f \
    $(printf '! -name %q ' ld-linux-x86-64.so.2 libc.so.6 libpthread.so.0) \
    -exec strip --strip-debug {} ';'
log "INFO" "System ready."
