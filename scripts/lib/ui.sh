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

ui_draw_dashboard() {
    [[ "${GINGER_UI_HEADLESS:-0}" -eq 1 ]] && return 0
    
    SPIN_IDX=$(( (SPIN_IDX + 1) % 4 ))
    local term_lines=$(tput lines)
    local s=$(local chars='/-\|'; echo -n "${chars:SPIN_IDX:1}")
    
    # Start Building Buffer
    UI_BUFFER=""
    
    # 1. Header Logic
    UI_BUFFER+="${ELECTRIC_BLUE}${BOLD}"
    if [ "$term_lines" -lt 25 ]; then
        UI_BUFFER+="  GingerOS Build System v1.0\e[K\n"
    else
        UI_BUFFER+="  _____ _                         ____   ____\e[K\n"
        UI_BUFFER+=" / ____(_)                       / __ \ / ____|\e[K\n"
        UI_BUFFER+="| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ \e[K\n"
        UI_BUFFER+="| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\\e[K\n"
        UI_BUFFER+="| |__| | | | | | (_| |  __/ |   | |__| |____) |\e[K\n"
        UI_BUFFER+=" \_____|_|_| |_|\__, |\___|_|    \____/|_____/ \e[K\n"
        UI_BUFFER+="                |___/         v1.0             \e[K\n"
    fi
    UI_BUFFER+="${NC}--------------------------------------------------------------------------------\e[K\n"
    UI_BUFFER+=$(printf "${BOLD} %-${LEFT_COL_WIDTH}s | %s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS")
    UI_BUFFER+="--------------------------+-----------------------------------------------------\e[K\n"

    # 2. Steps Table
    for i in "${!UI_STEPS[@]}"; do
        local marker=" [ ]" style="${NC}" right=""
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker=" [✓]"; style="${LASER_GREEN}"; right="Completed"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            marker=" [$s]"; style="${ELECTRIC_BLUE}${BOLD}"
            if [ ${#SUBSTEPS_ORDER[@]} -eq 0 ]; then
                right="${CURRENT_PKG:0:$RIGHT_COL_WIDTH}"
            else
                local sub1="${SUBSTEPS_ORDER[0]}"
                local st1="${SUBSTEP_STATUS[$sub1]}"
                local m1="[ ]"; [[ "$st1" == "running" ]] && m1="[$s]"; [[ "$st1" == "done" ]] && m1="[✓]"
                right="$m1 $sub1"
            fi
        fi
        UI_BUFFER+=$(printf "${style} %-${LEFT_COL_WIDTH}s${NC} | %b\e[K\n" "$marker ${UI_STEPS[$i]}" "$right")
        
        # Sub-steps
        if [ "$i" -eq "$UI_CURRENT_STEP" ] && [ ${#SUBSTEPS_ORDER[@]} -gt 1 ]; then
            for j in "${!SUBSTEPS_ORDER[@]}"; do
                [[ "$j" -eq 0 ]] && continue
                local sub="${SUBSTEPS_ORDER[$j]}"
                local st="${SUBSTEP_STATUS[$sub]}"
                local sm="[ ]" ss="${NC}"
                [[ "$st" == "running" ]] && { sm="[$s]"; ss="${BOLD}"; }
                [[ "$st" == "done" ]] && { sm="[✓]"; ss="${LASER_GREEN}"; }
                UI_BUFFER+=$(printf " %-${LEFT_COL_WIDTH}s | ${ss}%b${NC}\e[K\n" "" "$sm $sub")
            done
        fi
    done

    # 3. Footer & Logs
    UI_BUFFER+="--------------------------+-----------------------------------------------------\e[K\n"
    UI_BUFFER+="${BOLD} LIVE OUTPUT:${NC}\e[K\n"
    UI_BUFFER+="--------------------------------------------------------------------------------\e[K\n"

    local lp=0
    if [[ -f "$LOG_FILE" ]]; then
        # Using tail -n with a fixed width to prevent wrapping issues
        while IFS= read -r line; do
            local clean="${line//$'\r'/}"
            UI_BUFFER+="  ${clean:0:76}\e[K\n"
            ((lp++))
        done < <(tail -n "$LOG_LINES" "$LOG_FILE" 2>/dev/null)
    fi
    for ((p=lp; p<LOG_LINES; p++)); do UI_BUFFER+="\e[K\n"; done

    # 4. Progress Bar
    local total=${#UI_STEPS[@]}
    local pct=0; [[ $total -gt 0 ]] && pct=$(( (UI_CURRENT_STEP * 100) / total ))
    local f=$(( pct / 4 )); local e=$(( 25 - f ))
    local bar=""; for ((i=0; i<f; i++)); do bar+="#"; done; for ((i=0; i<e; i++)); do bar+=" "; done
    
    UI_BUFFER+="--------------------------------------------------------------------------------\e[K\n"
    UI_BUFFER+=$(printf " Progress: [${LASER_GREEN}%s${NC}] %d%%\e[K" "$bar" "$pct")

    # 5. ATOMIC DRAW - The Magic Trick
    tput cup 0 0    # Move to top
    echo -ne "$UI_BUFFER"
    tput ed         # Clear everything below the buffer (prevents ghosting)
}