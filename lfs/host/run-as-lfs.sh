#!/bin/bash
set -e

SCRIPT="$1"
shift

if [ -z "$SCRIPT" ]; then
  echo "Usage: run-as-lfs.sh <script> [args...]"
  exit 1
fi

# Validate script existence
if [ ! -f "$SCRIPT" ]; then
    echo "ERROR: Script '$SCRIPT' not found!"
    exit 1
fi

# Do NOT use readlink -f here! 
# If the script is in a bind-mount (like /mnt/ginger_lfs/scripts), 
# readlink will resolve it back to the host path (e.g. /home/west/...)
# which the lfs user cannot access due to home directory permissions.
ABS_SCRIPT="$SCRIPT"

# Determine GINGER_ROOT. If LFS is mounted and contains a ginger_os repo, 
# use that path so the lfs user has permission to access it.
GINGER_HOST_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
source "${GINGER_HOST_ROOT}/lfs/lib/common.sh"

# Ensure LFS is set (falls back to LFS_MOUNT from common.sh/config)
LFS="${LFS:-$LFS_MOUNT}"
export LFS

if [ -d "${LFS:-}/ginger_os" ]; then
    GINGER_ROOT="${LFS}/ginger_os"
else
    GINGER_ROOT="$GINGER_HOST_ROOT"
fi

exec runuser -u lfs -- env -i \
  HOME=/home/lfs \
  TERM=${TERM:-xterm} \
  LFS="$LFS" \
  LC_ALL=POSIX \
  LFS_TGT=$(uname -m)-lfs-linux-gnu \
  PATH="$LFS/tools/bin:/usr/bin" \
  MAKEFLAGS=-j$(( $(nproc) > 12 ? 12 : $(nproc) )) \
  MOVE_TO_BUILD_DIR="${MOVE_TO_BUILD_DIR:-false}" \
  GINGER_UI_MASTER_PID="${GINGER_UI_MASTER_PID:-}" \
  GINGER_ROOT="$GINGER_ROOT" \
  GINGER_SOURCES="$GINGER_ROOT/sources" \
  GINGER_LOGS="$GINGER_ROOT/logs" \
  GINGER_SCRIPTS="$GINGER_ROOT/lfs" \
  CCACHE_DIR="$GINGER_ROOT/.ccache" \
  CCACHE_COMPRESS=1 \
  CCACHE_MAXSIZE=10G \
  /bin/bash "$ABS_SCRIPT" "$@"
