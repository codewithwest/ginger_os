#!/bin/bash
# GingerOS - Enter chroot environment
# MUST BE RUN AS ROOT

# Source common functions (which also sources env.sh)
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"


log "INFO" "Mounting virtual kernel file systems..."
mkdir -p $LFS/{dev,proc,sys,run}

# Mount with safety checks
mkdir -p $LFS/etc
[ -f /etc/resolv.conf ] && rm -f $LFS/etc/resolv.conf && cp -v /etc/resolv.conf $LFS/etc/
mountpoint -q $LFS/dev || mount -v --bind /dev $LFS/dev
mountpoint -q $LFS/dev/pts || mount -v --bind /dev/pts $LFS/dev/pts
mountpoint -q $LFS/proc || mount -vt proc proc $LFS/proc
mountpoint -q $LFS/sys || mount -vt sysfs sysfs $LFS/sys
mountpoint -q $LFS/run || mount -vt tmpfs tmpfs $LFS/run

if [ -h $LFS/dev/shm ]; then
  install -v -d -m 1777 $LFS$(realpath /dev/shm)
else
  mountpoint -q $LFS/dev/shm || mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi

# Ensure scripts, config, and sources are accessible inside chroot
log "INFO" "Mounting project scripts, config, and sources into chroot..."
mkdir -p "$LFS/scripts" "$LFS/config" "$LFS/sources"
mountpoint -q "$LFS/scripts" || mount --bind "$GINGER_SCRIPTS" "$LFS/scripts"
mountpoint -q "$LFS/config"  || mount --bind "$GINGER_ROOT/config"  "$LFS/config"
mountpoint -q "$LFS/sources" || mount --bind "$GINGER_SOURCES" "$LFS/sources"

log "INFO" "Entering chroot..."

# Fix liblzma symlink if newer version was built in phase 3
# This ensures xz can decompress .tar.xz sources inside the chroot
if [ -f "$LFS/usr/lib/liblzma.so.5" ] && [ -d "$LFS/lib/x86_64-linux-gnu" ]; then
    log "INFO" "Ensuring xz uses the correct liblzma from /usr/lib..."
    ln -sfv /usr/lib/liblzma.so.5 "$LFS/lib/x86_64-linux-gnu/liblzma.so.5"
fi

# If we are running in the UI (where it just needs mounts), it can exit here.
# But if a user runs this manually, we want to drop them into the shell.
if [[ "${1:-}" != "--mount-only" ]]; then
    chroot "$LFS" /usr/bin/env -i   \
        HOME=/root                  \
        TERM="$TERM"                \
        PS1='(ginger-chroot) \u:\w\$ '  \
        PATH=/usr/bin:/usr/sbin     \
        /bin/bash --login
fi