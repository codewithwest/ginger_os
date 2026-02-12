#!/bin/bash
# GingerOS - Phase 2 Orchestrator
# Spinner + live logs + horizontal package view

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# ------------------------------
# Source UI + common functions
# ------------------------------
source "$SCRIPT_DIR/../lib/ui.sh"
source "$SCRIPT_DIR/../lib/common.sh"

LOG_DIR="${GINGER_LOGS:-$SCRIPT_DIR/../logs}"
mkdir -p "$LOG_DIR"


# ------------------------------
# Collect scripts and package names
# ------------------------------
SCRIPTS=("$SCRIPT_DIR/../phase2-tools"/*.sh)
PKG_NAMES=()
for s in "${SCRIPTS[@]}"; do
    PKG_NAMES+=("$(basename "$s" .sh | cut -d'-' -f2-)")
done

CURRENT_PHASE_POGS=()
ui_init_dashboard "Phase 2"

ui_draw_header
echo -e "${LASER_GREEN}${BOLD}Starting Phase 2: Temporary Tools...${NC}"

# Draw dashboard + pogs + last LOG_LINES
draw_phase2_dashboard() {
    clear  # clear screen once per refresh
    # Header / ASCII logo
    echo -e "${ELECTRIC_BLUE}${BOLD}"
    echo " _____ _                         ____   ____"
    echo " / ____(_)                       / __ \ / ____|"
    echo "| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ "
    echo "| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\"
    echo "| |__| | | | | | (_| |  __/ |   | |__| |____) |"
    echo " \\_____|_|_| |_|\__, |\___|_|    \\____/|_____/"
    echo "                 __/ |                         "
    echo "                |___/         v1.0              "
    echo -e "${NC}\n"

    # Phase + pogs row
    echo -n "SYSTEM PROGRESS        | CURRENT PHASE PACKAGES"
    echo -e "\n-----------------------+---------------------------------------------------------------------------------"

    # pogs row (single line)
    printf "${ELECTRIC_BLUE}[▶] Phase 2${NC} | "
    for pog in "${CURRENT_PHASE_POGS[@]}"; do
        printf "%s " "$pog"
    done
    echo -e "\n-----------------------+---------------------------------------------------------------------------------\n"

    # Last log lines
    tail -n $LOG_LINES "$1"
}

# ------------------------------
# Build each package
# ------------------------------
for i in "${!SCRIPTS[@]}"; do
    script="${SCRIPTS[$i]}"
    PKG_NAME="${PKG_NAMES[$i]}"
    SCRIPT_NAME=$(basename "$script" .sh)

    ui_step 0  # Highlight Phase 2
    # Update pogs with running package
    CURRENT_PHASE_POGS=()
    for j in "${!PKG_NAMES[@]}"; do
        if [ $j -lt $i ]; then
            CURRENT_PHASE_POGS+=("${LASER_GREEN}[✓] ${PKG_NAMES[$j]}${NC}")
        elif [ $j -eq $i ]; then
            CURRENT_PHASE_POGS+=("${ELECTRIC_BLUE}[▶] ${PKG_NAMES[$j]}${NC}")
        else
            CURRENT_PHASE_POGS+=("[ ] ${PKG_NAMES[$j]}")
        fi
    done
    draw_phase2_dashboard "$log_file"
    sleep 0.3


    # Skip if already built
    if [ -f "$LFS/var/lib/ginger/$PKG_NAME.built" ] || [ -f "$LFS/var/lib/ginger/$PKG_NAME-temp.built" ]; then
        ui_log "$PKG_NAME already built. Skipping."
        continue
    fi

    log_file="$LOG_DIR/$SCRIPT_NAME.log"
    : > "$log_file"

    # Run the build in background
    bash "$script" > >(tee -a "$log_file") 2>&1 &
    PID=$!

    # ------------------------------
    # Spinner + live log tail
    # ------------------------------
    while kill -0 "$PID" 2>/dev/null; do
        # Draw pogs again in case log updated
        ui_draw_dashboard
        tail -n $LOG_LINES "$log_file"
        sleep 0.2
        tput cuu $((LOG_LINES + ${#PKG_NAMES[@]} + 3))  # move cursor back up
    done

    wait "$PID"
    RET=$?

    # Mark as completed
    if [ $RET -eq 0 ]; then
        touch "$LFS/var/lib/ginger/$PKG_NAME-temp.built"
        ui_log "Successfully installed $PKG_NAME"
    else
        ui_error "Build failed: $PKG_NAME. Check $log_file"
    fi
done

ui_draw_header
echo -e "${LASER_GREEN}${BOLD}PHASE 2 (TEMPORARY TOOLS) COMPLETE!${NC}"
echo -e "\nNext step: sudo ./chroot.sh \"/scripts/build-phase3.sh\"\n"
