#!/bin/bash
# GingerOS - Common functions for LFS build scripts

set -e # Exit on error
set -u # Error on unset variables

# Source environment - finding it relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"

# State directory on host for orchestrator markers
GINGER_STATE_DIR="${GINGER_ROOT}/.build_state"
mkdir -p "$GINGER_STATE_DIR"

# Status directory - relative to LFS for package build markers
STATUS_DIR="$LFS/var/lib/ginger"
if [ "$LFS" != "/mnt/lfs" ] || [ -e "/mnt/lfs" ]; then
    # We only try to create the LFS status dir if the mountpoint exists
    # or if we are already inside chroot (where LFS=/ )
    mkdir -p "$STATUS_DIR" 2>/dev/null || true
fi

log() {
    local TYPE=$1
    local MSG=$2
    local COLOR=${NC:-}
    
    case $TYPE in
        "INFO")    COLOR=${GREEN:-} ;;
        "WARN")    COLOR=${YELLOW:-} ;;
        "ERROR")   COLOR=${RED:-} ;;
        "PROCESS") COLOR=${NC:-} ;;
    esac
    
    echo -e "${COLOR}[$(date +'%Y-%m-%d %H:%M:%S')] [$TYPE] $MSG\033[0m"
}

# Validate critical environment
# Inside chroot, LFS should be empty/root, and LFS_TGT is not strictly required for native builds
if [[ -z "${LFS:-}" ]]; then
    echo "ERROR: LFS environment variable is not defined!"
    exit 1
fi

check_built() {
    local PKG_NAME=$1
    if [ -f "$STATUS_DIR/$PKG_NAME.built" ] || [ -f "$GINGER_STATE_DIR/$PKG_NAME.built" ]; then
        log "INFO" "$PKG_NAME already built. Skipping."
        return 0
    fi
    return 1
}

mark_built() {
    local PKG_NAME=$1
    # 1. Always mark on the target filesystem if available
    if [ -d "$STATUS_DIR" ] || mkdir -p "$STATUS_DIR" 2>/dev/null; then
        touch "$STATUS_DIR/$PKG_NAME.built" 2>/dev/null || true
    fi
    
    # 2. Also mark on the host state dir so the orchestrator can see it even if unmounted
    touch "$GINGER_STATE_DIR/$PKG_NAME.built"
    
    log "INFO" "Finished building $PKG_NAME"
}

extract() {
    local PKG_PATTERN=$1
    
    # Find the matching archive in GINGER_SOURCES
    # This logic mimics the user's find/grep approach but is more robust.
    # Supports .tar.* and .tgz
    local ARCHIVE_NAME=$(ls "$GINGER_SOURCES" | grep -iE "^${PKG_PATTERN}-?[0-9]" | grep -E "\.(tar\..*|tgz)$" | head -n 1)
    
    # Fallback for packages without a standard hyphen-version (like 'tcl') or simple matches
    if [ -z "$ARCHIVE_NAME" ]; then
        ARCHIVE_NAME=$(ls "$GINGER_SOURCES" | grep -iE "^${PKG_PATTERN}" | grep -E "\.(tar\..*|tgz)$" | head -n 1)
    fi

    if [ -z "$ARCHIVE_NAME" ]; then
        log "ERROR" "No archive found matching pattern '$PKG_PATTERN' in $GINGER_SOURCES"
        exit 1
    fi

    # Determine the directory name (strip .tar.*)
    local DIR_NAME=$(echo "$ARCHIVE_NAME" | sed -E 's/\.(tar\.(gz|bz2|xz)|tgz)$//')
    
    # Handle specific source-suffix cases like tcl's "-src"
    DIR_NAME=${DIR_NAME/-src/}

    log "PROCESS" "Extracting $ARCHIVE_NAME..."
    # Build inside LFS sources to avoid permission issues on the host
    local BUILD_BASE="$LFS/sources"
    mkdir -p "$BUILD_BASE"
    cd "$BUILD_BASE"
    
    # Clean up previous build directory if it exists
    # We use a broad shell glob to catch variations (e.g., binutils-2.43.1 vs binutils-2.43)
    rm -rf "${DIR_NAME%-*}"* || true
    
    # Extract
    tar -xf "$GINGER_SOURCES/$ARCHIVE_NAME"
    
    # Find the newly created directory (it might not exactly match DIR_NAME)
    local NEW_DIR=$(ls -td */ | head -n 1 | cut -d'/' -f1)
    if [ -d "$NEW_DIR" ]; then
        cd "$NEW_DIR"
        # Export for cleanup later
        export GINGER_CURRENT_BUILD_DIR="$BUILD_BASE/$NEW_DIR"
    else
        log "ERROR" "Failed to find extracted directory in $BUILD_BASE"
        exit 1
    fi
}

cleanup() {
    if [ -n "${GINGER_CURRENT_BUILD_DIR:-}" ] && [ -d "$GINGER_CURRENT_BUILD_DIR" ]; then
        log "PROCESS" "Cleaning up build directory: $GINGER_CURRENT_BUILD_DIR"
        rm -rf "$GINGER_CURRENT_BUILD_DIR"
        unset GINGER_CURRENT_BUILD_DIR
    fi
}

# Error handler
error_handler() {
    local LINE=$1
    local CMD=$2
    log "ERROR" "Command '$CMD' failed at line $LINE"
    exit 1
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
