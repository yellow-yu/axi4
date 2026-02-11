#!/bin/bash
#==========================================================================
# run_all.sh - Run all AXI4 VIP test cases
#==========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test list
TESTS=(
    "axi4_single_rw_test"
    "axi4_incr_burst_test"
    "axi4_wrap_burst_test"
    "axi4_fixed_burst_test"
    "axi4_narrow_transfer_test"
    "axi4_unaligned_test"
    "axi4_outstanding_test"
    "axi4_byte_strobe_test"
    "axi4_max_burst_test"
    "axi4_exclusive_test"
    "axi4_random_test"
    "axi4_back2back_test"
)

LOG_DIR="logs"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL=${#TESTS[@]}

echo "=============================================="
echo "  AXI4 VIP - Running All Test Cases"
echo "=============================================="
echo "  Total tests: $TOTAL"
echo "=============================================="
echo ""

# Step 1: Compile
echo "=== Step 1: Compiling ==="
make clean
make compile
if [ $? -ne 0 ]; then
    echo -e "${RED}Compilation FAILED!${NC}"
    exit 1
fi
echo -e "${GREEN}Compilation PASSED${NC}"
echo ""

# Step 2: Run all tests
echo "=== Step 2: Running tests ==="
FAILED_TESTS=()

for test in "${TESTS[@]}"; do
    echo -n "  Running $test ... "
    
    make run TEST=$test > /dev/null 2>&1 || true
    
    if [ -f "$LOG_DIR/$test.log" ]; then
        if grep -q "TEST PASSED" "$LOG_DIR/$test.log"; then
            echo -e "${GREEN}PASS${NC}"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo -e "${RED}FAIL${NC}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_TESTS+=("$test")
        fi
    else
        echo -e "${YELLOW}NO LOG${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_TESTS+=("$test")
    fi
done

# Step 3: Print summary
echo ""
echo "=============================================="
echo "          TEST RESULTS SUMMARY"
echo "=============================================="
echo "  Total:  $TOTAL"
echo -e "  Pass:   ${GREEN}$PASS_COUNT${NC}"
echo -e "  Fail:   ${RED}$FAIL_COUNT${NC}"
echo "=============================================="

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    for ft in "${FAILED_TESTS[@]}"; do
        echo "  - $ft"
    done
fi

echo ""
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All tests PASSED!${NC}"
    exit 0
else
    echo -e "${RED}Some tests FAILED!${NC}"
    exit 1
fi
