#!/bin/bash
# GingerOS - Professional System Installer
# This script deploys the GingerOS RootFS tarball to a physical disk.
# Usage: sudo ./installer.sh /dev/sdX

set -euo pipefail

# Colors for UI
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INSTALLER]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

TARGET_DEV="${1:-}"

if [ -z "$TARGET_DEV" ]; then
    echo "Usage: sudo $0 /dev/sdX"
    echo "Available disks:"
    lsblk -d -n -p -o NAME,SIZE,MODEL
    exit 1
fi

if [ ! -b "$TARGET_DEV" ]; then
    error "Device $TARGET_DEV is not a valid block device."
fi

# 1. Safety Warning
echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
echo -e "${RED}  WARNING: ALL DATA ON $TARGET_DEV WILL BE WIPED!  ${NC}"
echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
read -p "Are you absolutely sure you want to proceed? (type 'yes'): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    log "Installation cancelled."
    exit 0
fi

# 2. Preparation
TARBALL="gingeros-base-rootfs.tar.gz"
if [ ! -f "$TARBALL" ]; then
    # Try to find it in the current directory or parent
    TARBALL=$(find . -name "gingeros-base-rootfs.tar.gz" | head -n 1)
    [ -z "$TARBALL" ] && error "Could not find $TARBALL. Please run the build first."
fi

log "Preparing $TARGET_DEV..."
# Clean existing partition table
sudo wipefs -a "$TARGET_DEV"

# 3. Partitioning (MBR/Legacy for compatibility)
log "Partitioning $TARGET_DEV..."
sudo parted -s "$TARGET_DEV" mklabel msdos
sudo parted -s "$TARGET_DEV" mkpart primary ext4 1MiB 100%
sudo parted -s "$TARGET_DEV" set 1 boot on

# Wait for kernel to update partition table
sleep 2
PART="${TARGET_DEV}1"
# Handle NVMe naming (e.g. /dev/nvme0n1p1)
if [[ "$TARGET_DEV" == *"nvme"* ]] || [[ "$TARGET_DEV" == *"mmcblk"* ]]; then
    PART="${TARGET_DEV}p1"
fi

# 4. Formatting
log "Formatting $PART as ext4..."
sudo mkfs.ext4 -F "$PART"

# 5. Deployment
MNT="/mnt/gingeros_install"
sudo mkdir -p "$MNT"
log "Mounting $PART to $MNT..."
sudo mount "$PART" "$MNT"

log "Extracting GingerOS RootFS (this may take a few minutes)..."
sudo tar --xattrs --acls -C "$MNT" -xpf "$TARBALL"

# 6. Hardware-Specific Configuration (The critical part!)
log "Configuring hardware-specific settings..."

# Generate new UUID for the destination disk
NEW_UUID=$(blkid -s UUID -o value "$PART")
log "New Root UUID: $NEW_UUID"

# Update fstab
cat << EOF | sudo tee "$MNT/etc/fstab"
# /etc/fstab: static file system information.
UUID=$NEW_UUID      /               ext4    defaults        1       1
proc           /proc           proc    nosuid,noexec,nodev 0       0
sysfs          /sys            sysfs   nosuid,noexec,nodev 0       0
devpts         /dev/pts        devpts  gid=5,mode=620      0       0
tmpfs          /run            tmpfs   defaults            0       0
EOF

# Update GRUB Config with the NEW UUID
sudo mkdir -p "$MNT/boot/grub"
# We find the kernel name dynamically
KERNEL_IMG=$(ls "$MNT/boot/vmlinuz-"* | head -n 1 | xargs basename)

cat << EOF | sudo tee "$MNT/boot/grub/grub.cfg"
set default=0
set timeout=5
insmod part_msdos
insmod ext2
search --no-floppy --fs-uuid --set=root $NEW_UUID
menuentry 'GingerOS (Installed)' {
    linux /boot/$KERNEL_IMG root=UUID=$NEW_UUID rw console=tty0
}
EOF

# 7. Bootloader Installation
log "Installing GRUB bootloader to $TARGET_DEV..."
# We must mount virtual filesystems to install GRUB correctly from the host
sudo mount --bind /dev "$MNT/dev"
sudo mount --bind /proc "$MNT/proc"
sudo mount --bind /sys "$MNT/sys"

# Use chroot to install grub to the target disk's MBR
sudo chroot "$MNT" grub-install --target=i386-pc "$TARGET_DEV"

# 8. Cleanup
log "Cleaning up..."
sudo umount "$MNT/dev" "$MNT/proc" "$MNT/sys"
sudo umount "$MNT"
sudo rm -rf "$MNT"

log "${GREEN}SUCCESS!${NC} GingerOS has been installed to $TARGET_DEV."
log "You can now reboot and unplug the installation medium."
