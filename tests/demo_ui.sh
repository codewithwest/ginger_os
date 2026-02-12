#!/bin/bash
# GingerOS - UI Stability Demo
# This script simulates a real build to demonstrate the "k9s-like" stability.

# Source the UI library
source ./scripts/lib/ui.sh

# Mock config
GINGER_OS_ROOT=$(pwd)
LOG_FILE="/tmp/ginger_demo.log"
: > "$LOG_FILE"

# --- Setup ---
UI_STEPS=("Prep" "Host Tools" "Phase 1" "Phase 2" "Phase 3" "Kernel")
ui_init_dashboard "${UI_STEPS[@]}"

# --- Helper to simulate work ---
simulate_work() {
    local phase_name="$1"
    local steps=("${@:2}")
    
    ui_init_substeps "${steps[@]}"
    
    for step in "${steps[@]}"; do
        ui_set_substep "$step" "running"
        
        # Simulate logs for this step
        for i in {1..15}; do
            ui_log "[$phase_name] $step: Processing item $i/15..."
            echo "Detailed log output for $step line $i..." >> "$LOG_FILE"
            
            # Artificial delay to show smoothness
            sleep 0.05 
        done
        
        ui_set_substep "$step" "done"
        sleep 0.2
    done
}

# --- Demo Sequence ---

# Step 0: Prep
ui_step 0
simulate_work "Prep" "Permissions" "Host Reqs" "Download Sources"

# Step 1: Host Tools
ui_step 1
simulate_work "Host Tools" "Setup LFS Env" "Build Cross-Tools"

# Step 2: Phase 1
ui_step 2
simulate_work "Phase 1" "Binutils" "GCC Pass 1" "Linux Headers"

# Step 3: Phase 2
ui_step 3
simulate_work "Phase 2" "Libstd++" "Gettext" "Bison" "Perl"

# Finish
ui_log "Demo Complete! The UI should have been rock solid."
sleep 2
tput cnorm
clear
