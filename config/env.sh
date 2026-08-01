#!/bin/bash
# GingerOS Environment Configuration
# Color codes for logging
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m' # No Color

# Source the central configuration file
# This allows overriding variables like LFS_VERSION, LFS_MOUNT, etc. in one place.
GINGER_ROOT_RAW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GINGER_ROOT=$(echo "$GINGER_ROOT_RAW" | sed 's|^//|/|; s|/$||')
[ -z "$GINGER_ROOT" ] && GINGER_ROOT="/"

CONF_FILE="${GINGER_ROOT}/ginger.conf"
# If not found at root, check if we are in a mount point with the repo inside it
if [ ! -f "$CONF_FILE" ] && [ -f "${GINGER_ROOT}/ginger_os/ginger.conf" ]; then
    CONF_FILE="${GINGER_ROOT}/ginger_os/ginger.conf"
fi

if [ -f "$CONF_FILE" ]; then
    # Basic key=value parser for ginger.conf
    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Ignore comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        export "$key"="$value"
    done < "$CONF_FILE"
fi

# Load central version constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/versions.sh"

# Target directory for the LFS system
export LFS="${LFS_MOUNT}"

# Chroot detection: clear LFS only in the INNER chroot (phase 3+)
# where we are actually running inside the LFS system being built.
# The outer Ubuntu chroot (steps 3-10) still needs LFS=/mnt/lfs.
# Detect inner chroot by checking if /tools exists (built during phase 1/2)
# AND /mnt/lfs does not exist (we are past the Ubuntu layer).
if [ ! -d "$LFS_MOUNT" ] && [ -d "/tools" ] && [ "$(id -u)" -eq 0 ]; then
    export LFS=""
fi

# In phase 3 chroot, sources and state dir are at known bind-mount paths
if [ ! -d "$LFS_MOUNT" ] && [ -d "/sources" ]; then
    export GINGER_SOURCES="/sources"
fi

# Target architecture triplet
export LFS_TGT="${LFS_TGT:-x86_64-lfs-linux-gnu}"

# Path configuration
export PATH="$LFS/tools/bin:/usr/bin:/usr/sbin:/usr/local/bin"

# Parallel build settings - cap at 12 to keep system responsive
CORES=$(nproc 2>/dev/null || echo 4)
if [ "$CORES" -gt 12 ]; then CORES=10; fi
export MAKEFLAGS="-j${CORES}"

# ccache - compiler cache for faster rebuilds
# NOTE: CC/CXX are NOT exported globally here — they interfere with cross-compiler
# builds in Phases 1-2. ccache is injected only inside chroot.sh for Phase 3+.
export CCACHE_DIR="${CCACHE_DIR:-${GINGER_ROOT}/.ccache}"
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-10G}"

# Workspace directories
# Use sed to ensure GINGER_ROOT is normalized (no double slashes or trailing slashes)
# especially when it becomes the root "/" inside chroot.
GINGER_ROOT_RAW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GINGER_ROOT=$(echo "$GINGER_ROOT_RAW" | sed 's|^//|/|; s|/$||')

# If GINGER_ROOT is empty (can happen at true root), make it /
[ -z "$GINGER_ROOT" ] && GINGER_ROOT="/"

# --- CRITICAL SAFETY CHECK (Issue #14) ---
# Skip this check inside chroot where GINGER_ROOT may resolve to /
if [ -n "${LFS:-}" ]; then
    if [ ! -d "$GINGER_ROOT/lfs" ] || [ ! -d "$GINGER_ROOT/config" ]; then
        echo -e "${RED}ERROR: Invalid GINGER_ROOT detected: $GINGER_ROOT${NC}"
        echo "This script must be run from within the GingerOS source tree."
        exit 1
    fi
fi

export GINGER_SCRIPTS="${GINGER_ROOT%/}/lfs"
export GINGER_SOURCES="${GINGER_ROOT%/}/sources"
export GINGER_LOGS="${GINGER_ROOT%/}/logs"

# Ensure logs are writable. If the project logs are root-owned or inaccessible,
# fall back to the LFS-managed log directory which is owned by lfs.
if [ "$(id -u)" -ne 0 ] && [ ! -w "$GINGER_LOGS" ]; then
    if [ -d "${LFS}/var/log/ginger" ]; then
        export GINGER_LOGS="${LFS}/var/log/ginger"
    fi
fi

# Ensure directories exist (silently ignore errors if they exist but are unwritable)
mkdir -p "$GINGER_SOURCES" 2>/dev/null || true
mkdir -p "$GINGER_LOGS" 2>/dev/null || true

