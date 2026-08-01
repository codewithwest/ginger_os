#!/bin/bash
# GingerOS - Safety Teardown (Unmount Chroot)
# MUST BE RUN AS ROOT

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"

log() {
    echo -e "\033[0;33m[UNMOUNT] $1\033[0m"
}

if [ -z "$LFS" ]; then
    echo "LFS variable not set. Cannot unmount."
    exit 1
fi

log "Unmounting virtual kernel file systems from $LFS..."

# Unmount in reverse order
grep -q "$LFS/sources " /proc/mounts && umount -v $LFS/sources
grep -q "$LFS/config " /proc/mounts && umount -v $LFS/config
grep -q "$LFS/lfs " /proc/mounts && umount -v $LFS/lfs
grep -q "$LFS/scripts " /proc/mounts && umount -v $LFS/scripts
grep -q "$LFS/dev/shm " /proc/mounts && umount -v $LFS/dev/shm
grep -q "$LFS/dev/pts " /proc/mounts && umount -v $LFS/dev/pts
grep -q "$LFS/run " /proc/mounts && umount -v $LFS/run
grep -q "$LFS/sys " /proc/mounts && umount -v $LFS/sys
grep -q "$LFS/proc " /proc/mounts && umount -v $LFS/proc
grep -q "$LFS/dev " /proc/mounts && umount -v $LFS/dev
grep -q "$LFS/ginger_os " /proc/mounts && umount -v $LFS/ginger_os

log "Teardown complete."

mark_built "13_teardown"
