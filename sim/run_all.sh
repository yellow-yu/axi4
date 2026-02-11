#!/bin/bash
#==========================================================================
# AXI4 VIP - Run All Tests Script
#==========================================================================
# Usage:
#   ./run_all.sh                  # Run iverilog testbench
#   ./run_all.sh questasim        # Run QuestaSim UVM tests
#   ./run_all.sh questasim <test> # Run specific QuestaSim test
#==========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#--------------------------------------------------------------------------
# QuestaSim UVM Flow
#--------------------------------------------------------------------------
run_questasim() {
    local test_name="$1"
    
    TESTS=(
        axi4_single_wr_rd_test
        axi4_incr_burst_test
        axi4_fixed_burst_test
        axi4_wrap_burst_test
        axi4_narrow_transfer_test
        axi4_unaligned_test
        axi4_byte_strobe_test
        axi4_multi_id_test
        axi4_exclusive_test
        axi4_back2back_test
        axi4_random_stress_test
        axi4_all_features_test
    )

    cd "$SCRIPT_DIR"

    echo "=== Creating work library ==="
    vlib work 2>/dev/null || true

    echo "=== Compiling sources ==="
    vlog -sv +incdir+../vip +incdir+../tests \
         ../axi4_interface.sv \
         ../vip/axi4_vip_pkg.sv \
         ../tests/axi4_test_pkg.sv \
         ../tb/axi4_tb_top.sv

    if [ -n "$test_name" ]; then
        # Run single test
        echo "=== Running test: $test_name ==="
        vsim -c -voptargs="+acc" work.axi4_tb_top \
             +UVM_TESTNAME=$test_name +UVM_VERBOSITY=UVM_MEDIUM \
             -do "run -all; quit -f" -l "$LOG_DIR/$test_name.log"
    else
        # Run all tests
        local pass=0
        local fail=0
        local total=0

        for test in "${TESTS[@]}"; do
            total=$((total + 1))
            echo -e "\n--- Running: $test ---"
            vsim -c -voptargs="+acc" work.axi4_tb_top \
                 +UVM_TESTNAME=$test +UVM_VERBOSITY=UVM_MEDIUM \
                 -do "run -all; quit -f" -l "$LOG_DIR/$test.log" 2>&1

            if grep -q "TEST PASSED" "$LOG_DIR/$test.log"; then
                echo -e "  ${GREEN}RESULT: PASSED${NC}"
                pass=$((pass + 1))
            else
                echo -e "  ${RED}RESULT: FAILED${NC}"
                fail=$((fail + 1))
            fi
        done

        echo ""
        echo "========================================="
        echo -e " SUMMARY: ${GREEN}$pass${NC}/$total PASSED, ${RED}$fail${NC} FAILED"
        echo "========================================="
    fi
}

#--------------------------------------------------------------------------
# Icarus Verilog Flow (non-UVM self-checking testbench)
#--------------------------------------------------------------------------
run_iverilog() {
    cd "$SCRIPT_DIR"

    echo "========================================="
    echo " AXI4 VIP - Icarus Verilog Simulation"
    echo "========================================="

    echo "=== Compiling ==="
    iverilog -g2012 -o axi4_tb \
             -I../vip \
             ../axi4_interface.sv \
             ../tb/axi4_tb_top_iv.sv \
             2>&1 | tee "$LOG_DIR/compile.log"

    echo "=== Running simulation ==="
    vvp axi4_tb 2>&1 | tee "$LOG_DIR/iverilog_sim.log"

    echo ""
    if grep -q "ALL TESTS PASSED" "$LOG_DIR/iverilog_sim.log"; then
        echo -e "${GREEN}=== ALL TESTS PASSED ===${NC}"
        return 0
    else
        echo -e "${RED}=== SOME TESTS FAILED ===${NC}"
        return 1
    fi
}

#--------------------------------------------------------------------------
# Main
#--------------------------------------------------------------------------
case "${1:-iverilog}" in
    questasim|questa|qs)
        run_questasim "$2"
        ;;
    iverilog|iv|"")
        run_iverilog
        ;;
    *)
        echo "Usage: $0 [iverilog|questasim] [test_name]"
        exit 1
        ;;
esac
