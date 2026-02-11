#!/bin/bash
#==========================================================================
# run_iverilog.sh - Run AXI4 VIP tests with Icarus Verilog
#==========================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd "$SCRIPT_DIR"

echo "========================================"
echo "   AXI4 VIP Test Suite (Icarus Verilog)"
echo "========================================"

# Compile
echo "Compiling..."
iverilog -g2012 -o axi4_sim \
    ../tb/tb_axi4_sv.sv \
    2>&1

if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

echo "Compilation successful."
echo ""

# Run simulation
echo "Running simulation..."
vvp axi4_sim 2>&1 | tee sim_output.log

echo ""
echo "Simulation complete. Check sim_output.log for details."

# Check result
if grep -q "ALL TESTS PASSED" sim_output.log; then
    echo "Result: ALL TESTS PASSED"
    exit 0
else
    echo "Result: SOME TESTS FAILED"
    exit 1
fi
