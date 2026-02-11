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
ui_log "Assembling Live Environment (Merged-Usr)..."
sudo rm -rf "$INITRD_WORK"
mkdir -p "$INITRD_WORK"/usr/{bin,lib}
mkdir -p "$INITRD_WORK"/{dev,etc,mnt,proc,run,sys,tmp,var,root}

# Essential Merged-Usr Symlinks
ln -sf usr/bin "$INITRD_WORK/bin"
ln -sf usr/bin "$INITRD_WORK/sbin"
ln -sf usr/lib "$INITRD_WORK/lib"
ln -sf lib "$INITRD_WORK/lib64"
ln -sf bin "$INITRD_WORK/usr/sbin"

# Tools List (Consolidated)
TOOLS=(bash sh ls cat cp mv mkdir rm ln chmod chown chgrp grep sed awk tee head tail sort uniq wc cut tr xgettext xargs basename dirname find mount umount findmnt blkid parted lsblk fdisk udevadm wipefs mke2fs mkfs.ext4 id whoami sleep sync uname hostname dmesg ps top kill mktemp readlink realpath tar gzip bzip2 xz md5sum grub-install grub-probe grub-mkconfig sudo chroot mountpoint find vi nano)

for tool in "${TOOLS[@]}"; do
    FILE=$(sudo find "$LFS/bin" "$LFS/sbin" "$LFS/usr/bin" "$LFS/usr/sbin" -name "$tool" 2>/dev/null | head -n 1) || true
    [ -z "$FILE" ] && FILE=$(which "$tool" 2>/dev/null) || true
    if [ -n "$FILE" ] && [ -f "$FILE" ]; then
        # Copy to the merged-usr target
        cp -Lv "$FILE" "$INITRD_WORK/usr/bin/$tool"
    fi
done

# Library Solver
ui_log "Solving binary dependencies..."
for file in "$INITRD_WORK/usr/bin/"*; do
    [ -f "$file" ] || continue
    LIBS=$(ldd "$file" 2>/dev/null | grep -o '/[a-zA-Z0-9._/-]*' || true)
    for lib in $LIBS; do
        if [ -f "$LFS$lib" ]; then
            SRC="$LFS$lib"
        elif [ -f "$lib" ]; then
            SRC="$lib"
        else
            continue
        fi
        
        # Determine the target internal path
        # In merged-usr, everything in /lib or /usr/lib goes to /usr/lib in the ramdisk
        target_name=$(basename "$lib")
        if [[ "$lib" == *"/bin/"* ]]; then
             cp -Lv "$SRC" "$INITRD_WORK/usr/bin/$target_name" 2>/dev/null || true
        else
             cp -Lv "$SRC" "$INITRD_WORK/usr/lib/$target_name" 2>/dev/null || true
        fi
    done
done

# Step 3: Packaging
ui_step 3
ui_log "Creating Live Initrd and Payload..."
# Improved robust init script
cat << 'EOF' > "$INITRD_WORK/init"
#!/bin/sh
# GingerOS Live Init
mount -vt proc proc /proc
mount -vt sysfs sysfs /sys
mount -vt devtmpfs devtmpfs /dev

echo "GingerOS Cyberpunk Edition - Booting..."

# Search for the ISO media
mkdir -p /mnt/iso
found=0
for dev in /dev/sr* /dev/sd*; do
    echo "Checking $dev for GingerOS media..."
    if mount -t iso9660 -o ro $dev /mnt/iso 2>/dev/null; then
        if [ -f /mnt/iso/installer/installer.sh ]; then
            found=1
            break
        fi
        umount /mnt/iso
    fi
done

if [ "$found" -eq 1 ]; then
    echo "Installer found. Launching Cyberpunk Dashboard..."
    cd /mnt/iso/installer
    /bin/bash /mnt/iso/installer/installer.sh
else
    echo "ERROR: Installation media not found."
    echo "Dropping to emergency bash shell..."
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
menuentry "GingerOS Installer (west Edition)" {
    linux /boot/vmlinuz root=/dev/ram0 rw quiet loglevel=3 splash
    initrd /boot/initrd.img
}
EOF
grub-mkrescue -o "$ISO_OUTPUT" "$ISO_DIR" >/dev/null 2>&1

ui_draw_header
echo -e "${GREEN}${BOLD}SUCCESS! ISO created at: $ISO_OUTPUT${NC}"
