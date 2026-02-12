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
    # Reset cursor to top-left to prevent flickering
    tput cup 0 0
    
    # 1. Header
    echo -e "${ELECTRIC_BLUE}${BOLD} GINGER_OS v1.0 | LFS BUILD DASHBOARD ${NC}"
    echo -e "--------------------------------------------------------------------------------"

    # 2. Table Headers
    printf "${BOLD} %-${LEFT_COL_WIDTH}s | %s${NC}\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS"
    echo -e "--------------------------+-----------------------------------------------------"

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
            right_content="${ELECTRIC_BLUE}${CURRENT_PKG}${NC}"
        fi

        # Use printf to force column alignment
        printf "${style} %-${LEFT_COL_WIDTH}s${NC} | %b\n" "$marker ${UI_STEPS[$i]}" "$right_content"
    done

    # 4. Logs Footer
    echo -e "--------------------------+-----------------------------------------------------"
    echo -e "${BOLD} LIVE OUTPUT:${NC}"
    echo -e "--------------------------------------------------------------------------------"
    
    # Ensure the log area is always the same height to prevent jumping
    if [ -s "$LOG_FILE" ]; then
        tail -n $LOG_LINES "$LOG_FILE" | sed 's/^/  /'
    else
        for l in $(seq 1 $LOG_LINES); do echo ""; done
    fi
    echo -e "--------------------------------------------------------------------------------"
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