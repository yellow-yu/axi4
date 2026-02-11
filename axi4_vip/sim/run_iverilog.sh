#!/bin/bash
#==========================================================================
# AXI4 VIP - Run Self-Checking Testbench with Icarus Verilog
#==========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "AXI4 VIP - Self-Checking Testbench"
echo "=========================================="
echo ""

# Compile
echo "Compiling with Icarus Verilog..."
iverilog -g2012 -o tb_self_check ../tb/tb_axi4_self_check.sv
echo "Compilation successful!"
echo ""

# Run
echo "Running simulation..."
echo ""
vvp tb_self_check

# Check result
if grep -q "ALL TESTS PASSED" <<< "$(vvp tb_self_check 2>&1)"; then
    echo ""
    echo "REGRESSION PASSED"
    exit 0
else
    echo ""
    echo "REGRESSION FAILED"
    exit 1
fi
