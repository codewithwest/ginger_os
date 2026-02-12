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

# 4. Download packages in parallel (but show progress)
ui_step 3
ui_log "Downloading missing packages (this may take a while)..."
total=$(grep -v '^#' wget-list | wc -l)
current=0

while read -r url; do
    current=$((current + 1))
    pkg=$(basename "$url")
    ui_log "[$current/$total] Downloading: $pkg (Sequential Mode)..."
    wget -4 -q -nc --continue --tries=5 --timeout=20 "$url"
    sleep 0.1 # Ensure UI has time to render and user sees the sequence
done < <(grep -v '^#' wget-list)

ui_log "Acquiring extra BLFS tools..."
extra_urls=(
    "https://files.libburnia-project.org/releases/libburn-1.5.6.tar.gz"
    "https://files.libburnia-project.org/releases/libisofs-1.5.6.tar.gz"
    "https://files.libburnia-project.org/releases/libisoburn-1.5.6.tar.gz"
)

for url in "${extra_urls[@]}"; do
    pkg=$(basename "$url")
    ui_log "Acquiring extra: $pkg..."
    wget -q -nc "$url"
done

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

check_extra "libburn-1.5.6.tar.gz" "cf9852f3b71dbc2b6c9e76f6eb0474f0"
check_extra "libisofs-1.5.6.tar.gz" "9f996b317f622802f12d28d27891709f"
check_extra "libisoburn-1.5.6.tar.gz" "efb19f7f718f0791f717b2c6094995ec"

if [ -n "$FAILED_FILES" ]; then
    ui_error "Integrity check failed. Bad files:$FAILED_FILES"
fi

ui_log "Source acquisition complete."
sleep 1
