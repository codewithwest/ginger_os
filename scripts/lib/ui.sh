ELECTRIC_BLUE='\033[38;5;39m'
LASER_GREEN='\033[38;5;118m'
WHITE='\033[1;37m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Dashboard State
UI_STEPS=()
UI_CURRENT_STEP=0

ui_init_dashboard() {
    UI_STEPS=("$@")
    UI_CURRENT_STEP=0
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
    echo "                |___/         v1.0             "
    echo -e "${NC}"
    echo -e "${WHITE}--------------------------------------------------${NC}"
}

ui_draw_status() {
    echo -e "\n${BOLD}SYSTEM PROGRESS:${NC}"
    # Default to 0 if unset or empty
    local current=${UI_CURRENT_STEP:-0}
    # Ensure it's a number
    [[ "$current" =~ ^[0-9]+$ ]] || current=0

    for i in "${!UI_STEPS[@]}"; do
        if [ "$i" -lt "$current" ]; then
            echo -e " ${LASER_GREEN}[✓] ${UI_STEPS[$i]}${NC}"
        elif [ "$i" -eq "$current" ]; then
            echo -e " ${ELECTRIC_BLUE}[▶] ${UI_STEPS[$i]}${NC}"
        else
            echo -e " [ ] ${UI_STEPS[$i]}"
        fi
    done
    echo -e "${WHITE}--------------------------------------------------${NC}\n"
}

ui_banner() {
    ui_draw_header
    ui_draw_status
}

ui_step() {
    UI_CURRENT_STEP=$1
    ui_banner
}

ui_spinner() {
    local pid=$1
    local msg=$2
    local delay=0.1
    local spinstr='|/-\'

    # Spinner loop
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r ${ELECTRIC_BLUE}[%c] %s${NC}" "$spinstr" "$msg"
        spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
    done

    # Wait for process and capture REAL exit code
    wait "$pid"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "\r${LASER_GREEN}[✓] $msg completed successfully.${NC}"
    else
        echo -e "\r${LASER_RED}[✗] $msg failed!${NC}"
    fi

    return $exit_code
}

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
