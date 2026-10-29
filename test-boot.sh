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
# QEMU_DISPLAY=terminal (or none) disables the virtual display and routes
# the guest serial console to this terminal. "curses" uses a text VGA console.
DISPLAY_BACKEND="${QEMU_DISPLAY:-}"
SERIAL_ARGS=()
DISPLAY_ARGS=()
case "$DISPLAY_BACKEND" in
    terminal|none)
        DISPLAY_ARGS=(-display none)
        SERIAL_ARGS=(-serial mon:stdio)
        ;;
    gtk|gtk,*|sdl|sdl,*|curses)
        DISPLAY_ARGS=(-display "$DISPLAY_BACKEND")
        ;;
    "")
        if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
            DISPLAY_ARGS=(-display gtk,zoom-to-fit=on)
        else
            DISPLAY_ARGS=(-display curses)
        fi
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
    -hda "$DISK_PATH" \
    -boot c \
    "${DISPLAY_ARGS[@]}" \
    "${SERIAL_ARGS[@]}" \
    -netdev "user,id=net0,hostfwd=tcp::${SSH_FORWARD_PORT}-:22" \
    -device e1000,netdev=net0 \
