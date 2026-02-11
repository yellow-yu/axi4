#==========================================================================
# AXI4 VIP Simulation Makefile for QuestaSim
#==========================================================================

# Source directories
SRC_DIR  = ../src
WORK_DIR = work

# QuestaSim commands
VLIB  = vlib
VLOG  = vlog
VSIM  = vsim
VOPT  = vopt

# UVM home (auto-detect or override)
UVM_HOME ?= $(shell questa_uvm_home 2>/dev/null || echo "")

# Compilation flags
VLOG_FLAGS = -sv \
             +incdir+$(SRC_DIR) \
             -suppress 2286 \
             -suppress 13314 \
             +define+UVM_NO_DEPRECATED

# If UVM_HOME is set, include it
ifneq ($(UVM_HOME),)
  VLOG_FLAGS += +incdir+$(UVM_HOME)/src
  VLOG_UVM    = $(UVM_HOME)/src/uvm_pkg.sv
endif

# Simulation flags
VSIM_FLAGS = -c \
             -suppress 3829 \
             -suppress 8386 \
             +UVM_VERBOSITY=UVM_MEDIUM \
             -do "run -all; quit -f"

# Source files (compilation order matters)
SRC_FILES = $(SRC_DIR)/axi4_if.sv \
            $(SRC_DIR)/axi4_pkg.sv \
            $(SRC_DIR)/tb_top.sv

# All test names
TESTS = axi4_single_write_read_test \
        axi4_incr_burst_test \
        axi4_wrap_burst_test \
        axi4_fixed_burst_test \
        axi4_narrow_transfer_test \
        axi4_unaligned_test \
        axi4_byte_strobe_test \
        axi4_outstanding_test \
        axi4_back2back_test \
        axi4_max_burst_test \
        axi4_exclusive_test \
        axi4_mixed_rw_test \
        axi4_random_test

#----------------------------------------------------------------------
# Targets
#----------------------------------------------------------------------

.PHONY: all lib compile run_all clean help $(TESTS)

all: compile run_all

help:
	@echo "Usage:"
	@echo "  make compile              - Compile all sources"
	@echo "  make run TEST=<testname>  - Run a specific test"
	@echo "  make run_all              - Run all tests"
	@echo "  make clean                - Clean work directory"
	@echo ""
	@echo "Available tests:"
	@$(foreach t,$(TESTS),echo "  $(t)";)

lib:
	@if [ ! -d $(WORK_DIR) ]; then $(VLIB) $(WORK_DIR); fi

compile: lib
	@echo "=========================================="
	@echo "Compiling AXI4 VIP..."
	@echo "=========================================="
ifneq ($(UVM_HOME),)
	$(VLOG) $(VLOG_FLAGS) -work $(WORK_DIR) $(VLOG_UVM)
endif
	$(VLOG) $(VLOG_FLAGS) -work $(WORK_DIR) $(SRC_FILES)
	@echo "Compilation successful!"

run:
	@if [ -z "$(TEST)" ]; then echo "ERROR: Specify TEST=<testname>"; exit 1; fi
	@echo "=========================================="
	@echo "Running test: $(TEST)"
	@echo "=========================================="
	@mkdir -p results/$(TEST)
	$(VSIM) $(VSIM_FLAGS) -work $(WORK_DIR) \
		+UVM_TESTNAME=$(TEST) \
		-l results/$(TEST)/sim.log \
		tb_top
	@echo ""
	@if grep -q "TEST PASSED" results/$(TEST)/sim.log; then \
		echo "[PASS] $(TEST)"; \
	else \
		echo "[FAIL] $(TEST)"; \
	fi

run_all:
	@echo "=========================================="
	@echo "Running all AXI4 VIP tests..."
	@echo "=========================================="
	@pass=0; fail=0; total=0; \
	for test in $(TESTS); do \
		total=$$((total + 1)); \
		echo ""; \
		echo "------------------------------------------"; \
		echo "Test $$total: $$test"; \
		echo "------------------------------------------"; \
		mkdir -p results/$$test; \
		$(VSIM) $(VSIM_FLAGS) -work $(WORK_DIR) \
			+UVM_TESTNAME=$$test \
			-l results/$$test/sim.log \
			tb_top 2>&1 | tail -5; \
		if grep -q "TEST PASSED" results/$$test/sim.log; then \
			echo "[PASS] $$test"; \
			pass=$$((pass + 1)); \
		else \
			echo "[FAIL] $$test"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "=========================================="; \
	echo "Results: $$pass passed, $$fail failed out of $$total tests"; \
	echo "=========================================="

# Individual test targets
$(TESTS): compile
	$(MAKE) run TEST=$@

clean:
	rm -rf $(WORK_DIR) results transcript vsim.wlf *.log modelsim.ini
