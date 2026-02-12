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
    PKG_NAME=$(basename "$script" .sh | cut -d'-' -f2-)

    echo "Building: $PKG_NAME (Final System)"

    if [ -f "/var/lib/ginger/$PKG_NAME.built" ]; then
        continue
    fi

    bash "$script"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed $PKG_NAME"
        exit 1
    fi
done
