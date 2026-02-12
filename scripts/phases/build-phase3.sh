#!/bin/bash
# GingerOS - Phase 3 Orchestrator (Inside Chroot)
# Pure bash spinner + logs

source /scripts/lib/ui.sh
set -e
set -o pipefail

LOG_DIR="/var/log/ginger"
mkdir -p "$LOG_DIR"

ui_init_dashboard "Base Setup" "System Libs" "Core Utils" "Shell & Env" "Final Tools"
ui_log "Inside Chroot: Starting Phase 3 (Final System Build)..."

# Map scripts to 5 dashboard steps
get_phase3_idx() {
    local num=$(echo "$1" | cut -d'-' -f1 | sed 's/^0//')
    if [ "$num" -le 10 ]; then echo 0
    elif [ "$num" -le 35 ]; then echo 1
    elif [ "$num" -le 65 ]; then echo 2
    elif [ "$num" -le 85 ]; then echo 3
    else echo 4
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
    log_file="$LOG_DIR/$SCRIPT_NAME.log"
    mkdir -p "$(dirname "$log_file")"

    # Run build in background
    bash "$script" > "$log_file" 2>&1 &
    PID=$!

    # Spinner + timer
    ui_spinner $PID "$PKG_NAME"

    RET=$?
    if [ $RET -ne 0 ]; then
        ui_error "Build failed: $PKG_NAME. Check $log_file"
    fi

    ui_log "Successfully installed $PKG_NAME"
done

ui_draw_header
echo -e "${LASER_GREEN}${BOLD}PHASE 3 COMPLETE! YOUR SYSTEM IS ASSEMBLED.${NC}"
