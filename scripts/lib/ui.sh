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
    local CMD="$1"
    local STEP_NAME="$2"
    local LOG_FILE="$3"

    : > "$LOG_FILE"
    bash -c "$CMD" > >(tee -a "$LOG_FILE") 2>&1 &
    local PID=$!

    local spinstr='|/-\'
    local start_time=$(date +%s)

    while kill -0 "$PID" 2>/dev/null; do
        ui_banner  # redraw dashboard with pogs

        # spinner frame
        local frame=${spinstr:0:1}
        spinstr=${spinstr:1}${frame}

        # elapsed time
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        local min=$((elapsed / 60))
        local sec=$((elapsed % 60))

        # print spinner + step + elapsed
        printf "\r ${ELECTRIC_BLUE}[%c] %s | Elapsed: %02d:%02d${NC}" "$frame" "$STEP_NAME" "$min" "$sec"

        # tail last $LOG_LINES
        tail -n $LOG_LINES "$LOG_FILE"

        sleep 0.1
        tput cuu $((LOG_LINES + 1))  # move cursor back
    done

    wait "$PID"
    return $?
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
