#!/bin/bash
# GingerOS - Boot Installed System
# Use this AFTER the installation is complete

GINGER_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DISK_PATH="$GINGER_ROOT/test-target.qcow2"

if [ ! -f "$DISK_PATH" ]; then
    echo "Error: Test disk not found at $DISK_PATH. Run the installer first."
    exit 1
fi

# Clear any existing locks
pkill qemu-system-x86 2>/dev/null || true

echo "--- Booting GingerOS from Hard Disk ---"
echo "TIP: Select 'Standard Boot (sda1)' from the GRUB menu."
qemu-system-x86_64 \
    -enable-kvm \
    -m 2G \
    -smp 4 \
    -hda "$DISK_PATH" \
    -boot c \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device e1000,netdev=net0 \
