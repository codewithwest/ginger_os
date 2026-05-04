#!/bin/bash
# GingerOS - Safety Teardown (Unmount Chroot)
# MUST BE RUN AS ROOT

source "$(dirname "$(readlink -f "$0")")/../../config/env.sh"

log() {
    echo -e "\033[0;33m[UNMOUNT] $1\033[0m"
}

if [ -z "$LFS" ]; then
    echo "LFS variable not set. Cannot unmount."
    exit 1
fi

log "Unmounting virtual kernel file systems from $LFS..."

# Unmount in reverse order
mountpoint -q $LFS/sources && umount -v $LFS/sources
mountpoint -q $LFS/config  && umount -v $LFS/config
mountpoint -q $LFS/scripts && umount -v $LFS/scripts
mountpoint -q $LFS/dev/shm && umount -v $LFS/dev/shm
mountpoint -q $LFS/dev/pts && umount -v $LFS/dev/pts
mountpoint -q $LFS/run     && umount -v $LFS/run
mountpoint -q $LFS/sys     && umount -v $LFS/sys
mountpoint -q $LFS/proc    && umount -v $LFS/proc
mountpoint -q $LFS/dev     && umount -v $LFS/dev
mountpoint -q $LFS/ginger_os && umount -v $LFS/ginger_os

log "Teardown complete."
