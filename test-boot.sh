#!/bin/bash
# GingerOS - Boot Installed System
# Use this AFTER the installation is complete

GINGER_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DISK_PATH="$GINGER_ROOT/test-target.qcow2"

if [ ! -f "$DISK_PATH" ]; then
    echo "Error: Test disk not found at $DISK_PATH. Run the installer first."
    exit 1
fi

# Never kill unrelated QEMU virtual machines. Refuse to reuse a locked disk.
if pgrep -af 'qemu-system-x86_64.*test-target.qcow2' >/dev/null; then
    echo "[ERROR] A GingerOS QEMU test appears to be running already; stop that VM explicitly first."
    exit 1
fi

echo "--- Booting GingerOS from Hard Disk ---"
echo "TIP: Select 'Standard Boot (sda1)' from the GRUB menu."
# Prefer KVM when available; fall back to TCG for nested/ordinary VMs.
ACCEL_ARGS=(-accel tcg)
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    ACCEL_ARGS=(-enable-kvm)
fi
# Use GTK in a desktop session, or curses from a terminal-only session.
DISPLAY_BACKEND="${QEMU_DISPLAY:-}"
if [ -z "$DISPLAY_BACKEND" ]; then
    if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        DISPLAY_BACKEND="gtk,zoom-to-fit=on"
    else
        DISPLAY_BACKEND="curses"
    fi
fi

qemu-system-x86_64 \
    "${ACCEL_ARGS[@]}" \
    -m 2G \
    -smp 4 \
    -hda "$DISK_PATH" \
    -boot c \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device e1000,netdev=net0 \
