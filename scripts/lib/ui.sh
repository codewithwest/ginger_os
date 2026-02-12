#!/bin/bash
# GingerOS UI Library - Resilient v1.3

ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
LASER_RED='\033[38;5;196m'
BOLD='\033[1m'
NC='\033[0m'

# State
UI_STEPS=()
UI_CURRENT_STEP=0
LOG_FILE="build.log"
SPIN_CHARS='/-\|'
SPIN_IDX=0

# Cleanup on exit
trap 'tput cnorm; printf "\e[?7h"; echo -e "${NC}"; exit' INT TERM

ui_init_dashboard() {
    UI_STEPS=("$@")
    printf "\e[?7l" # Disable line wrap to prevent shredding
    tput civis
    clear
    ui_draw_dashboard
}

ui_step() { UI_CURRENT_STEP=$1; ui_draw_dashboard; }

ui_log() {
    [[ -n "$1" ]] && echo "$1" >> "$LOG_FILE"
    ui_draw_dashboard
}

ui_draw_dashboard() {
    SPIN_IDX=$(( (SPIN_IDX + 1) % 4 ))
    local s="${SPIN_CHARS:SPIN_IDX:1}"
    local term_w=$(tput cols)
    local term_h=$(tput lines)
    local col_left=25
    local col_right=$(( term_w - col_left - 8 ))
    
    # 1. Build Buffer in memory
    local buf=""
    
    # Header - Only show ASCII if window is wide enough
    if [ "$term_w" -gt 80 ]; then
        buf+="${ELECTRIC_BLUE}${BOLD}"
        buf+="  GingerOS Build System v1.0\e[K\n"
        buf+="  [ Step $((UI_CURRENT_STEP + 1)) of ${#UI_STEPS[@]} ]\e[K\n"
    else
        buf+="${ELECTRIC_BLUE}${BOLD} >> GINGER OS BUILD [${s}]\e[K\n"
    fi
    
    buf+="${NC}$(printf '%.0s-' $(seq 1 $term_w))\e[K\n"
    buf+=$(printf "${BOLD} %-${col_left}s | %s${NC}\e[K\n" "PROCESS" "STATUS")
    buf+="$(printf '%.0s-' $(seq 1 $term_w))\e[K\n"

    # 2. Draw Steps
    for i in "${!UI_STEPS[@]}"; do
        local marker=" [ ]" style="${NC}" state="Pending"
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker=" [✓]"; style="${LASER_GREEN}"; state="Done"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            marker=" [$s]"; style="${ELECTRIC_BLUE}${BOLD}"; state="Processing..."
        fi
        buf+=$(printf "${style} %-${col_left}s${NC} | %-${col_right}s\e[K\n" "$marker ${UI_STEPS[$i]}" "$state")
    done

    buf+="$(printf '%.0s-' $(seq 1 $term_w))\e[K\n"
    buf+="${BOLD} LIVE LOGS:${NC}\e[K\n"

    # 3. Dynamic Logs (fills remaining height)
    local log_h=$(( term_h - ${#UI_STEPS[@]} - 10 ))
    [[ $log_h -lt 3 ]] && log_h=3
    
    if [ -f "$LOG_FILE" ]; then
        while IFS= read -r line; do
            buf+=$(printf "  > %-${col_right}s\e[K\n" "${line:0:$((term_w-5))}")
        done < <(tail -n "$log_h" "$LOG_FILE")
    fi

    # 4. Atomic Update
    tput cup 0 0
    echo -ne "$buf"
    tput ed
}