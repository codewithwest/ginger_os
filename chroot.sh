#!/bin/bash
# GingerOS - Enter chroot environment
# MUST BE RUN AS ROOT

# Source common functions (which also sources env.sh)
source "$(dirname "$(readlink -f "$0")")/scripts/lib/common.sh"

log "INFO" "Mounting virtual kernel file systems..."
chown --from lfs -R root:root $LFS/{usr,var,etc,tools}
case $(uname -m) in
  x86_64) chown --from lfs -R root:root $LFS/lib64 ;;
esac
mkdir -p $LFS/{dev,proc,sys,run}

# Mount with safety checks
mountpoint -q $LFS/dev || mount -v --bind /dev $LFS/dev
mkdir -p $LFS/dev/pts
mountpoint -q $LFS/dev/pts || mount -v --bind /dev/pts $LFS/dev/pts
mountpoint -q $LFS/proc || mount -vt proc proc $LFS/proc
mountpoint -q $LFS/sys || mount -vt sysfs sysfs $LFS/sys
mountpoint -q $LFS/run || mount -vt tmpfs tmpfs $LFS/run

if [ -h $LFS/dev/shm ]; then
  install -v -d -m 1777 $LFS$(realpath /dev/shm)
else
  mkdir -p $LFS/dev/shm
  mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi

# Ensure scripts, config, and sources are accessible inside chroot
log "INFO" "Mounting project scripts, config, and sources into chroot..."
mkdir -p "$LFS/scripts" "$LFS/config" "$LFS/sources"
mountpoint -q "$LFS/scripts" || mount --bind "$(dirname "$(readlink -f "$0")")/scripts" "$LFS/scripts"
mountpoint -q "$LFS/config"  || mount --bind "$(dirname "$(readlink -f "$0")")/config"  "$LFS/config"
mountpoint -q "$LFS/sources" || mount --bind "$(dirname "$(readlink -f "$0")")/sources" "$LFS/sources"

log "INFO" "Entering chroot..."



# Find the absolute path to chroot to avoid "command not found" issues
# chroot "$LFS" /usr/bin/env -i   \
#     HOME=/root                  \
#     TERM="$TERM"                \
#     PS1='(lfs chroot) \u:\w\$ ' \
#     PATH=/usr/bin:/usr/sbin     \
#     MAKEFLAGS="-j$(nproc)"      \
#     TESTSUITEFLAGS="-j$(nproc)" \
#     /bin/bash --login

# # Determine if we are running in interactive mode or executing a script
# if [ $# -gt 0 ]; then
#     log "INFO" "Executing command inside chroot: $@"
#     chroot "$LFS" /usr/bin/env -i   \
#         HOME=/root                  \
#         TERM="$TERM"                \
#         PATH=/usr/bin:/usr/sbin     \
#         /bin/bash -c "$@"
# else
#     log "INFO" "Entering interactive chroot..."
#     chroot "$LFS" /usr/bin/env -i   \
#         HOME=/root                  \
#         TERM="$TERM"                \
#         PS1='(ginger-chroot) \u:\w\$ '  \
#         PATH=/usr/bin:/usr/sbin     \
#         /bin/bash --login
# fi