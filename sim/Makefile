#==========================================================================
# Makefile - AXI4 VIP Simulation with QuestaSim
#==========================================================================

# QuestaSim commands
VLIB  = vlib
VMAP  = vmap
VLOG  = vlog
VSIM  = vsim

# Directories
WORK_DIR = work
LOG_DIR  = logs

# Source file list
FILELIST = filelist.f

# Compile flags
VLOG_FLAGS = -sv \
             +incdir+../vip \
             +incdir+../test \
             -suppress 2577 \
             -suppress 2583 \
             -suppress 13314

# Simulation flags
VSIM_FLAGS = -c \
             -suppress 3829 \
             -voptargs="+acc" \
             +UVM_VERBOSITY=UVM_MEDIUM \
             -do "run -all; quit -f"

# All test names
TESTS = axi4_single_rw_test \
        axi4_incr_burst_test \
        axi4_wrap_burst_test \
        axi4_fixed_burst_test \
        axi4_narrow_transfer_test \
        axi4_unaligned_test \
        axi4_outstanding_test \
        axi4_byte_strobe_test \
        axi4_max_burst_test \
        axi4_exclusive_test \
        axi4_random_test \
        axi4_back2back_test

#----------------------------------------------------------------------
# Default target
#----------------------------------------------------------------------
.PHONY: all
all: compile run_all

#----------------------------------------------------------------------
# Create work library
#----------------------------------------------------------------------
.PHONY: lib
lib:
	@echo "=== Creating work library ==="
	$(VLIB) $(WORK_DIR)

#----------------------------------------------------------------------
# Compile
#----------------------------------------------------------------------
.PHONY: compile
compile: lib
	@echo "=== Compiling AXI4 VIP ==="
	@mkdir -p $(LOG_DIR)
	$(VLOG) $(VLOG_FLAGS) -work $(WORK_DIR) -f $(FILELIST) \
		-l $(LOG_DIR)/compile.log

#----------------------------------------------------------------------
# Run a single test
# Usage: make run TEST=axi4_single_rw_test
#----------------------------------------------------------------------
.PHONY: run
run:
	@echo "=== Running test: $(TEST) ==="
	$(VSIM) $(VSIM_FLAGS) -work $(WORK_DIR) \
		+UVM_TESTNAME=$(TEST) \
		-l $(LOG_DIR)/$(TEST).log \
		axi4_tb_top

#----------------------------------------------------------------------
# Run all tests
#----------------------------------------------------------------------
.PHONY: run_all
run_all: $(addprefix run_,$(TESTS))
	@echo ""
	@echo "=============================================="
	@echo "  All tests completed! Checking results..."
	@echo "=============================================="
	@$(MAKE) --no-print-directory check_results

run_%: 
	@echo "=== Running test: $* ==="
	@$(VSIM) $(VSIM_FLAGS) -work $(WORK_DIR) \
		+UVM_TESTNAME=$* \
		-l $(LOG_DIR)/$*.log \
		axi4_tb_top || true

#----------------------------------------------------------------------
# Check test results
#----------------------------------------------------------------------
.PHONY: check_results
check_results:
	@echo ""
	@echo "=============================================="
	@echo "          TEST RESULTS SUMMARY"
	@echo "=============================================="
	@pass=0; fail=0; \
	for test in $(TESTS); do \
		if [ -f $(LOG_DIR)/$$test.log ]; then \
			if grep -q "TEST PASSED" $(LOG_DIR)/$$test.log; then \
				echo "  PASS: $$test"; \
				pass=$$((pass + 1)); \
			else \
				echo "  FAIL: $$test"; \
				fail=$$((fail + 1)); \
			fi; \
		else \
			echo "  MISS: $$test (no log file)"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo "=============================================="; \
	echo "  Total: $$((pass + fail))  Pass: $$pass  Fail: $$fail"; \
	echo "=============================================="; \
	if [ $$fail -ne 0 ]; then exit 1; fi

#----------------------------------------------------------------------
# Run with waveform dump
#----------------------------------------------------------------------
.PHONY: run_gui
run_gui:
	$(VSIM) -work $(WORK_DIR) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-voptargs="+acc" \
		axi4_tb_top

#----------------------------------------------------------------------
# Clean
#----------------------------------------------------------------------
.PHONY: clean
clean:
	rm -rf $(WORK_DIR) $(LOG_DIR) transcript vsim.wlf *.vcd modelsim.ini
