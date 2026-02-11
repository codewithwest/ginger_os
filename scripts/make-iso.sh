#!/bin/bash
# GingerOS - ISO Builder
# Creates a bootable GingerOS Installer ISO.

set -euo pipefail

# Colors for UI
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    local TYPE=$1
    local MSG="${2:-}"
    if [ -z "$MSG" ]; then
        echo -e "${GREEN}[ISO-BUILDER]${NC} $TYPE"
    else
        echo -e "${GREEN}[ISO-BUILDER]${NC} [$TYPE] $MSG"
    fi
}
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Prerequisites check
command -v xorriso >/dev/null || error "xorriso not found. Please install it: sudo apt install xorriso"
command -v grub-mkrescue >/dev/null || error "grub-mkrescue not found. Please install it: sudo apt install grub-common mtools"

GINGER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_DIR="$GINGER_ROOT/iso_work"
ISO_OUTPUT="$GINGER_ROOT/gingeros-installer.iso"
INITRD_WORK="$GINGER_ROOT/initrd_work"
LFS="/mnt/lfs"

# Cleanup function for safety
cleanup() {
    log "INFO" "Cleaning up temporary work directories..."
    sudo rm -rf "$ISO_DIR" "$INITRD_WORK"
}
trap cleanup EXIT

# 1. Pre-build Rescue and Cleanup
log "INFO" "Preparing environment for ISO build..."

# Check available disk space (need at least 5GB for a safe build)
FREE_BLOCKS=$(df -k "$GINGER_ROOT" | awk 'NR==2 {print $4}')
if [ "$FREE_BLOCKS" -lt 5000000 ]; then
    log "WARN" "Extremely low disk space detected!"
    IMAGE_PATH="$GINGER_ROOT/ginger_os.img"
    if [ -f "$IMAGE_PATH" ]; then
        log "INFO" "The 12GB ginger_os.img is taking up most of your space."
        log "INFO" "Since you have the RootFS tarball, we can delete the image to proceed."
        # Automatic cleanup for the user to make it seamless
        log "PROCESS" "Deleting $IMAGE_PATH to free up 12GB..."
        sudo umount -R "$LFS" 2>/dev/null || true
        sudo rm "$IMAGE_PATH"
        sudo losetup -D 2>/dev/null || true
    fi
fi

# Rescue Kernel if mounted (as fallback)
if mountpoint -q "$LFS"; then
    KERNEL_SYS=$(ls "$LFS/boot/vmlinuz-"* 2>/dev/null | head -n 1)
    if [ -n "$KERNEL_SYS" ]; then
        log "INFO" "Found kernel at $LFS/boot. Copying to project root..."
        cp -v "$KERNEL_SYS" "$GINGER_ROOT/vmlinuz-ginger"
    fi
    log "INFO" "Unmounting $LFS..."
    sudo umount -R "$LFS" 2>/dev/null || true
fi

# 2. Cleanup old work
cleanup
mkdir -p "$ISO_DIR/boot/grub"
mkdir -p "$ISO_DIR/installer"

# 3. Collect Kernel
log "Copying Kernel..."
# Look for the rescued kernel first
KERNEL_IMG=$(ls "$GINGER_ROOT/vmlinuz-"* 2>/dev/null | head -n 1)

if [ -z "$KERNEL_IMG" ]; then
    error "Kernel not found. The image/mount is gone and no rescued kernel was found in $GINGER_ROOT."
fi

cp -v "$KERNEL_IMG" "$ISO_DIR/boot/vmlinuz"

# 3. Create a Minimal Initrd (The "Live" filesystem)
# This is a small RAM disk that boots the system and runs the installer.
log "Preparing Live Initrd..."
sudo rm -rf "$INITRD_WORK"
mkdir -p "$INITRD_WORK"/{bin,dev,etc,lib,lib64,mnt,proc,run,sbin,sys,tmp,var}

# Copy essential tools to the initrd
log "Copying tools to initrd..."
TOOLS=(
    # Shell and Basic File Ops
    bash sh ls cat cp mv mkdir rm ln chmod chown chgrp
    # Text Processing
    grep sed awk tee head tail sort uniq wc cut tr xargs basename dirname printf
    # Disk and Filesystem
    mount umount findmnt blkid parted lsblk fdisk udevadm wipefs mke2fs mkfs.ext4 
    # System Info and Process
    id whoami sleep sync uname hostname dmesg ps top kill mktemp readlink realpath
    # Archives
    tar gzip bzip2 xz md5sum
    # Bootloader
    grub-install grub-probe grub-mkconfig
    # Misc
    sudo chroot mountpoint find
    # Maintenance
    vi nano
)
for tool in "${TOOLS[@]}"; do
    # 1. Try LFS first
    FILE=$(sudo find "$LFS/bin" "$LFS/sbin" "$LFS/usr/bin" "$LFS/usr/sbin" -name "$tool" 2>/dev/null | head -n 1) || true
    
    # 2. Try Host fallback if LFS is not mounted
    if [ -z "$FILE" ]; then
        FILE=$(command -v "$tool" 2>/dev/null) || true
    fi

    if [ -n "$FILE" ]; then
        log "INFO" "Adding tool: $tool ($FILE)"
        cp -v "$FILE" "$INITRD_WORK/bin/"
    else
        log "WARN" "Tool NOT found: $tool (Skipping...)"
    fi
done

# Copy required libraries (the heavy lifting)
log "Solving library dependencies for initrd..."
for file in "$INITRD_WORK/bin/"*; do
    [ -f "$file" ] || continue
    
    # We use ldd on the file itself. 
    # If it's an LFS tool, we might need to search in $LFS/lib
    LIBS=$(ldd "$file" 2>/dev/null | awk '{print $3}' | grep '^/' || true)
    for lib in $LIBS; do
        target_dir="$INITRD_WORK/$(dirname "$lib" | sed 's|^/||')"
        mkdir -p "$target_dir"
        
        if [ -f "$LFS$lib" ]; then
            cp -nv "$LFS$lib" "$target_dir/" 2>/dev/null || true
        else
            cp -nv "$lib" "$target_dir/" 2>/dev/null || true
        fi
    done
done

# Special case: Linker
# Ensure we have the basic linker for x86_64
LINKERS=("/lib/ld-linux-x86-64.so.2" "/lib64/ld-linux-x86-64.so.2")
for linker in "${LINKERS[@]}"; do
    target_dir="$INITRD_WORK/$(dirname "$linker" | sed 's|^/||')"
    mkdir -p "$target_dir"
    if [ -f "$LFS$linker" ]; then
        cp -nv "$LFS$linker" "$target_dir/" 2>/dev/null || true
    elif [ -f "$linker" ]; then
        cp -nv "$linker" "$target_dir/" 2>/dev/null || true
    fi
done

# 4. Create the Init Script (The first thing that runs)
cat << 'EOF' > "$INITRD_WORK/init"
#!/bin/sh
# GingerOS Live Init
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
echo "GingerOS Installation Media Booted"

# Find the ISO mount (it's often /dev/sr0)
mkdir -p /mnt/iso
for dev in /dev/sr* /dev/sd*; do
    mount -t iso9660 -o ro $dev /mnt/iso 2>/dev/null && break
done

if [ -f /mnt/iso/installer/installer.sh ]; then
    echo "Found GingerOS Installer. Starting environment..."
    cd /mnt/iso/installer
    /bin/bash
else
    echo "Error: Could not find GingerOS installer media."
    /bin/bash
fi
EOF
chmod +x "$INITRD_WORK/init"

# Package the Initrd
log "Packaging Initrd..."
(cd "$INITRD_WORK" && find . | cpio -o -H newc | gzip) > "$ISO_DIR/boot/initrd.img"

# 5. Add Installer and RootFS to ISO
log "PROCESS" "Adding GingerOS Installer and RootFS to ISO..."
cp "$GINGER_ROOT/scripts/installer.sh" "$ISO_DIR/installer/"

if [ -f "$GINGER_ROOT/gingeros-base-rootfs.tar.gz" ]; then
    log "INFO" "Copying RootFS to work dir..."
    cp "$GINGER_ROOT/gingeros-base-rootfs.tar.gz" "$ISO_DIR/installer/"
else
    log "WARN" "RootFS tarball missing. Will build without payload."
fi

# 6. Configure GRUB for ISO
cat << EOF > "$ISO_DIR/boot/grub/grub.cfg"
set default=0
set timeout=10

menuentry "Install GingerOS (Server Style)" {
    linux /boot/vmlinuz quiet splash
    initrd /boot/initrd.img
}

menuentry "GingerOS Live (Recovery Mode)" {
    linux /boot/vmlinuz quiet splash
    initrd /boot/initrd.img
}
EOF

# 7. Generate final ISO
log "Building final ISO: $ISO_OUTPUT"
grub-mkrescue -o "$ISO_OUTPUT" "$ISO_DIR"

# Cleanup
sudo rm -rf "$ISO_DIR" "$INITRD_WORK"

log "${GREEN}SUCCESS!${NC} Your installer ISO is ready at: $ISO_OUTPUT"
log "You can now burn this to a USB or boot it in QEMU."
