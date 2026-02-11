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

    # For steps that require the filesystem to be mounted, ensure it is.
    # We start requiring mounts after prepare_image (Step 04)
    if [[ "$STEP_NAME" =~ ^(05|06|07|09|10|11|12|13|14) ]]; then
        ensure_mounted
    fi

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

# Ensure LFS is mounted if we are resuming
ensure_mounted() {
    # Part 1: Ensure LFS base is mounted
    if ! mountpoint -q "$LFS"; then
        log "WARN" "LFS is not mounted but we are past the preparation stage. Re-mounting..."
        IMAGE_PATH="$GINGER_ROOT/ginger_os.img"
        if [ -f "$IMAGE_PATH" ]; then
            LOOP_DEV=$(sudo losetup -j "$IMAGE_PATH" | cut -d: -f1 | head -n 1)
            if [ -z "$LOOP_DEV" ]; then
                LOOP_DEV=$(sudo losetup -fP --show "$IMAGE_PATH")
            fi
            [ -d "$LFS" ] || sudo mkdir -p "$LFS"
            sudo mount "${LOOP_DEV}p1" "$LFS"
            
            # Only chown if the lfs user actually exists
            if id lfs >/dev/null 2>&1; then
                sudo chown -v lfs:lfs "$LFS"
            fi
            log "INFO" "Successfully re-mounted $LFS"
        else
            log "ERROR" "Disk image not found at $IMAGE_PATH. Cannot resume."
            exit 1
        fi
    fi

    # Part 2: Ensure chroot mounts are present
    if [[ "$STEP_NAME" =~ ^(12|13|14) ]] && [[ "$STEP_NAME" != "12_chroot_mounts" ]]; then
        if ! mountpoint -q "$LFS/proc"; then
            log "WARN" "Chroot mounts missing. Running chroot.sh..."
            sudo bash chroot.sh
        fi
    fi
}

log "INFO" "Starting GingerOS Build Process..."

# 1. Permissions
run_step "01_permissions" "chmod -R 777 ."

# 2. Host Requirements (Creates 'lfs' user)
run_step "02_host_reqs" "bash ./scripts/host-requirements-install.sh"

# 3. Version Check
run_step "03_version_check" "bash ./scripts/version-check.sh"

# 4. Prepare Image
run_step "04_prepare_image" "bash ./scripts/prepare-image.sh"

# 5. Download Sources
run_step "05_download_sources" "bash ./scripts/download.sh"

# 6. Host Setup
run_step "06_host_setup" "bash ./scripts/setup-host.sh"

# 7. Update Directory
run_step "07_update_dir" "bash ./scripts/update-dir.sh"

# 9. Setup LFS User Environment
run_step "09_setup_lfs_env" "bash scripts/run-as-lfs.sh $SCRIPT_DIR/setup-lfs-user-env.sh"

# 10. Phase 1 - Temporary Toolchain
run_step "10_phase1_toolchain" "bash scripts/run-as-lfs.sh $SCRIPT_DIR/build-phase1.sh"

# 11. Phase 2 - Temporary System
run_step "11_phase2_toolchain" "bash scripts/run-as-lfs.sh $SCRIPT_DIR/build-phase2.sh"

# 12. Chroot Mounts
run_step "12_chroot_mounts" "bash chroot.sh"

# 13. Phase 3 - System Tools
run_step "13_phase3_system" "sudo chroot "$LFS" /bin/bash -c \"bash scripts/build-phase3.sh\""

# 14. Kernel
run_step "14_kernel" "sudo chroot "$LFS" /bin/bash -c \"bash scripts/phase4-boot/01-kernel.sh\""

# 15. GRUB & Finalize
run_step "15_grub" "bash scripts/phase4-boot/02-grub.sh"

# 16. Teardown
run_step "16_teardown" "bash scripts/teardown.sh"

log "INFO" "GingerOS build process finished successfully!"
