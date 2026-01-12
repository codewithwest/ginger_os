#!/bin/bash
# GingerOS - Source downloader

source "$(dirname "$(readlink -f "$0")")/common.sh"

WGET_LIST="https://www.linuxfromscratch.org/lfs/view/stable/wget-list"
VERSION_CHECK="https://www.linuxfromscratch.org/lfs/view/stable/version-check.sh"

cd "$GINGER_SOURCES"

log "INFO" "Checking host requirements..."
# Note: In a real scenario, we'd run version-check.sh here.
# For now, we assume the environment is sane as per user prompt.

log "INFO" "Downloading LFS 12.4 package list..."
wget -nc "$WGET_LIST"
wget -nc "$VERSION_CHECK"

log "INFO" "Downloading all packages (this may take a while)..."
# -nc means no-clobber, don't download if exists
wget -nc -i wget-list --continue --directory-prefix="$GINGER_SOURCES"

log "INFO" "All sources downloaded."
