//==========================================================================
// AXI4 Base Test
//==========================================================================
class axi4_base_test extends uvm_test;

  `uvm_component_utils(axi4_base_test)

  axi4_env env;

  function new(string name = "axi4_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi4_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST", $sformatf("Starting test: %s", get_type_name()), UVM_LOW)

    // Wait for reset
    #200;

    run_test_sequence(phase);

    // Drain time
    #500;
    phase.drop_objection(this);
  endtask

  // Override in derived tests
  virtual task run_test_sequence(uvm_phase phase);
    `uvm_info("TEST", "Base test - no sequence", UVM_LOW)
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    svr = uvm_report_server::get_server();
    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) > 0)
      `uvm_info("TEST", "*** TEST FAILED ***", UVM_NONE)
    else
      `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
  endfunction

endclass
