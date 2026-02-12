#!/bin/bash
# GingerOS UI Library

# --- Colors ---
ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
LASER_RED='\033[38;5;196m'
BOLD='\033[1m'
NC='\033[0m'

# --- Layout Config ---
LEFT_COL_WIDTH=25
RIGHT_COL_WIDTH=55
LOG_LINES=8

# --- UI State ---
# --- New Sub-step State ---
declare -A SUBSTEP_STATUS
SUBSTEPS_ORDER=()

# --- Functions ---

ui_init_dashboard() {
    # Respect headless mode (for child processes)
    if [ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]; then
        return 0
    fi

    # Optional override for UI_STEPS
    if [ $# -gt 0 ]; then
        UI_STEPS=("$@")
    fi
    clear
    tput civis
    ui_draw_dashboard
}

ui_step() {
    local step_idx=$1
    UI_CURRENT_STEP=$step_idx
    # Clear substeps for new major step
    SUBSTEPS_ORDER=()
    SUBSTEP_STATUS=()
    ui_draw_dashboard
}

ui_init_substeps() {
    SUBSTEPS_ORDER=("$@")
    SUBSTEP_STATUS=()
    for sub in "${SUBSTEPS_ORDER[@]}"; do
        SUBSTEP_STATUS["$sub"]="pending"
    done
    ui_draw_dashboard
}

ui_set_substep() {
    local sub_name="$1"
    local status="$2"
    SUBSTEP_STATUS["$sub_name"]="$status"
    ui_draw_dashboard
}

ui_log() {
    local msg="$1"
    
    # In headless mode (child process), echo to stdout so parent sees it in logs
    if [ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]; then
        echo "$msg"
        return
    fi

    # Basic logging to file if set
    if [ -n "$LOG_FILE" ]; then
        echo "$msg" >> "$LOG_FILE"
    fi
    # Also update CURRENT_PKG for simple feedback if no substeps
    CURRENT_PKG="$msg"
    ui_draw_dashboard
}

ui_error() {
    local msg="$1"
    tput cnorm
    echo -e "${LASER_RED}[ERROR] $msg${NC}"
    exit 1
}

ui_draw_header() {
    # Move to top-left
    tput cup 0 0
    echo -e "${ELECTRIC_BLUE}${BOLD}"
    
    local lines=$(tput lines)
    if [ "$lines" -lt 30 ]; then
        # Compact Header for short terminals
        echo "  GingerOS Build System v1.0"
        echo -e "${NC}\e[K"
    else
        # Full ASCII Header
        echo "  _____ _                         ____   ____"
        echo " / ____(_)                       / __ \ / ____|"
        echo "| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ "
        echo "| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\"
        echo "| |__| | | | | | (_| |  __/ |   | |__| |____) |"
        echo " \_____|_|_| |_|\__, |\___|_|    \____/|_____/ "
        echo "                 __/ |                         "
        echo "                |___/         v1.0             "
        echo -e "${NC}\e[K"
    fi
}

get_spinner() {
    local chars="/-\|"
    local char="${chars:$SPIN_IDX:1}"
    SPIN_IDX=$(( (SPIN_IDX + 1) % 4 ))
    echo "$char"
}

ui_draw_dashboard() {
    # Respect headless mode
    if [ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]; then
        return 0
    fi

    # Hide cursor to prevent flicker
    tput civis
    
    ui_draw_header
    
    echo -e "--------------------------------------------------------------------------------\e[K"
    printf "${BOLD} %-${LEFT_COL_WIDTH}s | %s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS"
    echo -e "--------------------------+-----------------------------------------------------\e[K"

    # Calculate current usage to adjust log lines dynamically
    local term_lines=$(tput lines)
    local header_lines=6 # Approx for compact
    [ "$term_lines" -ge 30 ] && header_lines=14 # Approx for full
    
    # Render table
    for i in "${!UI_STEPS[@]}"; do
        local marker=" [ ]"
        local style="${NC}"
        local right_content=""

        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker=" [✓]"; style="${LASER_GREEN}"; right_content="Completed"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            marker=" [$(get_spinner)]"; style="${ELECTRIC_BLUE}${BOLD}"
            
            # --- Sub-step Rendering Logic ---
            if [ ${#SUBSTEPS_ORDER[@]} -eq 0 ]; then
                # Fallback to simple message
                right_content=$(echo "$CURRENT_PKG" | cut -c 1-$RIGHT_COL_WIDTH)
            else
                # Render first sub-step here
                local first_sub="${SUBSTEPS_ORDER[0]}"
                local status="${SUBSTEP_STATUS[$first_sub]}"
                local sub_marker="[ ]"
                [ "$status" == "running" ] && sub_marker="[$(get_spinner)]"
                [ "$status" == "done" ] && sub_marker="[✓]"
                [ "$status" == "failed" ] && sub_marker="[X]"
                
                right_content="$sub_marker $first_sub"
            fi
        fi
        printf "${style} %-${LEFT_COL_WIDTH}s${NC} | %-${RIGHT_COL_WIDTH}b\e[K\n" "$marker ${UI_STEPS[$i]}" "$right_content"
        header_lines=$((header_lines + 1))
        
        # --- Handle Extra Lines for Sub-steps ---
        if [ "$i" -eq "$UI_CURRENT_STEP" ] && [ ${#SUBSTEPS_ORDER[@]} -gt 1 ]; then
            for j in "${!SUBSTEPS_ORDER[@]}"; do
                [ "$j" -eq 0 ] && continue # Skip first one (already printed)
                
                local sub="${SUBSTEPS_ORDER[$j]}"
                local status="${SUBSTEP_STATUS[$sub]}"
                local sub_marker="[ ]"
                local sub_style="${NC}"
                
                if [ "$status" == "running" ]; then
                     sub_marker="[$(get_spinner)]"
                     sub_style="${BOLD}"
                elif [ "$status" == "done" ]; then
                     sub_marker="[✓]"
                     sub_style="${LASER_GREEN}"
                elif [ "$status" == "failed" ]; then
                     sub_marker="[X]"
                     sub_style="${LASER_RED}"
                fi

                printf " %-${LEFT_COL_WIDTH}s | ${sub_style}%-${RIGHT_COL_WIDTH}b${NC}\e[K\n" "" "$sub_marker $sub"
                header_lines=$((header_lines + 1))
            done
        fi
    done

    echo -e "--------------------------+-----------------------------------------------------\e[K"
    echo -e "${BOLD} LIVE OUTPUT:${NC}\e[K"
    echo -e "--------------------------------------------------------------------------------\e[K"
    header_lines=$((header_lines + 3)) # Footer borders + title
    
    # Cap Log Lines
    local available_lines=$((term_lines - header_lines - 1)) # -1 (bottom border)
    local target_log_lines=$LOG_LINES
    if [ "$available_lines" -lt 1 ]; then
        target_log_lines=0
    elif [ "$available_lines" -lt "$LOG_LINES" ]; then
        target_log_lines=$available_lines
    fi

    # Render Logs
    local lines_printed=0
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] && [ "$target_log_lines" -gt 0 ]; then
        while read -r line; do
            local clean_line=$(echo "$line" | tr -d '\r' | cut -c 1-76)
            printf "  %s\e[K\n" "$clean_line"
            ((lines_printed++))
        done < <(tail -n $target_log_lines "$LOG_FILE")
    fi
    # Fill empty log space
    while [ $lines_printed -lt $target_log_lines ]; do echo -e "\e[K"; ((lines_printed++)); done
    
    echo -e "--------------------------------------------------------------------------------\e[K"
}