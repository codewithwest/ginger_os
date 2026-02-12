#!/bin/bash
# GingerOS - ISO Builder
set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../lib/ui.sh"
source "${SCRIPT_DIR}/../lib/disk.sh"
source "${SCRIPT_DIR}/../lib/bash_config.sh"

GINGER_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
ISO_DIR="$GINGER_ROOT/iso_work"
ISO_OUTPUT="$GINGER_ROOT/gingeros-installer.iso"
INITRD_WORK="$GINGER_ROOT/initrd_work"
LFS="/mnt/lfs"

ui_init_dashboard "Cleanup" "Environment" "Initrd" "Packaging" "ISO Build"

# --- HELPERS ---
cleanup() {
    sudo rm -rf "$ISO_DIR" "$INITRD_WORK"
}
trap cleanup EXIT

# --- BUILD PROCESS ---

# Step 0: Cleanup
ui_step 0
ui_log "Preparing build arena..."
cleanup
mkdir -p "$ISO_DIR/boot/grub" "$ISO_DIR/installer"

# Low space protection
FREE_BLOCKS=$(df -k "$GINGER_ROOT" | awk 'NR==2 {print $4}')
if [ "$FREE_BLOCKS" -lt 5000000 ]; then
    ui_log "Low space detected. Purging heavy artifacts..."
    sudo rm -rf "$GINGER_ROOT/ginger_os.img" 2>/dev/null || true
fi

# Step 1: Environment
ui_step 1
ui_log "Collecting Kernel..."
KERNEL_IMG=$(ls "$GINGER_ROOT/vmlinuz-"* 2>/dev/null | head -n 1)
[ -z "$KERNEL_IMG" ] && ui_error "Kernel not found!"
cp -v "$KERNEL_IMG" "$ISO_DIR/boot/vmlinuz"

# Step 2: Initrd
ui_step 2
ui_log "Assembling Live Environment..."
sudo rm -rf "$INITRD_WORK"
mkdir -p "$INITRD_WORK"/{bin,dev,etc,lib,lib64,mnt,proc,run,sbin,sys,tmp,var,root}

# Check for the rootfs tarball
ROOTFS_TAR="$GINGER_ROOT/gingeros-base-rootfs.tar.gz"
if [ ! -f "$ROOTFS_TAR" ]; then
    ui_error "RootFS tarball not found at $ROOTFS_TAR. Please build GingerOS first."
fi

ui_log "Extracting binaries from RootFS tarball..."
# Extract essential directories from the tarball
tar -xzf "$ROOTFS_TAR" -C "$INITRD_WORK" --wildcards \
    './bin/*' './sbin/*' './usr/bin/*' './usr/sbin/*' \
    './lib/*' './lib64/*' './usr/lib/*' \
    2>/dev/null || true

# Ensure we have the critical binaries
CRITICAL_BINS=(bash sh mount umount mkdir ls cp mv rm cat grep sed awk tar gzip)
for bin in "${CRITICAL_BINS[@]}"; do
    if [ ! -f "$INITRD_WORK/bin/$bin" ] && [ ! -f "$INITRD_WORK/usr/bin/$bin" ]; then
        ui_log "Warning: $bin not found in tarball, attempting fallback..."
        FALLBACK=$(which "$bin" 2>/dev/null || true)
        if [ -n "$FALLBACK" ]; then
            cp -v "$FALLBACK" "$INITRD_WORK/bin/"
        fi
    fi
done

# Copy additional tools if they exist in the tarball
EXTRA_TOOLS=(blkid parted lsblk fdisk udevadm wipefs mke2fs mkfs.ext4 grub-install grub-probe grub-mkconfig chroot findmnt)
for tool in "${EXTRA_TOOLS[@]}"; do
    # Check if already extracted
    [ -f "$INITRD_WORK/bin/$tool" ] || [ -f "$INITRD_WORK/sbin/$tool" ] || [ -f "$INITRD_WORK/usr/bin/$tool" ] || [ -f "$INITRD_WORK/usr/sbin/$tool" ] && continue
    
    # Try to extract from tarball
    tar -xzf "$ROOTFS_TAR" -C "$INITRD_WORK" --wildcards "*/$tool" 2>/dev/null || true
done

# Step 3: Packaging
ui_step 3
ui_log "Creating Live Initrd and Payload..."
# Create init script
cat << 'EOF' > "$INITRD_WORK/init"
#!/bin/sh
mount -vt proc proc /proc; mount -vt sysfs sysfs /sys; mount -vt devtmpfs devtmpfs /dev
echo "GingerOS Installation Media Booted"
mkdir -p /mnt/iso
for dev in /dev/sr* /dev/sd*; do mount -t iso9660 -o ro $dev /mnt/iso 2>/dev/null && break; done
if [ -f /mnt/iso/installer/installer.sh ]; then
    cd /mnt/iso/installer && /bin/bash installer.sh
else
    /bin/bash
fi
EOF
chmod +x "$INITRD_WORK/init"
(cd "$INITRD_WORK" && find . | cpio -o -H newc | gzip -c > "$ISO_DIR/boot/initrd.img")

cp "$GINGER_ROOT/scripts/iso/installer.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/scripts/lib/ui.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/scripts/lib/disk.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/scripts/lib/bash_config.sh" "$ISO_DIR/installer/"

# Apply bash config to Live environment
write_bash_config "$INITRD_WORK/root/.bashrc" "root" "true"
cp "$INITRD_WORK/root/.bashrc" "$INITRD_WORK/.bashrc" 2>/dev/null || true
[ -f "$GINGER_ROOT/gingeros-base-rootfs.tar.gz" ] && cp "$GINGER_ROOT/gingeros-base-rootfs.tar.gz" "$ISO_DIR/installer/"

# Step 4: ISO Build
ui_step 4
ui_log "Generating final ISO..."
cat << EOF > "$ISO_DIR/boot/grub/grub.cfg"
set default=0
set timeout=5
menuentry "GingerOS Installer (Cyberpunk Edition)" {
    linux /boot/vmlinuz root=/dev/ram0 rw quiet loglevel=3 splash
    initrd /boot/initrd.img
}
EOF
grub-mkrescue -o "$ISO_OUTPUT" "$ISO_DIR" >/dev/null 2>&1

ui_draw_header
echo -e "${GREEN}${BOLD}SUCCESS! ISO created at: $ISO_OUTPUT${NC}"
