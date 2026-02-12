# ------------------------------
# Pure Bash Live Dashboard + Scrollable Logs
# ------------------------------
LOG_LINES=15  # visible log box height
SCROLL_STEP=1 # lines per up/down key press

# ANSI color shortcuts
ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ui_init_dashboard() {
    UI_STEPS=($@)
    UI_CURRENT_STEP=0
}
# ------------------------------
# Draw the dashboard header + progress
# ------------------------------
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
    echo "                |___/         v1.0             "
    echo -e "${NC}"
}

ui_draw_status() {
    local line=""
    for i in "${!UI_STEPS[@]}"; do
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            line+=" ${LASER_GREEN}[✓] ${UI_STEPS[$i]}${NC} "
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            line+=" ${ELECTRIC_BLUE}[▶] ${UI_STEPS[$i]}${NC} "
        else
            line+=" [ ] ${UI_STEPS[$i]} "
        fi
    done
    echo -e "$line"
    echo ""  # empty line before logs
}

ui_banner() {
    ui_draw_header
    ui_draw_status
}

# ------------------------------
# Scrollable log viewer
# ------------------------------

ui_scroll_log() {
    local LOG_FILE="$1"
    local scroll_pos=0
    local total_lines
    total_lines=$(wc -l < "$LOG_FILE")
    local key

    # Enable raw mode for arrow key detection
    stty -echo -icanon time 0 min 0

    while true; do
        tput cup $((UI_CURRENT_STEP + 12)) 0
        tput ed  # clear to end of screen

        # Determine slice of log to show
        local start=$scroll_pos
        local end=$((scroll_pos + LOG_LINES))
        if [ $end -gt $total_lines ]; then
            end=$total_lines
            start=$((end - LOG_LINES))
            [ $start -lt 0 ] && start=0
        fi

        # Print log lines with highlighting
        sed -n "$((start + 1)),$((end))p" "$LOG_FILE" | while IFS= read -r line; do
            if [[ "$line" =~ [Ee]rror|[Ff]ailed ]]; then
                echo -e "${RED}${line}${NC}"
            else
                echo "$line"
            fi
        done

        # Read user input (non-blocking)
        read -rsn1 key 2>/dev/null
        case "$key" in
            $'\x1b') # escape sequence
                read -rsn2 key
                case "$key" in
                    '[A') scroll_pos=$((scroll_pos - SCROLL_STEP)) ;; # Up
                    '[B') scroll_pos=$((scroll_pos + SCROLL_STEP)) ;; # Down
                esac
                ;;
        esac

        # Clamp scroll position
        [ $scroll_pos -lt 0 ] && scroll_pos=0
        [ $scroll_pos -gt $((total_lines - LOG_LINES)) ] && scroll_pos=$((total_lines - LOG_LINES))

        sleep 0.05
    done

    # Restore terminal
    stty sane
}

# Render the dashboard columns
ui_draw_dashboard() {
    clear
    echo -e "${ELECTRIC_BLUE}${BOLD}GingerOS Build v1.0${NC}"
    echo ""

    # Calculate spacing
    local left_width=25
    local right_width=50

    # Draw system progress (left column)
    echo -e "${BOLD}SYSTEM PROGRESS:${NC}"
    for i in "${!UI_STEPS[@]}"; do
        local marker="[ ]"
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            marker="${LASER_GREEN}[✓]${NC}"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            marker="${ELECTRIC_BLUE}[▶]${NC}"
        fi
        printf "%-${left_width}s" "$marker ${UI_STEPS[$i]}"
        # Right column only for current step
        if [ "$i" -eq "$UI_CURRENT_STEP" ] && [ "${#CURRENT_PHASE_POGS[@]}" -gt 0 ]; then
            for pog in "${CURRENT_PHASE_POGS[@]}"; do
                printf "%s " "$pog"
            done
        fi
        echo ""
    done
    echo ""
}

# ------------------------------
# Update pogs for current phase
# ------------------------------
ui_update_phase_pogs() {
    local pogs=("$@")
    CURRENT_PHASE_POGS=()
    for p in "${pogs[@]}"; do
        if [[ "$p" =~ built ]]; then
            CURRENT_PHASE_POGS+=("${LASER_GREEN}[✓] ${p}${NC}")
        elif [[ "$p" =~ running ]]; then
            CURRENT_PHASE_POGS+=("${ELECTRIC_BLUE}[▶] ${p}${NC}")
        else
            CURRENT_PHASE_POGS+=("[ ] $p")
        fi
    done
    ui_draw_dashboard
}


# ------------------------------
# Run a step with spinner, timer, and scrollable log
# ------------------------------
i_run_step() {
    local CMD="$1"
    local STEP_NAME="$2"
    local LOG_FILE="$3"

    : > "$LOG_FILE"

    # Run the command in background
    bash -c "$CMD" > >(tee -a "$LOG_FILE") 2>&1 &
    local PID=$!

    # Update pogs while process runs
    while kill -0 "$PID" 2>/dev/null; do
        # Parse log for "building" or "configuring" lines for pogs
        mapfile -t POGS < <(tail -n "$LOG_LINES" "$LOG_FILE" | awk '{print $1}')
        ui_update_phase_pogs "${POGS[@]}"
        sleep 0.3
    done

    wait "$PID"
    local RET=$?

    # Mark step pog as complete
    ui_update_phase_pogs "${POGS[@]/%/[✓]}"

    return $RET
}

# ------------------------------
# Wrapper to run steps with logs and timer
# ------------------------------


ui_confirm() {
    local msg=$1
    echo -ne "${LASER_GREEN}${BOLD}$msg (type 'yes'): ${NC}"
    read CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${RED}Aborted.${NC}"
        exit 0
    fi
}

ui_log() {
    echo -e "${LASER_GREEN}[INFO]${NC} $1"
}

ui_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

ui_input() {
    local prompt=$1
    local var_name=$2
    echo -ne "${ELECTRIC_BLUE}${BOLD}$prompt: ${NC}"
    read $var_name
}

ui_password() {
    local prompt=$1
    local var_name=$2
    echo -ne "${ELECTRIC_BLUE}${BOLD}$prompt: ${NC}"
    read -s $var_name
    echo ""
}

ui_step() {
    UI_CURRENT_STEP=$1
    ui_banner
}

ui_spinner() {
    local pid=$1
    local msg=$2
    local delay=0.1
    local spinstr='|/-\\'  # note the escaped backslash

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r ${ELECTRIC_BLUE}[%c] %s${NC}" "${spinstr:0:1}" "$msg"
        spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
    done

    wait "$pid"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "\r${LASER_GREEN}[✓] $msg completed successfully.${NC}"
    else
        echo -e "\r${LASER_RED}[✗] $msg failed!${NC}"
    fi

    return $exit_code
}
