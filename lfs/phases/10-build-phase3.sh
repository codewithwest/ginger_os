#!/bin/bash
# GingerOS - Phase 3 Orchestrator (Inside Chroot)

set -e
set -o pipefail

if [ -f /config/env.sh ]; then
    # Use the project’s inner-chroot environment configuration.
    source /config/env.sh
else
    export LFS=${LFS}
    export LC_ALL=POSIX
    export LFS_TGT=$(uname -m)-lfs-linux-gnu
    export PATH=/tools/bin:/bin:/usr/bin
    export MAKEFLAGS=-j$(nproc)
    export CONFIG_SITE=$LFS/usr/share/config.site
fi

STATE_DIR="/var/lib/ginger"
mkdir -p "$STATE_DIR"

LOG_DIR="/var/log/ginger"
mkdir -p "$LOG_DIR"

echo "Inside Chroot: Starting Phase 3 (Final System Build)..."

SCRIPTS=(/lfs/phase3-system/*.sh)
TOTAL_PKGS=${#SCRIPTS[@]}
CURRENT_PKG_IDX=0

for script in "${SCRIPTS[@]}"; do
    CURRENT_PKG_IDX=$((CURRENT_PKG_IDX + 1))
    SCRIPT_PKG_NAME=$(grep -E "^PKG_NAME=" "$script" | cut -d'"' -f2 || echo "")
    FILE_PKG_NAME=$(basename "$script" .sh | cut -d'-' -f2-)
    FULL_SCRIPT_NAME=$(basename "$script" .sh)

    if [ -f "$STATE_DIR/${FULL_SCRIPT_NAME}.built" ]; then
        echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME (Skipped)"
        continue
    fi

    # Phase 3 scripts must only be skipped if their specific full script name marker exists.
    # We remove the generic FILE_PKG_NAME/SCRIPT_PKG_NAME fallback because it 
    # incorrectly skips final system builds if toolchain markers exist.

    echo "__GINGER_PKG_MARKER__: $FILE_PKG_NAME"
    echo "__GINGER_PKG_COUNT__: $CURRENT_PKG_IDX/$TOTAL_PKGS : $FILE_PKG_NAME"
    echo "Building: $FILE_PKG_NAME (Final System)"

    if bash "$script"; then
        touch "$STATE_DIR/${FULL_SCRIPT_NAME}.built"
        echo "Successfully built: ${FILE_PKG_NAME}"
        find /sources -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    else
        echo "Error: Failed to build ${FILE_PKG_NAME}"
        exit 1
    fi
done
