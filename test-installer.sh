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

# Never kill unrelated QEMU virtual machines. Refuse to reuse a locked disk.
if pgrep -af 'qemu-system-x86_64.*gingeros-installer.iso' >/dev/null; then
    echo "[ERROR] A GingerOS QEMU test appears to be running already; stop that VM explicitly first."
    exit 1
fi

# Recreate the disposable target disk only when explicitly requested.
# This erases the prior VM installation; the ISO itself is never modified.
if [ "${FRESH_DISK:-0}" = "1" ]; then
    rm -f "$DISK_PATH"
fi
if [ ! -f "$DISK_PATH" ]; then
    echo "[INFO] Creating 20GB test disk..."
    qemu-img create -f qcow2 "$DISK_PATH" 20G
fi

# Fresh debug artifacts from the previous run
rm -f "$GINGER_ROOT/installer-serial.log" "$GINGER_ROOT/qemu-monitor.sock"

echo "--- Launching GingerOS Installer ---"
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
    -cdrom "$ISO_PATH" \
    -hda "$DISK_PATH" \
    -boot d \
    -vga std \
    -display "$DISPLAY_BACKEND" \
    -serial file:"$GINGER_ROOT/installer-serial.log" \
    -monitor unix:"$GINGER_ROOT/qemu-monitor.sock",server=on,wait=off \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device e1000,netdev=net0
