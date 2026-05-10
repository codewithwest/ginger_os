#!/bin/bash
# Test script for lfs/lib/common.sh

# Setup mock environment
export GINGER_ROOT="/tmp/ginger_test"
export LFS="/tmp/ginger_lfs"
export LFS_VERSION="12.4"
mkdir -p "$GINGER_ROOT" "$LFS"

# Mock date for stable logging tests
date() { echo "2026-02-13 21:05:00"; }
export -f date

# Setup directories
mkdir -p "$GINGER_ROOT/config"
mkdir -p "$GINGER_ROOT/logs"
mkdir -p "$GINGER_ROOT/sources"

# Source library - it will source real env.sh
source ./lfs/lib/common.sh

# FORCE MOCKS AFTER SOURCING
export GINGER_ROOT="/tmp/ginger_test"
export LFS="/tmp/ginger_lfs"
export GINGER_STATE_DIR="$GINGER_ROOT/.build_state"
export STATUS_DIR="$LFS/var/lib/ginger"

mkdir -p "$GINGER_ROOT" "$LFS" "$GINGER_STATE_DIR" "$STATUS_DIR"

# Test Logging
echo "Testing log function..."
# We expect the output to contain the timestamp and message. 
# We'll skip strict escape code matching which can be flaky across environments.
LOG_OUT=$(log "INFO" "Test Message")
echo "Log output (escaped): $(echo "$LOG_OUT" | cat -v)"

if [[ "$LOG_OUT" == *"[2026-02-13 21:05:00] [INFO] Test Message"* ]]; then
    echo "✅ log INFO passed (text content matched)"
else
    echo "❌ log INFO failed"
    echo "Got: $LOG_OUT"
    exit 1
fi

# Test Marker Creation
echo "Testing mark_built/check_built..."
TEST_PKG="test-pkg-99"

if check_built "$TEST_PKG"; then
    echo "❌ check_built should have failed before marking"
    exit 1
fi

mark_built "$TEST_PKG"

if check_built "$TEST_PKG"; then
    echo "✅ mark_built/check_built passed"
else
    echo "❌ check_built failed after marking"
    exit 1
fi

# Cleanup
rm -rf "$GINGER_ROOT" "$LFS"
echo "All bash library tests passed! 🎉"
