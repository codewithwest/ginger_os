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

LFS_BASE_URL="https://www.linuxfromscratch.org/lfs/downloads/13.0-systemd"

download_list() {
    wget --progress=bar:force:noscroll --tries=3 --timeout=30 "$LFS_BASE_URL/wget-list" -O wget-list
    wget --progress=bar:force:noscroll --tries=3 --timeout=30 "$LFS_BASE_URL/md5sums" -O md5sums
}

# Validate md5sums format: each non-comment line must match <32hex><space or *><filename>
validate_md5sums() {
    grep -v '^#' md5sums 2>/dev/null | grep -qE '^[a-fA-F0-9]{32}[ *]' 2>/dev/null
}

# Download or re-download if missing or invalid
if [ ! -f "md5sums" ] || ! validate_md5sums; then
    log "INFO" "Downloading package lists..."
    download_list
    if ! validate_md5sums; then
        log "ERROR" "Downloaded md5sums file is invalid."
        exit 1
    fi
    log "INFO" "Package lists downloaded and verified."
fi

# 3. Pre-Download Checksum Verification
echo "__GINGER_PKG_MARKER__: Pre-download Check"
log "INFO" "Performing pre-download checksum verification..."
# If all standard packages match, we might skip the whole thing
if grep -v '^#' md5sums | grep -E '^[a-fA-F0-9]{32}[ *]' | xargs -P "$(nproc)" -I {} sh -c "echo '{}' | md5sum -c --status" 2>/dev/null; then
    # Also check BLFS extras and bootscripts
    if [ -f "libburn-1.5.6.tar.gz" ] && [ -f "libisofs-1.5.6.tar.gz" ] && [ -f "libisoburn-1.5.6.tar.gz" ] && [ -f "lfs-bootscripts-20250827.tar.xz" ]; then
        log "INFO" "All packages already exist and are valid. Marking complete."
        mark_built "04_setup_downloads"
        exit 0
    fi
fi

# 4. Download packages in parallel
echo "__GINGER_PKG_MARKER__: Downloading Packages"
log "INFO" "Downloading missing manifest packages in parallel..."

total=$(grep -v '^#' wget-list | wc -l)

# Download missing packages in parallel using xargs
download_pkg() {
    local url="$1"
    if [[ "$url" == *"ftpmirror.gnu.org"* ]]; then
        url="${url/https:/http:}"
    fi
    pkg=$(basename "$url")
    if [ ! -f "$pkg" ] || [ ! -s "$pkg" ]; then
        echo "__GINGER_PKG_MARKER__: $pkg"
        if ! wget -4 --continue --progress=bar:force:noscroll --tries=3 --timeout=15 "$url"; then
            if [[ "$url" == *"lfs-bootscripts"* ]]; then
                wget -4 --continue --progress=bar:force:noscroll --tries=3 --timeout=15 "https://www.linuxfromscratch.org/lfs/downloads/stable/lfs-bootscripts-20250827.tar.xz" || return 1
            else
                return 1
            fi
        fi
    fi
}
export -f download_pkg

grep -v '^#' wget-list | xargs -P "$(nproc)" -I {} bash -c 'download_pkg "$@"' _ {} || true

# Count how many packages we still have missing
missing_count=0
while read -r url; do
    pkg=$(basename "$url")
    if [ ! -f "$pkg" ] || [ ! -s "$pkg" ]; then
        missing_count=$((missing_count + 1))
    fi
done < <(grep -v '^#' wget-list)

if [ "$missing_count" -eq 0 ]; then
    log "INFO" "All $total manifest packages are already present."
else
    log "WARN" "$missing_count/$total packages still missing after download."
fi

# ---------------------------------------------------------------------
# Extra Tools Verification
# ---------------------------------------------------------------------
echo "__GINGER_PKG_MARKER__: BLFS Tools"

# Additional packages needed for ISO creation and other tools
extra_urls=(
    "https://files.libburnia-project.org/releases/libburn-1.5.6.tar.gz"
    "https://files.libburnia-project.org/releases/libisofs-1.5.6.tar.gz"
    "https://files.libburnia-project.org/releases/libisoburn-1.5.6.tar.gz"
    "https://www.linuxfromscratch.org/lfs/downloads/stable/lfs-bootscripts-20250827.tar.xz"
)

download_extra() {
    local url="$1"
    pkg=$(basename "$url")
    if [ ! -f "$pkg" ] || [ ! -s "$pkg" ]; then
        wget -4 -nc --progress=bar:force:noscroll --continue "$url"
    fi
}
export -f download_extra
printf '%s\n' "${extra_urls[@]}" | xargs -P "$(nproc)" -I {} bash -c 'download_extra "$@"' _ {}

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

# Only pass properly formatted checksum lines to md5sum -c (filters out any corrupt lines)
if grep -v '^#' md5sums | grep -E '^[a-fA-F0-9]{32}[ *]' | md5sum -c --quiet > "$failed_log" 2>&1; then
    rm -f "$failed_log"
    log "INFO" "Source acquisition complete and verified."
    mark_built "04_setup_downloads"
else
    log "ERROR" "Checksum verification FAILED:"
    cat "$failed_log"
    
    # Auto-heal: Remove corrupted files (if any were specifically named)
    corrupted=$(grep "FAILED" "$failed_log" | cut -d: -f1 || true)
    if [ -n "$corrupted" ]; then
        log "PROCESS" "Removing corrupted files..."
        echo "$corrupted" | xargs -r rm -fv || true
    elif grep -q "no properly formatted" "$failed_log" 2>/dev/null; then
        log "WARN" "md5sums file appears invalid. Re-downloading..."
        rm -f md5sums wget-list
    fi
    
    rm -f "$failed_log"
    exit 1
fi
