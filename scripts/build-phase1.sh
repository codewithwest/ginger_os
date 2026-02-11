#!/bin/bash
# GingerOS - Main Build Orchestrator
# 
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

# 1. Download sources
# bash scripts/download.sh




set -e
set -o pipefail

# 3. Phase 1 - Cross Toolchain
log "INFO" "Starting Phase 1: Cross Toolchain..."
for script in scripts/phase1-tools/*.sh; do
    # Extract the base name (e.g., 01-binutils-pass1)
    SCRIPT_NAME=$(basename "$script" .sh)
    # Extract the LFS package name (everything after the first hyphen)
    # e.g., binutils-pass1
    PKG_NAME=$(echo "$SCRIPT_NAME" | cut -d'-' -f2-)

    if [ -f "$LFS/var/lib/ginger/$PKG_NAME.built" ]; then
        log "INFO" "$PKG_NAME already built. Skipping."
        continue
    fi

    log "INFO" "Running $script..."
    if ! time bash "$script" 2>&1 | tee "$GINGER_LOGS/$SCRIPT_NAME.log"; then
        log "ERROR" "Build failed during $script. Check $GINGER_LOGS/$SCRIPT_NAME.log"
        exit 1
    fi
done



