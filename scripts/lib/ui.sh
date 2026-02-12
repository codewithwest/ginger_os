#!/bin/bash
# GingerOS UI - Modern Dashboard + Live Logs
# ------------------------------------------

# ANSI colors
ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

LOG_LINES=15

# Dashboard state
UI_STEPS=()
UI_CURRENT_STEP=0
CURRENT_PHASE_POGS=()

# ------------------------------
# Initialize dashboard
# ------------------------------
ui_init_dashboard() {
    UI_STEPS=("$@")
    UI_CURRENT_STEP=0
}

# ------------------------------
# ASCII Header
# ------------------------------
ui_draw_header() {
    clear
    echo -e "${ELECTRIC_BLUE}${BOLD}"
    echo "  _____ _                         ____   ____"
    echo " / ____(_)                       / __ \\ / ____|"
    echo "| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ "
    echo "| | |_ | | '_ \\ / _\` |/ _ \\ '__|| |  | |\\___ \\"
    echo "| |__| | | | | | (_| |  __/ |   | |__| |____) |"
    echo " \\_____|_|_| |_|\\__, |\\___|_|    \\____/|_____/"
    echo "                 __/ |                         "
    echo "                |___/         v1.0             "
    echo -e "${NC}\n"
}

# ------------------------------
# Draw dashboard table
# ------------------------------
ui_draw_dashboard() {
    local left_width=25
    local right_width=60

    ui_draw_header
    echo -e "${BOLD}SYSTEM PROGRESS${NC} | ${BOLD}CURRENT PHASE PACKAGES${NC}"
    echo "------------------------+--------------------------------------------------"

    local max_rows=${#CURRENT_PHASE_POGS[@]}
    for i in "${!UI_STEPS[@]}"; do
        local marker="[ ]"
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker="${LASER_GREEN}[✓]${NC}"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            marker="${ELECTRIC_BLUE}[▶]${NC}"
        fi

        printf "%-${left_width}s | " "$marker ${UI_STEPS[$i]}"

        # Show package pogs for current step
        if [ "$i" -eq "$UI_CURRENT_STEP" ] && [ "${#CURRENT_PHASE_POGS[@]}" -gt 0 ]; then
            for pog in "${CURRENT_PHASE_POGS[@]}"; do
                printf "%s " "$pog"
            done
        fi
        echo ""
    done
    echo ""
}

# ------------------------------
# Update pogs for current phase
# ------------------------------
ui_update_phase_pogs() {
    local pogs=("$@")
    CURRENT_PHASE_POGS=()
    for p in "${pogs[@]}"; do
        if [[ "$p" =~ built ]]; then
            CURRENT_PHASE_POGS+=("${LASER_GREEN}[✓] $p${NC}")
        elif [[ "$p" =~ running ]]; then
            CURRENT_PHASE_POGS+=("${ELECTRIC_BLUE}[▶] $p${NC}")
        else
            CURRENT_PHASE_POGS+=("[ ] $p")
        fi
    done
    ui_draw_dashboard
}

# ------------------------------
# Run a step with spinner + live logs
# ------------------------------
ui_run_step() {
    local CMD="$1"
    local STEP_NAME="$2"
    local LOG_FILE="$3"

    : > "$LOG_FILE"

    # Launch command in background
    bash -c "$CMD" > >(tee -a "$LOG_FILE") 2>&1 &
    local PID=$!

    # Spinner + update pogs
    local spinstr='|/-\\'
    local delay=0.1
    while kill -0 "$PID" 2>/dev/null; do
        # Grab last LOG_LINES for pog display
        mapfile -t POGS < <(tail -n "$LOG_LINES" "$LOG_FILE" | awk '{print $1}')
        ui_update_phase_pogs "${POGS[@]}"

        local temp=${spinstr#?}
        printf "\r ${ELECTRIC_BLUE}[%c] %s${NC}" "${spinstr:0:1}" "$STEP_NAME"
        spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
    done

    wait "$PID"
    local RET=$?

    # Mark all pogs completed
    ui_update_phase_pogs "${POGS[@]/%/[✓]}"
    echo ""

    return $RET
}

# ------------------------------
# Simple logging and UI helpers
# ------------------------------
ui_log() {
    echo -e "${LASER_GREEN}[INFO]${NC} $1"
}

ui_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

ui_confirm() {
    local msg="$1"
    echo -ne "${LASER_GREEN}${BOLD}$msg (type 'yes'): ${NC}"
    read CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${RED}Aborted.${NC}"
        exit 0
    fi
}

ui_step() {
    UI_CURRENT_STEP="$1"
    ui_draw_dashboard
}

ui_spinner() {
    local pid=$1
    local msg=$2
    local delay=0.1
    local spinstr='|/-\\'

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r ${ELECTRIC_BLUE}[%c] %s${NC}" "${spinstr:0:1}" "$msg"
        spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
    done

    wait "$pid"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "\r${LASER_GREEN}[✓] $msg completed successfully.${NC}"
    else
        echo -e "\r${RED}[✗] $msg failed!${NC}"
    fi

    return $exit_code
}
