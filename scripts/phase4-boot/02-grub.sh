#!/bin/bash
# GingerOS - Bootloader and System Finalization
# 1. Configures GRUB inside the system
2. # 2. Installs GRUB to the disk image MBR
3. # 3. Creates a portable rootfs tarball

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Ensure LFS is set and mounted
if [ -z "${LFS:-}" ] || ! mountpoint -q "$LFS"; then
    log "ERROR" "LFS is not mounted. Cannot finalize."
    exit 1
fi

log "PROCESS" "Starting finalization of GingerOS..."

# ---------------------------------------------------------------------
# Step 1 — Clean temp files and machine-specific data
# ---------------------------------------------------------------------
log "INFO" "Cleaning temporary files in $LFS..."
rm -rf "$LFS"/tmp/*
rm -rf "$LFS"/var/tmp/*
find "$LFS"/var/log -type f -exec truncate -s 0 {} \;
rm -f "$LFS"/etc/ssh/ssh_host_* 2>/dev/null || true
rm -f "$LFS"/etc/machine-id 2>/dev/null || true
rm -f "$LFS"/root/.bash_history

# ---------------------------------------------------------------------
# Step 2 — Configuration (Users and Passwords)
# ---------------------------------------------------------------------
log "INFO" "Setting up default accounts..."
sudo chroot "$LFS" /bin/bash -c "
set -e
echo 'root:root' | chpasswd

if ! id ginger >/dev/null 2>&1; then
    groupadd -f ginger
    useradd -m -g ginger -s /bin/bash ginger 2>/dev/null || true
    echo 'ginger:ginger' | chpasswd
fi
"

# ---------------------------------------------------------------------
# Step 3 — FSTAB Generation
# ---------------------------------------------------------------------
log "INFO" "Generating /etc/fstab..."

# Inside the build VM, we can determine the UUID of the partition
# We find the device currently mounted to $LFS
PART_DEV=$(findmnt -n -o SOURCE "$LFS")
PART_UUID=$(blkid -s UUID -o value "$PART_DEV")

if [ -n "$PART_UUID" ]; then
    log "INFO" "Detected Root UUID: $PART_UUID"
    cat > "$LFS"/etc/fstab << EOF
# /etc/fstab: static file system information.
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
UUID=$PART_UUID      /               ext4    defaults        1       1
EOF
else
    log "WARN" "Could not determine UUID for $PART_DEV. Using generic fallback."
    cat > "$LFS"/etc/fstab << EOF
# /etc/fstab: static file system information.
/dev/sda1      /               ext4    defaults        1       1
EOF
fi

# Add virtual filesystems to fstab
cat >> "$LFS"/etc/fstab << EOF
proc           /proc           proc    nosuid,noexec,nodev 0       0
sysfs          /sys            sysfs   nosuid,noexec,nodev 0       0
devpts         /dev/pts        devpts  gid=5,mode=620      0       0
tmpfs          /run            tmpfs   defaults            0       0
devtmpfs       /dev            devtmpfs mode=0755,nosuid    0       0
EOF

# ---------------------------------------------------------------------
# Step 4 — GRUB Configuration
# ---------------------------------------------------------------------
log "INFO" "Creating hardware-agnostic GRUB configuration..."
mkdir -p "$LFS"/boot/grub

# We use the same UUID for the kernel command line
if [ -n "$PART_UUID" ]; then
    ROOT_PARAM="root=UUID=$PART_UUID"
else
    ROOT_PARAM="root=/dev/sda1"
fi

cat > "$LFS"/boot/grub/grub.cfg << GRUB_EOF
set default=0
set timeout=5

insmod part_msdos
insmod ext2

# Try to find the drive by UUID (more compatible)
search --no-floppy --fs-uuid --set=root $PART_UUID

menuentry 'GingerOS (LFS 12.4)' {
    linux /boot/vmlinuz-6.16.1-lfs-12.4 $ROOT_PARAM rw console=tty0
}
GRUB_EOF

# ---------------------------------------------------------------------
# Step 5 — Install GRUB to Image MBR
# ---------------------------------------------------------------------
IMAGE_PATH="${GINGER_ROOT}/ginger_os.img"
if [ -f "$IMAGE_PATH" ]; then
    log "INFO" "Installing GRUB to disk image MBR..."
    
    # Locate the base loop device (e.g., /dev/loop0 from /dev/loop0p1)
    LOOP_DEV=$(echo "$PART_DEV" | sed 's/p[0-9]*$//')
    
    if [ -n "$LOOP_DEV" ] && [ -b "$LOOP_DEV" ]; then
        log "INFO" "Found loop device: $LOOP_DEV. Running grub-install..."
        # Install GRUB to the MBR of the loop device
        sudo grub-install --target=i386-pc --boot-directory="$LFS/boot" "$LOOP_DEV"
    else
        log "WARN" "Could not determine loop device for partition $PART_DEV."
    fi
fi

# ---------------------------------------------------------------------
# Step 6 — Create Portable RootFS Tarball
# ---------------------------------------------------------------------
OUTPUT_TAR="${GINGER_ROOT}/gingeros-base-rootfs.tar"
log "INFO" "Packaging root filesystem into $OUTPUT_TAR..."
sudo tar --xattrs --acls -C "$LFS" -cpf "$OUTPUT_TAR" .

log "SUCCESS" "GingerOS finalized for installation."
log "INFO" "The resulting image uses UUID=$PART_UUID and is hardware-agnostic."
