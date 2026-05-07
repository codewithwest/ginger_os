#!/bin/bash
# GingerOS - Launch ISO Installer
# Use this to run the professional TUI installer

GINGER_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ISO_PATH="$GINGER_ROOT/gingeros-installer.iso"
DISK_PATH="$GINGER_ROOT/test-target.qcow2"

if [ ! -f "$ISO_PATH" ]; then
    echo "Error: ISO not found at $ISO_PATH. Run scripts/iso/make-iso.sh first."
    exit 1
fi

# Create test disk if it doesn't exist
if [ ! -f "$DISK_PATH" ]; then
    echo "[INFO] Creating 20GB test disk..."
    qemu-img create -f qcow2 "$DISK_PATH" 20G
fi

# Clear any existing locks
pkill qemu-system-x86 2>/dev/null || true

echo "--- Launching GingerOS Installer ---"
qemu-system-x86_64 \
    -enable-kvm \
    -m 2G \
    -smp 4 \
    -cdrom "$ISO_PATH" \
    -hda "$DISK_PATH" \
    -boot d \
    -vga std \
    -display gtk,zoom-to-fit=on \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device e1000,netdev=net0
