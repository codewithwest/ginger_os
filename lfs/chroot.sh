#!/bin/bash
# GingerOS - Enter chroot environment
# MUST BE RUN AS ROOT

# Source common functions (which also sources env.sh)
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"


log "INFO" "Mounting virtual kernel file systems..."
mkdir -p $LFS/{dev,proc,sys,run}

# Mount with safety checks (use grep on /proc/mounts instead of mountpoint command)
mkdir -p $LFS/etc
[ -f /etc/resolv.conf ] && rm -f $LFS/etc/resolv.conf && cp -v /etc/resolv.conf $LFS/etc/
grep -q "$LFS/dev " /proc/mounts || mount -v --bind /dev $LFS/dev
grep -q "$LFS/dev/pts " /proc/mounts || mount -v --bind /dev/pts $LFS/dev/pts
grep -q "$LFS/proc " /proc/mounts || mount -vt proc proc $LFS/proc
grep -q "$LFS/sys " /proc/mounts || mount -vt sysfs sysfs $LFS/sys
grep -q "$LFS/run " /proc/mounts || mount -vt tmpfs tmpfs $LFS/run

if [ -h $LFS/dev/shm ]; then
  install -v -d -m 1777 $LFS$(realpath /dev/shm)
else
  grep -q "$LFS/dev/shm " /proc/mounts || mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi

# Ensure lfs, config, and sources are accessible inside chroot
log "INFO" "Mounting project lfs, config, and sources into chroot..."
mkdir -p "$LFS/lfs" "$LFS/config" "$LFS/sources"
grep -q "$LFS/lfs " /proc/mounts || mount --bind "$GINGER_SCRIPTS" "$LFS/lfs"
grep -q "$LFS/config " /proc/mounts || mount --bind "$GINGER_ROOT/config"  "$LFS/config"
grep -q "$LFS/sources " /proc/mounts || mount --bind "$GINGER_SOURCES" "$LFS/sources"

log "INFO" "Entering chroot..."

# Mask Ubuntu multi-arch directories to prevent version leakage
# This is a more aggressive fix for the 'symbol lookup error'
MASKED_DIRS=()
for dir in "lib/x86_64-linux-gnu" "usr/lib/x86_64-linux-gnu"; do
    TARGET_DIR="${LFS}/${dir}"
    if [ -d "$TARGET_DIR" ]; then
        log "INFO" "Masking Ubuntu library directory: $TARGET_DIR"
        mv -v "$TARGET_DIR" "${TARGET_DIR}.masked" || log "ERROR" "Failed to move $TARGET_DIR"
        MASKED_DIRS+=("$dir")
    else
        log "INFO" "Directory not found (skipping mask): $TARGET_DIR"
    fi
done

# Ensure we restore the directories on exit
cleanup() {
    for dir in "${MASKED_DIRS[@]}"; do
        if [ -d "$LFS/${dir}.masked" ]; then
            log "INFO" "Restoring Ubuntu library directory: /$dir"
            mv "$LFS/${dir}.masked" "$LFS/$dir"
        fi
    done
    
    # Also restore the ld.so.conf.d file if it was backed up
    if [ -f "$LFS/etc/ld.so.conf.d/x86_64-linux-gnu.conf.bak" ]; then
        mv "$LFS/etc/ld.so.conf.d/x86_64-linux-gnu.conf.bak" "$LFS/etc/ld.so.conf.d/x86_64-linux-gnu.conf"
    fi
}
trap cleanup EXIT

# Fix liblzma symlink if newer version was built in phase 3
# (Note: we use the .masked path if we just moved it)
LZMA_TARGET="$LFS/lib/x86_64-linux-gnu/liblzma.so.5"
[ -d "$LFS/lib/x86_64-linux-gnu.masked" ] && LZMA_TARGET="$LFS/lib/x86_64-linux-gnu.masked/liblzma.so.5"

if [ -f "$LFS/usr/lib/liblzma.so.5" ] && [ -d "$(dirname "$LZMA_TARGET")" ]; then
    log "INFO" "Ensuring xz uses the correct liblzma..."
    ln -sfv /usr/lib/liblzma.so.5 "$LZMA_TARGET"
fi

# Execute command or shell
if [[ "${1:-}" == "--mount-only" ]]; then
    log "INFO" "Mounts set up. Exiting without entering chroot."
elif [[ -n "${1:-}" ]]; then
    log "INFO" "Executing command in chroot: $@"
    chroot "$LFS" /usr/bin/env -i   \
        HOME=/root                  \
        TERM="$TERM"                \
        PATH=/usr/bin:/usr/sbin     \
        /bin/bash "$@"
else
    log "INFO" "Entering interactive chroot shell..."
    chroot "$LFS" /usr/bin/env -i   \
        HOME=/root                  \
        TERM="$TERM"                \
        PS1='(ginger-chroot) \u:\w\$ '  \
        PATH=/usr/bin:/usr/sbin     \
        /bin/bash --login
fi

log "INFO" "Chroot phase complete."
if [[ "${MOUNT_ONLY:-false}" == "true" ]]; then
    mark_built "09_chroot_mounts"
fi

