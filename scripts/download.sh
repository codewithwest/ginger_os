#!/bin/bash
# GingerOS - Source downloader

source "$(dirname "$(readlink -f "$0")")/common.sh"

WGET_LIST="https://www.linuxfromscratch.org/lfs/view/stable/wget-list"

cd "$GINGER_SOURCES"

log "INFO" "Checking host requirements..."
bash "$GINGER_SCRIPTS/version-check.sh"

log "INFO" "Downloading LFS 12.4 package list..."
wget -nc "$WGET_LIST"

log "INFO" "Primary servers are flaky. Using LFS Anduin Mirror for reliability..."
# Extract just the filenames from the wget-list
grep -oP '[^/]+$' wget-list > filenames.txt

# Download everything from Anduin mirror
MIRROR_URL="https://anduin.linuxfromscratch.org/LFS"

while read -r FILE; do
    if [ ! -f "$FILE" ]; then
        log "PROCESS" "Mirroring $FILE..."
        wget -nc -T 20 -t 5 "$MIRROR_URL/$FILE" || log "WARN" "Failed to download $FILE"
    fi
done < filenames.txt

log "INFO" "Verifying packages..."
wget -nc https://www.linuxfromscratch.org/lfs/view/stable/md5sums
md5sum -c md5sums --status || log "WARN" "Some checksums failed. Total files: $(ls -1 | wc -l)"
rm filenames.txt
