#!/bin/bash
# GingerOS UI Library - Process-Safe v2.0
# Background Logger Pattern: UI runs in dedicated loop, commands run in foreground

# ============================================================================
# CONFIGURATION
# ============================================================================

ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
LASER_RED='\033[38;5;196m'
LASER_YELLOW='\033[38;5;226m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# State files
UI_STATE_FILE="/tmp/ginger_ui_state.$$"
UI_LOG_FILE="${UI_LOG_FILE:-build.log}"
UI_MONITOR_PID=""

# UI State
UI_STEPS=()
UI_CURRENT_STEP=0
UI_STATUS_MSG=""
UI_MODE="full"  # "full" or "minimal"

# Animation
SPIN_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPIN_IDX=0

# Terminal state
ORIGINAL_TERM_STATE=""
MIN_WIDTH=80

# ============================================================================
# CLEANUP AND SIGNAL HANDLING
# ============================================================================

ui_cleanup() {
    # Stop background monitor if running
    if [[ -n "$UI_MONITOR_PID" ]] && kill -0 "$UI_MONITOR_PID" 2>/dev/null; then
        kill "$UI_MONITOR_PID" 2>/dev/null
        wait "$UI_MONITOR_PID" 2>/dev/null
    fi
    
    # Restore terminal state
    tput cnorm 2>/dev/null          # Show cursor
    printf "\e[?7h" 2>/dev/null     # Re-enable line wrap
    printf "${NC}" 2>/dev/null      # Reset colors
    
    # Clean up state file
    rm -f "$UI_STATE_FILE" 2>/dev/null
    
    # Move cursor to bottom and print newline for clean exit
    tput cup "$(tput lines)" 0 2>/dev/null
    echo
}

trap 'ui_cleanup; exit' INT TERM EXIT

# ============================================================================
# TERMINAL WIDTH DETECTION
# ============================================================================

check_width() {
    local term_w=$(tput cols 2>/dev/null || echo 80)
    
    if [[ $term_w -lt $MIN_WIDTH ]]; then
        UI_MODE="minimal"
        return 1
    else
        UI_MODE="full"
        return 0
    fi
}

# ============================================================================
# STATE FILE MANAGEMENT
# ============================================================================

ui_save_state() {
    cat > "$UI_STATE_FILE" <<EOF
UI_CURRENT_STEP=$UI_CURRENT_STEP
UI_STATUS_MSG=$(printf '%q' "$UI_STATUS_MSG")
UI_STEPS=(${UI_STEPS[@]@Q})
EOF
}

ui_load_state() {
    if [[ -f "$UI_STATE_FILE" ]]; then
        source "$UI_STATE_FILE"
    fi
}

# ============================================================================
# ATOMIC RENDERING - FULL DASHBOARD MODE
# ============================================================================

ui_draw_full_dashboard() {
    local term_w=$(tput cols 2>/dev/null || echo 80)
    local term_h=$(tput lines 2>/dev/null || echo 24)
    
    # Update spinner
    SPIN_IDX=$(( (SPIN_IDX + 1) % ${#SPIN_CHARS} ))
    local s="${SPIN_CHARS:SPIN_IDX:1}"
    
    # Column widths
    local col_left=30
    local col_right=$(( term_w - col_left - 8 ))
    [[ $col_right -lt 20 ]] && col_right=20
    
    # Build entire dashboard as single string buffer
    local buf=""
    
    # ========== HEADER WITH ASCII ART ==========
    buf+="${ELECTRIC_BLUE}${BOLD}"
    buf+="\e[K\n"
    buf+="   ██████╗ ██╗███╗   ██╗ ██████╗ ███████╗██████╗  ██████╗ ███████╗\e[K\n"
    buf+="  ██╔════╝ ██║████╗  ██║██╔════╝ ██╔════╝██╔══██╗██╔═══██╗██╔════╝\e[K\n"
    buf+="  ██║  ███╗██║██╔██╗ ██║██║  ███╗█████╗  ██████╔╝██║   ██║███████╗\e[K\n"
    buf+="  ██║   ██║██║██║╚██╗██║██║   ██║██╔══╝  ██╔══██╗██║   ██║╚════██║\e[K\n"
    buf+="  ╚██████╔╝██║██║ ╚████║╚██████╔╝███████╗██║  ██║╚██████╔╝███████║\e[K\n"
    buf+="   ╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝\e[K\n"
    buf+="${NC}"
    buf+="${LASER_GREEN}        🌶️  Process-Safe Build System v1.0 - LFS 12.4 🌶️${NC}\e[K\n"
    buf+="\e[K\n"
    
    # ========== PROGRESS BAR ==========
    local total_steps=${#UI_STEPS[@]}
    local progress_pct=0
    [[ $total_steps -gt 0 ]] && progress_pct=$(( (UI_CURRENT_STEP * 100) / total_steps ))
    
    buf+="${BOLD}  Progress: ${NC}"
    buf+="[Step $((UI_CURRENT_STEP + 1))/${total_steps}] "
    buf+="${progress_pct}%\e[K\n"
    
    # Draw progress bar
    local bar_width=50
    local filled=$(( (progress_pct * bar_width) / 100 ))
    buf+="  ["
    for ((i=0; i<bar_width; i++)); do
        if [[ $i -lt $filled ]]; then
            buf+="${LASER_GREEN}█${NC}"
        else
            buf+="${DIM}░${NC}"
        fi
    done
    buf+="]\e[K\n"
    
    # ========== SEPARATOR ==========
    buf+="  $(printf '%.0s─' $(seq 1 $((term_w - 6))))\e[K\n"
    
    # ========== STEP TABLE (2-COLUMN LAYOUT) ==========
    buf+=$(printf "${BOLD}  %-${col_left}s │ %-${col_right}s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS")
    buf+="  $(printf '%.0s─' $(seq 1 $col_left))┼$(printf '%.0s─' $(seq 1 $((col_right + 2))))\e[K\n"
    
    # Show max 6 steps, centered around current step
    local total_steps=${#UI_STEPS[@]}
    local max_visible=6
    local start_idx=0
    local end_idx=$((total_steps - 1))
    
    if [[ $total_steps -gt $max_visible ]]; then
        # Center around current step
        start_idx=$((UI_CURRENT_STEP - 2))
        end_idx=$((UI_CURRENT_STEP + 3))
        
        # Adjust if at beginning
        if [[ $start_idx -lt 0 ]]; then
            start_idx=0
            end_idx=$((max_visible - 1))
        fi
        
        # Adjust if at end
        if [[ $end_idx -ge $total_steps ]]; then
            end_idx=$((total_steps - 1))
            start_idx=$((total_steps - max_visible))
        fi
    fi
    
    for i in $(seq $start_idx $end_idx); do
        local marker=" [ ]"
        local style="${NC}"
        local state=""
        
        if [[ $i -lt $UI_CURRENT_STEP ]]; then
            marker=" [✓]"
            style="${LASER_GREEN}"
            state="Completed"
        elif [[ $i -eq $UI_CURRENT_STEP ]]; then
            marker=" [▶]"
            style="${ELECTRIC_BLUE}${BOLD}"
            state="${UI_STATUS_MSG:-Processing...}"
        fi
        
        local step_name="${UI_STEPS[$i]}"
        buf+="${style}  $marker $step_name"
        # Pad to column width
        local padding=$((col_left - ${#marker} - ${#step_name} - 2))
        [[ $padding -gt 0 ]] && buf+="$(printf ' %.0s' $(seq 1 $padding))"
        buf+="${NC} │ $state\e[K
"
    done
    
    # ========== SEPARATOR ==========
    buf+="  $(printf '%.0s─' $(seq 1 $col_left))┼$(printf '%.0s─' $(seq 1 $((col_right + 2))))\e[K\n"
    
    # ========== LIVE LOGS ==========
    buf+="${BOLD}  LIVE OUTPUT:${NC}\e[K\n"
    buf+="  $(printf '%.0s─' $(seq 1 $((term_w - 6))))\e[K\n"
    
    # Show max 10 log lines
    local log_h=10
    
    if [[ -f "$UI_LOG_FILE" ]]; then
        while IFS= read -r line; do
            # Truncate to fit terminal width minus padding
            local max_len=$((term_w - 8))
            local display_line="${line:0:$max_len}"
            buf+="  ${DIM}▸${NC} $display_line\e[K
"
        done < <(tail -n "$log_h" "$UI_LOG_FILE" 2>/dev/null)
    else
        buf+="  ${DIM}(No logs yet)${NC}\e[K
"
    fi
    
    # ========== ATOMIC RENDER ==========
    # Move to top-left, print buffer, clear to end of screen
    tput cup 0 0
    printf "%b" "$buf"
    tput ed
}

# ============================================================================
# MINIMAL STREAM MODE (for narrow terminals)
# ============================================================================

ui_draw_minimal() {
    local s="${SPIN_CHARS:SPIN_IDX:1}"
    SPIN_IDX=$(( (SPIN_IDX + 1) % ${#SPIN_CHARS} ))
    
    local total_steps=${#UI_STEPS[@]}
    local current_step_name="${UI_STEPS[$UI_CURRENT_STEP]:-Unknown}"
    
    printf "\r${ELECTRIC_BLUE}${BOLD}[$s]${NC} GingerOS [%d/%d] %s... \e[K" \
        "$((UI_CURRENT_STEP + 1))" "$total_steps" "$current_step_name"
}

# ============================================================================
# BACKGROUND MONITOR LOOP
# ============================================================================

ui_monitor() {
    # This function runs in the background and continuously updates the UI
    # by reading from the state file
    
    # Disable line wrap and hide cursor
    printf "\e[?7l"
    tput civis
    
    # Initial clear
    clear
    
    while true; do
        # Load current state
        ui_load_state
        
        # Check terminal width and render appropriately
        if check_width; then
            ui_draw_full_dashboard
        else
            ui_draw_minimal
        fi
        
        # Refresh rate: 10 FPS for smooth spinner
        sleep 0.1
    done
}

# ============================================================================
# PUBLIC API
# ============================================================================

ui_init() {
    # Initialize UI with step names
    # Usage: ui_init "Step 1" "Step 2" "Step 3"
    
    UI_STEPS=("$@")
    UI_CURRENT_STEP=0
    UI_STATUS_MSG=""
    
    # Create log file if it doesn't exist
    touch "$UI_LOG_FILE"
    
    # Save initial state
    ui_save_state
    
    # Start background monitor
    ui_monitor &
    UI_MONITOR_PID=$!
    
    # Give monitor time to start
    sleep 0.2
}

ui_step() {
    # Move to the next step
    # Usage: ui_step <step_number> [status_message]
    
    UI_CURRENT_STEP=$1
    UI_STATUS_MSG="${2:-Processing...}"
    ui_save_state
}

ui_log() {
    # Append message to log file
    # Usage: ui_log "message"
    
    if [[ -n "$1" ]]; then
        echo "[$(date +'%H:%M:%S')] $1" >> "$UI_LOG_FILE"
    fi
}

ui_status() {
    # Update status message for current step
    # Usage: ui_status "Downloading packages..."
    
    UI_STATUS_MSG="$1"
    ui_save_state
}

ui_finish() {
    # Mark current step as complete and stop UI
    
    UI_CURRENT_STEP=${#UI_STEPS[@]}
    ui_save_state
    sleep 0.5
    
    # Cleanup will be called by trap
}

# ============================================================================
# SUDO KEEPALIVE
# ============================================================================

ui_sudo_keepalive() {
    # Keep sudo credentials fresh to prevent password prompts
    # Usage: ui_sudo_keepalive &
    
    while true; do
        sudo -v
        sleep 60
    done
}