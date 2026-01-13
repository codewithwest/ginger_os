#!/bin/bash
# GingerOS - Main Build Orchestrator

source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"

# 1. Download sources
# bash scripts/download.sh




set -e
set -o pipefail

# 4. Phase 2 - Temporary Tools
log "INFO" "Starting Phase 2: Temporary Tools..."
for script in scripts/phase2-tools/*.sh; do
    log "INFO" "Running $script..."
    if ! time bash "$script" 2>&1 | tee "$GINGER_LOGS/$(basename $script .sh).log"; then
        log "ERROR" "Build failed during $script. Check $GINGER_LOGS/$(basename $script .sh).log"
        exit 1
    fi
done

# 5. Phase 2 Complete - Transition to Chroot
log "INFO" "========================================"
log "INFO" "PHASE 2 (TEMPORARY TOOLS) COMPLETE!"
log "INFO" "========================================"
log "INFO" "The next phase (Phase 3) requires entering the chroot environment."
log "INFO" "Since this requires root privileges, please run the following:"
log ""
log "INFO" "  sudo ./chroot.sh \"/scripts/build-phase3.sh\""
log ""
log "INFO" "Alternatively, for an interactive shell, run: sudo ./chroot.sh"
log "INFO" "========================================"
