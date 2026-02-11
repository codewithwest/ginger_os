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

# 1. Prepare directory
log "INFO" "Preparing sources directory..."
mkdir -pv "$GINGER_SOURCES"
chmod -v a+wt "$GINGER_SOURCES"
cd "$GINGER_SOURCES"

# 2. Get list and checksums
log "INFO" "Fetching package lists for LFS ${LFS_VERSION}..."
wget -nc "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/wget-list"
wget -nc "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/md5sums"

# 3. Pre-Download Checksum Verification
log "INFO" "Performing pre-download checksum verification..."
if grep -v '^#' md5sums | xargs -P "$(nproc)" -I {} sh -c "echo '{}' | md5sum -c --status" 2>/dev/null; then
    # Also check BLFS extras
    if [ -f "libburn-1.5.6.tar.gz" ] && [ -f "libisofs-1.5.6.tar.gz" ] && [ -f "libisoburn-1.5.6.tar.gz" ]; then
        log "INFO" "All packages already exist and are valid. Skipping download."
        exit 0
    fi
fi

# 4. Download packages in parallel
log "INFO" "Sources missing or invalid. Downloading packages..."
grep -v '^#' wget-list | xargs -P 4 -n 1 wget -4 -nc --continue --tries=5 --timeout=20

# ---------------------------------------------------------------------
# Download Extra BLFS Packages (xorriso support)
# ---------------------------------------------------------------------
log "INFO" "Downloading extra BLFS packages (libburn, libisofs, libisoburn)..."

# Libburn
if [ ! -f "libburn-1.5.6.tar.gz" ]; then
    wget https://files.libburnia-project.org/releases/libburn-1.5.6.tar.gz
fi

# Libisofs
if [ ! -f "libisofs-1.5.6.tar.gz" ]; then
    wget https://files.libburnia-project.org/releases/libisofs-1.5.6.tar.gz
fi

# Libisoburn
if [ ! -f "libisoburn-1.5.6.tar.gz" ]; then
    wget https://files.libburnia-project.org/releases/libisoburn-1.5.6.tar.gz
fi

log "INFO" "Performing final checksum verification..."
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
    log "ERROR" "Checksum verification failed for files:$FAILED_FILES"
    log "INFO" "Try deleting the failed files and running the script again."
    exit 1
fi

log "INFO" "Source acquisition complete."
