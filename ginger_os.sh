#!/bin/bash
# GingerOS Build Script - Automated & Fail-proof
# This script manages the entire build process with state tracking to allow resuming.

# Ensure we are in the script's directory or project root
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$SCRIPT_DIR"

# Source common functions
if [ -f "./scripts/common.sh" ]; then
    source ./scripts/common.sh
else
    echo "Error: ./scripts/common.sh not found. key scripts missing?"
    exit 1
fi

# State directory for tracking progress
STATE_DIR="$SCRIPT_DIR/.build_state"
mkdir -p "$STATE_DIR"

# Function to run a step idempotently
run_step() {
    local STEP_NAME="$1"
    local CMD="$2"
    local STEP_FILE="$STATE_DIR/$STEP_NAME"

    if [ -f "$STEP_FILE" ]; then
        log "INFO" "Step '$STEP_NAME' already completed. Skipping."
    else
        log "PROCESS" "Starting Step: $STEP_NAME"
        log "INFO" "Command: $CMD"
        
        # Execute the command
        eval "$CMD"
        local RET=$?
        
        if [ $RET -eq 0 ]; then
            touch "$STEP_FILE"
            log "INFO" "Step '$STEP_NAME' completed successfully."
        else
            log "ERROR" "Step '$STEP_NAME' failed with exit code $RET."
            exit $RET
        fi
    fi
}

log "INFO" "Starting GingerOS Build Process..."

# 1. Permissions (Always run specific checks or skip if done)
run_step "01_permissions" "chmod -R 777 ."

# 2. Prepare Image (CLEANS EVERYTHING - so handle with care)
# If image exists and step is marked, we skip.
run_step "02_prepare_image" "bash ./scripts/prepare-image.sh"

# 3. Download Sources
run_step "03_download_sources" "bash ./scripts/download.sh"

# 4. Host Setup
# Fixed path: host-setup.sh -> setup-host.sh
run_step "04_host_setup" "bash ./scripts/setup-host.sh"

# 5. Update Directory
run_step "05_update_dir" "bash ./scripts/update-dir.sh"

# 6. Host Requirements
run_step "06_host_reqs" "bash ./scripts/host-requirements-install.sh"

# 7. Version Check
run_step "07_version_check" "bash ./scripts/version-check.sh"

# 9. Setup LFS User Environment
# Note: 'su - lfs' resets CWD. We must ensure the script is accessible.
# Using absolute path for safety if possible, or assuming lfs user can access $SCRIPT_DIR.
# We'll pass the full path to the script to ensure it's found.
# Fixed path: setup-ls-user-env -> setup-lfs-user-env.sh
run_step "09_setup_lfs_env" "bash scripts/run-as-lfs.sh $SCRIPT_DIR/setup-lfs-user-env.sh"

# 10. Phase 1 - Temporary Toolchain
run_step "10_phase1_toolchain" \
  "bash scripts/run-as-lfs.sh $SCRIPT_DIR/build-phase1.sh"

# 11. Phase 2 - Temporary System
run_step "11_phase2_toolchain" \
  "bash scripts/run-as-lfs.sh $SCRIPT_DIR/build-phase2.sh"

# 12. Chroot Mounts
run_step "12_chroot_mounts" "bash chroot.sh"


# 12. Phase 3 - System Tools
run_step "12_phase3_system" "sudo chroot "$LFS" /bin/bash -c \"bash scripts/build-phase3.sh\""

# 13. Kernel
run_step "13_kernel" "sudo chroot "$LFS" /bin/bash -c \"bash scripts/phase4-boot/01-kernel.sh\""

# # 14. GRUB
# run_step "14_grub" "bash scripts/phase4-boot/02-grub.sh"

# # 15. Teardown
# run_step "15_teardown" "bash scripts/teardown.sh"

# 16. Finalize Image
run_step "16_finalize_image" "bash scripts/finalize-image.sh"

log "INFO" "GingerOS build process finished successfully!"
