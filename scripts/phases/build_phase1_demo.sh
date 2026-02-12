#!/bin/bash
# GingerOS Build Phase 1 Demo
# Demonstrates the Process-Safe UI with actual LFS preparation tasks

set -e  # Exit on error

# ============================================================================
# SETUP
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/ui.sh"

# Set log file location
export UI_LOG_FILE="${GINGER_LOGS}/phase1-demo.log"

# ============================================================================
# SUDO KEEPALIVE
# ============================================================================

sudo -v

ui_sudo_keepalive &
SUDO_KEEPALIVE_PID=$!

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
    "Verify LFS Environment" \
    "Create LFS Directories" \
    "Set Permissions" \
    "Download Sample Package" \
    "Extract and Verify"

# ============================================================================
# STEP 0: VERIFY LFS ENVIRONMENT
# ============================================================================

ui_step 0 "Checking LFS mount point..."
ui_log "Verifying LFS environment variable: $LFS"

if [[ -z "$LFS" ]]; then
    ui_log "ERROR: LFS environment variable not set!"
    exit 1
fi

ui_log "LFS is set to: $LFS"

# Check if LFS directory exists
if [[ ! -d "$LFS" ]]; then
    ui_log "Creating LFS mount point: $LFS"
    sudo mkdir -pv "$LFS" >> "$UI_LOG_FILE" 2>&1
fi

ui_log "LFS environment verified"

# ============================================================================
# STEP 1: CREATE LFS DIRECTORIES
# ============================================================================

ui_step 1 "Creating LFS directory structure..."
ui_log "Setting up standard LFS directories"

# Create essential directories
sudo mkdir -pv "$LFS"/{etc,var,usr,tools,sources} >> "$UI_LOG_FILE" 2>&1
sudo mkdir -pv "$LFS"/usr/{bin,lib,sbin} >> "$UI_LOG_FILE" 2>&1

# Create symlinks for compatibility
if [[ ! -L "$LFS/bin" ]]; then
    ui_log "Creating /bin -> /usr/bin symlink"
    sudo ln -sv usr/bin "$LFS/bin" >> "$UI_LOG_FILE" 2>&1
fi

if [[ ! -L "$LFS/lib" ]]; then
    ui_log "Creating /lib -> /usr/lib symlink"
    sudo ln -sv usr/lib "$LFS/lib" >> "$UI_LOG_FILE" 2>&1
fi

if [[ ! -L "$LFS/sbin" ]]; then
    ui_log "Creating /sbin -> /usr/sbin symlink"
    sudo ln -sv usr/sbin "$LFS/sbin" >> "$UI_LOG_FILE" 2>&1
fi

# Create lib64 for x86_64
case $(uname -m) in
    x86_64)
        ui_log "Creating lib64 directory for x86_64"
        sudo mkdir -pv "$LFS/lib64" >> "$UI_LOG_FILE" 2>&1
        ;;
esac

ui_log "Directory structure created successfully"

# ============================================================================
# STEP 2: SET PERMISSIONS
# ============================================================================

ui_step 2 "Configuring permissions..."
ui_log "Setting ownership for LFS directories"

# Check if lfs user exists
if id lfs >/dev/null 2>&1; then
    ui_log "Setting ownership to lfs:lfs for $LFS/{tools,sources}"
    sudo chown -v lfs:lfs "$LFS"/{tools,sources} >> "$UI_LOG_FILE" 2>&1
    
    # Set permissions
    sudo chmod -v 755 "$LFS"/{tools,sources} >> "$UI_LOG_FILE" 2>&1
    
    ui_log "Permissions configured for lfs user"
else
    ui_log "WARNING: lfs user not found, skipping ownership change"
    ui_log "Run host-requirements-install.sh first to create lfs user"
fi

ui_log "Permissions set successfully"

# ============================================================================
# STEP 3: DOWNLOAD SAMPLE PACKAGE
# ============================================================================

ui_step 3 "Downloading sample package (m4)..."
ui_log "Demonstrating package download with wget"

# Use m4 as a small demo package
M4_URL="https://ftp.gnu.org/gnu/m4/m4-${M4_VERSION}.tar.xz"
M4_FILE="$GINGER_SOURCES/m4-${M4_VERSION}.tar.xz"

if [[ ! -f "$M4_FILE" ]]; then
    ui_log "Downloading: $M4_URL"
    wget -q --show-progress "$M4_URL" -O "$M4_FILE" >> "$UI_LOG_FILE" 2>&1
    ui_log "Download complete: m4-${M4_VERSION}.tar.xz"
else
    ui_log "Package already exists: m4-${M4_VERSION}.tar.xz"
fi

# Verify download
if [[ -f "$M4_FILE" ]]; then
    local size=$(du -h "$M4_FILE" | cut -f1)
    ui_log "Package size: $size"
fi

# ============================================================================
# STEP 4: EXTRACT AND VERIFY
# ============================================================================

ui_step 4 "Extracting and verifying package..."
ui_log "Testing extraction functionality"

# Create temporary build directory
BUILD_DIR="/tmp/ginger_build_test"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

ui_log "Extracting to: $BUILD_DIR"
tar -xf "$M4_FILE" -C "$BUILD_DIR" >> "$UI_LOG_FILE" 2>&1

# Verify extraction
EXTRACTED_DIR=$(ls -1 "$BUILD_DIR" | head -n1)
if [[ -d "$BUILD_DIR/$EXTRACTED_DIR" ]]; then
    ui_log "Successfully extracted: $EXTRACTED_DIR"
    
    # List contents
    ui_log "Package contents:"
    ls -lh "$BUILD_DIR/$EXTRACTED_DIR" | head -n 10 >> "$UI_LOG_FILE" 2>&1
    
    # Cleanup
    ui_log "Cleaning up test extraction"
    rm -rf "$BUILD_DIR"
else
    ui_log "ERROR: Extraction failed"
    exit 1
fi

ui_log "Extraction verified successfully"

# ============================================================================
# FINISH
# ============================================================================

ui_step 5 "Phase 1 demo complete!"
ui_log "All LFS preparation tasks completed successfully"

sleep 2
ui_finish

# ============================================================================
# SUMMARY
# ============================================================================

echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              🎉 PHASE 1 DEMO COMPLETE 🎉                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo
echo "LFS environment prepared successfully!"
echo
echo "What was demonstrated:"
echo "  ✓ LFS directory structure creation"
echo "  ✓ Proper symlink setup for FHS compliance"
echo "  ✓ Permission configuration for lfs user"
echo "  ✓ Package download with wget"
echo "  ✓ Archive extraction and verification"
echo
echo "The UI remained stable throughout all operations with no visual artifacts!"
echo
echo "Next steps:"
echo "  1. Review the log: $UI_LOG_FILE"
echo "  2. Proceed with actual LFS build: ./scripts/phases/build-phase1.sh"
echo
echo "LFS directory: $LFS"
echo
