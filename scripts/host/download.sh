#!/bin/bash
# GingerOS - Source Downloader

set -euo pipefail

command -v wget >/dev/null || {
  log "ERROR" "wget not installed"
  exit 1
}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/ui.sh"

ui_init_dashboard "Environment" "Fetching Lists" "Verification" "Download" "Final Check"
ui_step 0


# 1. Prepare directory
ui_log "Preparing sources directory..."
mkdir -pv "$GINGER_SOURCES" >/dev/null 2>&1
chmod -v a+wt "$GINGER_SOURCES" >/dev/null 2>&1
cd "$GINGER_SOURCES"

# 2. Get list and checksums
ui_step 1
ui_log "Fetching package lists for LFS ${LFS_VERSION}..."
wget -nc -q "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/wget-list"
wget -nc -q "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/md5sums"

# 3. Pre-Download Checksum Verification
ui_step 2
ui_log "Executing pre-download checksum verification..."
if grep -v '^#' md5sums | xargs -P "$(nproc)" -I {} sh -c "echo '{}' | md5sum -c --status" 2>/dev/null; then
    # Also check BLFS extras
    if [ -f "libburn-1.5.6.tar.gz" ] && [ -f "libisofs-1.5.6.tar.gz" ] && [ -f "libisoburn-1.5.6.tar.gz" ]; then
        ui_log "All packages valid. Skipping download."
        exit 0
    fi
fi

# 4. Download packages in parallel
ui_step 3
ui_log "Downloading missing packages (this may take a while)..."
grep -v '^#' wget-list | xargs -P 4 -n 1 wget -4 -q -nc --continue --tries=5 --timeout=20 &
ui_spinner $! "Acquiring LFS sources..."

ui_log "Acquiring extra BLFS tools (xorriso dependencies)..."
wget -q -nc https://files.libburnia-project.org/releases/libburn-1.5.6.tar.gz &
ui_spinner $! "Downloading libburn..."
wget -q -nc https://files.libburnia-project.org/releases/libisofs-1.5.6.tar.gz &
ui_spinner $! "Downloading libisofs..."
wget -q -nc https://files.libburnia-project.org/releases/libisoburn-1.5.6.tar.gz &
ui_spinner $! "Downloading libisoburn..."

ui_step 4
ui_log "Performing final integrity check..."
# Use all available cores to verify checksums, capture output to show failures
FAILED_FILES=""
while read -r line; do
    echo "$line" | md5sum -c --status || FAILED_FILES="$FAILED_FILES $(echo "$line" | awk '{print $2}')"
done < <(grep -v '^#' md5sums)

# Verify extra BLFS packages manually
check_extra() {
    local file=$1
    local expected=$2
    if [ -f "$file" ]; then
        local actual=$(md5sum "$file" | awk '{print $1}')
        if [ "$actual" != "$expected" ]; then
            FAILED_FILES="$FAILED_FILES $file(MD5_MISMATCH)"
        fi
    else
        FAILED_FILES="$FAILED_FILES $file(MISSING)"
    fi
}

check_extra "libburn-1.5.6.tar.gz" "7843818f98a3350367e163351ec3c2e6"
check_extra "libisofs-1.5.6.tar.gz" "601e355df02741d440938afdc1dd2138"
check_extra "libisoburn-1.5.6.tar.gz" "576722d7a9609a56d683783a3889163b"

if [ -n "$FAILED_FILES" ]; then
    ui_error "Integrity check failed. Bad files:$FAILED_FILES"
fi

ui_log "Source acquisition complete."
sleep 1
