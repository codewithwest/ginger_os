#!/bin/bash
# GingerOS Host Requirements Installation
# Process-Safe UI Demo - Phase 1

set -e  # Exit on error

# ============================================================================
# SETUP
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"
source "${SCRIPT_DIR}/../lib/common.sh"

# Set log file location
export UI_LOG_FILE="${UI_LOG_FILE:-${GINGER_LOGS}/host-requirements.log}"
mkdir -p "$(dirname "$UI_LOG_FILE")"

# ============================================================================
# STEP 0: CONFIGURE HOST SHELL (LFS Requirement)
# ============================================================================

sudo -v
echo "GINGER_PKG: Configure Host Shell"
echo "Ensuring /bin/sh is bash..."
sudo ln -sf bash /bin/sh

# Function to wait for apt locks
wait_for_apt_lock() {
    local lock_files=("/var/lib/dpkg/lock-frontend" "/var/lib/apt/lists/lock" "/var/lib/dpkg/lock")
    echo "Checking for package manager locks..."
    for lock_file in "${lock_files[@]}"; do
        while [ -e "$lock_file" ] && sudo fuser "$lock_file" >/dev/null 2>&1; do
            local pid=$(sudo fuser "$lock_file" 2>/dev/null | awk '{print $NF}')
            echo "Waiting for process $pid to release $lock_file..."
            sleep 3
        done
    done
    # Final grace period
    sleep 1
}

# ============================================================================
# STEP 1: UPDATE PACKAGE CACHE
# ============================================================================

echo "GINGER_PKG: Update Package Cache"
echo "Refreshing package database..."
export DEBIAN_FRONTEND=noninteractive
wait_for_apt_lock
echo "Apt-get update starting... (this may take a minute)"
sudo apt-get update -qq >> "$UI_LOG_FILE" 2>&1 || { echo "Failed to update package cache. Check $UI_LOG_FILE"; exit 1; }
echo "Apt-get update finished."

# ============================================================================
# STEP 2: INSTALL BUILD TOOLS
# ============================================================================

echo "GINGER_PKG: Install Build Tools"
echo "Installing essential build tools..."
wait_for_apt_lock
sudo apt-get install -y -qq build-essential bison gawk m4 texinfo >> "$UI_LOG_FILE" 2>&1 || { echo "ERROR: Failed to install core build tools"; exit 1; }

# ============================================================================
# STEP 3: INSTALL LFS DEPENDENCIES
# ============================================================================

echo "GINGER_PKG: Install LFS Dependencies"
echo "Installing LFS-specific dependencies..."
wait_for_apt_lock
sudo apt-get install -y -qq \
    libncurses5-dev libtool autoconf automake patch wget curl \
    xz-utils bzip2 file bc flex zlib1g-dev xorriso grub-pc-bin \
    grub-efi-amd64-bin mtools >> "$UI_LOG_FILE" 2>&1 || { echo "ERROR: Failed to install LFS dependencies"; exit 1; }

# ============================================================================
# STEP 4: CREATE LFS USER
# ============================================================================

echo "GINGER_PKG: Create LFS User"
if ! id lfs >/dev/null 2>&1; then
    echo "Creating lfs group and user"
    sudo groupadd lfs >> "$UI_LOG_FILE" 2>&1 || true
    sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs >> "$UI_LOG_FILE" 2>&1
else
    echo "LFS user already exists, skipping creation"
fi

# Set up LFS user bash profile
echo "Configuring LFS user environment"
sudo tee /home/lfs/.bash_profile > /dev/null <<'EOF'
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

sudo tee /home/lfs/.bashrc > /dev/null <<'EOF'
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF

sudo chown -R lfs:lfs /home/lfs >> "$UI_LOG_FILE" 2>&1

# ============================================================================
# STEP 5: VERIFY INSTALLATION
# ============================================================================

echo "GINGER_PKG: Verify Installation"
echo "Verifying installation..."
{
    echo "=== Tool Versions ==="
    bash --version | head -n1
    gcc --version | head -n1
    make --version | head -n1
    bison --version | head -n1
    gawk --version | head -n1
    m4 --version | head -n1
    echo "=== LFS User ==="
    id lfs
    echo "=== Verification Complete ==="
} >> "$UI_LOG_FILE" 2>&1

echo "Host system is ready for LFS build"