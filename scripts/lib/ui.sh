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

ui_draw_header_to_buffer() {
    UI_BUFFER+="${ELECTRIC_BLUE}${BOLD}\n"
    
    local lines=$(tput lines)
    if [ "$lines" -lt 30 ]; then
        # Compact Header
        UI_BUFFER+="  GingerOS Build System v1.0\n"
        UI_BUFFER+="${NC}\e[K\n"
    else
        # Full Header
        UI_BUFFER+="  _____ _                         ____   ____\n"
        UI_BUFFER+=" / ____(_)                       / __ \ / ____|\n"
        UI_BUFFER+="| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ \n"
        UI_BUFFER+="| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\\n"
        UI_BUFFER+="| |__| | | | | | (_| |  __/ |   | |__| |____) |\n"
        UI_BUFFER+=" \_____|_|_| |_|\__, |\___|_|    \____/|_____/ \n"
        UI_BUFFER+="                 __/ |                         \n"
        UI_BUFFER+="                |___/         v1.0             \n"
        UI_BUFFER+="${NC}\e[K\n"
    fi
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
    UI_BUFFER="" # Global buffer
    
    # 1. Build Header
    ui_draw_header_to_buffer
    
    UI_BUFFER+="--------------------------------------------------------------------------------\e[K\n"
    # Use printf -v to print to variable if bash 4.3+, but let's stick to string append for compat
    UI_BUFFER+=$(printf "${BOLD} %-${LEFT_COL_WIDTH}s | %s${NC}\e[K" "SYSTEM PROGRESS" "CURRENT PHASE STATUS")
    UI_BUFFER+="\n"
    UI_BUFFER+="--------------------------+-----------------------------------------------------\e[K\n"

    # 2. Build Table
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
        
        # Append Line
        UI_BUFFER+=$(printf "${style} %-${LEFT_COL_WIDTH}s${NC} | %-${RIGHT_COL_WIDTH}b\e[K" "$marker ${UI_STEPS[$i]}" "$right_content")
        UI_BUFFER+="\n"
        
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

                UI_BUFFER+=$(printf " %-${LEFT_COL_WIDTH}s | ${sub_style}%-${RIGHT_COL_WIDTH}b${NC}\e[K" "" "$sub_marker $sub")
                UI_BUFFER+="\n"
            done
        fi
    done
    
    UI_BUFFER+="--------------------------+-----------------------------------------------------\e[K\n"
    UI_BUFFER+="${BOLD} LIVE OUTPUT:${NC}\e[K\n"
    UI_BUFFER+="--------------------------------------------------------------------------------\e[K\n"

    # 3. Calculate Log Space
    local current_line_count=$(echo -ne "$UI_BUFFER" | wc -l)
    local available_lines=$((term_lines - current_line_count - 2)) # Reserve 1 for bottom border, 1 safety
    
    local target_log_lines=$LOG_LINES
    if [ "$available_lines" -lt 1 ]; then target_log_lines=0
    elif [ "$available_lines" -lt "$LOG_LINES" ]; then target_log_lines=$available_lines; fi

    # 4. Build Logs
    local lines_printed=0
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] && [ "$target_log_lines" -gt 0 ]; then
        local log_content=$(tail -n $target_log_lines "$LOG_FILE")
        while IFS= read -r line; do
            local clean_line=$(echo "$line" | tr -d '\r' | cut -c 1-76)
            UI_BUFFER+=$(printf "  %s\e[K" "$clean_line")
            UI_BUFFER+="\n"
            ((lines_printed++))
        done <<< "$log_content"
    fi
    # Fill filler
    while [ $lines_printed -lt $target_log_lines ]; do
        UI_BUFFER+="\e[K\n"
        ((lines_printed++))
    done
    
    # 5. Global Progress Bar (Footer)
    local total_steps=${#UI_STEPS[@]}
    local percent=0
    if [ "$total_steps" -gt 0 ]; then
        percent=$(( (UI_CURRENT_STEP * 100) / total_steps ))
    fi
    local filled=$(( percent / 4 ))
    local empty=$(( 25 - filled ))
    
    # Construct progress bar string
    local prog_bar=$(printf " Progress: [${LASER_GREEN}%s${NC}%s] %d%%\e[K" \
           "$(printf '#%.0s' $(seq 1 $filled 2>/dev/null))" \
           "$(printf ' %.0s' $(seq 1 $empty 2>/dev/null))" \
           "$percent")
    
    UI_BUFFER+="$prog_bar\n"
    UI_BUFFER+="--------------------------------------------------------------------------------\e[K"

    # 5. ATOMIC PRINT
    tput civis
    tput cup 0 0
    echo -ne "$UI_BUFFER"
    tput ed
}