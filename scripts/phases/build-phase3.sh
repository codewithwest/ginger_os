#!/bin/bash
# GingerOS - Phase 3 (Inside Chroot) Orchestrator
# This script is meant to be run INSIDE the chroot environment.

# Inside chroot, we need to source the environment
# The /scripts directory is bind-mounted from the host
source /scripts/lib/common.sh
source /scripts/lib/ui.sh

set -e
set -o pipefail

# Log directory for build logs
LOG_DIR="/var/log/ginger"
mkdir -p "$LOG_DIR"

ui_init_dashboard "Base Setup" "System Libs" "Core Utils" "Shell & Env" "Final Tools"
ui_log "Inside Chroot: Starting Phase 3 (Final System Build)..."

# Mapping 94 scripts to 5 UI steps
get_phase3_idx() {
    local num=$(echo "$1" | cut -d'-' -f1 | sed 's/^0//')
    if [ "$num" -le 10 ]; then echo 0;    # Base Setup
    elif [ "$num" -le 35 ]; then echo 1; # System Libs
    elif [ "$num" -le 65 ]; then echo 2; # Core Utils
    elif [ "$num" -le 85 ]; then echo 3; # Shell & Env
    else echo 4;                         # Final Tools
    fi
}

SCRIPTS=(/scripts/phase3-system/*.sh)
for script in "${SCRIPTS[@]}"; do
    SCRIPT_NAME=$(basename "$script" .sh)
    PKG_NAME=$(echo "$SCRIPT_NAME" | cut -d'-' -f2-)
    
    IDX=$(get_phase3_idx "$SCRIPT_NAME")
    ui_step "$IDX"

    if [ -f "/var/lib/ginger/$PKG_NAME.built" ]; then
        ui_log "$PKG_NAME already built. Skipping."
        continue
    fi

    ui_log "Building $PKG_NAME..."
    (bash "$script" > "$LOG_DIR/$SCRIPT_NAME.log" 2>&1) &
    ui_spinner $! "Compiling $PKG_NAME..."
    
    if [ $? -ne 0 ]; then
        ui_error "Build failed: $PKG_NAME. Check $LOG_DIR/$SCRIPT_NAME.log"
    fi
    ui_log "Successfully installed $PKG_NAME"
done

ui_draw_header
echo -e "${LASER_GREEN}${BOLD}PHASE 3 COMPLETE! YOUR SYSTEM IS ASSEMBLED.${NC}"
sleep 2

