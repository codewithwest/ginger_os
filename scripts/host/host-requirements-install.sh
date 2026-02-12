#!/bin/bash

#!/bin/bash
# GingerOS - Source Downloader

set -euo pipefail

command -v wget >/dev/null || {
  log "ERROR" "wget not installed"
  exit 1
}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/ui.sh"

# 1. Setup
LOG_FILE="build.log"
> "$LOG_FILE"  # Clear old logs
UI_STEPS=("Init" "Host Reqs" "LFS User" "Finish")
ui_init_dashboard "${UI_STEPS[@]}"

# 2. Update Step
ui_step 1
ui_log "Updating package lists..."
# Redirect ALL output to the log file so it doesn't mess up the screen
sudo apt update -y >> "$LOG_FILE" 2>&1

# 3. Install Step
ui_log "Installing build dependencies..."
# Use -y and redirect output. The UI will show the last line in the dashboard.
sudo apt install -y \
    build-essential bison gawk m4 texinfo \
    libncurses5-dev libtool autoconf automake \
    patch wget curl xz-utils bzip2 \
    file bc flex zlib1g-dev \
    xorriso >> "$LOG_FILE" 2>&1

# 4. User Creation Step
ui_step 2
ui_log "Configuring LFS user environment..."
if ! id lfs >/dev/null 2>&1; then
    sudo groupadd lfs >> "$LOG_FILE" 2>&1
    sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs >> "$LOG_FILE" 2>&1
    echo "lfs:lfs" | sudo chpasswd
fi

# 5. Done
ui_step 3
ui_log "Host environment ready!"
tput cnorm