#!/bin/bash
# GingerOS - Phase 1 Orchestrator (Cross Toolchain)
# Run on the host system

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

set -e
set -o pipefail

GINGER_LOGS="$SCRIPT_DIR/../logs/phase1"
mkdir -p "$GINGER_LOGS"

# Collect scripts and package names
SCRIPTS=("$SCRIPT_DIR/../phase1-tools"/*.sh)
PKG_NAMES=()
for s in "${SCRIPTS[@]}"; do
    PKG_NAMES+=("$(basename "$s" .sh | cut -d'-' -f2-)")
done

ui_init_dashboard "${PKG_NAMES[@]}"
ui_log "Starting Phase 1: Cross Toolchain..."

for i in "${!SCRIPTS[@]}"; do
    script="${SCRIPTS[$i]}"
    SCRIPT_NAME=$(basename "$script" .sh)
    PKG_NAME="${PKG_NAMES[$i]}"

    ui_step "$i"

    if [ -f "$LFS/var/lib/ginger/$PKG_NAME.built" ]; then
        ui_log "$PKG_NAME already built. Skipping."
        continue
    fi

    ui_log "Building $PKG_NAME..."
    log_file="$GINGER_LOGS/$SCRIPT_NAME.log"

    # Start build in background
    bash "$script" >"$log_file" 2>&1 &
    PID=$!

    # Spinner with elapsed timer
    ui_spinner $PID "$PKG_NAME"

    if [ $? -ne 0 ]; then
        ui_error "Build failed: $PKG_NAME. Check $log_file"
    fi

    touch "$LFS/var/lib/ginger/$PKG_NAME.built"
    ui_log "Successfully installed $PKG_NAME"
done
