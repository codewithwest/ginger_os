#!/bin/bash
# Package versions for LFS 12.4
export BINUTILS_VERSION="2.45"
export GCC_VERSION="15.2.0"
export GLIBC_VERSION="2.42"
export LINUX_VERSION="6.16.1"
export MPFR_VERSION="4.2.1"
export GMP_VERSION="6.3.0"
export MPC_VERSION="1.3.1"

# Target directory for the LFS system
export LFS="/mnt/lfs"

# Target architecture triplet
export LFS_TGT="x86_64-lfs-linux-gnu"

# Path configuration
export PATH="$LFS/tools/bin:/usr/bin:/usr/local/bin"

# Parallel build settings - use all available cores
export MAKEFLAGS="-j$(nproc)"

# Workspace directories
export GINGER_ROOT="/home/jonas/Documents/west/ginger_os"
export GINGER_SCRIPTS="$GINGER_ROOT/scripts"
export GINGER_SOURCES="$GINGER_ROOT/sources"
export GINGER_LOGS="$GINGER_ROOT/logs"

# Ensure directories exist
mkdir -p "$GINGER_SOURCES" "$GINGER_LOGS"

# Color codes for logging
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m' # No Color
