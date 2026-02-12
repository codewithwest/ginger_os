#!/bin/bash
# Test script for GingerOS UI - Complex Substep Scenario
# Simulates the structure of 'ginger_os.sh' with the new sub-step requirement.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/scripts/lib/ui.sh"

GINGER_OS_ROOT="$PROJECT_ROOT"
STATE_DIR="$GINGER_OS_ROOT/.build_state_test"
mkdir -p "$STATE_DIR"

# --- Simulating ginger_os.sh structure ---

# 1. Define Major Steps
UI_STEPS=("Prep" "Host Tools" "Phase 1" "Phase 2" "Phase 3" "Kernel")
UI_CURRENT_STEP=0

# 2. Mock 'run_step' but with sub-step support
run_step_SIM() {
    local SUB_STEP_NAME="$1"
    local DESCRIPTION="$2"
    
    # In the real script, this would be passed or we'd map "01_permissions" to "Permissions"
    # For this test, we assume the user wants readable names in the UI.
    
    # Update status to running
    ui_set_substep "$DESCRIPTION" "running"
    ui_log "Starting $DESCRIPTION..."
    
    sleep 0.5 # Simulate work
    
    # Update status to done
    ui_set_substep "$DESCRIPTION" "done"
    ui_log "Finished $DESCRIPTION."
}

# --- Execution ---

# Hide cursor
tput civis

# Initialize Dashboard (Major)
ui_init_dashboard 
# Note: In reality ginger_os.sh sets UI_STEPS manually, but ui_init_dashboard 
# should probably handle the initial clear/draw.

# Start "Prep" (Index 0)
UI_CURRENT_STEP=0

# Initialize Sub-steps for "Prep"
# This is the KEY NEW FEATURE
ui_init_substeps "Permissions" "Host Reqs" "Version Check" "Prepare Image" "Download Sources" "Host Setup" "Setup LFS Env"

# Run through them
run_step_SIM "01_permissions" "Permissions"
run_step_SIM "02_host_reqs" "Host Requirements" # "Host Reqs" in init, "Host Requirements" here? Needs to match exact string or index.
# Let's assume exact string matching for now to be safe.
# Retrying with exact matches from init
run_step_SIM "02_host_reqs" "Host Reqs"
run_step_SIM "03_version_check" "Version Check"
run_step_SIM "04_prepare_image" "Prepare Image"

# Simulate a failure? No, let's just show success for now.
run_step_SIM "05_download" "Download Sources"

# Move to next major step?
# UI_CURRENT_STEP=1
# run_step_SIM ...

tput cnorm
echo ""
echo "Test Complete."
