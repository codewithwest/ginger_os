#!/bin/bash
# GingerOS - Main Build Orchestrator

source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"

# 1. Download sources
# bash scripts/download.sh

# 2. Host Setup (Must be run as root initially)
if [ "$USER" != "root" ]; then
    log "WARN" "Host setup requires root. Please run 'sudo ./scripts/setup-host.sh' manually if not done."
fi

# 3. Phase 1 - Cross Toolchain
log "INFO" "Starting Phase 1: Cross Toolchain..."
for script in scripts/phase1-tools/*.sh; do
    log "INFO" "Running $script..."
    if ! bash "$script" 2>&1 | tee "$GINGER_LOGS/$(basename $script .sh).log"; then
        log "ERROR" "Build failed during $script. Check $GINGER_LOGS/$(basename $script .sh).log"
        exit 1
    fi
done

# 4. Phase 2 - Temporary Tools
log "INFO" "Starting Phase 2: Temporary Tools..."
for script in scripts/phase2-tools/*.sh; do
    log "INFO" "Running $script..."
    bash "$script" 2>&1 | tee -a "$GINGER_LOGS/$(basename $script).log"
done

# 5. Chroot and Phase 3 - Building Final System
log "INFO" "Phase 2 complete."
log "INFO" "Proceed to setup chroot with sudo ./chroot.sh"
# Further automation inside chroot would follow.
