#!/bin/bash
# GingerOS - Phase 1 Orchestrator
# Pure bash spinner + logs

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

set -e
set -o pipefail

LOG_DIR="$GINGER_LOGS"
mkdir -p "$LOG_DIR"

# Collect scripts and package names
SCRIPTS=("$SCRIPT_DIR/../phase1-tools"/*.sh)
PKG_NAMES=()
for s in "${SCRIPTS[@]}"; do
    PKG_NAMES+=("$(basename "$s" .sh | cut -d'-' -f2-)")
done

ui_init_dashboard "${PKG_NAMES[@]}"
ui_log "Starting Phase 1: Cross Toolchain..."

# Loop through packages
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
    log_file="$LOG_DIR/$SCRIPT_NAME.log"
    mkdir -p "$(dirname "$log_file")"

    # Run the package build in background
    bash "$script" > "$log_file" 2>&1 &
    PID=$!

    # Spinner + timer
    ui_spinner $PID "$PKG_NAME"

    # Check exit status
    RET=$?
    if [ $RET -ne 0 ]; then
        ui_error "Build failed: $PKG_NAME. Check $log_file"
    fi

    ui_log "Successfully installed $PKG_NAME"
done

ui_draw_header
echo -e "${LASER_GREEN}${BOLD}PHASE 1 COMPLETE!${NC}"
