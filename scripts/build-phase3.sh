#!/bin/bash
# GingerOS - Phase 3 (Inside Chroot) Orchestrator
# This script is meant to be run INSIDE the chroot environment.

# We can't source common.sh easily from here because paths have changed.
# But inside chroot, / is /mnt/lfs.
# We expect common.sh to be at /scripts/common.sh (relative to host $LFS)

# Re-define a simple log for inside chroot if common.sh isn't accessible
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$1] $2"
}

set -e
set -o pipefail

log "INFO" "Inside Chroot: Starting Phase 3 (Final System Build)..."

# Sanity Check: Ensure we ARE in chroot and not on the host!
if [ ! -f /usr/bin/bash ] || [ "$(id -u)" != "0" ]; then
    log "ERROR" "Sanity check failed! Are you sure you are running this inside the chroot as root?"
    exit 1
fi

# We need to source environment variables again
# They are at /config/env.sh (host $LFS/config/env.sh)
source /config/env.sh

# Marker for log location inside chroot
LOG_DIR="/logs"
mkdir -p "$LOG_DIR"

# Loop through Phase 3 scripts
# Scripts are at /scripts/phase3-system/*.sh (host $LFS/scripts/phase3-system/*.sh)
for script in /scripts/phase3-system/*.sh; do
    log "INFO" "Running $script..."
    
    # Check if already built (using the marker path from common.sh logic)
    # Inside chroot, marker path is /var/lib/ginger
    PKG_NAME=$(basename "$script" .sh)
    if [ -f "/var/lib/ginger/$PKG_NAME.built" ]; then
        log "INFO" "$PKG_NAME already built. Skipping."
        continue
    fi

    if ! time bash "$script" 2>&1 | tee "$LOG_DIR/$PKG_NAME.log"; then
        log "ERROR" "Build failed during $script. Check $LOG_DIR/$PKG_NAME.log"
        exit 1
    fi
done

log "INFO" "Phase 3 complete! Your system is now built."
