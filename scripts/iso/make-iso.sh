#!/bin/bash
# GingerOS - ISO Builder
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../lib/disk.sh"
source "${SCRIPT_DIR}/../lib/bash_config.sh"

GINGER_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
ISO_DIR="$GINGER_ROOT/iso_work"
ISO_OUTPUT="$GINGER_ROOT/gingeros-installer.iso"
INITRD_WORK="$GINGER_ROOT/initrd_work"

log() {
    local TYPE=$1
    local MSG=$2
    echo "[$(date +'%H:%M:%S')] [$TYPE] $MSG"
}

cleanup() {
    sudo rm -rf "$ISO_DIR" "$INITRD_WORK"
}
trap cleanup EXIT

echo "__GINGER_PKG_MARKER__: Preparation"
cleanup
mkdir -p "$ISO_DIR/boot/grub" "$ISO_DIR/installer"

echo "__GINGER_PKG_MARKER__: Kernel"
if [ -f "$GINGER_ROOT/vmlinuz-ginger" ]; then
    KERNEL_IMG="$GINGER_ROOT/vmlinuz-ginger"
else
    KERNEL_IMG=$(ls "$GINGER_ROOT"/vmlinuz-* 2>/dev/null | head -n 1 || true)
fi

[ -z "${KERNEL_IMG:-}" ] && { echo "Kernel not found!"; exit 1; }
cp -v "$KERNEL_IMG" "$ISO_DIR/boot/vmlinuz"

echo "__GINGER_PKG_MARKER__: Initrd"
sudo rm -rf "$INITRD_WORK"

ESSENTIAL_TOOLS=(
    bash sh mount umount mkdir ls cat grep sed awk rm
    parted partprobe mkfs.ext4 tar lsblk blkid wipefs gzip udevadm
    grub-install tee sleep which clear ps kill tput 
    readlink dirname touch du df
    head tail sort uniq date wc tr cut xargs cp mv ln
    python3 chmod env find losetup fuser locale
)

# Create essential system directory structure
mkdir -p "$INITRD_WORK"/{bin,dev,etc,lib,lib64,mnt,proc,run,sys,tmp,var,root,usr}

# Create merged usr compatibility symlinks and standard layout
ln -sf bin "$INITRD_WORK/sbin"
ln -sf ../bin "$INITRD_WORK/usr/bin"
ln -sf ../bin "$INITRD_WORK/usr/sbin"
# Function to copy binary and its dependencies
copy_exe() {
    local exe=$1
    local dest=$2
    local binary_path=$(which "$exe")
    
    if [ -z "$binary_path" ]; then
        log "WARN" "Binary $exe not found, skipping."
        return
    fi
    
    # Copy the binary
    cp "$binary_path" "$dest/bin/"
    
    # Copy its libraries
    ldd "$binary_path" | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' "$dest/lib/x86_64-linux-gnu/" 2>/dev/null || true
    # Also copy the loader if present
    ldd "$binary_path" | grep "/lib64/" | awk '{print $1}' | xargs -I '{}' cp -v '{}' "$dest/lib64/" 2>/dev/null || true
}

log "INFO" "Preparing tool binaries..."
mkdir -p "$INITRD_WORK/bin" "$INITRD_WORK/lib/x86_64-linux-gnu" "$INITRD_WORK/lib64"
for tool in "${ESSENTIAL_TOOLS[@]}"; do
    copy_exe "$tool" "$INITRD_WORK"
done
ln -sf ../lib "$INITRD_WORK/usr/lib"
ln -sf ../lib64 "$INITRD_WORK/usr/lib64"

for tool in "${ESSENTIAL_TOOLS[@]}"; do
    # Use 'type -P' to find the executable path, ignoring shell builtins and aliases
    TOOL_PATH=$(type -P "$tool" || true)
    
    if [ -z "$TOOL_PATH" ]; then
        echo "[WARN] Missing tool '$tool' (or only available as builtin), skipping"
        continue
    fi
    
    cp -vL "$TOOL_PATH" "$INITRD_WORK/bin/"
done

echo "[INFO] Resolving library dependencies..."
for file in "$INITRD_WORK/bin/"*; do
    # Check if file exists (in case glob matches nothing)
    [ -e "$file" ] || continue
    
    # Skip if not an executable or is a directory
    [ -f "$file" ] || continue

    # Get libraries, ignoring errors (e.g. if file is a script or static binary)
    # properly handle pipefail: ensure command doesn't fail if grep finds nothing
    LIBS=$(ldd "$file" 2>/dev/null | awk '{print $3}' | grep '^/' || true)

    if [ -n "$LIBS" ]; then
        echo "  - Dependencies for $(basename "$file")"
        echo "$LIBS" | while read -r lib; do
            dest="$INITRD_WORK$(dirname "$lib")"
            if [ ! -d "$dest" ]; then
                mkdir -p "$dest"
            fi
            cp -nL "$lib" "$dest/" 2>/dev/null || true
        done
    fi
done

# Dynamic linker
if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
    mkdir -p "$INITRD_WORK/lib64"
    cp -L /lib64/ld-linux-x86-64.so.2 "$INITRD_WORK/lib64/"
fi

# Copy installer payload
cp "$GINGER_ROOT/scripts/iso/ginger-installer-bin" "$ISO_DIR/installer/installer-bin"
cp "$GINGER_ROOT/scripts/iso/installer.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/scripts/iso/installer.py" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/scripts/lib/ui.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/scripts/lib/disk.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/scripts/lib/bash_config.sh" "$ISO_DIR/installer/"
cp "$GINGER_ROOT/ginger.conf" "$ISO_DIR/installer/" 2>/dev/null || true

# Copy GRUB modules (Essential for grub-install)
if [ -d /usr/lib/grub ]; then
    echo "[INFO] Copying GRUB modules..."
    mkdir -p "$INITRD_WORK/usr/lib"
    cp -r /usr/lib/grub "$INITRD_WORK/usr/lib/"
fi

# Copy Terminfo (Fixes "terminals database is inaccessible")
if [ -d /usr/share/terminfo ]; then
    echo "[INFO] Copying terminfo..."
    mkdir -p "$INITRD_WORK/usr/share"
    cp -r /usr/share/terminfo "$INITRD_WORK/usr/share/"
elif [ -d /lib/terminfo ]; then
     echo "[INFO] Copying terminfo from /lib..."
     mkdir -p "$INITRD_WORK/lib"
     cp -r /lib/terminfo "$INITRD_WORK/lib/"
fi

# Copy Professional Python Environment
log "INFO" "Bundling Python standard library..."
PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
mkdir -p "$INITRD_WORK/usr/lib/python$PY_VER"

# Copy all top-level .py files
cp -r /usr/lib/python$PY_VER/*.py "$INITRD_WORK/usr/lib/python$PY_VER/" 2>/dev/null || true

# Copy ALL subdirectories
cp -r /usr/lib/python$PY_VER/*/ "$INITRD_WORK/usr/lib/python$PY_VER/" 2>/dev/null || true

# Remove massive/unneeded folders to save space
rm -rf "$INITRD_WORK/usr/lib/python$PY_VER/"{test,tkinter,idlelib,turtledemo,pydoc_data,ensurepip,__pycache__}

# Copy Rich library
RICH_PATH=$(python3 -c "import rich; import os; print(os.path.dirname(rich.__file__))")
mkdir -p "$INITRD_WORK/usr/lib/python3/dist-packages"
cp -r "$RICH_PATH" "$INITRD_WORK/usr/lib/python3/dist-packages/"
# Ensure python looks in the right place
export PYTHONPATH="/usr/lib/python3/dist-packages:/usr/lib/python$PY_VER"

# Rootfs payload
ROOTFS_PATH="$GINGER_ROOT/gingeros-base-rootfs.tar.gz"
echo "[DEBUG] Looking for RootFS at: $ROOTFS_PATH"
if [ -f "$ROOTFS_PATH" ]; then
    echo "[INFO] Found RootFS, copying..."
    ls -lh "$ROOTFS_PATH"
    cp "$ROOTFS_PATH" "$ISO_DIR/installer/" || { echo "[ERROR] Failed to copy RootFS"; exit 1; }
else
    echo "[ERROR] RootFS not found at $ROOTFS_PATH"
    echo "Directory contents of $GINGER_ROOT:"
    ls -lh "$GINGER_ROOT" | head -n 5
    echo "[WARN] Continuing without RootFS (ISO will be small/incomplete)"
fi

# Init script
cat << 'EOF' > "$INITRD_WORK/init"
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "=== GingerOS Installer Boot ==="

mount -t proc proc /proc || true
mount -t sysfs sysfs /sys || true
mount -t devtmpfs devtmpfs /dev || true

mkdir -p /mnt/iso

# Find ISO
for dev in /dev/sr0 /dev/vda /dev/sda /dev/sdb /dev/sdc; do
    if [ -b "$dev" ]; then
        if mount -o ro "$dev" /mnt/iso 2>/dev/null; then
            if [ -f /mnt/iso/installer/installer.sh ]; then
                FOUND_ISO="$dev"
                echo "Found GingerOS ISO on $dev"
                break
            fi
            umount /mnt/iso 2>/dev/null
        fi
    fi
done

if [ -n "$FOUND_ISO" ]; then
    cd /mnt/iso/installer
    export PYTHONPATH="/usr/lib/python3/dist-packages:/usr/lib/python$PY_VER"
    # Launch Professional TUI Installer with fail-safe
    if ! python3 ./installer.py; then
        echo "ERROR: Professional TUI failed to start."
        echo "Dropping to recovery shell..."
        /bin/sh
    fi
else
    echo "ERROR: GingerOS ISO not found."
    exec /bin/sh
fi
EOF
chmod +x "$INITRD_WORK/init"

(cd "$INITRD_WORK" && find . | cpio -o -H newc | gzip -c > "$ISO_DIR/boot/initrd.img")

cat << EOF > "$ISO_DIR/boot/grub/grub.cfg"
set default=1
set timeout=10
terminal_input console
terminal_output console

menuentry "Install GingerOS" {
    linux /boot/vmlinuz root=/dev/ram0 rw console=tty0 loglevel=3 quiet
    initrd /boot/initrd.img
}

menuentry "Install GingerOS (Terminal Debug)" {
    linux /boot/vmlinuz root=/dev/ram0 rw console=tty0 console=ttyS0,115200 loglevel=7 debug earlyprintk=serial
    initrd /boot/initrd.img
}
EOF

grub-mkrescue -o "$ISO_OUTPUT" "$ISO_DIR"
echo "SUCCESS! ISO created at: $ISO_OUTPUT"