#!/bin/bash

# Colors
ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
WHITE='\033[1;37m'
RED='\033[0;31m'
YELLOW='\033[33m'
BOLD='\033[1m'
NC='\033[0m'

# Dashboard state
UI_STEPS=()
UI_CURRENT_STEP=0
LOG_LINES=15

ui_init_dashboard() {
    UI_STEPS=("$@")
    UI_CURRENT_STEP=0
}

ui_draw_header() {
    clear
    echo -e "${ELECTRIC_BLUE}${BOLD}"
    echo "  _____ _                         ____   ____"
    echo " / ____(_)                       / __ \\ / ____|"
    echo "| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ "
    echo "| | |_ | | '_ \\ / _\` |/ _ \\ '__|| |  | |\\___ \\"
    echo "| |__| | | | | | (_| |  __/ |   | |__| |____) |"
    echo " \\_____|_|_| |_|\\__, |\\___|_|    \\____/|_____/ "
    echo "                 __/ |                         "
    echo "                |___/         v1.0             "
    echo -e "${NC}"
    echo -e "${WHITE}--------------------------------------------------${NC}"
}

ui_draw_status() {
    echo -e "${BOLD}SYSTEM PROGRESS:${NC}"
    for i in "${!UI_STEPS[@]}"; do
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            echo -e " ${LASER_GREEN}[✓] ${UI_STEPS[$i]}${NC}"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            echo -e " ${ELECTRIC_BLUE}[▶] ${UI_STEPS[$i]}${NC}"
        else
            echo -e " [ ] ${UI_STEPS[$i]}"
        fi
    done
    echo -e "${WHITE}--------------------------------------------------${NC}\n"
}

ui_banner() {
    ui_draw_header
    ui_draw_status
}

ui_run_step() {
    local PID=$1
    local STEP_NAME="$2"
    local LOG_FILE="$3"
    local START_TIME=$(date +%s)
    local delay=0.1
    local scroll_pos=0

    # Spinner chars
    local spinstr='|/-\'

    # Live log loop
    while kill -0 "$PID" 2>/dev/null; do
        # Spinner
        local temp=${spinstr#?}
        spinstr=$temp${spinstr%"$temp"}

        # Clear log box area
        tput sc  # Save cursor
        tput cup $((UI_CURRENT_STEP + 12)) 0

        # Print last LOG_LINES lines
        tail -n $LOG_LINES "$LOG_FILE" | while IFS= read -r line; do
            # Highlight errors
            if [[ "$line" =~ [Ee]rror|[Ff]ailed ]]; then
                echo -e "${RED}${line}${NC}"
            else
                echo "$line"
            fi
        done

        # Elapsed time
        local NOW=$(date +%s)
        local ELAPSED=$((NOW - START_TIME))
        printf "\r ${ELECTRIC_BLUE}[%c] %s | Elapsed: %02d:%02d${NC}" \
            "$spinstr" "$STEP_NAME" $((ELAPSED/60)) $((ELAPSED%60))

        tput rc  # Restore cursor
        sleep $delay
    done

    wait "$PID"
    local RET=$?
    echo ""  # Move cursor below log box

    return $RET
}

ui_step() {
    UI_CURRENT_STEP=$1
    ui_banner
}
