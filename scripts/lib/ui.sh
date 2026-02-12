#!/bin/bash
# GingerOS UI - Table + live logs

# Colors
ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Max log lines shown
LOG_LINES=15

# State
UI_STEPS=()
CURRENT_STEP=0
CURRENT_PHASE_POGS=()

# ASCII header
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

# Initialize dashboard
ui_init_dashboard() {
    UI_STEPS=("$@")
}

# Draw the table
ui_draw_table() {
    local left_width=20
    local right_width=50

    echo -e "${BOLD}SYSTEM PROGRESS${NC} | ${BOLD}PHASE PACKAGES${NC}"
    echo -e "--------------------+--------------------------------------------------"

    local max_rows=${#CURRENT_PHASE_POGS[@]}
    for i in "${!UI_STEPS[@]}"; do
        local step_marker="[ ]"
        if [ "$i" -lt "$CURRENT_STEP" ]; then
            step_marker="${LASER_GREEN}[✓]${NC}"
        elif [ "$i" -eq "$CURRENT_STEP" ]; then
            step_marker="${ELECTRIC_BLUE}[▶]${NC}"
        fi

        # Grab the package for this row (if exists)
        local pkg=""
        if [ $i -eq $CURRENT_STEP ] && [ $i -lt $max_rows ]; then
            pkg="${CURRENT_PHASE_POGS[$i]}"
        fi

        printf "%-${left_width}s | %s\n" "$step_marker ${UI_STEPS[$i]}" "$pkg"
    done
    echo ""
}

# Update packages (pogs) in current phase
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
    ui_draw_header
    ui_draw_table
}

# Run a command with live log and update pogs
ui_run_step() {
    local CMD="$1"
    local STEP_NAME="$2"
    local LOG_FILE="$3"

    : > "$LOG_FILE"

    # Run command in background
    bash -c "$CMD" > >(tee -a "$LOG_FILE") 2>&1 &
    local PID=$!

    # Spinner + live log
    local spinstr='|/-\\'
    local delay=0.1
    while kill -0 "$PID" 2>/dev/null; do
        # Last LOG_LINES for pog updates
        mapfile -t POGS < <(tail -n "$LOG_LINES" "$LOG_FILE" | awk '{print $1}')
        ui_update_phase_pogs "${POGS[@]}"

        local temp=${spinstr#?}
        printf "\r ${ELECTRIC_BLUE}[%c] %s${NC}" "${spinstr:0:1}" "$STEP_NAME"
        spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
    done

    wait "$PID"
    local RET=$?

    # Final update
    ui_update_phase_pogs "${POGS[@]/%/[✓]}"
    echo ""
    return $RET
}


# ------------------------------
# Wrapper to run steps with logs and timer
# ------------------------------


ui_confirm() {
    local msg=$1
    echo -ne "${LASER_GREEN}${BOLD}$msg (type 'yes'): ${NC}"
    read CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${RED}Aborted.${NC}"
        exit 0
    fi
}

ui_log() {
    echo -e "${LASER_GREEN}[INFO]${NC} $1"
}

ui_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

ui_input() {
    local prompt=$1
    local var_name=$2
    echo -ne "${ELECTRIC_BLUE}${BOLD}$prompt: ${NC}"
    read $var_name
}

ui_password() {
    local prompt=$1
    local var_name=$2
    echo -ne "${ELECTRIC_BLUE}${BOLD}$prompt: ${NC}"
    read -s $var_name
    echo ""
}

ui_step() {
    UI_CURRENT_STEP=$1
    ui_banner
}

ui_spinner() {
    local pid=$1
    local msg=$2
    local delay=0.1
    local spinstr='|/-\\'  # note the escaped backslash

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
        echo -e "\r${LASER_RED}[✗] $msg failed!${NC}"
    fi

    return $exit_code
}
