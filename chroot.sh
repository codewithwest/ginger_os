#!/bin/bash
# GingerOS - Enter chroot environment
# MUST BE RUN AS ROOT

source "$(dirname "$(readlink -f "$0")")/config/env.sh"

log "INFO" "Mounting virtual kernel file systems..."
mkdir -p $LFS/{dev,proc,sys,run}

mount -v --bind /dev $LFS/dev
mount -v --bind /dev/pts $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run

if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
else
  mount -vt tmpfs shm $LFS/dev/shm
fi

log "INFO" "Entering chroot..."
chroot "$LFS" /usr/bin/env -i \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(ginger-chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    /bin/bash --login
