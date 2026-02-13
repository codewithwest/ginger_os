#!/bin/bash
# GingerOS - ISO Builder
set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../lib/disk.sh"
source "${SCRIPT_DIR}/../lib/bash_config.sh"

GINGER_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
ISO_DIR="$GINGER_ROOT/iso_work"
ISO_OUTPUT="$GINGER_ROOT/gingeros-installer.iso"
INITRD_WORK="$GINGER_ROOT/initrd_work"
LFS="/mnt/lfs"

# --- HELPERS ---
cleanup() {
    sudo rm -rf "$ISO_DIR" "$INITRD_WORK"
}
trap cleanup EXIT

# --- BUILD PROCESS ---

# Step 0: Cleanup
echo "__GINGER_PKG_MARKER__: Preparation"
echo "Preparing build arena..."
cleanup
mkdir -p "$ISO_DIR/boot/grub" "$ISO_DIR/installer"

# Low space protection
FREE_BLOCKS=$(df -k "$GINGER_ROOT" | awk 'NR==2 {print $4}')
if [ "$FREE_BLOCKS" -lt 5000000 ]; then
    echo "Low space detected. Purging heavy artifacts..."
    sudo rm -rf "$GINGER_ROOT/ginger_os.img" 2>/dev/null || true
fi

# Step 1: Environment
echo "__GINGER_PKG_MARKER__: Environment"
echo "Collecting Kernel..."
KERNEL_IMG=$(ls "$GINGER_ROOT/vmlinuz-"* 2>/dev/null | head -n 1)
[ -z "$KERNEL_IMG" ] && { echo "Kernel not found!"; exit 1; }
cp -v "$KERNEL_IMG" "$ISO_DIR/boot/vmlinuz"

# Step 2: Initrd
echo "__GINGER_PKG_MARKER__: Initrd"
echo "Assembling Minimal Live Environment..."
sudo rm -rf "$INITRD_WORK"
mkdir -p "$INITRD_WORK"/{bin,dev,etc,lib,lib64,mnt,proc,run,sbin,sys,tmp,var,root}

echo "Using host system binaries for minimal boot environment..."
# Essential tools needed ONLY to boot and mount the ISO
# We use the host system binaries since we only need them for initial boot
ESSENTIAL_TOOLS=(bash xd sh mount umount mkdir ls cat grep sed awk)

for tool in "${ESSENTIAL_TOOLS[@]}"; do
    TOOL_PATH=$(which "$tool" 2>/dev/null || true)
    if [ -n "$TOOL_PATH" ] && [ -f "$TOOL_PATH" ]; then
        cp -v "$TOOL_PATH" "$INITRD_WORK/bin/"
    else
        echo "Critical tool $tool not found on host system!"
        exit 1
    fi
done

echo "Resolving library dependencies..."
# Copy only the libraries needed by our minimal binaries
for file in "$INITRD_WORK/bin/"*; do
    [ -f "$file" ] || continue
    
    # Get list of required libraries
    LIBS=$(ldd "$file" 2>/dev/null | grep -o '/[^ ]*' | grep '\.so' || true)
    
    for lib in $LIBS; do
        LIB_BASENAME=$(basename "$lib")
        TARGET_DIR="$INITRD_WORK/$(dirname "$lib" | sed 's|^/||')"
        
        # Skip if already copied
        [ -f "$TARGET_DIR/$LIB_BASENAME" ] && continue
        
        mkdir -p "$TARGET_DIR"
        
        if [ -f "$lib" ]; then
            cp -L "$lib" "$TARGET_DIR/" 2>/dev/null || true
        fi
    done
done

# CRITICAL: Ensure the dynamic linker is present
echo "Ensuring dynamic linker is present..."
DYNAMIC_LINKER="/lib64/ld-linux-x86-64.so.2"
if [ -f "$DYNAMIC_LINKER" ]; then
    mkdir -p "$INITRD_WORK/lib64"
    cp -L "$DYNAMIC_LINKER" "$INITRD_WORK/lib64/" || { echo "Failed to copy dynamic linker!"; exit 1; }
else
    echo "Dynamic linker not found at $DYNAMIC_LINKER"
    exit 1
fi

# Step 4: Packaging
echo "__GINGER_PKG_MARKER__: Packaging"
echo "Creating Live Initrd and Payload..."
# Create init script with error handling
cat << 'EOF' > "$INITRD_WORK/init"
#!/bin/sh
# GingerOS Live Init - Minimal Boot Environment

echo "=== GingerOS Installer Boot ==="
echo "Mounting kernel filesystems..."

mount -t proc proc /proc || echo "WARNING: Failed to mount /proc"
mount -t sysfs sysfs /sys || echo "WARNING: Failed to mount /sys"
mount -t devtmpfs devtmpfs /dev || echo "WARNING: Failed to mount /dev"

echo "Kernel filesystems mounted."
echo "Searching for installation media..."

mkdir -p /mnt/iso

# Try to find and mount the ISO
found=0
for dev in /dev/sr0 /dev/sr1 /dev/sda /dev/sdb /dev/sdc; do
    if [ -b "$dev" ]; then
        echo "Trying $dev..."
        if mount -t iso9660 -o ro "$dev" /mnt/iso 2>/dev/null; then
            if [ -f /mnt/iso/installer/installer.sh ]; then
                echo "Found GingerOS installer on $dev"
                found=1
                break
            else
                echo "No installer found on $dev, unmounting..."
                umount /mnt/iso 2>/dev/null
            fi
        fi
    fi
done

if [ "$found" -eq 1 ]; then
    echo "Launching GingerOS installer..."
    cd /mnt/iso/installer
    exec /bin/bash /mnt/iso/installer/installer.sh
else
    echo "ERROR: Could not find GingerOS installation media!"
    echo "Dropping to rescue shell. Type 'exit' to reboot."
    exec /bin/sh
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
echo "__GINGER_PKG_MARKER__: ISO Build"
echo "Generating final ISO..."
cat << EOF > "$ISO_DIR/boot/grub/grub.cfg"
set default=0
set timeout=5
menuentry "GingerOS Installer (Cyberpunk Edition)" {
    linux /boot/vmlinuz root=/dev/ram0 rw quiet loglevel=3 splash
    initrd /boot/initrd.img
}
EOF
grub-mkrescue -o "$ISO_OUTPUT" "$ISO_DIR" >/dev/null 2>&1

echo "SUCCESS! ISO created at: $ISO_OUTPUT"
