#!/bin/bash
# GingerOS - Source downloader

source "$(dirname "$(readlink -f "$0")")/common.sh"

WGET_LIST="https://www.linuxfromscratch.org/lfs/view/stable/wget-list"

cd "$GINGER_SOURCES"

log "INFO" "Checking host requirements..."
bash "$GINGER_SCRIPTS/version-check.sh"

log "INFO" "Downloading LFS 12.4 package list..."
wget -nc "$WGET_LIST"

log "INFO" "Downloading all packages (this may take a while)..."
# Try official wget-list first
if ! wget -nc --input-file=wget-list --continue --tries=3 --timeout=15; then
    log "WARN" "Primary download failed. Attempting to use LFS mirror..."
    
    # Create a mirror-list by replacing gnu.org and other problematic domains with the LFS mirror
    sed 's|https://.*\.gnu\.org/gnu/|https://anduin.linuxfromscratch.org/LFS/|g' wget-list > wget-list-mirror
    sed -i 's|https://.*\.kernel\.org/pub/linux/|https://anduin.linuxfromscratch.org/LFS/|g' wget-list-mirror
    
    wget -nc --input-file=wget-list-mirror --continue --tries=5 --timeout=30
fi

log "INFO" "Verifying packages..."
wget -nc https://www.linuxfromscratch.org/lfs/view/stable/md5sums
md5sum -c md5sums --status || log "WARN" "Some checksums failed. Check logs/md5_errors.txt"
