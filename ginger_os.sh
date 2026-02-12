#!/bin/bash
# GingerOS Main Orchestrator

# Secure the Root Path
GINGER_OS_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
STATE_DIR="$GINGER_OS_ROOT/.build_state"
mkdir -p "$STATE_DIR"

# Source the UI library using absolute path
source "$GINGER_OS_ROOT/scripts/lib/ui.sh"

# Define the build steps for the table
UI_STEPS=("Prep" "Host Tools" "Phase 1" "Phase 2" "Phase 3" "Kernel")
UI_CURRENT_STEP=0

get_step_index() {
    case $1 in
        "prep") echo 0 ;;
        "host_tools") echo 1 ;;
        "phase1") echo 2 ;;
        "phase2") echo 3 ;;
        "phase3") echo 4 ;;
        "kernel") echo 5 ;;
        *) echo 0 ;;
    esac
}

run_step() {
    local STEP_NAME="$1"
    local CMD="$2"
    LOG_FILE="$STATE_DIR/$STEP_NAME.log"
    UI_CURRENT_STEP=$(get_step_index "$STEP_NAME")
    
    # Ensure log is fresh
    : > "$LOG_FILE"

    # Start the worker in background
    eval "$CMD" >> "$LOG_FILE" 2>&1 &
    local PID=$!

    tput civis
    while kill -0 $PID 2>/dev/null; do
        # Extract the current progress from the log
        CURRENT_PKG=$(tail -n 1 "$LOG_FILE" | sed 's/[^[:print:]]//g' | cut -c 1-50)
        [ -z "$CURRENT_PKG" ] && CURRENT_PKG="Working..."
        
        ui_draw_dashboard
        sleep 0.2
    done
    tput cnorm
    
    wait $PID
    if [ $? -ne 0 ]; then
        echo -e "${LASER_RED}Error in $STEP_NAME. Log: $LOG_FILE${NC}"
        exit 1
    fi
}

# --- Build Sequence ---
clear
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
