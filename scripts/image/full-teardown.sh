#!/bin/bash
# GingerOS - Full Teardown
# Unmounts ALL /mnt/lfs mounts (bind mounts, root, and loop device)
# MUST BE RUN AS ROOT

set -euo pipefail

LFS="${LFS:-/mnt/lfs}"

log() { echo -e "\033[0;33m[TEARDOWN] $1\033[0m"; }
ok()  { echo -e "\033[0;32m[TEARDOWN] $1\033[0m"; }
err() { echo -e "\033[0;31m[TEARDOWN] $1\033[0m"; }

if [ "$(id -u)" -ne 0 ]; then
    err "Must be run as root (use sudo)"
    exit 1
fi

if ! mountpoint -q "$LFS" 2>/dev/null; then
    log "$LFS is not mounted — nothing to do."
    exit 0
fi

log "Unmounting virtual kernel filesystems from $LFS..."

# Unmount in strict reverse dependency order
safe_umount() {
    local MNT="$1"
    if mountpoint -q "$MNT" 2>/dev/null; then
        umount -v "$MNT" && ok "Unmounted $MNT" || err "Failed to unmount $MNT (busy?)"
    fi
}

safe_umount "$LFS/dev/shm"
safe_umount "$LFS/dev/pts"
safe_umount "$LFS/dev"
safe_umount "$LFS/proc"
safe_umount "$LFS/sys"
safe_umount "$LFS/run"
safe_umount "$LFS/sources"
safe_umount "$LFS/scripts"
safe_umount "$LFS/config"
safe_umount "$LFS/ginger_os"

log "Unmounting $LFS root filesystem..."
# Find the loop device backing this mount before unmounting
LOOP_DEV=$(losetup -j "$(findmnt -n -o SOURCE --target "$LFS" 2>/dev/null)" 2>/dev/null | cut -d: -f1 || true)
if [ -z "$LOOP_DEV" ]; then
    # Try finding via /proc/mounts directly
    LOOP_DEV=$(awk -v mp="$LFS" '$2 == mp {print $1}' /proc/mounts | grep loop | head -1 || true)
fi

umount -v "$LFS" && ok "Unmounted $LFS"

# Detach the loop device (only the one that was used for /mnt/lfs)
if [ -n "$LOOP_DEV" ]; then
    log "Detaching loop device: $LOOP_DEV"
    losetup -d "$LOOP_DEV" 2>/dev/null && ok "Detached $LOOP_DEV" || err "Could not detach $LOOP_DEV (may already be gone)"
else
    log "No GingerOS loop device found to detach (snap loops left untouched)."
fi

ok "Full teardown complete."
