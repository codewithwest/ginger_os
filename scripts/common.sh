#!/bin/bash
# GingerOS - Common functions for LFS build scripts

set -e # Exit on error
set -u # Error on unset variables

# Source environment - finding it relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"

STATUS_DIR="$LFS/var/lib/ginger"
mkdir -p "$STATUS_DIR"

log() {
    local TYPE=$1
    local MSG=$2
    local COLOR=$NC
    
    case $TYPE in
        "INFO")    COLOR=$GREEN ;;
        "WARN")    COLOR=$YELLOW ;;
        "ERROR")   COLOR=$RED ;;
        "PROCESS") COLOR=$NC ;;
    esac
    
    echo -e "${COLOR}[$(date +'%Y-%m-%d %H:%M:%S')] [$TYPE] $MSG${NC}"
}

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
    local ARCHIVE=$1
    local DIR_NAME=$2
    
    log "PROCESS" "Extracting $ARCHIVE..."
    mkdir -p "$GINGER_ROOT/build"
    cd "$GINGER_ROOT/build"
    
    # Clean up previous build directory if it exists
    rm -rf "$DIR_NAME"
    
    tar -xf "$GINGER_SOURCES/$ARCHIVE"
    cd "$DIR_NAME"
}

# Error handler
error_handler() {
    local LINE=$1
    local CMD=$2
    log "ERROR" "Command '$CMD' failed at line $LINE"
    exit 1
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
