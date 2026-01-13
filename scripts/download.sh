#!/bin/bash
# GingerOS - Source Downloader

set -euo pipefail

command -v wget >/dev/null || {
  log "ERROR" "wget not installed"
  exit 1
}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"
source "${SCRIPT_DIR}/../common.sh"

# 1. Prepare directory
log "INFO" "Preparing sources directory..."
mkdir -pv "$GINGER_SOURCES"
chmod -v a+wt "$GINGER_SOURCES"
cd "$GINGER_SOURCES"

# 2. Get list and checksums
log "INFO" "Fetching package lists for LFS ${LFS_VERSION}..."
wget -nc "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/wget-list"
wget -nc "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/md5sums"

# 3. Download packages using the input file
log "INFO" "Downloading packages (using wget-list)..."
# We add -4 to ensure IPv4 and -nc to skip existing
wget -4 --input-file=wget-list --continue --tries=5 --timeout=20

# 4. Verification
log "INFO" "Verifying checksums..."
md5sum -c md5sums || {
  log "ERROR" "Checksum verification failed"
  exit 1
}

log "INFO" "Source acquisition complete."
