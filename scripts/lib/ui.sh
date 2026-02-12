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
UI_STEPS=()
UI_CURRENT_STEP=0
CURRENT_PKG="Waiting..."
LOG_FILE=""
SPIN_IDX=0

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

ui_draw_header_buffer() {
    # Returns header content as string
    local buffer=""
    buffer+="${ELECTRIC_BLUE}${BOLD}\n"
    
    local lines=$(tput lines)
    if [ "$lines" -lt 30 ]; then
        # Compact Header
        buffer+="  GingerOS Build System v1.0\n"
        buffer+="${NC}\e[K\n"
    else
        # Full Header
        buffer+="  _____ _                         ____   ____\n"
        buffer+=" / ____(_)                       / __ \ / ____|\n"
        buffer+="| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ \n"
        buffer+="| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\\n"
        buffer+="| |__| | | | | | (_| |  __/ |   | |__| |____) |\n"
        buffer+=" \_____|_|_| |_|\__, |\___|_|    \____/|_____/ \n"
        buffer+="                 __/ |                         \n"
        buffer+="                |___/         v1.0             \n"
        buffer+="${NC}\e[K\n"
    fi
    echo -ne "$buffer"
}

get_spinner() {
    local chars="/-\|"
    echo "${chars:$SPIN_IDX:1}"
}

ui_draw_dashboard() {
    # Respect headless mode
    if [ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]; then
        return 0
    fi
    
    # Increment spinner global state once per frame
    SPIN_IDX=$(( (SPIN_IDX + 1) % 4 ))

    local term_lines=$(tput lines)
    local buffer=""
    
    # 1. Build Header
    buffer+=$(ui_draw_header_buffer)
    
    buffer+="--------------------------------------------------------------------------------\e[K\n"
    buffer+=$(printf "${BOLD} %-${LEFT_COL_WIDTH}s | %s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS")
    buffer+="--------------------------+-----------------------------------------------------\e[K\n"

    # 2. Build Table
    # We need to calculate how many lines the table takes to reserve space for logs
    # But since resizing logs is dynamic, we do a two-pass or just accurate accounting.
    # Let's just build the table and see how tall it is.
    
    local table_buffer=""
    for i in "${!UI_STEPS[@]}"; do
        local marker=" [ ]"
        local style="${NC}"
        local right_content=""

        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker=" [✓]"; style="${LASER_GREEN}"; right_content="Completed"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            marker=" [$(get_spinner)]"; style="${ELECTRIC_BLUE}${BOLD}"
            
            if [ ${#SUBSTEPS_ORDER[@]} -eq 0 ]; then
                right_content=$(echo "$CURRENT_PKG" | cut -c 1-$RIGHT_COL_WIDTH)
            else
                local first_sub="${SUBSTEPS_ORDER[0]}"
                local status="${SUBSTEP_STATUS[$first_sub]}"
                local sub_marker="[ ]"
                [ "$status" == "running" ] && sub_marker="[$(get_spinner)]"
                [ "$status" == "done" ] && sub_marker="[✓]"
                [ "$status" == "failed" ] && sub_marker="[X]"
                right_content="$sub_marker $first_sub"
            fi
        fi
        
        table_buffer+=$(printf "${style} %-${LEFT_COL_WIDTH}s${NC} | %-${RIGHT_COL_WIDTH}b\e[K\n" "$marker ${UI_STEPS[$i]}" "$right_content")
        
        # Sub-steps
        if [ "$i" -eq "$UI_CURRENT_STEP" ] && [ ${#SUBSTEPS_ORDER[@]} -gt 1 ]; then
            for j in "${!SUBSTEPS_ORDER[@]}"; do
                [ "$j" -eq 0 ] && continue
                local sub="${SUBSTEPS_ORDER[$j]}"
                local status="${SUBSTEP_STATUS[$sub]}"
                local sub_marker="[ ]"
                local sub_style="${NC}"
                [ "$status" == "running" ] && { sub_marker="[$(get_spinner)]"; sub_style="${BOLD}"; }
                [ "$status" == "done" ] && { sub_marker="[✓]"; sub_style="${LASER_GREEN}"; }
                [ "$status" == "failed" ] && { sub_marker="[X]"; sub_style="${LASER_RED}"; }

                table_buffer+=$(printf " %-${LEFT_COL_WIDTH}s | ${sub_style}%-${RIGHT_COL_WIDTH}b${NC}\e[K\n" "" "$sub_marker $sub")
            done
        fi
    done
    
    buffer+="$table_buffer"
    buffer+="--------------------------+-----------------------------------------------------\e[K\n"
    buffer+="${BOLD} LIVE OUTPUT:${NC}\e[K\n"
    buffer+="--------------------------------------------------------------------------------\e[K\n"

    # 3. Calculate Log Space
    # Count current lines in buffer (approximate by newlines)
    local current_line_count=$(echo -ne "$buffer" | wc -l)
    local available_lines=$((term_lines - current_line_count - 2)) # Reserve 1 for bottom border, 1 safety
    
    local target_log_lines=$LOG_LINES
    if [ "$available_lines" -lt 1 ]; then target_log_lines=0
    elif [ "$available_lines" -lt "$LOG_LINES" ]; then target_log_lines=$available_lines; fi

    # 4. Build Logs
    local lines_printed=0
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] && [ "$target_log_lines" -gt 0 ]; then
        # We need to capture exact lines
        local log_content=$(tail -n $target_log_lines "$LOG_FILE")
        while IFS= read -r line; do
            local clean_line=$(echo "$line" | tr -d '\r' | cut -c 1-76)
            buffer+=$(printf "  %s\e[K\n" "$clean_line")
            ((lines_printed++))
        done <<< "$log_content"
    fi
    # Fill filler
    while [ $lines_printed -lt $target_log_lines ]; do
        buffer+="\e[K\n"
        ((lines_printed++))
    done
    
    buffer+="--------------------------------------------------------------------------------\e[K"

    # 5. ATOMIC PRINT
    # Hide cursor, move to 0,0, print buffer, clear rest of screen
    tput civis
    tput cup 0 0
    echo -ne "$buffer"
    tput ed
}