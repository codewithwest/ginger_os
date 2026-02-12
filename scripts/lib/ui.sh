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
# Use a master PID to ensure all sub-scripts share the same UI session
export GINGER_UI_MASTER_PID="${GINGER_UI_MASTER_PID:-$$}"
UI_STATE_FILE="/tmp/ginger_ui_state.${GINGER_UI_MASTER_PID}"
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
    # Only the master process should stop the monitor and clean up
    if [[ "$$" == "$GINGER_UI_MASTER_PID" ]]; then
        # Stop background monitor if running
        if [[ -n "$UI_MONITOR_PID" ]] && kill -0 "$UI_MONITOR_PID" 2>/dev/null; then
            kill "$UI_MONITOR_PID" 2>/dev/null
            wait "$UI_MONITOR_PID" 2>/dev/null
        fi
        
        # Clean up state file
        rm -f "$UI_STATE_FILE" 2>/dev/null
        
        # Restore terminal state
        tput cnorm 2>/dev/null          # Show cursor
        printf "\e[?7h" 2>/dev/null     # Re-enable line wrap
        printf "${NC}" 2>/dev/null      # Reset colors
        
        # Move cursor to bottom and print newline for clean exit
        tput cup "$(tput lines)" 0 2>/dev/null
        echo
    fi
}

trap 'ui_cleanup' EXIT

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
UI_ACTIVE_LOG=$(printf '%q' "${UI_ACTIVE_LOG:-}")
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
    
    # Column widths
    local col_left=30
    local col_right=$(( term_w - col_left - 8 ))
    [[ $col_right -lt 20 ]] && col_right=20
    
    # Build entire dashboard as single string buffer
    local buf=""
    
    # ========== HEADER WITH LOGO (Adaptive) ==========
    # Require at least 32 lines of height to show the big logo
    if [[ $term_h -ge 32 ]]; then
        buf+="${ELECTRIC_BLUE}${BOLD}"
        buf+="  _____ _                         ____   ____\e[K\n"
        buf+=" / ____(_)                       / __ \ / ____|\e[K\n"
        buf+="| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ \e[K\n"
        buf+="| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\\\ \e[K\n"
        buf+="| |__| | | | | | (_| |  __/ |   | |__| |____) |\e[K\n"
        buf+=" \_____|_|_| |_|\__, |\___|_|    \____/|_____/ \e[K\n"
        buf+="                 __/ |                         \e[K\n"
        buf+="                |___/         v1.0             \e[K\n"
        buf+="${NC}"
    fi
    buf+="${LASER_GREEN}        🌶️  GingerOS Build System v1.0 - LFS 12.4 🌶️${NC}\e[K\n"
    
    # ========== PROGRESS BAR ==========
    local total_steps=${#UI_STEPS[@]}
    local progress_pct=0
    [[ $total_steps -gt 0 ]] && progress_pct=$(( (UI_CURRENT_STEP * 100) / total_steps ))
    
    buf+="\e[K\n"
    buf+="${BOLD}  Progress: [Step $((UI_CURRENT_STEP + 1))/$total_steps] $progress_pct%${NC}\e[K\n"
    local bar_width=$(( term_w - 6 ))
    local fill_width=$(( (progress_pct * bar_width) / 100 ))
    buf+="  [${LASER_GREEN}$(printf '%*s' "$fill_width" | tr ' ' '━')${NC}"
    buf+="$(printf '%*s' "$(( bar_width - fill_width ))" | tr ' ' '─')]\e[K\n"
    
    # ========== SEPARATOR ==========
    buf+="  $(printf '%.0s─' $(seq 1 $((term_w - 6))))\e[K\n"
    
    # ========== STEP TABLE ==========
    buf+=$(printf "${BOLD}  %-${col_left}s │ %-${col_right}s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS")
    buf+="  $(printf '%.0s─' $(seq 1 $col_left))┼$(printf '%.0s─' $(seq 1 $((col_right + 2))))\e[K\n"
    
    # Dynamic Step Visibility (Adaptive based on height)
    local max_steps=6
    [[ $term_h -lt 28 ]] && max_steps=4
    [[ $term_h -lt 20 ]] && max_steps=2
    
    local start_idx=0
    if [[ ${#UI_STEPS[@]} -gt $max_steps ]]; then
        start_idx=$(( UI_CURRENT_STEP - (max_steps / 2) ))
        [[ $start_idx -lt 0 ]] && start_idx=0
        [[ $(( start_idx + max_steps )) -gt ${#UI_STEPS[@]} ]] && start_idx=$(( ${#UI_STEPS[@]} - max_steps ))
    fi
    local end_idx=$(( start_idx + max_steps - 1 ))
    [[ $end_idx -ge ${#UI_STEPS[@]} ]] && end_idx=$(( ${#UI_STEPS[@]} - 1 ))

    for i in $(seq $start_idx $end_idx); do
        local marker=" [ ]"
        local style="${NC}"
        local state="Pending"
        
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
        # Truncate step name to fit column
        local max_step_name=$((col_left - 8))
        [[ ${#step_name} -gt $max_step_name ]] && step_name="${step_name:0:$((max_step_name-3))}..."
        
        local row=$(printf "  $marker %-${max_step_name}s" "$step_name")
        buf+="${style}${row}${NC} │ $state\e[K
"
    done
    
    # ========== SEPARATOR ==========
    buf+="  $(printf '%.0s─' $(seq 1 $col_left))┼$(printf '%.0s─' $(seq 1 $((col_right + 2))))\e[K\n"
    
    # ========== LIVE LOGS (Adaptive Height) ==========
    buf+="${BOLD}  LIVE OUTPUT:${NC}\e[K\n"
    buf+="  $(printf '%.0s─' $(seq 1 $((term_w - 6))))\e[K\n"
    
    # Calculate how many lines are left for logs
    # Base lines: Progress(4) + Sep(1) + TableHeader(2) + VisibleSteps + Sep(1) + LogHeader(2) + VersionLine(1)
    local lines_used=$(( 4 + 1 + 2 + (end_idx - start_idx + 1) + 1 + 2 + 1 ))
    [[ $term_h -ge 32 ]] && lines_used=$((lines_used + 9)) # Add logo space
    
    local log_h=$(( term_h - lines_used - 2 ))
    [[ $log_h -lt 3 ]] && log_h=3
    [[ $log_h -gt 15 ]] && log_h=15
    
    local target_log="$UI_LOG_FILE"
    local prefix="  ${DIM}▸${NC} "
    
    if [[ -n "${UI_ACTIVE_LOG:-}" && -f "$UI_ACTIVE_LOG" ]]; then
        target_log="$UI_ACTIVE_LOG"
        prefix="  ${LASER_GREEN}⚙${NC} "
    fi
    
    if [[ -f "$target_log" ]]; then
        while IFS= read -r line; do
            local max_len=$((term_w - 8))
            local display_line="${line:0:$max_len}"
            display_line="${display_line//%/%%}"
            buf+="$prefix$display_line\e[K
"
        done < <(tail -n "$log_h" "$target_log" 2>/dev/null)
    else
        buf+="  ${DIM}(No output yet)${NC}\e[K
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
    
    # If we are a subscript and UI is already active, don't re-init steps
    if [[ "$$" != "$GINGER_UI_MASTER_PID" ]] && [[ -f "$UI_STATE_FILE" ]]; then
        return 0
    fi
    
    UI_STEPS=("$@")
    UI_CURRENT_STEP=0
    UI_STATUS_MSG=""
    
    # Create log file if it doesn't exist
    touch "$UI_LOG_FILE"
    
    # Save initial state
    ui_save_state
    
    # Start background monitor only if not already running
    if ! pgrep -f "ui_monitor" >/dev/null; then
        ui_monitor &
        UI_MONITOR_PID=$!
        sleep 0.2
    fi
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

ui_error() {
    # Log an error and update status with error message
    # Usage: ui_error "Something went wrong"
    
    local msg="$1"
    ui_log "ERROR: $msg"
    UI_STATUS_MSG="ERROR: $msg"
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