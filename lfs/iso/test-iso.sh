#!/bin/bash
# GingerOS ISO Validation Script (QEMU)
# Launches the installer ISO in a virtual machine for testing.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
GINGER_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
ISO_PATH="$GINGER_ROOT/gingeros-installer.iso"

# Safety: Check if ISO exists
if [ ! -f "$ISO_PATH" ]; then
    echo "ERROR: ISO not found at $ISO_PATH"
    echo "Please run: bash lfs/iso/make-iso.sh first."
    exit 1
fi

# Safety: Check if qemu is installed
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "ERROR: qemu-system-x86_64 not found. Please install QEMU."
    exit 1
fi

echo "--- GingerOS ISO Validation ---"
echo "Launching QEMU with 2GB RAM and 2 CPUs..."
echo "Tip: If you see a black screen, try running with -nographic"
echo "Press Ctrl+C to exit."

# Create a temporary virtual disk for testing the installer (10GB)
TEST_DISK="$GINGER_ROOT/test-target.qcow2"
if [ ! -f "$TEST_DISK" ]; then
    echo "Creating 10GB test disk: $TEST_DISK"
    qemu-img create -f qcow2 "$TEST_DISK" 10G
fi

qemu-system-x86_64 \
    -enable-kvm \
    -m 2G \
    -smp 2 \
    -cdrom "$ISO_PATH" \
    -hda "$TEST_DISK" \
    -boot d \
    -vga std \
    -display gtk,zoom-to-fit=on \
    -serial stdio
