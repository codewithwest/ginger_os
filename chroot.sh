#!/bin/bash
# GingerOS - Enter chroot environment
# MUST BE RUN AS ROOT

# Source common functions (which also sources env.sh)
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"

log "INFO" "Mounting virtual kernel file systems..."
mkdir -p $LFS/{dev,proc,sys,run}

# Mount with safety checks
mountpoint -q $LFS/dev || mount -v --bind /dev $LFS/dev
mountpoint -q $LFS/dev/pts || mount -v --bind /dev/pts $LFS/dev/pts
mountpoint -q $LFS/proc || mount -vt proc proc $LFS/proc
mountpoint -q $LFS/sys || mount -vt sysfs sysfs $LFS/sys
mountpoint -q $LFS/run || mount -vt tmpfs tmpfs $LFS/run

if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
else
  mountpoint -q $LFS/dev/shm || mount -vt tmpfs shm $LFS/dev/shm
fi

# Ensure scripts and config are accessible inside chroot
log "INFO" "Mounting project scripts and config into chroot..."
mkdir -p "$LFS/scripts" "$LFS/config"
mountpoint -q "$LFS/scripts" || mount --bind "$(dirname "$(readlink -f "$0")")/scripts" "$LFS/scripts"
mountpoint -q "$LFS/config"  || mount --bind "$(dirname "$(readlink -f "$0")")/config"  "$LFS/config"

log "INFO" "Entering chroot..."

# Find the absolute path to chroot to avoid "command not found" issues
CHROOT_BIN=$(command -v chroot || echo "/usr/sbin/chroot")

# Determine if we are running in interactive mode or executing a script
if [ $# -gt 0 ]; then
    log "INFO" "Executing command inside chroot: $@"
    $CHROOT_BIN "$LFS" /usr/bin/env -i   \
        HOME=/root                      \
        TERM="$TERM"                    \
        PATH=/usr/bin:/usr/sbin         \
        /usr/bin/bash -c "$@"
else
    $CHROOT_BIN "$LFS" /usr/bin/env -i   \
        HOME=/root                      \
        TERM="$TERM"                    \
        PS1='(ginger-chroot) \u:\w\$ '  \
        PATH=/usr/bin:/usr/sbin         \
        /usr/bin/bash --login
fi
