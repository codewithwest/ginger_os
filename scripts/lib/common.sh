#!/bin/bash
# GingerOS - Common functions for LFS build scripts

set -e # Exit on error
set -u # Error on unset variables

# Source environment - finding it relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../../config/env.sh"

STATUS_DIR="$LFS/var/lib/ginger"
mkdir -p "$STATUS_DIR"

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

# Source environment - finding it relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../../config/env.sh"

# Validate critical environment
# Inside chroot, LFS should be empty/root, and LFS_TGT is not strictly required for native builds
if [ -z "${LFS+x}" ]; then
    log "ERROR" "LFS environment variable is not defined! Check ../../config/env.sh"
    exit 1
fi

check_built() {
    local PKG_NAME=$1
    if [ -f "$STATUS_DIR/$PKG_NAME.built" ]; then
        log "INFO" "$PKG_NAME already built. Skipping."
        return 0
    fi
    return 1
}

mark_built() {
    local PKG_NAME=$1
    touch "$STATUS_DIR/$PKG_NAME.built"
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
    mkdir -p "$GINGER_ROOT/build"
    cd "$GINGER_ROOT/build"
    
    # Clean up previous build directory
    rm -rf "$DIR_NAME"
    
    # Extract
    tar -xf "$GINGER_SOURCES/$ARCHIVE_NAME"
    
    # Some archives extract to a directory slightly different than the filename
    # but 99% match. We'll try to find the directory if cd fails.
    if [ -d "$DIR_NAME" ]; then
        cd "$DIR_NAME"
    else
        # Find the most recently created directory
        local NEW_DIR=$(ls -td */ | head -n 1 | cut -d'/' -f1)
        cd "$NEW_DIR"
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
