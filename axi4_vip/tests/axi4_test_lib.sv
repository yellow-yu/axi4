//==========================================================================
// axi4_test_lib.sv - AXI4 Test Library
//==========================================================================

// ============================================================
// Test 1: Single Write-Read Test
// ============================================================
class axi4_single_rw_test extends axi4_base_test;

  `uvm_component_utils(axi4_single_rw_test)

  function new(string name = "axi4_single_rw_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_single_write_read_seq seq;
    phase.raise_objection(this);
    seq = axi4_single_write_read_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 2: INCR Burst Test
// ============================================================
class axi4_incr_burst_test extends axi4_base_test;

  `uvm_component_utils(axi4_incr_burst_test)

  function new(string name = "axi4_incr_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_incr_burst_seq seq;
    phase.raise_objection(this);

    // Test with different burst lengths
    for (int len = 1; len <= 8; len++) begin
      seq = axi4_incr_burst_seq::type_id::create($sformatf("seq_len%0d", len));
      seq.burst_len = len;
      seq.start(env.master_agent.sequencer);
    end

    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 3: WRAP Burst Test
// ============================================================
class axi4_wrap_burst_test extends axi4_base_test;

  `uvm_component_utils(axi4_wrap_burst_test)

  function new(string name = "axi4_wrap_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_wrap_burst_seq seq;
    phase.raise_objection(this);
    seq = axi4_wrap_burst_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 4: FIXED Burst Test
// ============================================================
class axi4_fixed_burst_test extends axi4_base_test;

  `uvm_component_utils(axi4_fixed_burst_test)

  function new(string name = "axi4_fixed_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_fixed_burst_seq seq;
    phase.raise_objection(this);
    seq = axi4_fixed_burst_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 5: Narrow Transfer Test
// ============================================================
class axi4_narrow_transfer_test extends axi4_base_test;

  `uvm_component_utils(axi4_narrow_transfer_test)

  function new(string name = "axi4_narrow_transfer_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_narrow_transfer_seq seq;
    phase.raise_objection(this);
    seq = axi4_narrow_transfer_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 6: Unaligned Transfer Test
// ============================================================
class axi4_unaligned_test extends axi4_base_test;

  `uvm_component_utils(axi4_unaligned_test)

  function new(string name = "axi4_unaligned_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_unaligned_seq seq;
    phase.raise_objection(this);
    seq = axi4_unaligned_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 7: Byte Strobe Test
// ============================================================
class axi4_strobe_test extends axi4_base_test;

  `uvm_component_utils(axi4_strobe_test)

  function new(string name = "axi4_strobe_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_strobe_seq seq;
    phase.raise_objection(this);
    seq = axi4_strobe_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 8: Exclusive Access Test
// ============================================================
class axi4_exclusive_test extends axi4_base_test;

  `uvm_component_utils(axi4_exclusive_test)

  function new(string name = "axi4_exclusive_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_exclusive_seq seq;
    phase.raise_objection(this);
    seq = axi4_exclusive_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 9: Back-to-Back Transaction Test
// ============================================================
class axi4_back2back_test extends axi4_base_test;

  `uvm_component_utils(axi4_back2back_test)

  function new(string name = "axi4_back2back_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_back2back_seq seq;
    phase.raise_objection(this);
    seq = axi4_back2back_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 10: QoS and Region Test
// ============================================================
class axi4_qos_region_test extends axi4_base_test;

  `uvm_component_utils(axi4_qos_region_test)

  function new(string name = "axi4_qos_region_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_qos_region_seq seq;
    phase.raise_objection(this);
    seq = axi4_qos_region_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 11: Outstanding Transactions Test
// ============================================================
class axi4_outstanding_test extends axi4_base_test;

  `uvm_component_utils(axi4_outstanding_test)

  function new(string name = "axi4_outstanding_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_outstanding_seq seq;
    phase.raise_objection(this);
    seq = axi4_outstanding_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 12: Long Burst Test
// ============================================================
class axi4_long_burst_test extends axi4_base_test;

  `uvm_component_utils(axi4_long_burst_test)

  function new(string name = "axi4_long_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_long_burst_seq seq;
    phase.raise_objection(this);
    seq = axi4_long_burst_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 13: Cache/Protection Attributes Test
// ============================================================
class axi4_cache_prot_test extends axi4_base_test;

  `uvm_component_utils(axi4_cache_prot_test)

  function new(string name = "axi4_cache_prot_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_cache_prot_seq seq;
    phase.raise_objection(this);
    seq = axi4_cache_prot_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #200ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 14: Random Stress Test
// ============================================================
class axi4_random_stress_test extends axi4_base_test;

  `uvm_component_utils(axi4_random_stress_test)

  function new(string name = "axi4_random_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_random_stress_seq seq;
    phase.raise_objection(this);
    seq = axi4_random_stress_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    #500ns;
    phase.drop_objection(this);
  endtask

endclass

// ============================================================
// Test 15: Comprehensive All-Features Test
// ============================================================
class axi4_all_features_test extends axi4_base_test;

  `uvm_component_utils(axi4_all_features_test)

  function new(string name = "axi4_all_features_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    begin
      axi4_single_write_read_seq seq1;
      seq1 = axi4_single_write_read_seq::type_id::create("seq1");
      seq1.start(env.master_agent.sequencer);
    end

    begin
      axi4_incr_burst_seq seq2;
      seq2 = axi4_incr_burst_seq::type_id::create("seq2");
      seq2.burst_len = 4;
      seq2.start(env.master_agent.sequencer);
    end

    begin
      axi4_wrap_burst_seq seq3;
      seq3 = axi4_wrap_burst_seq::type_id::create("seq3");
      seq3.start(env.master_agent.sequencer);
    end

    begin
      axi4_fixed_burst_seq seq4;
      seq4 = axi4_fixed_burst_seq::type_id::create("seq4");
      seq4.start(env.master_agent.sequencer);
    end

    begin
      axi4_narrow_transfer_seq seq5;
      seq5 = axi4_narrow_transfer_seq::type_id::create("seq5");
      seq5.start(env.master_agent.sequencer);
    end

    begin
      axi4_strobe_seq seq6;
      seq6 = axi4_strobe_seq::type_id::create("seq6");
      seq6.start(env.master_agent.sequencer);
    end

    begin
      axi4_back2back_seq seq7;
      seq7 = axi4_back2back_seq::type_id::create("seq7");
      seq7.start(env.master_agent.sequencer);
    end

    begin
      axi4_exclusive_seq seq8;
      seq8 = axi4_exclusive_seq::type_id::create("seq8");
      seq8.start(env.master_agent.sequencer);
    end

    #500ns;
    phase.drop_objection(this);
  endtask

endclass
