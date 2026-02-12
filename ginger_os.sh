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
ui_init_dashboard "${UI_STEPS[@]}"

# Helper to run a step with UI updates
run_step() {
    local STEP_ID="$1"
    local STEP_NAME="$2"
    local CMD="$3"
    
    LOG_FILE="$STATE_DIR/$STEP_ID.log"
    
    # Update UI
    ui_set_substep "$STEP_NAME" "running"
    ui_log "Starting $STEP_NAME..."
    
    # Ensure log is fresh
    : > "$LOG_FILE"

    # Start the worker in background
    eval "GINGER_UI_HEADLESS=1 $CMD" >> "$LOG_FILE" 2>&1 &
    local PID=$!

    tput civis
    while kill -0 $PID 2>/dev/null; do
        # Extract the current progress from the log
        local last_line=$(tail -n 1 "$LOG_FILE" | sed 's/[^[:print:]]//g' | cut -c 1-50)
        [ -n "$last_line" ] && CURRENT_PKG="$last_line"
        
        ui_draw_dashboard
        sleep 0.2
    done
    tput cnorm
    
    wait $PID
    if [ $? -ne 0 ]; then
        ui_set_substep "$STEP_NAME" "failed"
        ui_error "Error in $STEP_NAME. Log: $LOG_FILE"
    fi
    
    ui_set_substep "$STEP_NAME" "done"
}

# --- STEP 1: PREP ---
ui_step 0
ui_init_substeps "Permissions" "Host Reqs" "Version Check" "Prepare Image" "Download Sources" "Host Setup" "Update Dir"

run_step "01_permissions"    "Permissions"      "chmod -R 777 ."
run_step "02_host_reqs"      "Host Reqs"        "bash ./scripts/host/host-requirements-install.sh"
run_step "03_version_check"  "Version Check"    "bash ./scripts/host/version-check.sh"
run_step "04_prepare_image"  "Prepare Image"    "bash ./scripts/image/prepare-image.sh"
run_step "05_download_sources" "Download Sources" "bash ./scripts/host/download.sh"
run_step "06_host_setup"     "Host Setup"       "bash ./scripts/host/setup-host.sh"
run_step "07_update_dir"     "Update Dir"       "bash ./scripts/host/update-dir.sh"

# --- STEP 2: HOST TOOLS ---
ui_step 1
ui_init_substeps "Setup LFS Env"

run_step "09_setup_lfs_env"  "Setup LFS Env"    "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/setup-lfs-user-env.sh"

# --- STEP 3: PHASE 1 ---
ui_step 2
# Phase 1 script manages its own internal progress/substeps if needed, or we just show it running.
# run_step "10_phase1_toolchain" "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/build-phase1.sh"
# BUT wait, run_step now requires 3 args and expects substeps.
# We should probably init a single substep for these big phases if they don't do it themselves.
ui_init_substeps "Toolchain Build"
run_step "10_phase1_toolchain" "Toolchain Build" "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/build-phase1.sh"

# --- STEP 4: PHASE 2 ---
ui_step 3
ui_init_substeps "Cross Tools"
run_step "11_phase2_toolchain" "Cross Tools" "bash scripts/host/run-as-lfs.sh $GINGER_OS_ROOT/scripts/phases/build-phase2.sh"

# --- STEP 5: PHASE 3 ---
ui_step 4
# Phase 3 script (build-phase3.sh) calls ui_init_dashboard itself!
# We should let it take over? Or just wrap it?
# If it calls ui_init_dashboard, it resets everything.
# For now, let's treat it as a black box substep.
# To properly integrate, build-phase3.sh should probably NOT reset the dashboard but just update substeps.
# But for now, let's just run it.
run_step "12_chroot_mounts" "Mount Chroot" "bash chroot.sh"
sudo ls "$LFS/scripts"
ui_init_substeps "System Build"
run_step "13_phase3_system" "System Build" "sudo chroot \"$LFS\" /bin/bash -c \"bash scripts/phases/build-phase3.sh\""

# --- STEP 6: KERNEL ---
ui_step 5
ui_init_substeps "Kernel Build" "Grub Setup" "Teardown"

run_step "14_kernel"   "Kernel Build" "sudo chroot \"$LFS\" /bin/bash -c \"bash scripts/phases/build-phase4.sh\""
run_step "15_grub"     "Grub Setup"   "bash scripts/phase4-boot/02-grub.sh"
run_step "16_teardown" "Teardown"     "bash scripts/image/teardown.sh"

ui_draw_header
echo -e "${LASER_GREEN}${BOLD}--------------------------------------------------"
echo "    GINGEROS CORE BUILD COMPLETED SUCCESSFULLY     "
echo -e "--------------------------------------------------${NC}"
echo -e "\nYou are now ready to run 'sudo bash scripts/iso/make-iso.sh'\n"

ui_log "Main Build Pipeline Finished Successfully."
