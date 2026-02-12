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
source "${SCRIPT_DIR}/../lib/ui.sh"

# Set log file location
export UI_LOG_FILE="${GINGER_LOGS}/host-requirements.log"

# ============================================================================
# SUDO KEEPALIVE
# ============================================================================

# Get sudo credentials upfront
sudo -v

# Start background sudo keepalive to prevent password prompts
ui_sudo_keepalive &
SUDO_KEEPALIVE_PID=$!

# Ensure sudo keepalive is killed on exit
cleanup_sudo() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    fi
}
trap cleanup_sudo EXIT

# ============================================================================
# INITIALIZE UI
# ============================================================================

ui_init \
    "Update Package Cache" \
    "Install Build Tools" \
    "Install LFS Dependencies" \
    "Create LFS User" \
    "Verify Installation"

# ============================================================================
# STEP 0: UPDATE PACKAGE CACHE
# ============================================================================

ui_step 0 "Refreshing package database..."
ui_log "Starting apt update"

sudo apt update -y >> "$UI_LOG_FILE" 2>&1

ui_log "Package cache updated successfully"

# ============================================================================
# STEP 1: INSTALL BUILD TOOLS
# ============================================================================

ui_step 1 "Installing essential build tools..."
ui_log "Installing: build-essential, bison, gawk, m4, texinfo"

sudo apt install -y \
    build-essential \
    bison \
    gawk \
    m4 \
    texinfo \
    >> "$UI_LOG_FILE" 2>&1

ui_log "Build tools installed successfully"

# ============================================================================
# STEP 2: INSTALL LFS DEPENDENCIES
# ============================================================================

ui_step 2 "Installing LFS-specific dependencies..."
ui_log "Installing development libraries and tools"

sudo apt install -y \
    libncurses5-dev \
    libtool \
    autoconf \
    automake \
    patch \
    wget \
    curl \
    xz-utils \
    bzip2 \
    file \
    bc \
    flex \
    zlib1g-dev \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    >> "$UI_LOG_FILE" 2>&1

ui_log "All LFS dependencies installed successfully"

# ============================================================================
# STEP 3: CREATE LFS USER
# ============================================================================

ui_step 3 "Setting up LFS user environment..."

if ! id lfs >/dev/null 2>&1; then
    ui_log "Creating lfs group and user"
    
    sudo groupadd lfs >> "$UI_LOG_FILE" 2>&1 || true
    sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs >> "$UI_LOG_FILE" 2>&1
    
    ui_log "LFS user created successfully"
else
    ui_log "LFS user already exists, skipping creation"
fi

# Set up LFS user bash profile
ui_log "Configuring LFS user environment"

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

ui_log "LFS user environment configured"

# ============================================================================
# STEP 4: VERIFY INSTALLATION
# ============================================================================

ui_step 4 "Verifying installation..."
ui_log "Running version checks"

# Check critical tools
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

ui_log "All tools verified successfully"

# ============================================================================
# FINISH
# ============================================================================

ui_step 5 "Installation complete!"
ui_log "Host system is ready for LFS build"

sleep 2
ui_finish

# ============================================================================
# SUMMARY
# ============================================================================

echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    ✅ SUCCESS ✅                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo
echo "Host requirements installed successfully!"
echo
echo "Next steps:"
echo "  1. Prepare LFS partition: sudo ./scripts/host/prepare-partition.sh"
echo "  2. Download sources: ./scripts/host/download-sources.sh"
echo "  3. Begin LFS build: ./scripts/phases/build-phase1.sh"
echo
echo "Log file: $UI_LOG_FILE"
echo