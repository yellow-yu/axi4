`ifndef AXI4_TESTS_SVH
`define AXI4_TESTS_SVH

//==========================================================================
// 1. Single write-read test
//==========================================================================
class axi4_single_write_read_test extends axi4_base_test;
    `uvm_component_utils(axi4_single_write_read_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_single_wr_rd_seq seq;
        seq = axi4_single_wr_rd_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 2. INCR burst test
//==========================================================================
class axi4_incr_burst_test extends axi4_base_test;
    `uvm_component_utils(axi4_incr_burst_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_incr_burst_seq seq;
        seq = axi4_incr_burst_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 3. WRAP burst test
//==========================================================================
class axi4_wrap_burst_test extends axi4_base_test;
    `uvm_component_utils(axi4_wrap_burst_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_wrap_burst_seq seq;
        seq = axi4_wrap_burst_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 4. FIXED burst test
//==========================================================================
class axi4_fixed_burst_test extends axi4_base_test;
    `uvm_component_utils(axi4_fixed_burst_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_fixed_burst_seq seq;
        seq = axi4_fixed_burst_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 5. Narrow transfer test
//==========================================================================
class axi4_narrow_transfer_test extends axi4_base_test;
    `uvm_component_utils(axi4_narrow_transfer_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_narrow_transfer_seq seq;
        seq = axi4_narrow_transfer_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 6. Unaligned transfer test
//==========================================================================
class axi4_unaligned_test extends axi4_base_test;
    `uvm_component_utils(axi4_unaligned_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_unaligned_seq seq;
        seq = axi4_unaligned_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 7. Byte strobe test
//==========================================================================
class axi4_byte_strobe_test extends axi4_base_test;
    `uvm_component_utils(axi4_byte_strobe_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_byte_strobe_seq seq;
        seq = axi4_byte_strobe_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 8. Outstanding transactions test
//==========================================================================
class axi4_outstanding_test extends axi4_base_test;
    `uvm_component_utils(axi4_outstanding_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_outstanding_seq seq;
        seq = axi4_outstanding_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 9. Back-to-back transactions test
//==========================================================================
class axi4_back2back_test extends axi4_base_test;
    `uvm_component_utils(axi4_back2back_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_back2back_seq seq;
        seq = axi4_back2back_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 10. Maximum burst length test
//==========================================================================
class axi4_max_burst_test extends axi4_base_test;
    `uvm_component_utils(axi4_max_burst_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_max_burst_seq seq;
        seq = axi4_max_burst_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 11. Exclusive access test
//==========================================================================
class axi4_exclusive_test extends axi4_base_test;
    `uvm_component_utils(axi4_exclusive_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_exclusive_seq seq;
        seq = axi4_exclusive_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 12. Mixed read/write test
//==========================================================================
class axi4_mixed_rw_test extends axi4_base_test;
    `uvm_component_utils(axi4_mixed_rw_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_mixed_rw_seq seq;
        seq = axi4_mixed_rw_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

//==========================================================================
// 13. Random stress test
//==========================================================================
class axi4_random_test extends axi4_base_test;
    `uvm_component_utils(axi4_random_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_test_sequence(uvm_phase phase);
        axi4_random_seq seq;
        seq = axi4_random_seq::type_id::create("seq");
        seq.start(env.master_agent.sequencer);
    endtask
endclass

`endif
