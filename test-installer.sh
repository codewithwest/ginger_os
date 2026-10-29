#!/bin/bash
# GingerOS - Launch ISO Installer
# Use this to run the professional TUI installer

GINGER_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ISO_PATH="$GINGER_ROOT/gingeros-installer.iso"
DISK_PATH="$GINGER_ROOT/test-target.qcow2"

if [ ! -f "$ISO_PATH" ]; then
    echo "Error: ISO not found at $ISO_PATH. Run lfs/iso/make-iso.sh first."
    exit 1
fi

# Create test disk if it doesn't exist
if [ ! -f "$DISK_PATH" ]; then
    echo "[INFO] Creating 20GB test disk..."
    qemu-img create -f qcow2 "$DISK_PATH" 20G
fi

# Never kill unrelated QEMU virtual machines. Refuse to reuse a locked disk.
if pgrep -af 'qemu-system-x86_64.*gingeros-installer.iso' >/dev/null; then
    echo "[ERROR] A GingerOS QEMU test appears to be running already; stop that VM explicitly first."
    exit 1
fi

# Fresh debug artifacts from the previous run
rm -f "$GINGER_ROOT/installer-serial.log" "$GINGER_ROOT/qemu-monitor.sock"

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
    -serial file:"$GINGER_ROOT/installer-serial.log" \
    -monitor unix:"$GINGER_ROOT/qemu-monitor.sock",server=on,wait=off \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device e1000,netdev=net0
