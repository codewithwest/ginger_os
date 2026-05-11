#!/bin/bash
# GingerOS - Host Finalization Script
# Runs on the HOST after Phase 4 is complete.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Ensure LFS is set and mounted
if [ -z "${LFS:-}" ] || ! mountpoint -q "$LFS"; then
    log "ERROR" "LFS is not mounted. Cannot proceed with host-side finalization."
    exit 1
fi

log "PROCESS" "Starting host-side finalization of GingerOS..."

# 1. Hardware-Specific Sync (UUIDs)
log "INFO" "Synchronizing partition UUIDs..."
PART_DEV=$(findmnt -n -o SOURCE "$LFS")
PART_UUID=$(blkid -s UUID -o value "$PART_DEV")

if [ -n "$PART_UUID" ]; then
    log "INFO" "Applying Root UUID: $PART_UUID to grub.cfg and fstab"
    sed -i "s|root=/dev/sda1|root=UUID=$PART_UUID|g" "$LFS/boot/grub/grub.cfg"
    sed -i "s|/dev/sda1|UUID=$PART_UUID|g" "$LFS/etc/fstab"
fi

# 2. GRUB MBR Installation
log "INFO" "Installing GRUB to disk image MBR..."
# Locate the base loop device (e.g., /dev/loop0 from /dev/loop0p1)
LOOP_DEV=$(echo "$PART_DEV" | sed 's/p[0-9]*$//')

if [ -n "$LOOP_DEV" ] && [ -b "$LOOP_DEV" ]; then
    log "INFO" "Targeting loop device for bootloader: $LOOP_DEV"
    sudo grub-install --target=i386-pc --boot-directory="$LFS/boot" "$LOOP_DEV"
else
    log "WARN" "Could not determine loop device for MBR installation."
fi

# 3. Save Kernel for ISO creation
log "INFO" "Saving kernel image to project root..."
KERNEL_FILE=$(ls "$LFS/boot/vmlinuz-"* 2>/dev/null | head -n 1)
if [ -n "$KERNEL_FILE" ]; then
    cp -v "$KERNEL_FILE" "${GINGER_ROOT}/vmlinuz-ginger"
fi

# 4. Clean Machine-Specific Data and Temp Logs
log "INFO" "Purging non-essential data (tmp, machine-id, logs)..."
sudo rm -rf "$LFS"/tmp/* "$LFS"/var/tmp/*
sudo rm -f "$LFS"/etc/machine-id "$LFS"/var/lib/dbus/machine-id 2>/dev/null || true
sudo find "$LFS"/var/log -type f -exec truncate -s 0 {} \;
sudo rm -rf "$LFS"/var/cache/* 2>/dev/null || true
# Remove build markers from inside the rootfs but keep them in the state dir
sudo rm -rf "$LFS"/var/lib/ginger/*.built 2>/dev/null || true

# 5. Create Portable RootFS Tarball (Extra-Lean)
OUTPUT_TAR="${GINGER_ROOT}/gingeros-base-rootfs.tar.gz"
log "INFO" "Packaging Extra-Lean root filesystem into $OUTPUT_TAR..."

# We use direct directory exclusions and --warning=no-file-changed
# This is the most robust way to tar a live root.
sudo ln -sv usr/lib/lsb "$LFS/lib/lsb"
sudo ln -sv ../usr/bin/kmod "$LFS/sbin/kmod"

# 2. Tell every boot script to actually use the functions
sudo find "$LFS/etc/rc.d/init.d/" -type f -not -name "README" \
    -exec sed -i '/### END INIT INFO/a \\n. /lib/lsb/init-functions' {} +
    
sudo tar --xattrs --acls --one-file-system \
    --warning=no-file-changed \
    --exclude=./proc/* \
    --exclude=./sys/* \
    --exclude=./dev/* \
    --exclude=./run/* \
    --exclude=./tmp/* \
    --exclude=./sources/* \
    --exclude=./var/cache/* \
    --exclude=./usr/src/* \
    --exclude=./usr/share/doc/* \
    --exclude=./usr/share/man/* \
    --exclude=./tools/* \
    -C "$LFS" -cpzf "$OUTPUT_TAR" . || [ $? -eq 1 ]

log "SUCCESS" "Host-side finalization complete."
log "INFO" "RootFS Tarball: $OUTPUT_TAR"

mark_built "12_finalize"
