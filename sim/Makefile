#==========================================================================
# AXI4 VIP Simulation Makefile (QuestaSim)
#==========================================================================

# Tool settings
VLOG   = vlog
VSIM   = vsim
VLIB   = vlib
VMAP   = vmap

# Directories
VIP_DIR  = ../vip
TEST_DIR = ../tests
TB_DIR   = ../tb
WORK_DIR = work

# Compile flags
VLOG_FLAGS = -sv +incdir+$(VIP_DIR) +incdir+$(TEST_DIR) -L questa_uvm_1_2

# Simulation flags
VSIM_FLAGS = -c -L questa_uvm_1_2 -voptargs="+acc" -do "run -all; quit -f"

# Source files
SRCS = ../axi4_interface.sv \
       $(VIP_DIR)/axi4_vip_pkg.sv \
       $(TEST_DIR)/axi4_test_pkg.sv \
       $(TB_DIR)/axi4_tb_top.sv

# Test names
TESTS = axi4_single_wr_rd_test \
        axi4_incr_burst_test \
        axi4_fixed_burst_test \
        axi4_wrap_burst_test \
        axi4_narrow_transfer_test \
        axi4_unaligned_test \
        axi4_byte_strobe_test \
        axi4_multi_id_test \
        axi4_exclusive_test \
        axi4_back2back_test \
        axi4_random_stress_test \
        axi4_all_features_test

#==========================================================================
# Targets
#==========================================================================

.PHONY: all lib compile run_all clean help

all: lib compile run_all

help:
	@echo "========================================="
	@echo " AXI4 VIP Simulation Targets"
	@echo "========================================="
	@echo "  make all       - Compile and run all tests"
	@echo "  make lib       - Create work library"
	@echo "  make compile   - Compile all sources"
	@echo "  make run_all   - Run all test cases"
	@echo "  make run TEST=<testname> - Run specific test"
	@echo "  make clean     - Clean build artifacts"
	@echo ""
	@echo " Available tests:"
	@for t in $(TESTS); do echo "   $$t"; done

lib:
	@echo "=== Creating work library ==="
	$(VLIB) $(WORK_DIR)

compile: lib
	@echo "=== Compiling sources ==="
	$(VLOG) $(VLOG_FLAGS) $(SRCS)

# Run a specific test
run:
ifndef TEST
	@echo "ERROR: specify TEST=<testname>"; exit 1
endif
	@echo "=== Running test: $(TEST) ==="
	@mkdir -p logs
	$(VSIM) $(VSIM_FLAGS) work.axi4_tb_top +UVM_TESTNAME=$(TEST) \
		-l logs/$(TEST).log +UVM_VERBOSITY=UVM_MEDIUM
	@echo "=== Test $(TEST) complete. Log: logs/$(TEST).log ==="

# Run all tests
run_all: compile
	@echo "=== Running all tests ==="
	@mkdir -p logs
	@pass=0; fail=0; total=0; \
	for test in $(TESTS); do \
		total=$$((total + 1)); \
		echo "--- Running: $$test ---"; \
		$(VSIM) $(VSIM_FLAGS) work.axi4_tb_top +UVM_TESTNAME=$$test \
			-l logs/$$test.log +UVM_VERBOSITY=UVM_MEDIUM 2>&1; \
		if grep -q "TEST PASSED" logs/$$test.log; then \
			echo "  RESULT: PASSED"; \
			pass=$$((pass + 1)); \
		else \
			echo "  RESULT: FAILED"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo "========================================="; \
	echo " SUMMARY: $$pass/$$total PASSED, $$fail FAILED"; \
	echo "========================================="

clean:
	rm -rf $(WORK_DIR) logs transcript vsim.wlf modelsim.ini *.vcd
