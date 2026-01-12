#!/bin/bash
# GingerOS - Source Downloader

source "$(dirname "$(readlink -f "$0")")/../config/env.sh"
source "$(dirname "$(readlink -f "$0")")/common.sh"

# 1. Prepare directory
log "INFO" "Preparing sources directory..."
mkdir -pv "$GINGER_SOURCES"
chmod -v a+wt "$GINGER_SOURCES"
cd "$GINGER_SOURCES"

# 2. Get list and checksums
log "INFO" "Fetching package lists for LFS 12.4..."
wget -nc https://www.linuxfromscratch.org/lfs/downloads/stable/wget-list
wget -nc https://www.linuxfromscratch.org/lfs/downloads/stable/md5sums

# 3. Download packages using the input file
log "INFO" "Downloading packages (using wget-list)..."
# We add -4 to ensure IPv4 and -nc to skip existing
wget -4 --input-file=wget-list --continue --tries=5 --timeout=20

# 4. Verification
log "INFO" "Verifying checksums..."
md5sum -c md5sums

log "INFO" "Source acquisition complete."
