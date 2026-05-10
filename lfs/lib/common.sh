#!/bin/bash
# GingerOS - Common functions for LFS build scripts

set -e # Exit on error
set -u # Error on unset variables

# Source environment - finding it relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"

# State directory on host for orchestrator markers
# Inside phase 3 chroot, ginger_os is bind-mounted at /ginger_os
if [ -d "/ginger_os/.build_state" ]; then
    GINGER_STATE_DIR="/ginger_os/.build_state"
else
    GINGER_STATE_DIR="${GINGER_ROOT}/.build_state"
fi
mkdir -p "$GINGER_STATE_DIR" 2>/dev/null || true

# Status directory - relative into the LFS partition
STATUS_DIR="$LFS/var/lib/ginger"

# Safety: Only try to create this if:
# 1. We are NOT at the default ${LFS} (meaning we are likely inside chroot)
# 2. OR the mountpoint actually exists and is writable.
if [ "$LFS" != "${LFS}" ] || { mountpoint -q "$LFS" && [ -w "$LFS" ]; }; then
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
    
    # Use the host's state directory as the single source of truth.
    if [ -n "${GINGER_STATE_DIR:-}" ]; then
        if [ ! -d "$GINGER_STATE_DIR" ]; then
            mkdir -p "$GINGER_STATE_DIR" 2>/dev/null || sudo mkdir -p "$GINGER_STATE_DIR" 2>/dev/null || true
        fi
        
        # Try touching normally first
        if ! touch "$GINGER_STATE_DIR/$PKG_NAME.built" 2>/dev/null; then
            # Fallback to sudo if permission denied
            sudo touch "$GINGER_STATE_DIR/$PKG_NAME.built" 2>/dev/null || true
            # Try to give ownership back to the current user so the TUI can manage it
            sudo chown $(id -u):$(id -g) "$GINGER_STATE_DIR/$PKG_NAME.built" 2>/dev/null || true
        fi
    fi
    
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
        wget -nc --progress=bar:force:noscroll -O "$WGET_LIST" "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/wget-list" || true
    fi

    log "PROCESS" "Searching manifest for '$PKG_PATTERN'..."
    local URL=$(grep -iE "/${PKG_PATTERN}-?[0-9]" "$WGET_LIST" 2>/dev/null | head -n 1)
    
    # Fallback to direct GNU mirror if manifest search fails for gettext
    if [ -z "$URL" ]; then
        if [[ "$PKG_PATTERN" == *"gettext"* ]]; then
            URL="https://ftp.gnu.org/gnu/gettext/gettext-0.26.tar.xz"
        elif [[ "$PKG_PATTERN" == *"libburn"* ]]; then
            URL="https://files.libburnia-project.org/releases/libburn-1.5.6.tar.gz"
        elif [[ "$PKG_PATTERN" == *"libisofs"* ]]; then
            URL="https://files.libburnia-project.org/releases/libisofs-1.5.6.tar.gz"
        elif [[ "$PKG_PATTERN" == *"libisoburn"* ]]; then
            URL="https://files.libburnia-project.org/releases/libisoburn-1.5.6.tar.gz"
        fi
    fi

    if [ -n "$URL" ]; then
        log "INFO" "Found download target: $URL"
        
        # Check if we have tools to download
        if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
            log "WARN" "Download tools (wget/curl) are missing (likely Phase 3 chroot)."
            log "INFO" "__GINGER_MISSING_SOURCE_URL__: $URL"
            log "PROCESS" "Waiting for host to process download (60s timeout)..."
            
            # Wait up to 60 seconds for the file to appear
            local TARGET_PKG_NAME=$(basename "$URL")
            for i in {1..12}; do
                sleep 5
                if [ -s "${SRC_DIR}/${TARGET_PKG_NAME}" ]; then
                    log "INFO" "Host successfully acquired $TARGET_PKG_NAME!"
                    return 0
                fi
                log "INFO" "Polling for $TARGET_PKG_NAME... ($((i*5))s)"
            done
            
            log "ERROR" "Timeout waiting for host download. Please download $URL manually on the host and place it in $SRC_DIR"
            return 1
        fi

        log "PROCESS" "Downloading to $SRC_DIR..."
        
        # Save to a temp location first to ensure we don't end up with a 0-byte file
        local PKG_NAME=$(basename "$URL")
        
        if command -v wget &> /dev/null; then
            if wget -4 --continue --progress=bar:force:noscroll --tries=3 --timeout=15 -O "${SRC_DIR}/${PKG_NAME}.tmp" "$URL"; then
                 mv "${SRC_DIR}/${PKG_NAME}.tmp" "${SRC_DIR}/${PKG_NAME}"
                 log "INFO" "Successfully acquired $PKG_NAME via wget"
                 return 0
            fi
        elif command -v curl &> /dev/null; then
            if curl -L --connect-timeout 15 --retry 3 -o "${SRC_DIR}/${PKG_NAME}.tmp" "$URL"; then
                 mv "${SRC_DIR}/${PKG_NAME}.tmp" "${SRC_DIR}/${PKG_NAME}"
                 log "INFO" "Successfully acquired $PKG_NAME via curl"
                 return 0
            fi
        fi
        
        rm -f "${SRC_DIR}/${PKG_NAME}.tmp"
        log "ERROR" "Network Error: Could not reach $URL"
    fi
    return 1
}

apply_patch() {
    local PKG_PATTERN=$1
    local PATCH_SEARCH=${2:-} # Optional search term within the patch name
    
    # Try to find the patch file with smart filtering
    local PATCH_NAME=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -name "${PKG_PATTERN}*${PATCH_SEARCH}*.patch" | head -n 1)
    
    if [ -z "$PATCH_NAME" ]; then
        # Fallback to case-insensitive search
        PATCH_NAME=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -iname "${PKG_PATTERN}*${PATCH_SEARCH}*.patch" | head -n 1)
    fi
    
    if [ -z "$PATCH_NAME" ]; then
        log "WARN" "No patch matching '${PKG_PATTERN}*${PATCH_SEARCH}*.patch' found in $GINGER_SOURCES"
        return 1
    fi
    
    # In Phase 3 chroot, use the internal /sources path
    local INTERNAL_PATCH_PATH="/sources/$(basename "$PATCH_NAME")"
    [ -f "$INTERNAL_PATCH_PATH" ] || INTERNAL_PATCH_PATH="$PATCH_NAME"
    
    log "INFO" "Applying patch: $(basename "$PATCH_NAME")..."
    
    # Try applying with -f (force) to avoid interactive prompts
    if patch -Np1 -f -i "$INTERNAL_PATCH_PATH" &>/dev/null; then
        log "INFO" "Successfully applied $(basename "$PATCH_NAME")"
        return 0
    else
        # Check if already applied by attempting a dry-run reversal
        if patch -Np1 --dry-run -R -i "$INTERNAL_PATCH_PATH" &>/dev/null; then
            log "WARN" "Patch $(basename "$PATCH_NAME") appears already applied. Skipping."
            return 0
        else
            log "ERROR" "Failed to apply patch $(basename "$PATCH_NAME")"
            return 1
        fi
    fi
}

extract() {
    local PKG_PATTERN=$1
    
    # 1. Try to find local archive with smart filtering
    # We prefer case-sensitive first, then case-insensitive
    local ARCHIVE_NAME=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -name "${PKG_PATTERN}*" \
        ! -name "*-docs-*" ! -name "*-html-*" ! -name "*-man-*" ! -name "*-manpages-*" | grep -E "\.(tar\..*|tgz|zip)$" | head -n 1)
    
    if [ -z "$ARCHIVE_NAME" ]; then
        # Fallback to case-insensitive search
        ARCHIVE_NAME=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -iname "${PKG_PATTERN}*" \
            ! -iname "*-docs-*" ! -iname "*-html-*" ! -iname "*-man-*" ! -iname "*-manpages-*" | grep -E "\.(tar\..*|tgz|zip)$" | head -n 1)
    fi
    
    # If still not found or if the file is basically empty/incomplete
    if [ -z "$ARCHIVE_NAME" ] || [ ! -s "$ARCHIVE_NAME" ]; then
        log "WARN" "Source archive for '$PKG_PATTERN' not found or empty in $GINGER_SOURCES."
        if fetch_missing_source "$PKG_PATTERN"; then
            log "INFO" "Recovery successful. Re-checking for archive..."
            ARCHIVE_NAME=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -iname "${PKG_PATTERN}*" \
                ! -iname "*-docs-*" ! -iname "*-html-*" ! -iname "*-man-*" ! -iname "*-manpages-*" | grep -E "\.(tar\..*|tgz|zip)$" | head -n 1)
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
        log "PROCESS" "Cleaning up any existing directory for $DIR_NAME..."
        # Remove the exact directory if it exists
        rm -rf "$DIR_NAME" 2>/dev/null || true
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
            # Re-locate the archive, prioritizing non-doc/non-man archives
            local NEW_SEARCH=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -name "${PKG_PATTERN}*" | \
                               grep -E "\.(tar\..*|tgz)$" | \
                               grep -vE "-(man|docs|doc|manual|html|pdf|extra)" | head -n 1)
            # If that failed, try any match as a fallback
            if [ -z "$NEW_SEARCH" ]; then
                NEW_SEARCH=$(find "$GINGER_SOURCES" -maxdepth 1 -type f -name "${PKG_PATTERN}*" | \
                             grep -E "\.(tar\..*|tgz)$" | head -n 1)
            fi
            
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
    
    # Determine the directory name from the tarball itself to be deterministic
    local NEW_DIR=$(tar -tf "$SRC_PATH" | head -n 1 | cut -d/ -f1)
    
    if [ -d "$NEW_DIR" ]; then
        cd "$NEW_DIR"
        # Export for cleanup later
        export GINGER_CURRENT_BUILD_DIR="$BUILD_BASE/$NEW_DIR"
    else
        log "ERROR" "Failed to find extracted directory '$NEW_DIR' in $BUILD_BASE"
        exit 1
    fi
}

cleanup() {
    if [ -n "${GINGER_CURRENT_BUILD_DIR:-}" ]; then
        if [ -d "$GINGER_CURRENT_BUILD_DIR" ]; then
            log "PROCESS" "Cleaning up build directory: $GINGER_CURRENT_BUILD_DIR"
            rm -rf "$GINGER_CURRENT_BUILD_DIR"
        fi
        unset GINGER_CURRENT_BUILD_DIR
    fi
}

# Error handler
error_handler() {
    local LINE=$1
    local CMD=$2
    log "ERROR" "Command '$CMD' failed at line $LINE"
    # cleanup
    exit 1
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
