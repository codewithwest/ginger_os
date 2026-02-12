#!/bin/bash
# GingerOS - Phase 2 Orchestrator
# Spinner + live logs + horizontal package view

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# ------------------------------
# Source UI + common functions
# ------------------------------
source "$SCRIPT_DIR/../lib/ui.sh"
source "$SCRIPT_DIR/../lib/common.sh"

LOG_DIR="${GINGER_LOGS:-$SCRIPT_DIR/../logs}"
mkdir -p "$LOG_DIR"


# ------------------------------
# Collect scripts and package names
# ------------------------------
SCRIPTS=("$SCRIPT_DIR/../phase2-tools"/*.sh)
# ------------------------------
# Build each package
# ------------------------------
# Simplified Phase 2 Orchestrator snippet:
for i in "${!SCRIPTS[@]}"; do
    PKG_NAME="${PKG_NAMES[$i]}"
    
    echo "Building: $PKG_NAME (Temp Tools)"

    if [ -f "$LFS/var/lib/ginger/$PKG_NAME-temp.built" ]; then
        continue
    fi

    bash "${SCRIPTS[$i]}"
    
    if [ $? -eq 0 ]; then
        touch "$LFS/var/lib/ginger/$PKG_NAME-temp.built"
    else
        exit 1
    fi
done
