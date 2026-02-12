#!/bin/bash
set -e

SCRIPT="$1"
shift

if [ -z "$SCRIPT" ]; then
  echo "Usage: run-as-lfs.sh <script> [args...]"
  exit 1
fi

# Determine GINGER_ROOT from the script location
GINGER_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"

exec sudo runuser -u lfs -- env -i \
  HOME=/home/lfs \
  TERM=${TERM:-xterm} \
  LFS=/mnt/lfs \
  LC_ALL=POSIX \
  LFS_TGT=$(uname -m)-lfs-linux-gnu \
  PATH=/mnt/lfs/tools/bin:/usr/bin \
  MAKEFLAGS=-j$(nproc) \
  MOVE_TO_BUILD_DIR="${MOVE_TO_BUILD_DIR:-false}" \
  GINGER_UI_MASTER_PID="${GINGER_UI_MASTER_PID:-}" \
  GINGER_ROOT="$GINGER_ROOT" \
  GINGER_SOURCES="$GINGER_ROOT/sources" \
  GINGER_LOGS="$GINGER_ROOT/logs" \
  GINGER_SCRIPTS="$GINGER_ROOT/scripts" \
  bash "$SCRIPT" "$@"
