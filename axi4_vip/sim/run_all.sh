#!/bin/bash
#==========================================================================
# AXI4 VIP - Run All Tests Script
#==========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "AXI4 VIP - Full Regression"
echo "=========================================="
echo ""

# Test list
TESTS=(
    "axi4_single_write_read_test"
    "axi4_incr_burst_test"
    "axi4_wrap_burst_test"
    "axi4_fixed_burst_test"
    "axi4_narrow_transfer_test"
    "axi4_unaligned_test"
    "axi4_byte_strobe_test"
    "axi4_outstanding_test"
    "axi4_back2back_test"
    "axi4_max_burst_test"
    "axi4_exclusive_test"
    "axi4_mixed_rw_test"
    "axi4_random_test"
)

# Clean and compile
echo "Step 1: Cleaning..."
make clean 2>/dev/null || true

echo "Step 2: Compiling..."
make compile
echo ""

# Run tests
PASS=0
FAIL=0
TOTAL=${#TESTS[@]}
FAILED_TESTS=()

for test in "${TESTS[@]}"; do
    echo "------------------------------------------"
    echo "Running: $test"
    echo "------------------------------------------"
    
    mkdir -p results/$test
    
    if make run TEST=$test 2>&1 | tee results/$test/console.log | tail -3; then
        if grep -q "TEST PASSED" results/$test/sim.log 2>/dev/null; then
            echo "[PASS] $test"
            PASS=$((PASS + 1))
        else
            echo "[FAIL] $test"
            FAIL=$((FAIL + 1))
            FAILED_TESTS+=("$test")
        fi
    else
        echo "[FAIL] $test (simulation error)"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$test")
    fi
    echo ""
done

# Summary
echo "=========================================="
echo "REGRESSION SUMMARY"
echo "=========================================="
echo "Total:  $TOTAL"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -gt 0 ]; then
    echo "Failed tests:"
    for ft in "${FAILED_TESTS[@]}"; do
        echo "  - $ft"
    done
    echo ""
    echo "REGRESSION FAILED"
    exit 1
else
    echo "ALL TESTS PASSED!"
    exit 0
fi
