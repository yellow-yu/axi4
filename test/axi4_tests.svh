//==========================================================================
// axi4_tests.svh - All AXI4 Test Classes
//==========================================================================

`ifndef AXI4_TESTS_SVH
`define AXI4_TESTS_SVH

//==========================================================================
// Test 1: Single Write-Read Test
//==========================================================================
class axi4_single_rw_test extends axi4_base_test;
    `uvm_component_utils(axi4_single_rw_test)

    function new(string name = "axi4_single_rw_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_single_rw_seq seq = axi4_single_rw_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 2: INCR Burst Test
//==========================================================================
class axi4_incr_burst_test extends axi4_base_test;
    `uvm_component_utils(axi4_incr_burst_test)

    function new(string name = "axi4_incr_burst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_incr_burst_seq seq = axi4_incr_burst_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 3: WRAP Burst Test
//==========================================================================
class axi4_wrap_burst_test extends axi4_base_test;
    `uvm_component_utils(axi4_wrap_burst_test)

    function new(string name = "axi4_wrap_burst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_wrap_burst_seq seq = axi4_wrap_burst_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 4: FIXED Burst Test
//==========================================================================
class axi4_fixed_burst_test extends axi4_base_test;
    `uvm_component_utils(axi4_fixed_burst_test)

    function new(string name = "axi4_fixed_burst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_fixed_burst_seq seq = axi4_fixed_burst_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 5: Narrow Transfer Test
//==========================================================================
class axi4_narrow_transfer_test extends axi4_base_test;
    `uvm_component_utils(axi4_narrow_transfer_test)

    function new(string name = "axi4_narrow_transfer_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_narrow_seq seq = axi4_narrow_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 6: Unaligned Transfer Test
//==========================================================================
class axi4_unaligned_test extends axi4_base_test;
    `uvm_component_utils(axi4_unaligned_test)

    function new(string name = "axi4_unaligned_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_unaligned_seq seq = axi4_unaligned_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 7: Outstanding Transactions Test
//==========================================================================
class axi4_outstanding_test extends axi4_base_test;
    `uvm_component_utils(axi4_outstanding_test)

    function new(string name = "axi4_outstanding_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_outstanding_seq seq = axi4_outstanding_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 8: Byte Strobe Test
//==========================================================================
class axi4_byte_strobe_test extends axi4_base_test;
    `uvm_component_utils(axi4_byte_strobe_test)

    function new(string name = "axi4_byte_strobe_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_byte_strobe_seq seq = axi4_byte_strobe_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 9: Max Burst Length Test (256 beats)
//==========================================================================
class axi4_max_burst_test extends axi4_base_test;
    `uvm_component_utils(axi4_max_burst_test)

    function new(string name = "axi4_max_burst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_max_burst_seq seq = axi4_max_burst_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 10: Exclusive Access Test
//==========================================================================
class axi4_exclusive_test extends axi4_base_test;
    `uvm_component_utils(axi4_exclusive_test)

    function new(string name = "axi4_exclusive_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_exclusive_seq seq = axi4_exclusive_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 11: Random Test
//==========================================================================
class axi4_random_test extends axi4_base_test;
    `uvm_component_utils(axi4_random_test)

    function new(string name = "axi4_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_random_seq seq = axi4_random_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// Test 12: Back-to-Back Test
//==========================================================================
class axi4_back2back_test extends axi4_base_test;
    `uvm_component_utils(axi4_back2back_test)

    function new(string name = "axi4_back2back_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_test_sequence(uvm_phase phase);
        axi4_back2back_seq seq = axi4_back2back_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

`endif
