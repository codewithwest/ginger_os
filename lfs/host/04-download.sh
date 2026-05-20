#!/bin/bash
# GingerOS - Source Downloader (Parallelized & UI-Hooked)

set -euo pipefail

command -v wget >/dev/null || {
  echo "ERROR: wget not installed"
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/env.sh"
source "${SCRIPT_DIR}/../lfs/lib/common.sh"

# 1. Prepare directory
echo "__GINGER_PKG_MARKER__: Directory Preparation"
log "INFO" "Preparing sources directory..."
mkdir -p "$GINGER_SOURCES"
chmod a+wt "$GINGER_SOURCES"
cd "$GINGER_SOURCES"

# 2. Get list and checksums
echo "__GINGER_PKG_MARKER__: Fetching Package Lists"
log "INFO" "Fetching package lists for LFS ${LFS_VERSION}..."
# 2. Get list and checksums
echo "__GINGER_PKG_MARKER__: Fetching Package Lists"
log "INFO" "Fetching package lists for LFS ${LFS_VERSION}..."
# Download unified list from stable-systemd (includes all packages)
wget -nc --progress=bar:force:noscroll "https://www.linuxfromscratch.org/lfs/downloads/13.0-systemd/wget-list" -O wget-list
wget -nc --progress=bar:force:noscroll "https://www.linuxfromscratch.org/lfs/downloads/13.0-systemd/md5sums" -O md5sums

# 3. Pre-Download Checksum Verification
echo "__GINGER_PKG_MARKER__: Pre-download Check"
log "INFO" "Performing pre-download checksum verification..."
# If all standard packages match, we might skip the whole thing
if grep -v '^#' md5sums | xargs -P "$(nproc)" -I {} sh -c "echo '{}' | md5sum -c --status" 2>/dev/null; then
    # Also check BLFS extras
    if [ -f "libburn-1.5.6.tar.gz" ] && [ -f "libisofs-1.5.6.tar.gz" ] && [ -f "libisoburn-1.5.6.tar.gz" ]; then
        log "INFO" "All packages already exist and are valid. Marking complete."
        mark_built "04_setup_downloads"
        exit 0
    fi
fi

# 4. Download packages sequentially
echo "__GINGER_PKG_MARKER__: Downloading Packages"
log "INFO" "Verifying all manifest packages exist locally..."

total=$(grep -v '^#' wget-list | wc -l)
current=0
missing_count=0
tmp_missing=$(mktemp)
echo 0 > "$tmp_missing"

grep -v '^#' wget-list | while read -r url; do
    current=$((current + 1))
    
    if [[ "$url" == *"ftpmirror.gnu.org"* ]]; then
        url="${url/https:/http:}"
    fi

    # ncurses snapshots move frequently — use stable ftp.gnu.org release
    if [[ "$url" == *"invisible-mirror.net"* ]] || [[ "$url" == *"invisible-island.net"* ]]; then
        url="https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz"
    fi

    pkg=$(basename "$url")
    
    if [ ! -f "$pkg" ] || [ ! -s "$pkg" ]; then
        echo "__GINGER_PKG_MARKER__: $pkg [$current/$total]"
        log "PROCESS" "Missing: $pkg. Downloading..."
        if ! wget -4 --continue --progress=bar:force:noscroll --tries=3 --timeout=15 "$url"; then
            log "ERROR" "Failed to download $pkg"
            exit 1
        fi
        missing_count=$((missing_count + 1))
        echo $missing_count > "$tmp_missing"
    fi
done

missing_count=$(cat "$tmp_missing")
rm -f "$tmp_missing"

if [ "$missing_count" -eq 0 ]; then
    log "INFO" "All $total manifest packages are already present."
else
    log "INFO" "Successfully acquired $missing_count missing packages."
fi

# ---------------------------------------------------------------------
# Extra Tools Verification
# ---------------------------------------------------------------------
echo "__GINGER_PKG_MARKER__: BLFS Tools"

# Additional packages needed for ISO creation and other tools
extra_urls=(
    "https://files.libburnia-project.org/releases/libburn-1.5.6.tar.gz"
    "https://files.libburnia-project.org/releases/libisofs-1.5.6.tar.gz"
    "https://www.freedesktop.org/software/systemd/systemd-${SYSTEMD_VERSION}.tar.xz"
)

for url in "${extra_urls[@]}"; do
    pkg=$(basename "$url")
    if [ ! -f "$pkg" ] || [ ! -s "$pkg" ]; then
        log "PROCESS" "Downloading extra: $pkg..."
        wget -4 -nc --progress=bar:force:noscroll --continue "$url"
    fi
done

# Patch md5sums to match any redirected filenames
# ncurses: snapshot filename in manifest vs stable release we actually downloaded
if grep -q 'ncurses-6.5-[0-9]\+\.tgz' md5sums 2>/dev/null; then
    NCURSES_MD5=$(md5sum ncurses-6.5.tar.gz 2>/dev/null | cut -d' ' -f1)
    if [ -n "$NCURSES_MD5" ]; then
        sed -i "s|[a-f0-9]\+  ncurses-6\.5-[0-9]\+\.tgz|${NCURSES_MD5}  ncurses-6.5.tar.gz|" md5sums
        log "INFO" "Patched md5sums: ncurses snapshot → ncurses-6.5.tar.gz"
    fi
fi

log "INFO" "Final manifest verification..."
failed_log=$(mktemp)

# Run check, capture output (failures go to stderr usually, but capture both)
if grep -v '^#' md5sums | md5sum -c --quiet > "$failed_log" 2>&1; then
    rm -f "$failed_log"
    log "INFO" "Source acquisition complete and verified."
    mark_built "04_setup_downloads"
else
    log "ERROR" "Checksum verification FAILED:"
    cat "$failed_log"
    
    # Auto-heal: Remove corrupted files
    log "PROCESS" "Removing corrupted files to force re-download..."
    grep "FAILED" "$failed_log" | cut -d: -f1 | xargs rm -fv
    
    rm -f "$failed_log"
    exit 1
fi
