#!/bin/bash
#==========================================================================
# run_all.sh - Run all AXI4 VIP tests with QuestaSim
#==========================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd "$SCRIPT_DIR"

TESTS=(
    axi4_single_rw_test
    axi4_incr_burst_test
    axi4_wrap_burst_test
    axi4_fixed_burst_test
    axi4_narrow_transfer_test
    axi4_unaligned_test
    axi4_strobe_test
    axi4_exclusive_test
    axi4_back2back_test
    axi4_qos_region_test
    axi4_outstanding_test
    axi4_long_burst_test
    axi4_cache_prot_test
    axi4_random_stress_test
    axi4_all_features_test
)

echo "========================================"
echo "   AXI4 VIP Test Suite (QuestaSim)"
echo "========================================"

# Compile
make compile
if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

mkdir -p logs results

PASS=0
FAIL=0

for test in "${TESTS[@]}"; do
    echo ""
    echo "Running $test..."
    make run_${test} 2>&1 | tail -5
    if grep -q "TEST PASSED" logs/${test}.log 2>/dev/null; then
        echo "  Result: PASSED"
        PASS=$((PASS + 1))
    else
        echo "  Result: FAILED"
        FAIL=$((FAIL + 1))
    fi
done

TOTAL=$((PASS + FAIL))

echo ""
echo "========================================"
echo "          TEST SUMMARY"
echo "========================================"
echo "  Total:  $TOTAL"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "========================================"

if [ $FAIL -eq 0 ]; then
    echo "  *** ALL TESTS PASSED ***"
else
    echo "  *** SOME TESTS FAILED ***"
fi

echo ""
echo "$PASS/$TOTAL tests passed" > results/summary.txt
