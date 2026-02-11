#==========================================================================
# Makefile - AXI4 VIP Simulation (QuestaSim)
#==========================================================================

# Directories
VIP_DIR   = ../uvm_vip
TEST_DIR  = ../tests
TB_DIR    = ../tb
IF_DIR    = ../..

# QuestaSim commands
VLIB  = vlib
VLOG  = vlog
VSIM  = vsim

# Compile options
VLOG_OPTS = -sv +acc -timescale 1ns/1ps \
            +incdir+$(VIP_DIR) \
            +incdir+$(TEST_DIR) \
            +define+AXI4_DATA_WIDTH=32 \
            +define+AXI4_ADDR_WIDTH=32 \
            +define+AXI4_ID_WIDTH=4 \
            +define+AXI4_USER_WIDTH=1

# Simulation options  
VSIM_OPTS = -c -voptargs="+acc" -sv_seed random

# Source files
SRC_FILES = $(IF_DIR)/axi4_interface.sv \
            $(VIP_DIR)/axi4_pkg.sv \
            $(TEST_DIR)/axi4_test_pkg.sv \
            $(TB_DIR)/tb_top.sv

# All test names
TESTS = axi4_single_rw_test \
        axi4_incr_burst_test \
        axi4_wrap_burst_test \
        axi4_fixed_burst_test \
        axi4_narrow_transfer_test \
        axi4_unaligned_test \
        axi4_strobe_test \
        axi4_exclusive_test \
        axi4_back2back_test \
        axi4_qos_region_test \
        axi4_outstanding_test \
        axi4_long_burst_test \
        axi4_cache_prot_test \
        axi4_random_stress_test \
        axi4_all_features_test

# Default target
all: compile run_all

# Create work library
lib:
	$(VLIB) work

# Compile
compile: lib
	$(VLOG) $(VLOG_OPTS) $(SRC_FILES)

# Run a single test
run_%: compile
	@mkdir -p logs
	$(VSIM) $(VSIM_OPTS) tb_top +UVM_TESTNAME=$* \
		-do "run -all; quit -f" \
		-l logs/$*.log

# Run all tests
run_all: compile
	@mkdir -p logs results
	@echo "Running all AXI4 VIP tests..."
	@pass=0; fail=0; \
	for test in $(TESTS); do \
		echo "Running $$test..."; \
		$(VSIM) $(VSIM_OPTS) tb_top +UVM_TESTNAME=$$test \
			-do "run -all; quit -f" \
			-l logs/$$test.log 2>&1; \
		if grep -q "TEST PASSED" logs/$$test.log; then \
			echo "  $$test: PASSED"; \
			pass=$$((pass+1)); \
		else \
			echo "  $$test: FAILED"; \
			fail=$$((fail+1)); \
		fi; \
	done; \
	echo ""; \
	echo "========================================"; \
	echo "  Total: $$((pass+fail))  Passed: $$pass  Failed: $$fail"; \
	echo "========================================"; \
	echo "$$pass/$$((pass+fail)) tests passed" > results/summary.txt

# Clean
clean:
	rm -rf work logs results *.vcd *.wlf transcript

.PHONY: all lib compile run_all clean
