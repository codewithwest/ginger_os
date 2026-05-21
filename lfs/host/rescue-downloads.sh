#!/bin/bash
# GingerOS - Rescue Missing Downloads
# Use this script when sources are accidentally deleted or corrupted.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"
source "${SCRIPT_DIR}/../lib/common.sh"

log "INFO" "Starting Rescue Downloads script..."

if [ ! -d "$GINGER_SOURCES" ]; then
    log "ERROR" "Sources directory $GINGER_SOURCES does not exist!"
    exit 1
fi

cd "$GINGER_SOURCES"

if [ ! -f "wget-list" ] || [ ! -f "md5sums" ]; then
    log "WARN" "wget-list or md5sums is missing. Re-downloading manifests..."
    wget -nc "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/wget-list"
    wget -nc "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/md5sums"
fi

log "PROCESS" "Scanning for missing or empty files..."
missing_count=0

grep -v '^#' wget-list | while read -r url; do
    if [[ "$url" == *"ftpmirror.gnu.org"* ]]; then
        url="${url/https:/http:}"
    fi

    # ncurses snapshots move frequently — use stable ftp.gnu.org release
    # if [[ "$url" == *"invisible-mirror.net"* ]] || [[ "$url" == *"invisible-island.net"* ]]; then
    #     url="https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz"
    # fi

    pkg=$(basename "$url")
    
    if [ ! -f "$pkg" ] || [ ! -s "$pkg" ]; then
        log "WARN" "Missing or empty: $pkg. Rescuing..."
        rm -f "$pkg" # Remove if empty
        if wget -4 --continue --progress=bar:force:noscroll --tries=3 --timeout=15 "$url"; then
            log "INFO" "Successfully rescued $pkg"
        else
            log "ERROR" "Failed to rescue $pkg"
            missing_count=$((missing_count + 1))
        fi
    fi
done

if [ "$missing_count" -gt 0 ]; then
    log "ERROR" "Failed to rescue $missing_count files. Check network connectivity."
    exit 1
fi

log "PROCESS" "Verifying md5sums of all rescued files..."

# Patch md5sums for ncurses if needed
if grep -q 'ncurses-6.5-[0-9]\+\.tgz' md5sums 2>/dev/null; then
    NCURSES_MD5=$(md5sum ncurses-6.5.tar.gz 2>/dev/null | cut -d' ' -f1 || echo "")
    if [ -n "$NCURSES_MD5" ]; then
        sed -i "s|[a-f0-9]\+  ncurses-6\.5-[0-9]\+\.tgz|${NCURSES_MD5}  ncurses-6.5.tar.gz|" md5sums
    fi
fi

failed_log=$(mktemp)
if grep -v '^#' md5sums | md5sum -c --quiet > "$failed_log" 2>&1; then
    rm -f "$failed_log"
    log "INFO" "Rescue complete! All files are present and verified."
else
    log "ERROR" "Checksum verification FAILED for some files:"
    cat "$failed_log"
    log "WARN" "Removing corrupted files to force re-download on next run..."
    grep "FAILED" "$failed_log" | cut -d: -f1 | xargs -r rm -fv
    rm -f "$failed_log"
    log "ERROR" "Please run the rescue script again."
    exit 1
fi
