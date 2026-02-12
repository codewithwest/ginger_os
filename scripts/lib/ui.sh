#!/bin/bash
# GingerOS UI Library - Stable v1.2

ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
LASER_RED='\033[38;5;196m'
BOLD='\033[1m'
NC='\033[0m'

LEFT_COL_WIDTH=25
RIGHT_COL_WIDTH=55
LOG_LINES=8

UI_STEPS=()
UI_CURRENT_STEP=0
CURRENT_PKG="Waiting..."
LOG_FILE=""
SPIN_IDX=0
declare -A SUBSTEP_STATUS
SUBSTEPS_ORDER=()

# Track last draw time to prevent "flicker flooding"
LAST_DRAW=0

trap 'tput cnorm; echo -e "${NC}"; exit' INT TERM

ui_init_dashboard() {
    [[ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]] && return 0
    [[ $# -gt 0 ]] && UI_STEPS=("$@")
    
    printf "\e[?7l" # DISABLE line wrapping (Prevents shredding if window is small)
    clear
    tput civis
    ui_draw_dashboard
}
# ... (ui_step, ui_init_substeps, ui_set_substep remain the same) ...

ui_log() {
    local msg="$1"
    [[ -n "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE"
    CURRENT_PKG="$msg"
    
    # THROTTLE: Only redraw if 0.05 seconds have passed OR if it's a critical update
    # This stops the "shredding" during fast apt-get output
    local now=$(date +%s%N)
    if (( now - LAST_DRAW > 50000000 )); then
        ui_draw_dashboard
        LAST_DRAW=$now
    fi
}

ui_draw_header() {
    local term_w=$(tput cols)
    # If the terminal is too narrow, skip the ASCII art entirely to prevent shredding
    if [ "$term_w" -lt 85 ]; then
        UI_BUFFER+="${ELECTRIC_BLUE}${BOLD}  GingerOS Build System v1.0${NC}\e[K\n"
        return
    fi

    # Using -e with a limit to ensure no wrap
    UI_BUFFER+="${ELECTRIC_BLUE}${BOLD}"
    UI_BUFFER+="  _____ _                         ____   ____\e[K\n"
    UI_BUFFER+=" / ____(_)                       / __ \ / ____|\e[K\n"
    UI_BUFFER+="| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ \e[K\n"
    UI_BUFFER+="| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\\e[K\n"
    UI_BUFFER+="| |__| | | | | | (_| |  __/ |   | |__| |____) |\e[K\n"
    UI_BUFFER+=" \_____|_|_| |_|\__, |\___|_|    \____/|_____/ \e[K\n"
    UI_BUFFER+="                 __/ |                         \e[K\n"
    UI_BUFFER+="                |___/         v1.0             \e[K\n"
    UI_BUFFER+="${NC}"
}

ui_draw_dashboard() {
    [[ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]] && return 0
    
    SPIN_IDX=$(( (SPIN_IDX + 1) % 4 ))
    local term_h=$(tput lines)
    local term_w=$(tput cols)
    local s=$(local chars='/-\|'; echo -n "${chars:SPIN_IDX:1}")
    
    UI_BUFFER=""
    ui_draw_header

    # Ensure separators don't exceed window width
    local sep="--------------------------------------------------------------------------------"
    local short_sep="${sep:0:$((term_w - 2))}"
    
    UI_BUFFER+="${short_sep}\e[K\n"
    UI_BUFFER+=$(printf "${BOLD} %-25.25s | %s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS")
    UI_BUFFER+="--------------------------+-----------------------------------------------------\e[K\n"

    # Steps (added .25 and .55 to printf to FORCE truncation)
    for i in "${!UI_STEPS[@]}"; do
        local marker=" [ ]" style="${NC}" right=""
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker=" [✓]"; style="${LASER_GREEN}"; right="Completed"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            marker=" [$s]"; style="${ELECTRIC_BLUE}${BOLD}"
            # Truncate right-side content to prevent wrapping
            right="${CURRENT_PKG:0:50}"
        fi
        UI_BUFFER+=$(printf "${style} %-25.25s${NC} | %-50.50b\e[K\n" "$marker ${UI_STEPS[$i]}" "$right")
    done

    UI_BUFFER+="${short_sep}\e[K\n"
    UI_BUFFER+="${BOLD} LIVE OUTPUT:${NC}\e[K\n"
    UI_BUFFER+="${short_sep}\e[K\n"

    # Logs - strictly limited to 76 chars
    local lp=0
    if [[ -f "$LOG_FILE" ]]; then
        while IFS= read -r line; do
            local clean="${line//$'\r'/}"
            UI_BUFFER+=$(printf "  %-76.76s\e[K\n" "$clean")
            ((lp++))
        done < <(tail -n "$LOG_LINES" "$LOG_FILE" 2>/dev/null)
    fi
    for ((p=lp; p<LOG_LINES; p++)); do UI_BUFFER+="\e[K\n"; done

    UI_BUFFER+="${short_sep}\e[K\n"
    
    # Progress Bar
    local pct=0; [[ ${#UI_STEPS[@]} -gt 0 ]] && pct=$(( (UI_CURRENT_STEP * 100) / ${#UI_STEPS[@]} ))
    local f=$(( pct / 4 )); local e=$(( 25 - f ))
    local bar=""; for ((i=0; i<f; i++)); do bar+="#"; done; for ((i=0; i<e; i++)); do bar+=" "; done
    UI_BUFFER+=$(printf " Progress: [${LASER_GREEN}%-25.25s${NC}] %d%%\e[K" "$bar" "$pct")

    # DRAW ATOMICALLY
    tput cup 0 0
    echo -ne "$UI_BUFFER"
    tput ed
}