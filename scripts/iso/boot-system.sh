#!/bin/bash
# GingerOS - Boot Installed System
GINGER_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../../" && pwd)"
TEST_DISK="$GINGER_ROOT/test-target.qcow2"

if [ ! -f "$TEST_DISK" ]; then
    echo "Error: Installed disk not found at $TEST_DISK"
    exit 1
fi

echo "--- Launching Installed GingerOS ---"
qemu-system-x86_64 \
    -enable-kvm \
    -m 2G \
    -smp 2 \
    -hda "$TEST_DISK" \
    -boot c \
    -vga std \
    -display gtk,zoom-to-fit=on \
    -serial stdio
