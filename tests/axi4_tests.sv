//==========================================================================
// AXI4 Test Classes - One per feature
//==========================================================================

//--------------------------------------------------------------------------
// Test 1: Single Write/Read
//--------------------------------------------------------------------------
class axi4_single_wr_rd_test extends axi4_base_test;
  `uvm_component_utils(axi4_single_wr_rd_test)

  function new(string name = "axi4_single_wr_rd_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_test_sequence(uvm_phase phase);
    axi4_single_wr_rd_seq seq = axi4_single_wr_rd_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
  endtask
endclass

//--------------------------------------------------------------------------
// Test 2: INCR Burst
//--------------------------------------------------------------------------
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

//--------------------------------------------------------------------------
// Test 3: FIXED Burst
//--------------------------------------------------------------------------
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

//--------------------------------------------------------------------------
// Test 4: WRAP Burst
//--------------------------------------------------------------------------
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

//--------------------------------------------------------------------------
// Test 5: Narrow Transfer
//--------------------------------------------------------------------------
class axi4_narrow_transfer_test extends axi4_base_test;
  `uvm_component_utils(axi4_narrow_transfer_test)

  function new(string name = "axi4_narrow_transfer_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_test_sequence(uvm_phase phase);
    axi4_narrow_transfer_seq seq = axi4_narrow_transfer_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
  endtask
endclass

//--------------------------------------------------------------------------
// Test 6: Unaligned Transfer
//--------------------------------------------------------------------------
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

//--------------------------------------------------------------------------
// Test 7: Byte Strobe
//--------------------------------------------------------------------------
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

//--------------------------------------------------------------------------
// Test 8: Multiple IDs / Outstanding
//--------------------------------------------------------------------------
class axi4_multi_id_test extends axi4_base_test;
  `uvm_component_utils(axi4_multi_id_test)

  function new(string name = "axi4_multi_id_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_test_sequence(uvm_phase phase);
    axi4_multi_id_seq seq = axi4_multi_id_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
  endtask
endclass

//--------------------------------------------------------------------------
// Test 9: Exclusive Access
//--------------------------------------------------------------------------
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

//--------------------------------------------------------------------------
// Test 10: Back-to-Back
//--------------------------------------------------------------------------
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

//--------------------------------------------------------------------------
// Test 11: Random Stress
//--------------------------------------------------------------------------
class axi4_random_stress_test extends axi4_base_test;
  `uvm_component_utils(axi4_random_stress_test)

  function new(string name = "axi4_random_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_test_sequence(uvm_phase phase);
    axi4_random_stress_seq seq = axi4_random_stress_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
  endtask
endclass

//--------------------------------------------------------------------------
// Test 12: All Features Combined
//--------------------------------------------------------------------------
class axi4_all_features_test extends axi4_base_test;
  `uvm_component_utils(axi4_all_features_test)

  function new(string name = "axi4_all_features_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_test_sequence(uvm_phase phase);
    axi4_all_features_seq seq = axi4_all_features_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
  endtask
endclass
