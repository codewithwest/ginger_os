#!/bin/bash
# GingerOS - Main Build Orchestrator

source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"

# 1. Download sources
# bash scripts/download.sh




set -e
set -o pipefail

# 3. Phase 1 - Cross Toolchain
log "INFO" "Starting Phase 1: Cross Toolchain..."
for script in scripts/phase1-tools/*.sh; do
    log "INFO" "Running $script..."
    if ! time bash "$script" 2>&1 | tee "$GINGER_LOGS/$(basename $script .sh).log"; then
        log "ERROR" "Build failed during $script. Check $GINGER_LOGS/$(basename $script .sh).log"
        exit 1
    fi
done
