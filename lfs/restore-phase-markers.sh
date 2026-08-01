#!/usr/bin/env bash
# One-time repair: restore phase1/phase2 completion markers.
# The "create qemu img" step wipes ALL .build_state/*.built markers when a
# fresh disk is detected. The phase1/2 toolchain is genuinely built inside the
# mounted rootfs (/mnt/ginger_lfs/tools), so we re-create the metadata markers
# to unblock the dependency gate in server/engine.py (_should_skip).
#
# Does NOT touch phase3 markers, so kmod/udev/systemd/dbus still rebuild.
# Run as root:  sudo bash lfs/restore-phase-markers.sh

set -euo pipefail

cd "$(dirname "$0")/.."
STATE_DIR="$(pwd)/.build_state"

# Sanity check: the cross toolchain must actually exist.
TOOLS_BIN="/mnt/ginger_lfs/tools/bin"
if [ ! -d "$TOOLS_BIN" ] || ! ls "$TOOLS_BIN" | grep -q "x86_64-lfs-linux-gnu-"; then
    echo "ERROR: cross toolchain not found in $TOOLS_BIN — do NOT restore markers."
    exit 1
fi

markers=(
    binutils-pass1 gcc-pass1 linux-headers glibc libstdcxx
    m4-temp ncurses-temp bash-temp coreutils-temp diffutils-temp
    file-temp findutils-temp gawk-temp grep-temp gzip-temp
    make-temp patch-temp sed-temp tar-temp xz-temp
    binutils-pass2 gcc-pass2
)

mkdir -p "$STATE_DIR"
for m in "${markers[@]}"; do
    touch "$STATE_DIR/$m.built"
done

echo "Restored ${#markers[@]} phase1/2 markers in $STATE_DIR"
