#!/bin/bash

# --- Colors ---
ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
LASER_RED='\033[38;5;196m'
BOLD='\033[1m'
NC='\033[0m'

# --- Layout ---
LEFT_COL_WIDTH=25
RIGHT_COL_WIDTH=55
LOG_LINES=10

UI_STEPS=()
UI_CURRENT_STEP=0
CURRENT_PKG="Waiting..."
LOG_FILE=""

ui_init_dashboard() { UI_STEPS=("$@"); }

ui_draw_dashboard() {
    tput cup 0 0
    # Logo
    echo -e "${ELECTRIC_BLUE}${BOLD}"
    echo "  _____ _                         ____   ____"
    echo " / ____(_)                       / __ \ / ____|"
    echo "| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ "
    echo "| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\"
    echo "| |__| | | | | | (_| |  __/ |   | |__| |____) |"
    echo " \_____|_|_| |_|\__, |\___|_|    \____/|_____/ "
    echo "                |___/         v1.0             ${NC}\e[K"

    echo -e "--------------------------------------------------------------------------------\e[K"
    printf "${BOLD} %-${LEFT_COL_WIDTH}s | %s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS"
    echo -e "--------------------------+-----------------------------------------------------\e[K"

    for i in "${!UI_STEPS[@]}"; do
        local marker=" [ ]"
        local style="${NC}"
        local right_content=""
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker=" [✓]"; style="${LASER_GREEN}"; right_content="Completed"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            marker=" [▶]"; style="${ELECTRIC_BLUE}${BOLD}"; right_content=$(echo "$CURRENT_PKG" | cut -c 1-$RIGHT_COL_WIDTH)
        fi
        printf "${style} %-${LEFT_COL_WIDTH}s${NC} | %-${RIGHT_COL_WIDTH}b\e[K\n" "$marker ${UI_STEPS[$i]}" "$right_content"
    done

    echo -e "--------------------------+-----------------------------------------------------\e[K"
    echo -e "${BOLD} LIVE OUTPUT:${NC}\e[K"
    echo -e "--------------------------------------------------------------------------------\e[K"
    
    local lines_printed=0
    if [ -f "$LOG_FILE" ]; then
        while read -r line; do
            printf "  %-.76s\e[K\n" "$line"
            ((lines_printed++))
        done < <(tail -n $LOG_LINES "$LOG_FILE")
    fi
    while [ $lines_printed -lt $LOG_LINES ]; do echo -e "\e[K"; ((lines_printed++)); done
    echo -e "--------------------------------------------------------------------------------\e[K"
}