#!/bin/bash
# GingerOS - ISO Builder
# Creates a bootable GingerOS Installer ISO.

set -euo pipefail

# Colors for UI
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[ISO-BUILDER]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Prerequisites check
command -v xorriso >/dev/null || error "xorriso not found. Please install it: sudo apt install xorriso"
command -v grub-mkrescue >/dev/null || error "grub-mkrescue not found. Please install it: sudo apt install grub-common mtools"

GINGER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_DIR="$GINGER_ROOT/iso_work"
ISO_OUTPUT="$GINGER_ROOT/gingeros-installer.iso"
LFS="/mnt/lfs"

# 1. Cleanup old work
sudo rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR/boot/grub"
mkdir -p "$ISO_DIR/installer"

# 2. Collect Kernel
log "Copying Kernel..."
KERNEL_IMG=$(ls "$LFS/boot/vmlinuz-"* | head -n 1)
[ -z "$KERNEL_IMG" ] && error "Kernel not found at $LFS/boot. Did you finish the build?"
cp -v "$KERNEL_IMG" "$ISO_DIR/boot/vmlinuz"

# 3. Create a Minimal Initrd (The "Live" filesystem)
# This is a small RAM disk that boots the system and runs the installer.
log "Preparing Live Initrd..."
INITRD_WORK="$GINGER_ROOT/initrd_work"
sudo rm -rf "$INITRD_WORK"
mkdir -p "$INITRD_WORK"/{bin,dev,etc,lib,lib64,mnt,proc,run,sbin,sys,tmp,var}

# Copy essential tools from our new LFS system to the initrd
# We need basic shell and installation tools
log "Copying tools to initrd..."
# Busybox is ideal here, but we'll use our LFS binaries
# This ensures the "Live" environment is genuinely GingerOS-based
TOOLS=(bash sh ls cat cp mv mkdir mount umount md5sum tar gzip grep sed awk findmnt blkid parted grub-install mke2fs mkfs.ext4 wipefs)
for tool in "${TOOLS[@]}"; do
    FILE=$(sudo find "$LFS/bin" "$LFS/sbin" "$LFS/usr/bin" "$LFS/usr/sbin" -name "$tool" | head -n 1)
    if [ -n "$FILE" ]; then
        cp -v "$FILE" "$INITRD_WORK/bin/"
    fi
done

# Copy required libraries (the heavy lifting)
log "Solving library dependencies for initrd..."
# We use a simple loop to find all .so files needed by our tools
for file in "$INITRD_WORK/bin/"*; do
    [ -f "$file" ] || continue
    LIBS=$(sudo chroot "$LFS" ldd "/bin/$(basename "$file")" 2>/dev/null | awk '{print $3}' | grep '^/') || true
    for lib in $LIBS; do
        target_dir="$INITRD_WORK/$(dirname "$lib" | sed 's|^/||')"
        mkdir -p "$target_dir"
        cp -nv "$LFS$lib" "$target_dir/" 2>/dev/null || true
    done
done
# Special case: Linker
cp -nv "$LFS"/lib/ld-linux-x86-64.so.2 "$INITRD_WORK/lib/" 2>/dev/null || true
cp -nv "$LFS"/lib64/ld-linux-x86-64.so.2 "$INITRD_WORK/lib64/" 2>/dev/null || true

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
log "Adding GingerOS Installer and RootFS to ISO..."
cp "$GINGER_ROOT/scripts/installer.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/gingeros-base-rootfs.tar" "$ISO_DIR/installer/" || echo "Warning: RootFS tarball missing. Will build without payload."

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
