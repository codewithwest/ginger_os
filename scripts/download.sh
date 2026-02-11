#!/bin/bash
# GingerOS - Source Downloader

set -euo pipefail

command -v wget >/dev/null || {
  log "ERROR" "wget not installed"
  exit 1
}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"
source "${SCRIPT_DIR}/common.sh"

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
# Use all available cores to verify checksums
grep -v '^#' md5sums | xargs -P "$(nproc)" -I {} sh -c "echo '{}' | md5sum -c --status" || {
  log "ERROR" "Checksum verification failed after download"
  exit 1
}

log "INFO" "Source acquisition complete."
