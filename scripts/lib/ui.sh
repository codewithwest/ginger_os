#!/bin/bash
# GingerOS UI Library - Optimized v1.1

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
declare -A SUBSTEP_STATUS
SUBSTEPS_ORDER=()

# --- Cleanup Trap (Restores cursor on exit) ---
trap 'tput cnorm; echo -e "${NC}"; exit' INT TERM

# --- Functions ---

ui_init_dashboard() {
    [[ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]] && return 0
    [[ $# -gt 0 ]] && UI_STEPS=("$@")
    
    clear
    tput civis
    ui_draw_dashboard
}

ui_step() {
    UI_CURRENT_STEP=$1
    SUBSTEPS_ORDER=()
    SUBSTEP_STATUS=()
    ui_draw_dashboard
}

ui_init_substeps() {
    SUBSTEPS_ORDER=("$@")
    for sub in "${SUBSTEPS_ORDER[@]}"; do
        SUBSTEP_STATUS["$sub"]="pending"
    done
    ui_draw_dashboard
}

ui_set_substep() {
    SUBSTEP_STATUS["$1"]="$2"
    ui_draw_dashboard
}

ui_log() {
    local msg="$1"
    if [[ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]]; then
        echo "$msg"
        return
    fi

    [[ -n "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE"
    CURRENT_PKG="$msg"
    ui_draw_dashboard
}

ui_error() {
    tput cnorm
    echo -e "\n${LASER_RED}${BOLD}[ERROR] $1${NC}"
    exit 1
}

get_spinner() {
    local chars='/-\|' # Fixed backslash escape
    echo -n "${chars:SPIN_IDX:1}"
}

ui_draw_header() {
    local lines
    lines=$(tput lines)
    UI_BUFFER+="${ELECTRIC_BLUE}${BOLD}"
    if [ "$lines" -lt 30 ]; then
        UI_BUFFER+="  GingerOS Build System v1.0\e[K\n"
    else
        UI_BUFFER+="  _____ _                         ____   ____\e[K\n"
        UI_BUFFER+=" / ____(_)                       / __ \ / ____|\e[K\n"
        UI_BUFFER+="| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ \e[K\n"
        UI_BUFFER+="| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\\e[K\n"
        UI_BUFFER+="| |__| | | | | | (_| |  __/ |   | |__| |____) |\e[K\n"
        UI_BUFFER+=" \_____|_|_| |_|\__, |\___|_|    \____/|_____/ \e[K\n"
        UI_BUFFER+="                 __/ |                         \e[K\n"
        UI_BUFFER+="                |___/         v1.0             \e[K\n"
    fi
    UI_BUFFER+="${NC}"
}

ui_draw_dashboard() {
    [[ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]] && return 0
    
    SPIN_IDX=$(( (SPIN_IDX + 1) % 4 ))
    local term_lines=$(tput lines)
    UI_BUFFER="" 
    
    ui_draw_header
    
    UI_BUFFER+="--------------------------------------------------------------------------------\e[K\n"
    UI_BUFFER+=$(printf "${BOLD} %-${LEFT_COL_WIDTH}s | %s${NC}\e[K" "SYSTEM PROGRESS" "CURRENT PHASE STATUS")
    UI_BUFFER+="\n--------------------------+-----------------------------------------------------\e[K\n"

    # Build Step Table
    for i in "${!UI_STEPS[@]}"; do
        local marker=" [ ]" style="${NC}" right_content=""
        
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker=" [✓]"; style="${LASER_GREEN}"; right_content="Completed"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            local s; s=$(get_spinner)
            marker=" [$s]"; style="${ELECTRIC_BLUE}${BOLD}"
            
            if [ ${#SUBSTEPS_ORDER[@]} -eq 0 ]; then
                right_content="${CURRENT_PKG:0:$RIGHT_COL_WIDTH}"
            else
                local first_sub="${SUBSTEPS_ORDER[0]}"
                local status="${SUBSTEP_STATUS[$first_sub]}"
                local sub_m="[ ]"
                [[ "$status" == "running" ]] && sub_m="[$s]"
                [[ "$status" == "done" ]] && sub_m="[✓]"
                [[ "$status" == "failed" ]] && sub_m="[X]"
                right_content="$sub_m $first_sub"
            fi
        fi
        
        UI_BUFFER+=$(printf "${style} %-${LEFT_COL_WIDTH}s${NC} | %b\e[K" "$marker ${UI_STEPS[$i]}" "$right_content")
        UI_BUFFER+="\n"
        
        # Draw Sub-steps
        if [ "$i" -eq "$UI_CURRENT_STEP" ] && [ ${#SUBSTEPS_ORDER[@]} -gt 1 ]; then
            for j in "${!SUBSTEPS_ORDER[@]}"; do
                [[ "$j" -eq 0 ]] && continue
                local sub="${SUBSTEPS_ORDER[$j]}"
                local status="${SUBSTEP_STATUS[$sub]}"
                local sub_m="[ ]" sub_s="${NC}"
                [[ "$status" == "running" ]] && { sub_m="[$(get_spinner)]"; sub_s="${BOLD}"; }
                [[ "$status" == "done" ]] && { sub_m="[✓]"; sub_s="${LASER_GREEN}"; }
                [[ "$status" == "failed" ]] && { sub_m="[X]"; sub_s="${LASER_RED}"; }
                UI_BUFFER+=$(printf " %-${LEFT_COL_WIDTH}s | ${sub_s}%b${NC}\e[K\n" "" "$sub_m $sub")
            done
        fi
    done
    
    UI_BUFFER+="--------------------------+-----------------------------------------------------\e[K\n"
    UI_BUFFER+="${BOLD} LIVE OUTPUT:${NC}\e[K\n"
    UI_BUFFER+="--------------------------------------------------------------------------------\e[K\n"

    # Logs
    local lines_printed=0
    if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        local log_content; log_content=$(tail -n "$LOG_LINES" "$LOG_FILE" 2>/dev/null)
        while IFS= read -r line; do
            # Clean carriage returns and truncate using bash expansion
            local clean="${line//$'\r'/}"
            UI_BUFFER+="  ${clean:0:76}\e[K\n"
            ((lines_printed++))
        done <<< "$log_content"
    fi
    
    # Pad logs
    for ((p=lines_printed; p<LOG_LINES; p++)); do UI_BUFFER+="\e[K\n"; done

    # Global Progress Bar
    local total=${#UI_STEPS[@]}
    local percent=0
    [[ $total -gt 0 ]] && percent=$(( (UI_CURRENT_STEP * 100) / total ))
    
    local filled=$(( percent / 4 ))
    local empty=$(( 25 - filled ))
    local bar_str=""
    for ((i=0; i<filled; i++)); do bar_str+="#"; done
    for ((i=0; i<empty; i++)); do bar_str+=" "; done

    UI_BUFFER+="--------------------------------------------------------------------------------\e[K\n"
    UI_BUFFER+=$(printf " Progress: [${LASER_GREEN}%s${NC}] %d%%\e[K" "$bar_str" "$percent")
    
    # Atomic redraw
    tput cup 0 0
    echo -ne "$UI_BUFFER"
    tput ed
}