#!/bin/bash
# GingerOS - Live Build Dashboard + Logs
# Supports vertical system progress, horizontal current phase packages, spinner, and live logs

# ------------------------------
# ANSI colors & config
# ------------------------------
ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
LASER_RED='\033[38;5;196m'
BOLD='\033[1m'
NC='\033[0m'

LOG_LINES=15          # lines of logs to display
POG_SCROLL_STEP=5     # horizontal scroll for packages

UI_STEPS=()
UI_CURRENT_STEP=0
CURRENT_PHASE_POGS=()
CURRENT_PHASE_POG_OFFSET=0
LOG_FILE=""

# ------------------------------
# Initialize dashboard steps
# ------------------------------
ui_init_dashboard() {
    UI_STEPS=("$@")
    UI_CURRENT_STEP=0
}

# ------------------------------
# Draw header with ASCII logo
# ------------------------------
ui_draw_header() {
    clear
    echo -e "${ELECTRIC_BLUE}${BOLD}"
    echo "  _____ _                         ____   ____"
    echo " / ____(_)                       / __ \ / ____|"
    echo "| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ "
    echo "| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\"
    echo "| |__| | | | | | (_| |  __/ |   | |__| |____) |"
    echo " \_____|_|_| |_|\__, |\___|_|    \____/|_____/ "
    echo "                 __/ |                         "
    echo "                |___/         v1.0             "
    echo -e "${NC}"
}

# ------------------------------
# Draw dashboard table
# Left: vertical SYSTEM PROGRESS
# Right: horizontal current phase packages (POGs)
# ------------------------------
ui_draw_dashboard() {
    local left_width=22
    local right_width=80
    local total_pogs=${#CURRENT_PHASE_POGS[@]}
    local start=$CURRENT_PHASE_POG_OFFSET
    local end=$((start + right_width / 10))   # rough estimate for visible packages

    # Draw header
    printf "%-${left_width}s | %s\n" "SYSTEM PROGRESS" "CURRENT PHASE PACKAGES"
    printf -- "%-${left_width}s-+-%s\n" "$(printf '%.0s-' $(seq 1 $left_width))" "$(printf '%.0s-' $(seq 1 $right_width))"

    # Draw steps
    for i in "${!UI_STEPS[@]}"; do
        local marker="[ ]"
        [ "$i" -lt "$UI_CURRENT_STEP" ] && marker="${LASER_GREEN}[✓]${NC}"
        [ "$i" -eq "$UI_CURRENT_STEP" ] && marker="${ELECTRIC_BLUE}[▶]${NC}"

        printf "%-${left_width}s | " "$marker ${UI_STEPS[$i]}"

        # Only show pogs for current step
        if [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            local line=""
            for ((j=start;j<end && j<total_pogs;j++)); do
                line+="${CURRENT_PHASE_POGS[$j]} "
            done
            echo -e "$line"
        else
            echo ""
        fi
    done

    echo -e "\nLast logs (tail $LOG_LINES lines):\n"
    if [ -f "$LOG_FILE" ]; then
        tail -n $LOG_LINES "$LOG_FILE"
    fi
}

# ------------------------------
# Update the horizontal package POGs
# ------------------------------
ui_update_phase_pogs() {
    local pogs=("$@")
    CURRENT_PHASE_POGS=()
    for p in "${pogs[@]}"; do
        if [[ "$p" =~ built ]]; then
            CURRENT_PHASE_POGS+=("${LASER_GREEN}[✓] ${p}${NC}")
        elif [[ "$p" =~ running ]]; then
            CURRENT_PHASE_POGS+=("${ELECTRIC_BLUE}[▶] ${p}${NC}")
        else
            CURRENT_PHASE_POGS+=("[ ] $p")
        fi
    done
    ui_draw_dashboard
}

# ------------------------------
# Run command with spinner + live pog updates
# ------------------------------
ui_run_step() {
    local CMD="$1"
    local STEP_NAME="$2"
    LOG_FILE="$3"

    : > "$LOG_FILE"
    bash -c "$CMD" > >(tee -a "$LOG_FILE") 2>&1 &
    local PID=$!

    local spinstr='|/-\\'
    local start_time=$(date +%s)

    # Live update loop
    while kill -0 "$PID" 2>/dev/null; do
        # Read last lines to detect pogs
        mapfile -t pogs < <(tail -n $LOG_LINES "$LOG_FILE" | awk '{print $1}')
        CURRENT_PHASE_POGS=()
        for p in "${pogs[@]}"; do
            CURRENT_PHASE_POGS+=("[ ] $p")
        done

        # Spinner + elapsed time for last running package
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        local min=$((elapsed / 60))
        local sec=$((elapsed % 60))
        local frame=${spinstr:0:1}
        spinstr=${spinstr:1}${frame}

        ui_draw_dashboard
        printf "\r%s | Elapsed: %02d:%02d\n" "$frame $STEP_NAME" "$min" "$sec"

        sleep 0.3
    done

    wait "$PID"
    return $?
}

# ------------------------------
# Wrapper for running steps idempotently
# ------------------------------
run_step() {
    local STEP_NAME="$1"
    local CMD="$2"
    local STEP_FILE="$STATE_DIR/$STEP_NAME"
    local LOG_FILE="$STATE_DIR/$STEP_NAME.log"

    UI_CURRENT_STEP=$(get_step_index "$STEP_NAME")

    if [ -f "$STEP_FILE" ]; then
        echo -e "${LASER_GREEN}[INFO]${NC} Step '$STEP_NAME' already completed."
        return 0
    fi

    echo -e "${ELECTRIC_BLUE}[INFO]${NC} Starting: $STEP_NAME"

    ui_run_step "$CMD" "$STEP_NAME" "$LOG_FILE"
    local RET=$?

    if [ $RET -eq 0 ]; then
        touch "$STEP_FILE"
        echo -e "${LASER_GREEN}[✓] $STEP_NAME completed.${NC}"
    else
        echo -e "${LASER_RED}[✗] $STEP_NAME failed! Check $LOG_FILE${NC}"
        exit 1
    fi
}


# ------------------------------
# Basic UI helpers
# ------------------------------
ui_log() {
    echo -e "${LASER_GREEN}[INFO]${NC} $1"
}

ui_error() {
    echo -e "${LASER_RED}[ERROR]${NC} $1"
    exit 1
}

ui_confirm() {
    local msg=$1
    echo -ne "${LASER_GREEN}${BOLD}$msg (type 'yes'): ${NC}"
    read CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        ui_error "Aborted by user."
    fi
}
