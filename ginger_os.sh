#!/bin/bash
# GingerOS Build Script - Automated & Fail-proof
# This script manages the entire build process with state tracking, spinner, and live logs.

set -e
set -o pipefail

# ------------------------------
# Paths and initialization
# ------------------------------
GINGER_OS_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$GINGER_OS_ROOT"

STATE_DIR="$GINGER_OS_ROOT/.build_state"
mkdir -p "$STATE_DIR"

LOG_LINES=15  # number of log lines to show in dashboard

# Source common and UI functions
if [ -f "./scripts/lib/common.sh" ]; then
    source ./scripts/lib/common.sh
    source ./scripts/lib/ui.sh
else
    echo "Error: ./scripts/lib/common.sh not found."
    exit 1
fi

# ------------------------------
# Dashboard setup
# ------------------------------
ui_init_dashboard "Prep" "Host Tools" "Environment" "Download" \
                  "Phase 1" "Phase 2" "Chroot" "Phase 3" "Kernel" "Finalize" "Teardown"

# ------------------------------
# Map step names to dashboard indices
# ------------------------------
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

# ------------------------------
# Run a step with spinner + live logs
# ------------------------------
ui_run_step() {
    local CMD="$1"
    local STEP_NAME="$2"
    local LOG_FILE="$3"

    : > "$LOG_FILE"
    bash -c "$CMD" > >(tee -a "$LOG_FILE") 2>&1 &
    local PID=$!

    local spinstr='|/-\'
    local start_time=$(date +%s)

    while kill -0 "$PID" 2>/dev/null; do
        # spinner frame
        local frame=${spinstr:0:1}
        spinstr=${spinstr:1}${frame}

        # elapsed time
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        local min=$((elapsed / 60))
        local sec=$((elapsed % 60))

        # print spinner + step + elapsed
        printf "\r ${ELECTRIC_BLUE}[%c] %s | Elapsed: %02d:%02d${NC}\n" \
               "$frame" "$STEP_NAME" "$min" "$sec"

        # show last LOG_LINES from log
        tail -n $LOG_LINES "$LOG_FILE"

        sleep 0.2
        tput cuu $((LOG_LINES + 2))  # move cursor back
    done

    wait "$PID"
    return $?
}

# ------------------------------
# Run a build step idempotently
# ------------------------------
# ------------------------------
# Run a build step with dashboard, spinner, pogs, and logs
# ------------------------------
run_step() {
    local STEP_NAME="$1"
    local CMD="$2"
    local STEP_FILE="$STATE_DIR/$STEP_NAME"
    local LOG_FILE="$STATE_DIR/$STEP_NAME.log"

    IDX=$(get_step_index "$STEP_NAME")
    UI_CURRENT_STEP="$IDX"

    # Clear screen and draw dashboard
    ui_draw_dashboard

    if [ -f "$STEP_FILE" ]; then
        ui_log "Step '$STEP_NAME' already completed."
        return 0
    fi

    ui_log "Starting: $STEP_NAME"

    # Create empty log
    : > "$LOG_FILE"

    # Run command in background
    bash -c "$CMD" > >(tee -a "$LOG_FILE") 2>&1 &
    local PID=$!

    local spinstr='|/-\'
    local start_time=$(date +%s)

    # Live dashboard + logs
    while kill -0 "$PID" 2>/dev/null; do
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        local min=$((elapsed / 60))
        local sec=$((elapsed % 60))

        # Build pogs from last lines of log
        mapfile -t POGS < <(tail -n $LOG_LINES "$LOG_FILE" | awk '{print $1}')

        # Draw dashboard with pogs
        ui_update_phase_pogs "${POGS[@]}"

        # Spinner
        local frame=${spinstr:0:1}
        spinstr=${spinstr:1}${frame}
        tput cup 1 0
        printf "${ELECTRIC_BLUE}[%c] %s | Elapsed: %02d:%02d${NC}\n" \
               "$frame" "$STEP_NAME" "$min" "$sec"

        sleep 0.2
    done

    wait "$PID"
    local RET=$?

    # Mark step as done
    touch "$STEP_FILE"

    if [ $RET -eq 0 ]; then
        ui_log "Success: $STEP_NAME"
    else
        ui_error "Step '$STEP_NAME' failed. Check $LOG_FILE"
    fi
}


# ------------------------------
# Main Build Pipeline
# ------------------------------
ui_draw_header
echo -e "${ELECTRIC_BLUE}GingerOS Main Build System Engaged.${NC}"
echo "Ready to assemble the next generation of speed."
sleep 1

run_step "01_permissions" "chmod -R 777 ."
run_step "02_host_reqs" "bash ./scripts/host/host-requirements-install.sh"
run_step "03_version_check" "bash ./scripts/host/version-check.sh"
run_step "04_prepare_image" "bash ./scripts/image/prepare-image.sh"
run_step "05_download_sources" "bash ./scripts/host/download.sh"
run_step "06_host_setup" "bash ./scripts/host/setup-host.sh"
run_step "07_update_dir" "bash ./scripts/host/update-dir.sh"
run_step "09_setup_lfs_env" "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/setup-lfs-user-env.sh"
run_step "10_phase1_toolchain" "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/build-phase1.sh"
run_step "11_phase2_toolchain" "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/build-phase2.sh"
run_step "12_chroot_mounts" "bash chroot.sh"
sudo ls "$LFS/scripts"
run_step "13_phase3_system" "sudo chroot \"$LFS\" /bin/bash -c \"bash scripts/phases/build-phase3.sh\""
run_step "14_kernel" "sudo chroot \"$LFS\" /bin/bash -c \"bash scripts/phases/build-phase4.sh\""
run_step "15_grub" "bash scripts/phase4-boot/02-grub.sh"
run_step "16_teardown" "bash scripts/image/teardown.sh"

ui_draw_header
echo -e "${LASER_GREEN}${BOLD}--------------------------------------------------"
echo "    GINGEROS CORE BUILD COMPLETED SUCCESSFULLY     "
echo -e "--------------------------------------------------${NC}"
echo -e "\nYou are now ready to run 'sudo bash scripts/iso/make-iso.sh'\n"

ui_log "Main Build Pipeline Finished Successfully."
