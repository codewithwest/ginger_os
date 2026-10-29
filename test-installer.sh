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
# QEMU_DISPLAY=terminal (or none) uses the host terminal as the guest serial
# console. Graphical and curses modes retain the serial log and monitor socket.
DISPLAY_BACKEND="${QEMU_DISPLAY:-}"
SERIAL_ARGS=()
MONITOR_ARGS=(-monitor "unix:$GINGER_ROOT/qemu-monitor.sock,server=on,wait=off")
case "$DISPLAY_BACKEND" in
    terminal|none)
        DISPLAY_ARGS=(-display none)
        SERIAL_ARGS=(-serial mon:stdio)
        MONITOR_ARGS=()
        ;;
    gtk|gtk,*|sdl|sdl,*|curses)
        DISPLAY_ARGS=(-display "$DISPLAY_BACKEND")
        SERIAL_ARGS=(-serial "file:$GINGER_ROOT/installer-serial.log")
        ;;
    "")
        if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
            DISPLAY_ARGS=(-display gtk,zoom-to-fit=on)
        else
            DISPLAY_ARGS=(-display curses)
        fi
        SERIAL_ARGS=(-serial "file:$GINGER_ROOT/installer-serial.log")
        ;;
    *)
        echo "[ERROR] Unsupported QEMU_DISPLAY='$DISPLAY_BACKEND'. Use terminal, none, curses, or gtk." >&2
        exit 2
        ;;
esac

SSH_FORWARD_PORT="${SSH_FORWARD_PORT:-2223}"
if ! [[ "$SSH_FORWARD_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_FORWARD_PORT" -lt 1 ] || [ "$SSH_FORWARD_PORT" -gt 65535 ]; then
    echo "[ERROR] SSH_FORWARD_PORT must be a TCP port from 1 to 65535." >&2
    exit 2
fi

qemu-system-x86_64 \
    "${ACCEL_ARGS[@]}" \
    -m 2G \
    -smp 4 \
    -cdrom "$ISO_PATH" \
    -hda "$DISK_PATH" \
    -boot d \
    -vga std \
    "${DISPLAY_ARGS[@]}" \
    "${SERIAL_ARGS[@]}" \
    "${MONITOR_ARGS[@]}" \
    -netdev "user,id=net0,hostfwd=tcp::${SSH_FORWARD_PORT}-:22" \
    -device e1000,netdev=net0
