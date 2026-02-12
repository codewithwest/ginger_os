#!/bin/bash
# GingerOS Main Orchestrator - Updated for Process-Safe UI v2.0

set -e

# ============================================================================
# SETUP
# ============================================================================

GINGER_OS_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
STATE_DIR="$GINGER_OS_ROOT/.build_state"
mkdir -p "$STATE_DIR"

# Source the UI library
source "$GINGER_OS_ROOT/scripts/lib/ui.sh"

# Set log file
export UI_LOG_FILE="$STATE_DIR/ginger_os_build.log"

# ============================================================================
# SUDO KEEPALIVE
# ============================================================================

sudo -v

ui_sudo_keepalive &
SUDO_KEEPALIVE_PID=$!

cleanup_sudo() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    fi
}
trap cleanup_sudo EXIT

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

run_step() {
    local STEP_ID="$1"
    local STEP_NAME="$2"
    local CMD="$3"
    
    LOG_FILE="$STATE_DIR/$STEP_ID.log"
    
    ui_status "$STEP_NAME - Running..."
    ui_log "Starting $STEP_NAME..."
    
    # Ensure log is fresh
    : > "$LOG_FILE"

    # Run command with output to log
    if eval "$CMD" >> "$LOG_FILE" 2>&1; then
        ui_log "$STEP_NAME completed successfully"
    else
        ui_log "ERROR: $STEP_NAME failed! Check log: $LOG_FILE"
        exit 1
    fi
}

# ============================================================================
# INITIALIZE UI
# ============================================================================

ui_init \
    "Preparation" \
    "Host Tools" \
    "Phase 1 Toolchain" \
    "Phase 2 Cross Tools" \
    "Phase 3 System" \
    "Kernel & Boot"

# ============================================================================
# STEP 0: PREPARATION
# ============================================================================

ui_step 0 "Preparing build environment..."

run_step "01_permissions" "Set Permissions" "chmod -R 755 ."
run_step "02_host_reqs" "Install Host Requirements" "bash ./scripts/host/host-requirements-install.sh"
run_step "03_version_check" "Version Check" "bash ./scripts/host/version-check.sh"
run_step "04_prepare_image" "Prepare Image" "bash ./scripts/image/prepare-image.sh"
run_step "05_download_sources" "Download Sources" "bash ./scripts/host/download.sh"
run_step "06_host_setup" "Host Setup" "bash ./scripts/host/setup-host.sh"
run_step "07_update_dir" "Update Directories" "bash ./scripts/host/update-dir.sh"

ui_log "Preparation phase complete"

# ============================================================================
# STEP 1: HOST TOOLS
# ============================================================================

ui_step 1 "Setting up LFS environment..."

run_step "09_setup_lfs_env" "Setup LFS Environment" \
    "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/setup-lfs-user-env.sh"

ui_log "Host tools phase complete"

# ============================================================================
# STEP 2: PHASE 1 TOOLCHAIN
# ============================================================================

ui_step 2 "Building Phase 1 toolchain..."

run_step "10_phase1_toolchain" "Toolchain Build" \
    "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/build-phase1.sh"

ui_log "Phase 1 toolchain complete"

# ============================================================================
# STEP 3: PHASE 2 CROSS TOOLS
# ============================================================================

ui_step 3 "Building Phase 2 cross tools..."

run_step "11_phase2_toolchain" "Cross Tools Build" \
    "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/build-phase2.sh"

ui_log "Phase 2 cross tools complete"

# ============================================================================
# STEP 4: PHASE 3 SYSTEM
# ============================================================================

ui_step 4 "Building Phase 3 system..."

run_step "12_chroot_mounts" "Mount Chroot" "bash chroot.sh"

ui_log "Verifying chroot environment"
sudo ls "$LFS/scripts" >> "$UI_LOG_FILE" 2>&1

run_step "13_phase3_system" "System Build" \
    "sudo chroot \"$LFS\" /bin/bash -c \"bash scripts/phases/build-phase3.sh\""

ui_log "Phase 3 system complete"

# ============================================================================
# STEP 5: KERNEL & BOOT
# ============================================================================

ui_step 5 "Building kernel and bootloader..."

run_step "14_kernel" "Kernel Build" \
    "sudo chroot \"$LFS\" /bin/bash -c \"bash scripts/phases/build-phase4.sh\""

run_step "15_grub" "Grub Setup" "bash scripts/phase4-boot/02-grub.sh"

run_step "16_teardown" "Teardown" "bash scripts/image/teardown.sh"

ui_log "Kernel and boot phase complete"

# ============================================================================
# FINISH
# ============================================================================

ui_finish

# ============================================================================
# SUCCESS MESSAGE
# ============================================================================

echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         🎉 GINGEROS BUILD COMPLETED SUCCESSFULLY 🎉        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo
echo "All build phases completed successfully!"
echo
echo "Next step:"
echo "  → Create ISO: sudo bash scripts/iso/make-iso.sh"
echo
echo "Build log: $UI_LOG_FILE"
echo
