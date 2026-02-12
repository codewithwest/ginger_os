#!/bin/bash
# GingerOS - Phase 2 Orchestrator
# Pure bash spinner + logs

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

set -e
set -o pipefail

LOG_DIR="$GINGER_LOGS"
mkdir -p "$LOG_DIR"

# Collect scripts and package names
SCRIPTS=("$SCRIPT_DIR/../phase2-tools"/*.sh)
PKG_NAMES=()
for s in "${SCRIPTS[@]}"; do
    PKG_NAMES+=("$(basename "$s" .sh | cut -d'-' -f2-)")
done

ui_init_dashboard "${PKG_NAMES[@]}"
ui_log "Starting Phase 2: Temporary Tools..."

for i in "${!SCRIPTS[@]}"; do
    script="${SCRIPTS[$i]}"
    SCRIPT_NAME=$(basename "$script" .sh)
    PKG_NAME="${PKG_NAMES[$i]}"

    ui_step "$i"

    # Skip if already built
    if [ -f "$LFS/var/lib/ginger/$PKG_NAME.built" ] || [ -f "$LFS/var/lib/ginger/$PKG_NAME-temp.built" ]; then
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

    # Check exit status
    RET=$?
    if [ $RET -ne 0 ]; then
        ui_error "Build failed: $PKG_NAME. Check $log_file"
    fi

    ui_log "Successfully installed $PKG_NAME"
done

ui_draw_header
echo -e "${LASER_GREEN}${BOLD}PHASE 2 (TEMPORARY TOOLS) COMPLETE!${NC}"
echo -e "\nNext step: sudo ./chroot.sh \"/scripts/build-phase3.sh\"\n"
