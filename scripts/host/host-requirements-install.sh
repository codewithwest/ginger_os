#!/bin/bash

# Get sudo out of the way first!
sudo -v

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/ui.sh"

# Setup
UI_STEPS=("Update" "Install" "LFS User" "Finalize")
ui_init_dashboard "${UI_STEPS[@]}"

# Step 0: Update
ui_step 0
ui_log "Refreshing package cache..."
sudo apt update -y >> build.log 2>&1

# Step 1: Install
ui_step 1
ui_log "Installing dependencies (this takes a minute)..."
sudo apt install -y build-essential bison gawk m4 texinfo \
    libncurses5-dev libtool autoconf automake \
    patch wget curl xz-utils bzip2 \
    file bc flex zlib1g-dev \
    xorriso >> build.log 2>&1

# Step 2: User
ui_step 2
ui_log "Setting up lfs user..."
if ! id lfs >/dev/null 2>&1; then
    sudo groupadd lfs >> build.log 2>&1
    sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs >> build.log 2>&1
fi

ui_step 3
ui_log "Ready!"
sleep 2

# Cleanup
printf "\e[?7h" # Re-enable wrap
tput cnorm