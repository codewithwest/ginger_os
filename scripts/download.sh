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
# -nc means no-clobber, don't download if exists
wget -nc -i wget-list --continue --directory-prefix="$GINGER_SOURCES"

log "INFO" "All sources downloaded."
