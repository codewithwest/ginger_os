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
echo "GINGER_PKG: Directory Preparation"
echo "Preparing sources directory..."
mkdir -pv "$GINGER_SOURCES" >/dev/null 2>&1
chmod -v a+wt "$GINGER_SOURCES" >/dev/null 2>&1
cd "$GINGER_SOURCES"

# 2. Get list and checksums
echo "GINGER_PKG: Fetching Package Lists"
echo "Fetching package lists for LFS ${LFS_VERSION}..."
wget -nc -q "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/wget-list"
wget -nc -q "https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}/md5sums"

# 3. Pre-Download Checksum Verification
echo "GINGER_PKG: Pre-download Check"
echo "Executing pre-download checksum verification..."
if grep -v '^#' md5sums | xargs -P "$(nproc)" -I {} sh -c "echo '{}' | md5sum -c --status" 2>/dev/null; then
    # Also check BLFS extras
    if [ -f "libburn-1.5.6.tar.gz" ] && [ -f "libisofs-1.5.6.tar.gz" ] && [ -f "libisoburn-1.5.6.tar.gz" ]; then
        echo "All packages valid. Skipping download."
        exit 0
    fi
fi

# 4. Download packages sequentially
echo "GINGER_PKG: Downloading Packages"
echo "Downloading missing packages..."
total=$(grep -v '^#' wget-list | wc -l)
current=0

while read -r url; do
    current=$((current + 1))
    pkg=$(basename "$url")
    echo "GINGER_PKG: $pkg [$current/$total]"
    echo "Downloading: $pkg..."
    wget -4 -q -nc --continue --tries=5 --timeout=20 "$url"
done < <(grep -v '^#' wget-list)

echo "GINGER_PKG: BLFS Tools"
echo "Downloading extra BLFS tools..."
extra_urls=(
    "https://files.libburnia-project.org/releases/libburn-1.5.6.tar.gz"
    "https://files.libburnia-project.org/releases/libisofs-1.5.6.tar.gz"
    "https://files.libburnia-project.org/releases/libisoburn-1.5.6.tar.gz"
)

for url in "${extra_urls[@]}"; do
    pkg=$(basename "$url")
    echo "GINGER_PKG: $pkg"
    echo "Downloading extra: $pkg..."
    wget -q -nc "$url"
done

echo "GINGER_PKG: Final Integrity Check"
echo "Performing final integrity check..."
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

check_extra "libburn-1.5.6.tar.gz" "cf9852f3b71dbc2b6c9e76f6eb0474f0"
check_extra "libisofs-1.5.6.tar.gz" "9f996b317f622802f12d28d27891709f"
check_extra "libisoburn-1.5.6.tar.gz" "efb19f7f718f0791f717b2c6094995ec"

if [ -n "$FAILED_FILES" ]; then
    echo "Error: Integrity check failed for:$FAILED_FILES"
    exit 1
fi

echo "Source acquisition complete."
mark_built "05_download_sources"
sleep 1
