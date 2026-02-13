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

UI_RENDER_TMP="/tmp/ginger_render.$GINGER_UI_MASTER_PID"

ui_load_state() {
    if [[ -f "$UI_STATE_FILE" ]]; then
        # Safe parsing: read line by line instead of sourcing
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # Remove potential surrounding quotes from printf %q
            # This is a basic unquote implementation for simple values
            value="${value#\'}"
            value="${value%\'}"
            
            # Additional safety: only allow specific keys
            case "$key" in
                UI_CURRENT_STEP|UI_STATUS_MSG|UI_ACTIVE_LOG|UI_STEPS)
                    # For UI_STEPS (array), we need careful handling or just skip it 
                    # if it uses complex array syntax. Bash arrays are hard to parse safely without source.
                    # Given UI_STEPS is used for internal state tracking, we might skip it 
                    # if we can't parse it safely, or rely on engine re-sending it.
                    # For now, let's skip complex array parsing to be safe and only load scalars.
                    if [[ "$key" != "UI_STEPS" ]]; then
                        printf -v "$key" '%s' "$value"
                    fi
                    ;;
            esac
        done < "$UI_STATE_FILE"
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
    
    local buf=""
    
    # ========== HEADER WITH LOGO ==========
    if [[ $term_h -ge 30 ]]; then
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
    buf+="${LASER_GREEN}  🌶️  GingerOS Build System v1.0 - LFS 12.4 🌶️${NC}\e[K\n"
    
    # ========== PROGRESS BAR ==========
    local total_steps=${#UI_STEPS[@]}
    local progress_pct=0
    [[ $total_steps -gt 0 ]] && progress_pct=$(( (UI_CURRENT_STEP * 100) / total_steps ))
    
    buf+="\e[K\n"
    buf+="${BOLD}  Progress: [Step $((UI_CURRENT_STEP + 1))/$total_steps] $progress_pct%${NC}\e[K\n"
    
    local bar_width=50
    buf+="  ["
    local filled=$(( (progress_pct * bar_width) / 100 ))
    for ((i=0; i<bar_width; i++)); do
        if [[ $i -lt $filled ]]; then buf+="${LASER_GREEN}█${NC}"; else buf+="${DIM}░${NC}"; fi
    done
    buf+="]\e[K\n"
    
    # ========== SEPARATOR ==========
    buf+="  $(printf '%.0s─' $(seq 1 $((term_w - 6))))\e[K\n"
    
    # ========== STEP TABLE ==========
    buf+=$(printf "${BOLD}  %-${col_left}s │ %-${col_right}s${NC}\e[K\n" "SYSTEM PROGRESS" "CURRENT PHASE STATUS")
    buf+="  $(printf '%.0s─' $(seq 1 $col_left))┼$(printf '%.0s─' $(seq 1 $((col_right + 2))))\e[K\n"
    
    # Visible steps
    local start_idx=0
    local max_visible=6
    [[ $term_h -lt 25 ]] && max_visible=4
    
    if [[ ${#UI_STEPS[@]} -gt $max_visible ]]; then
        start_idx=$(( UI_CURRENT_STEP - (max_visible / 2) ))
        [[ $start_idx -lt 0 ]] && start_idx=0
        [[ $(( start_idx + max_visible )) -gt ${#UI_STEPS[@]} ]] && start_idx=$(( ${#UI_STEPS[@]} - max_visible ))
    fi
    local end_idx=$(( start_idx + max_visible - 1 ))
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
        local row=$(printf "  $marker %-$((col_left - 8))s" "${step_name:0:$((col_left - 8))}")
        buf+="${style}${row}${NC} │ $state\e[K\n"
    done
    
    # ========== SEPARATOR ==========
    buf+="  $(printf '%.0s─' $(seq 1 $col_left))┼$(printf '%.0s─' $(seq 1 $((col_right + 2))))\e[K\n"
    
    # ========== LIVE LOGS ==========
    buf+="${BOLD}  LIVE OUTPUT:${NC}\e[K\n"
    buf+="  $(printf '%.0s─' $(seq 1 $((term_w - 6))))\e[K\n"
    
    # Calculate log height
    local lines_used=$(( 4 + 1 + 2 + (end_idx - start_idx + 1) + 1 + 2 + 1 ))
    [[ $term_h -ge 30 ]] && lines_used=$((lines_used + 9))
    local log_h=$(( term_h - lines_used - 2 ))
    [[ $log_h -lt 3 ]] && log_h=3
    [[ $log_h -gt 10 ]] && log_h=10
    
    local target_log="$UI_LOG_FILE"
    local prefix="  ${DIM}▸${NC} "
    [[ -n "${UI_ACTIVE_LOG:-}" && -f "$UI_ACTIVE_LOG" ]] && { target_log="$UI_ACTIVE_LOG"; prefix="  ${LASER_GREEN}⚙${NC} "; }
    
    if [[ -f "$target_log" ]]; then
        while IFS= read -r line; do
            local max_len=$((term_w - 8))
            local display_line="${line:0:$max_len}"
            display_line="${display_line//%/%%}"
            buf+="$prefix$display_line\e[K\n"
        done < <(tail -n "$log_h" "$target_log" 2>/dev/null)
    else
        buf+="  ${DIM}(No output yet)${NC}\e[K\n"
    fi
    
    # ========== ATOMIC RENDER ==========
    tput cup 0 0
    printf "%b" "$buf"
    tput ed
}

ui_stop_monitor() {
    if [[ -n "$UI_MONITOR_PID" ]] && kill -0 "$UI_MONITOR_PID" 2>/dev/null; then
        kill -SIGSTOP "$UI_MONITOR_PID" 2>/dev/null
        tput rmcup
        tput cnorm
        printf "\e[?7h" # Re-enable wrap
    fi
}

ui_resume_monitor() {
    if [[ -n "$UI_MONITOR_PID" ]] && kill -0 "$UI_MONITOR_PID" 2>/dev/null; then
        tput smcup
        tput civis
        printf "\e[?7l" # Disable wrap
        kill -SIGCONT "$UI_MONITOR_PID" 2>/dev/null
    fi
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
    # Enter alternate screen buffer to keep terminal clean
    tput smcup
    tput civis
    printf "\e[?7l" # Disable wrap

    # Handle terminal resize signals
    trap 'clear' SIGWINCH

    while true; do
        ui_load_state
        
        # Draw directly to the terminal
        if check_width; then
            ui_draw_full_dashboard
        else
            ui_draw_minimal
        fi
        
        # Refresh rate: 10 FPS for smooth spinner
        sleep 0.1
    done
}

# Add a specific status for LFS ownership changes (as seen in your screenshot)
ui_set_active_log() {
    export UI_ACTIVE_LOG="$1"
    ui_save_state
}
# ============================================================================
# PUBLIC API
# ============================================================================

ui_init_dashboard() {
    # Initialize UI with step names
    # Usage: ui_init_dashboard "Step 1" "Step 2" "Step 3"
    
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
    # Force output to /dev/tty to prevent UI leaking into step logs
    # Start background monitor atomic check
    local pi_file="/tmp/ginger_ui_monitor.${GINGER_UI_MASTER_PID}.pid"
    
    if [[ -f "$pi_file" ]]; then
        # Check if process is actually running
        local existing_pid=$(cat "$pi_file")
        if kill -0 "$existing_pid" 2>/dev/null; then
             return
        fi
        # Stale PID file, remove it
        rm -f "$pi_file"
    fi

    # Start monitor
    ui_monitor > /dev/tty 2>&1 &
    UI_MONITOR_PID=$!
    echo "$UI_MONITOR_PID" > "$pi_file"
    
    # Ensure cleanup on exit
    trap "rm -f '$pi_file'; exit" EXIT
    
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

ui_input() {
    local prompt="$1"
    local var_name="$2"
    ui_stop_monitor
    echo -ne "${ELECTRIC_BLUE}${BOLD}▸ $prompt: ${NC}"
    read -r val
    eval "$var_name=\"$val\""
    ui_resume_monitor
}

ui_password() {
    local prompt="$1"
    local var_name="$2"
    ui_stop_monitor
    echo -ne "${LASER_YELLOW}${BOLD}🔑 $prompt: ${NC}"
    read -rs val
    echo
    eval "$var_name=\"$val\""
    ui_resume_monitor
}

ui_confirm() {
    local prompt="$1"
    ui_stop_monitor
    echo -ne "${LASER_RED}${BOLD}❓ $prompt [y/N]: ${NC}"
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    ui_resume_monitor
}

ui_draw_header() {
    clear
    echo -e "${ELECTRIC_BLUE}${BOLD}"
    echo "  _____ _                         ____   ____"
    echo " / ____(_)                       / __ \ / ____|"
    echo "| |  __ _ _ __   __ _  ___ _ __ | |  | | (___ "
    echo "| | |_ | | '_ \ / _\` |/ _ \ '__|| |  | |\___ \\"
    echo "| |__| | | | | | (_| |  __/ |   | |__| |____) |"
    echo " \_____|_|_| |_|\__, |\___|_|    \____/|_____/ "
    echo "                 __/ |                         "
    echo "                |___/         Installer        "
    echo -e "${NC}"
}

ui_spinner() {
    local pid=$1
    local msg=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    tput civis
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r${ELECTRIC_BLUE}${spin:$i:1}${NC} $msg..."
        sleep 0.1
    done
    tput cnorm
    echo -e " [${LASER_GREEN}DONE${NC}]"
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