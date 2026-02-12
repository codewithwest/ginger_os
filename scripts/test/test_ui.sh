#!/bin/bash
# GingerOS UI Test Suite
# Automated tests for the process-safe terminal UI system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ui.sh"

TEST_LOG="/tmp/ginger_ui_test.log"
export UI_LOG_FILE="$TEST_LOG"

# Colors for test output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# TEST HELPERS
# ============================================================================

test_start() {
    echo -e "${YELLOW}▶ TEST: $1${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    echo -e "${GREEN}  ✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}  ✗ FAIL: $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

cleanup_test() {
    # Kill any running UI monitors
    pkill -f "ui_monitor" 2>/dev/null || true
    rm -f /tmp/ginger_ui_state.* 2>/dev/null || true
    rm -f "$TEST_LOG" 2>/dev/null || true
}

# ============================================================================
# TEST 1: BASIC INITIALIZATION
# ============================================================================

test_basic_init() {
    test_start "Basic UI initialization"
    
    cleanup_test
    
    ui_init "Step 1" "Step 2" "Step 3"
    sleep 0.5
    
    # Check if monitor is running
    if pgrep -f "ui_monitor" > /dev/null; then
        test_pass
    else
        test_fail "UI monitor not running"
    fi
    
    ui_finish
    cleanup_test
}

# ============================================================================
# TEST 2: STATE FILE MANAGEMENT
# ============================================================================

test_state_file() {
    test_start "State file creation and updates"
    
    cleanup_test
    
    ui_init "Test Step"
    sleep 0.3
    
    # Check state file exists
    if [[ -f "$UI_STATE_FILE" ]]; then
        test_pass
    else
        test_fail "State file not created"
    fi
    
    ui_finish
    cleanup_test
}

# ============================================================================
# TEST 3: LOG FILE WRITING
# ============================================================================

test_log_writing() {
    test_start "Log file writing"
    
    cleanup_test
    
    ui_init "Logging Test"
    sleep 0.3
    
    ui_log "Test message 1"
    ui_log "Test message 2"
    sleep 0.2
    
    # Check log file exists and has content
    if [[ -f "$TEST_LOG" ]] && grep -q "Test message 1" "$TEST_LOG"; then
        test_pass
    else
        test_fail "Log file not created or messages not written"
    fi
    
    ui_finish
    cleanup_test
}

# ============================================================================
# TEST 4: STEP PROGRESSION
# ============================================================================

test_step_progression() {
    test_start "Step progression"
    
    cleanup_test
    
    ui_init "Step A" "Step B" "Step C"
    sleep 0.3
    
    ui_step 0 "Working on A"
    sleep 0.2
    ui_step 1 "Working on B"
    sleep 0.2
    ui_step 2 "Working on C"
    sleep 0.2
    
    # Load state and check current step
    ui_load_state
    if [[ $UI_CURRENT_STEP -eq 2 ]]; then
        test_pass
    else
        test_fail "Step progression failed (expected 2, got $UI_CURRENT_STEP)"
    fi
    
    ui_finish
    cleanup_test
}

# ============================================================================
# TEST 5: CLEANUP ON EXIT
# ============================================================================

test_cleanup() {
    test_start "Cleanup on exit"
    
    cleanup_test
    
    ui_init "Cleanup Test"
    sleep 0.3
    
    local state_file="$UI_STATE_FILE"
    ui_finish
    sleep 0.5
    
    # Check if monitor stopped
    if ! pgrep -f "ui_monitor" > /dev/null; then
        test_pass
    else
        test_fail "UI monitor still running after finish"
    fi
    
    cleanup_test
}

# ============================================================================
# TEST 6: TERMINAL WIDTH DETECTION
# ============================================================================

test_width_detection() {
    test_start "Terminal width detection"
    
    # Save original terminal size
    original_cols=$(tput cols)
    
    # Test narrow terminal
    if check_width; then
        # Terminal is wide enough
        if [[ "$UI_MODE" == "full" ]]; then
            test_pass
        else
            test_fail "Wide terminal detected as minimal"
        fi
    else
        # Terminal is too narrow
        if [[ "$UI_MODE" == "minimal" ]]; then
            test_pass
        else
            test_fail "Narrow terminal detected as full"
        fi
    fi
}

# ============================================================================
# TEST 7: CONCURRENT OPERATIONS
# ============================================================================

test_concurrent_operations() {
    test_start "Concurrent UI updates and logging"
    
    cleanup_test
    
    ui_init "Concurrent Test"
    sleep 0.3
    
    # Simulate concurrent operations
    for i in {1..10}; do
        ui_log "Concurrent message $i"
    done
    sleep 0.5
    
    # Check all messages were logged
    local count=$(grep -c "Concurrent message" "$TEST_LOG" || echo 0)
    if [[ $count -eq 10 ]]; then
        test_pass
    else
        test_fail "Only $count/10 messages logged"
    fi
    
    ui_finish
    cleanup_test
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           GingerOS UI Test Suite                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo

test_basic_init
test_state_file
test_log_writing
test_step_progression
test_cleanup
test_width_detection
test_concurrent_operations

# ============================================================================
# SUMMARY
# ============================================================================

echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    TEST RESULTS                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
