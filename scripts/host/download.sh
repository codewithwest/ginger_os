#!/bin/bash
# GingerOS - Source Downloader (Parallelized & UI-Hooked)

set -euo pipefail

command -v wget >/dev/null || {
  echo "ERROR: wget not installed"
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"
source "${SCRIPT_DIR}/../lib/common.sh"

# 1. Prepare directory
echo "GINGER_PKG: Directory Preparation"
log "INFO" "Preparing sources directory..."
mkdir -p "$GINGER_SOURCES"
chmod a+wt "$GINGER_SOURCES"
cd "$GINGER_SOURCES"

# 2. Get list and checksums
echo "GINGER_PKG: Fetching Package Lists"
log "INFO" "Fetching package lists for LFS ${LFS_VERSION}..."
wget -nc --progress=bar:force:noscroll "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/wget-list"
wget -nc --progress=bar:force:noscroll "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/md5sums"

# 3. Pre-Download Checksum Verification
echo "GINGER_PKG: Pre-download Check"
log "INFO" "Performing pre-download checksum verification..."
# If all standard packages match, we might skip the whole thing
if grep -v '^#' md5sums | xargs -P "$(nproc)" -I {} sh -c "echo '{}' | md5sum -c --status" 2>/dev/null; then
    # Also check BLFS extras
    if [ -f "libburn-1.5.6.tar.gz" ] && [ -f "libisofs-1.5.6.tar.gz" ] && [ -f "libisoburn-1.5.6.tar.gz" ]; then
        log "INFO" "All packages already exist and are valid. Marking complete."
        mark_built "05_download_sources"
        exit 0
    fi
fi

# 4. Download packages sequentially
echo "GINGER_PKG: Downloading Packages"
log "INFO" "Verifying all manifest packages exist locally..."

total=$(grep -v '^#' wget-list | wc -l)
current=0
missing_count=0

while read -r url; do
    current=$((current + 1))
    pkg=$(basename "$url")
    
    if [ ! -f "$pkg" ] || [ ! -s "$pkg" ]; then
        echo "GINGER_PKG: $pkg [$current/$total]"
        log "PROCESS" "Missing: $pkg. Downloading..."
        if ! wget -4 --continue --progress=bar:force:noscroll --tries=3 --timeout=15 "$url"; then
            log "ERROR" "Failed to download $pkg"
            exit 1
        fi
        missing_count=$((missing_count + 1))
    fi
done < <(grep -v '^#' wget-list)

if [ "$missing_count" -eq 0 ]; then
    log "INFO" "All $total manifest packages are already present."
else
    log "INFO" "Successfully acquired $missing_count missing packages."
fi

# ---------------------------------------------------------------------
# Extra Tools Verification
# ---------------------------------------------------------------------
echo "GINGER_PKG: BLFS Tools"
for url in "${extra_urls[@]}"; do
    pkg=$(basename "$url")
    if [ ! -f "$pkg" ] || [ ! -s "$pkg" ]; then
        log "PROCESS" "Downloading extra: $pkg..."
        wget -4 -nc --progress=bar:force:noscroll --continue "$url"
    fi
done

log "INFO" "Final manifest verification..."
local failed_log=$(mktemp)

# Run check, capture output (failures go to stderr usually, but capture both)
if grep -v '^#' md5sums | md5sum -c --quiet > "$failed_log" 2>&1; then
    rm -f "$failed_log"
    log "INFO" "Source acquisition complete and verified."
    mark_built "05_download_sources"
else
    log "ERROR" "Checksum verification FAILED:"
    cat "$failed_log"
    
    # Auto-heal: Remove corrupted files
    log "PROCESS" "Removing corrupted files to force re-download..."
    grep "FAILED" "$failed_log" | cut -d: -f1 | xargs rm -fv
    
    rm -f "$failed_log"
    exit 1
fi
