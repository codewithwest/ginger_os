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

# Status directory - relative into the LFS partition
STATUS_DIR="$LFS/var/lib/ginger"

# Safety: Only try to create this if:
# 1. We are NOT at the default /mnt/lfs (meaning we are likely inside chroot)
# 2. OR the mountpoint actually exists and is writable.
if [ "$LFS" != "/mnt/lfs" ] || { mountpoint -q /mnt/lfs && [ -w /mnt/lfs ]; }; then
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
# Inside chroot, LFS is often set to "" (empty string) to represent root.
if [ -z "${LFS+x}" ]; then
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

fetch_missing_source() {
    local PKG_PATTERN=$1
    # Use a hard-coded path if we are inside chroot to be safe
    local SRC_DIR="/sources"
    [ -d "$SRC_DIR" ] || SRC_DIR="$GINGER_SOURCES"
    
    local WGET_LIST="${SRC_DIR}/wget-list"
    
    if [ ! -f "$WGET_LIST" ]; then
        log "INFO" "wget-list missing, fetching manifest..."
        wget -q -nc -O "$WGET_LIST" "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/wget-list" || true
    fi

    log "PROCESS" "Searching manifest for '$PKG_PATTERN'..."
    local URL=$(grep -iE "/${PKG_PATTERN}-?[0-9]" "$WGET_LIST" 2>/dev/null | head -n 1)
    
    # Fallback to direct GNU mirror if manifest search fails for gettext
    if [ -z "$URL" ] && [[ "$PKG_PATTERN" == *"gettext"* ]]; then
        URL="https://ftp.gnu.org/gnu/gettext/gettext-0.23.1.tar.gz"
    fi

    if [ -n "$URL" ]; then
        log "INFO" "Found download target: $URL"
        log "PROCESS" "Downloading to $SRC_DIR..."
        
        # Save to a temp location first to ensure we don't end up with a 0-byte file
        local PKG_NAME=$(basename "$URL")
        if wget -4 --continue --tries=3 --timeout=15 -O "${SRC_DIR}/${PKG_NAME}.tmp" "$URL"; then
             mv "${SRC_DIR}/${PKG_NAME}.tmp" "${SRC_DIR}/${PKG_NAME}"
             log "INFO" "Successfully acquired $PKG_NAME"
             return 0
        else
             rm -f "${SRC_DIR}/${PKG_NAME}.tmp"
             log "ERROR" "Network Error: Could not reach $URL"
        fi
    fi
    return 1
}

extract() {
    local PKG_PATTERN=$1
    
    # 1. Try to find local archive
    # We use find to be more robust than ls | grep
    local ARCHIVE_NAME=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -name "${PKG_PATTERN}*" | grep -E "\.(tar\..*|tgz)$" | head -n 1)
    
    # If not found or if the file is basically empty/incomplete
    if [ -z "$ARCHIVE_NAME" ] || [ ! -s "$ARCHIVE_NAME" ]; then
        log "WARN" "Source archive for '$PKG_PATTERN' not found or empty in $GINGER_SOURCES."
        if fetch_missing_source "$PKG_PATTERN"; then
            log "INFO" "Recovery successful. Re-checking for archive..."
            ARCHIVE_NAME=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -name "${PKG_PATTERN}*" | grep -E "\.(tar\..*|tgz)$" | head -n 1)
        fi
    fi

    if [ -z "$ARCHIVE_NAME" ] || [ ! -f "$ARCHIVE_NAME" ]; then
        log "ERROR" "CRITICAL: Could not find or download source for '$PKG_PATTERN'"
        exit 1
    fi
    
    # Just the basename for processing
    ARCHIVE_NAME=$(basename "$ARCHIVE_NAME")

    # Determine the directory name (strip .tar.*)
    local DIR_NAME=$(echo "$ARCHIVE_NAME" | sed -E 's/\.(tar\.(gz|bz2|xz)|tgz)$//')
    
    # Handle specific source-suffix cases like tcl's "-src"
    DIR_NAME=${DIR_NAME/-src/}

    log "PROCESS" "Extracting $ARCHIVE_NAME..."
    # Build inside LFS sources to avoid permission issues on the host
    local BUILD_BASE="$LFS/sources"
    mkdir -p "$BUILD_BASE"
    cd "$BUILD_BASE"
    
    # Safe cleanup of previous build directory
    if [[ -n "$DIR_NAME" && "$DIR_NAME" != "/" && "$DIR_NAME" != "." ]]; then
        # Only remove if pattern is sufficiently specific (length > 2)
        if [[ ${#DIR_NAME} -gt 2 ]]; then
             rm -rf "${DIR_NAME%-*}"* || true
        fi
    fi
    
    # Extract with re-download fallback
    # Normalize the path to remove double slashes
    local CLEAN_SOURCES=$(echo "$GINGER_SOURCES" | sed 's|//|/|g')
    local SRC_PATH="${CLEAN_SOURCES%/}/$ARCHIVE_NAME"
    
    log "PROCESS" "Attempting extraction of $SRC_PATH..."
    
    # Isolate extraction attempt using the '||' pattern (prevents set -e and trap ERR)
    TAR_EXIT=0
    tar -xf "$SRC_PATH" 2>/dev/null || TAR_EXIT=$?

    if [ $TAR_EXIT -ne 0 ]; then
        log "WARN" "Primary extraction failed for $SRC_PATH (Archive likely missing)."
        log "PROCESS" "Triggering self-healing recovery..."
        
        if fetch_missing_source "$PKG_PATTERN"; then
            # Re-locate the archive (it might have a different name)
            local NEW_SEARCH=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -name "${PKG_PATTERN}*" | grep -E "\.(tar\..*|tgz)$" | head -n 1)
            if [ -n "$NEW_SEARCH" ]; then
                ARCHIVE_NAME=$(basename "$NEW_SEARCH")
                SRC_PATH="${CLEAN_SOURCES%/}/$ARCHIVE_NAME"
                log "PROCESS" "Retrying extraction with fresh archive: $ARCHIVE_NAME"
                # This time we let it fail normally if it still doesn't work (no isolation)
                tar -xf "$SRC_PATH"
            else
                log "ERROR" "CRITICAL: fetch_missing_source reported success but archive is still missing!"
                exit 1
            fi
        else
            log "ERROR" "CRITICAL: Could not primary-extract AND could not download $PKG_PATTERN"
            exit 1
        fi
    fi
    
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
    cleanup
}
    exit 1
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
