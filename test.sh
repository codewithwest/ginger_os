#!/bin/bash

# --- Colors ---
ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
BOLD='\033[1m'
NC='\033[0m'

# --- Layout Config ---
LEFT_COL_WIDTH=25
RIGHT_COL_WIDTH=55
LOG_LINES=8  # Adjusted to fit ASCII logo on smaller screens

# --- State ---
UI_STEPS=("Prep" "Host Tools" "Phase 1" "Phase 2" "Phase 3" "Kernel")
UI_CURRENT_STEP=0
CURRENT_PKG="Waiting..."
LOG_FILE="/tmp/ginger_os.log"

ui_draw_dashboard() {
    # Move cursor to top-left (no clear = no flicker)
    tput cup 0 0
    
    # 1. YOUR ASCII LOGO
    echo -e "${ELECTRIC_BLUE}${BOLD}"
    echo "  _____ _                         ____   ____"
    echo " / ____(_)                       / __ \ / ____|"
    echo "| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ "
    echo "| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\"
    echo "| |__| | | | | | (_| |  __/ |   | |__| |____) |"
    echo " \_____|_|_| |_|\__, |\___|_|    \____/|_____/ "
    echo "                 __/ |                         "
    echo "                |___/         v1.0             "
    echo -e "${NC}\e[K"

    # 2. Table Headers
    echo -e "--------------------------------------------------------------------------------\e[K"
    printf "${BOLD} %-${LEFT_COL_WIDTH}s | %s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS"
    echo -e "--------------------------+-----------------------------------------------------\e[K"

    # 3. Two-Column Table Body
    for i in "${!UI_STEPS[@]}"; do
        local marker=" [ ]"
        local style="${NC}"
        local right_content=""

        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker=" [✓]"
            style="${LASER_GREEN}"
            right_content="Completed"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            marker=" [▶]"
            style="${ELECTRIC_BLUE}${BOLD}"
            right_content=$(echo "$CURRENT_PKG" | cut -c 1-$RIGHT_COL_WIDTH)
        fi

        printf "${style} %-${LEFT_COL_WIDTH}s${NC} | %-${RIGHT_COL_WIDTH}b\e[K\n" "$marker ${UI_STEPS[$i]}" "$right_content"
    done

    # 4. Logs Header
    echo -e "--------------------------+-----------------------------------------------------\e[K"
    echo -e "${BOLD} LIVE OUTPUT:${NC}\e[K"
    echo -e "--------------------------------------------------------------------------------\e[K"
    
    # 5. Log Feed (with line-clearing to prevent ghosting)
    local lines_printed=0
    if [ -f "$LOG_FILE" ]; then
        while read -r line; do
            printf "  %-.76s\e[K\n" "$line"
            ((lines_printed++))
        done < <(tail -n $LOG_LINES "$LOG_FILE")
    fi

    # Keep log box height consistent
    while [ $lines_printed -lt $LOG_LINES ]; do
        echo -e "\e[K"
        ((lines_printed++))
    done

    # 6. Global Progress Bar (Footer)
    local total_steps=${#UI_STEPS[@]}
    local percent=$(( (UI_CURRENT_STEP * 100) / total_steps ))
    local filled=$(( percent / 4 ))
    local empty=$(( 25 - filled ))
    
    printf " Progress: [${LASER_GREEN}%s${NC}%s] %d%%\e[K\n" \
           "$(printf '#%.0s' $(seq 1 $filled 2>/dev/null))" \
           "$(printf ' %.0s' $(seq 1 $empty 2>/dev/null))" \
           "$percent"
    echo -e "--------------------------------------------------------------------------------\e[K"
}

# ------------------------------
# Usage Example
# ------------------------------
# Hide cursor
tput civis
# Initial Draw
ui_draw_dashboard

# In your real scripts, just update these vars and call ui_draw_dashboard
# UI_CURRENT_STEP=2
# CURRENT_PKG="Compiling Glibc..."
# ui_draw_dashboard

# For simulation only:
for i in "${!UI_STEPS[@]}"; do
    UI_CURRENT_STEP=$i
    for p in 1 2 3; do
        CURRENT_PKG="Processing Package $p of Phase $(($i+1))..."
        echo "[$(date +%T)] Working on $CURRENT_PKG" >> "$LOG_FILE"
        ui_draw_dashboard
        sleep 1
    done
done

tput cnorm