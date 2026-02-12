#!/bin/bash
# GingerOS Build Script - Automated & Fail-proof
# This script manages the entire build process with state tracking to allow resuming.

# Ensure we are in the script's directory or project root
GINGER_OS_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$GINGER_OS_ROOT"

# Source common and UI functions
if [ -f "./scripts/lib/common.sh" ]; then
    source ./scripts/lib/common.sh
    source ./scripts/lib/ui.sh
else
    echo "Error: ./scripts/lib/common.sh not found."
    exit 1
fi

# Define the build roadmap for the dashboard
ui_init_dashboard "Prep" "Host Tools" "Environment" "Download" "Phase 1" "Phase 2" "Chroot" "Phase 3" "Kernel" "Finalize" "Teardown"

# State directory for tracking progress
STATE_DIR="$GINGER_OS_ROOT/.build_state"
mkdir -p "$STATE_DIR"

# Mapping specific step numbers to dashboard indices
get_step_index() {
    case $1 in
        01*|02*|03*) echo 0 ;; # Prep
        04*)          echo 2 ;; # Environment
        05*)          echo 3 ;; # Download
        06*|07*)      echo 1 ;; # Host Tools
        09*)          echo 2 ;; # Environment (Setup LFS)
        10*)          echo 4 ;; # Phase 1
        11*)          echo 5 ;; # Phase 2
        12*)          echo 6 ;; # Chroot
        13*)          echo 7 ;; # Phase 3
        14*)          echo 8 ;; # Kernel
        15*)          echo 9 ;; # Finalize
        16*)          echo 10 ;; # Teardown
        *)            echo 0 ;; # Fallback
    esac
}

# Function to run a step idempotently
run_step() {
    local STEP_NAME="$1"
    local CMD="$2"
    local STEP_FILE="$STATE_DIR/$STEP_NAME"
    
    local IDX=$(get_step_index "$STEP_NAME")
    ui_step "$IDX"

    # For steps that require the filesystem to be mounted, ensure it is.
    # We start requiring mounts after prepare_image (Step 04)
    if [[ "$STEP_NAME" =~ ^(05|06|07|09|10|11|12|13|14) ]]; then
        ensure_mounted
    fi

    if [ -f "$STEP_FILE" ]; then
        ui_log "Step '$STEP_NAME' already completed. Skipping."
    else
        ui_log "Starting: $STEP_NAME"
        
        # Execute the command
        eval "$CMD"
        local RET=$?
        
        if [ $RET -eq 0 ]; then
            touch "$STEP_FILE"
            ui_log "Success: $STEP_NAME"
        else
            ui_error "Step '$STEP_NAME' failed. Build halted."
        fi
    fi
}

# Ensure LFS is mounted if we are resuming
ensure_mounted() {
    # Part 1: Ensure LFS base is mounted
    if ! mountpoint -q "$LFS"; then
        ui_log "LFS is not mounted. Re-mounting image..."
        IMAGE_PATH="$GINGER_ROOT/ginger_os.img"
        if [ -f "$IMAGE_PATH" ]; then
            LOOP_DEV=$(sudo losetup -j "$IMAGE_PATH" | cut -d: -f1 | head -n 1)
            if [ -z "$LOOP_DEV" ]; then
                LOOP_DEV=$(sudo losetup -fP --show "$IMAGE_PATH")
            fi
            [ -d "$LFS" ] || sudo mkdir -p "$LFS"
            sudo mount "${LOOP_DEV}p1" "$LFS"
            
            if id lfs >/dev/null 2>&1; then
                sudo chown -v lfs:lfs "$LFS"
            fi
            ui_log "Successfully re-mounted $LFS"
        else
            ui_error "Disk image not found at $IMAGE_PATH. Cannot resume build."
        fi
    fi

    # Part 2: Ensure chroot mounts are present
    if [[ "$STEP_NAME" =~ ^(12|13|14) ]] && [[ "$STEP_NAME" != "12_chroot_mounts" ]]; then
        if ! mountpoint -q "$LFS/proc"; then
            ui_log "Chroot mounts missing. Running chroot.sh..."
            sudo bash chroot.sh
        fi
    fi
}

ui_draw_header
echo -e "${ELECTRIC_BLUE}GingerOS Main Build System Engaged.${NC}"
echo "Ready to assemble the next generation of speed."
sleep 1

# 1. Permissions
run_step "01_permissions" "chmod -R 777 ."

# 2. Host Requirements (Creates 'lfs' user)
run_step "02_host_reqs" "bash ./scripts/host/host-requirements-install.sh"

# 3. Version Check
run_step "03_version_check" "bash ./scripts/host/version-check.sh"

# 4. Prepare Image
run_step "04_prepare_image" "bash ./scripts/image/prepare-image.sh"

# 5. Download Sources
run_step "05_download_sources" "bash ./scripts/host/download.sh"

# 6. Host Setup
run_step "06_host_setup" "bash ./scripts/host/setup-host.sh"

# 7. Update Directory
run_step "07_update_dir" "bash ./scripts/host/update-dir.sh"

# 9. Setup LFS User Environment
run_step "09_setup_lfs_env" "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/setup-lfs-user-env.sh"

# 10. Phase 1 - Temporary Toolchain
run_step "10_phase1_toolchain" "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/build-phase1.sh"

# 11. Phase 2 - Temporary System
run_step "11_phase2_toolchain" "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/build-phase2.sh"

# 12. Chroot Mounts
run_step "12_chroot_mounts" "bash chroot.sh"

sudo ls "$LFS/scripts"

# 13. Phase 3 - System Tools
run_step "13_phase3_system" "sudo chroot \"$LFS\" /bin/bash -c \"bash scripts/phases/build-phase3.sh\""


# 14. Kernel
run_step "14_kernel" "sudo chroot \"$LFS\" /bin/bash -c \"bash scripts/phases/build-phase4.sh\""

# 15. GRUB & Finalize
run_step "15_grub" "bash scripts/phase4-boot/02-grub.sh"

# 16. Teardown
run_step "16_teardown" "bash scripts/image/teardown.sh"

ui_draw_header
echo -e "${LASER_GREEN}${BOLD}--------------------------------------------------"
echo "    GINGEROS CORE BUILD COMPLETED SUCCESSFULY     "
echo -e "--------------------------------------------------${NC}"
echo -e "\nYou are now ready to run 'sudo bash scripts/iso/make-iso.sh'\n"

ui_log "Main Build Pipeline Finished Successfully."
