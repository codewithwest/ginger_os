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
    echo -e "${BOLD}SYSTEM PROGRESS:${NC}"
    for i in "${!UI_STEPS[@]}"; do
        if [ "$i" -lt "$UI_CURRENT_STEP" ]; then
            echo -e " ${LASER_GREEN}[✓] ${UI_STEPS[$i]}${NC}"
        elif [ "$i" -eq "$UI_CURRENT_STEP" ]; then
            echo -e " ${ELECTRIC_BLUE}[▶] ${UI_STEPS[$i]}${NC}"
        else
            echo -e " [ ] ${UI_STEPS[$i]}"
        fi
    done
    echo -e ""
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

# ------------------------------
# Run a step with spinner, timer, and scrollable log
# ------------------------------
ui_run_step() {
    local PID=$1
    local STEP_NAME="$2"
    local LOG_FILE="$3"
    local START_TIME=$(date +%s)
    local spinstr='|/-\'
    local scroll_pid

    # Launch scrolling in background
    ui_scroll_log "$LOG_FILE" &
    scroll_pid=$!

    # Spinner loop
    while kill -0 "$PID" 2>/dev/null; do
        local temp=${spinstr#?}
        spinstr=$temp${spinstr%"$temp"}
        local NOW=$(date +%s)
        local ELAPSED=$((NOW - START_TIME))
        printf "\r ${ELECTRIC_BLUE}[%c] %s | Elapsed: %02d:%02d${NC}" \
            "$spinstr" "$STEP_NAME" $((ELAPSED/60)) $((ELAPSED%60))
        sleep 0.1
    done

    wait "$PID"
    local RET=$?

    # Kill scroll viewer
    kill $scroll_pid 2>/dev/null
    wait $scroll_pid 2>/dev/null

    echo ""  # leave space after log
    return $RET
}

# ------------------------------
# Wrapper to run steps with logs and timer
# ------------------------------

