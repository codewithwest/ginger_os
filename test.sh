#!/bin/bash

# --- Colors ---
ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
BOLD='\033[1m'
NC='\033[0m'

# --- Config ---
LEFT_COL_WIDTH=25
RIGHT_COL_WIDTH=55
LOG_LINES=10

UI_STEPS=("Prep" "Host Tools" "Phase 1" "Phase 2" "Phase 3" "Kernel")
UI_CURRENT_STEP=0
CURRENT_PKG="Initializing..."
LOG_FILE="/tmp/ginger_mock.log"

# Clean start
echo "" > "$LOG_FILE"
clear

ui_draw_dashboard() {
    tput cup 0 0
    
    # 1. Header
    echo -e "${ELECTRIC_BLUE}${BOLD} GINGER_OS v1.0 | LFS BUILD DASHBOARD ${NC}\e[K"
    echo -e "--------------------------------------------------------------------------------\e[K"

    # 2. Table Headers
    printf "${BOLD} %-${LEFT_COL_WIDTH}s | %s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS"
    echo -e "--------------------------+-----------------------------------------------------\e[K"

    # 3. Two-Column Body
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
            # Truncate right_content to ensure it doesn't wrap and break the table
            right_content=$(echo "$CURRENT_PKG" | cut -c 1-$RIGHT_COL_WIDTH)
        fi

        # \e[K clears the rest of the line to prevent "ghost" characters
        printf "${style} %-${LEFT_COL_WIDTH}s${NC} | %-${RIGHT_COL_WIDTH}b\e[K\n" "$marker ${UI_STEPS[$i]}" "$right_content"
    done

    # 4. Logs Footer
    echo -e "--------------------------+-----------------------------------------------------\e[K"
    echo -e "${BOLD} LIVE OUTPUT:${NC}\e[K"
    echo -e "--------------------------------------------------------------------------------\e[K"
    
    # Fill log area
    local lines_printed=0
    if [ -s "$LOG_FILE" ]; then
        # Process logs to ensure no line is wider than the terminal
        while read -r line; do
            printf "  %-.75s\e[K\n" "$line"
            ((lines_printed++))
        done < <(tail -n $LOG_LINES "$LOG_FILE")
    fi

    # Fill remaining empty log lines so the bottom border doesn't jump up and down
    while [ $lines_printed -lt $LOG_LINES ]; do
        echo -e "\e[K"
        ((lines_printed++))
    done
    
    echo -e "--------------------------------------------------------------------------------\e[K"
}
# --- Simulation Logic ---
simulate_build() {
    for i in "${!UI_STEPS[@]}"; do
        UI_CURRENT_STEP=$i
        local packages=("binutils-2.41" "gcc-13.2.0" "glibc-2.38" "libstdc++" "m4-1.4.19")
        
        for pkg in "${packages[@]}"; do
            CURRENT_PKG="Building $pkg..."
            
            # Simulate logs hitting the file
            echo "[$(date +%T)] Compiling $pkg source..." >> "$LOG_FILE"
            echo "[$(date +%T)] Applying patches for $pkg..." >> "$LOG_FILE"
            echo "[$(date +%T)] make -j$(nproc) ..." >> "$LOG_FILE"
            
            ui_draw_dashboard
            sleep 0.8
        done
        
        echo "[DONE] Finished phase: ${UI_STEPS[$i]}" >> "$LOG_FILE"
    done
}

# Run the simulation
# Hide cursor for better UI experience
tput civis
simulate_build
tput cnorm

echo -e "\n${LASER_GREEN}Build Simulation Complete!${NC}"