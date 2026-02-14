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
    python3 chmod env find losetup
)

# ... (omitted unchanged parts for brevity if tool allows, but here we replace the chunk) ...

# Create essential system directory structure
mkdir -p "$INITRD_WORK"/{bin,dev,etc,lib,lib64,mnt,proc,run,sys,tmp,var,root,usr}

# ... (omitted unchanged symlinks) ...

# Init script
cat << 'EOF' > "$INITRD_WORK/init"
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "=== GingerOS Installer Boot (Terminal Debug) ==="

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
    
    # Interactive Installer Menu
    while true; do
        clear
        echo "========================================"
        echo "   GingerOS Installer - Select Target"
        echo "========================================"
        echo ""
        echo "Available Disks:"
        lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep "disk" | grep -v "sr0" | grep -v "loop"
        echo ""
        echo "Type the disk name to install to (e.g. sda)"
        echo "Type 'shell' to drop to a debug shell"
        echo "Type 'reboot' to restart system"
        echo ""
        printf "Target Disk > "
        read TARGET
        
        if [ "$TARGET" = "shell" ]; then
            echo "Starting debug shell..."
            /bin/bash
            continue
        elif [ "$TARGET" = "reboot" ]; then
            reboot -f
        fi
        
        # Check if disk exists
        if [ -b "/dev/$TARGET" ]; then
            echo ""
            echo "WARNING: ALL DATA ON /dev/$TARGET WILL BE ERASED!"
            printf "Are you sure? (y/N) > "
            read CONFIRM
            
            if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
                echo "Starting installation..."
                /bin/bash ./installer.sh "/dev/$TARGET"
                
                if [ $? -eq 0 ]; then
                    echo ""
                    echo "Installation Complete!"
                    echo "Press COMMAND to continue:"
                    echo "  [Enter] Reboot"
                    echo "  [s]     Shell"
                    read ACTION
                    if [ "$ACTION" = "s" ]; then
                        /bin/bash
                    else
                        reboot -f
                    fi
                else
                    echo "Installation failed. Dropping to shell."
                    /bin/bash
                fi
            else
                echo "Aborted."
                sleep 1
            fi
        else
            echo "Invalid disk: /dev/$TARGET not found."
            sleep 2
        fi
    done
else
    echo "ERROR: GingerOS ISO not found."
    exec /bin/sh
fi
EOF
chmod +x "$INITRD_WORK/init"

(cd "$INITRD_WORK" && find . | cpio -o -H newc | gzip -c > "$ISO_DIR/boot/initrd.img")

cat << EOF > "$ISO_DIR/boot/grub/grub.cfg"
set default=0
set timeout=5
terminal_input console
terminal_output console

menuentry "GingerOS Installer (Terminal Debug)" {
    linux /boot/vmlinuz root=/dev/ram0 rw console=tty0 console=ttyS0,115200 loglevel=7 debug earlyprintk=serial
    initrd /boot/initrd.img
}
EOF

grub-mkrescue -o "$ISO_OUTPUT" "$ISO_DIR"
echo "SUCCESS! ISO created at: $ISO_OUTPUT"