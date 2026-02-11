//==========================================================================
// axi4_base_test.sv - AXI4 Base Test
//==========================================================================

class axi4_base_test extends uvm_test;

  axi4_env env;

  `uvm_component_utils(axi4_base_test)

  function new(string name = "axi4_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi4_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info(get_type_name(), "Base test run_phase - override in derived tests", UVM_LOW)
    #100ns;
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();
    if (svr.get_severity_count(UVM_ERROR) > 0 || svr.get_severity_count(UVM_FATAL) > 0) begin
      `uvm_info(get_type_name(), "\n========================================", UVM_NONE)
      `uvm_info(get_type_name(), "          *** TEST FAILED ***", UVM_NONE)
      `uvm_info(get_type_name(), "========================================\n", UVM_NONE)
    end else begin
      `uvm_info(get_type_name(), "\n========================================", UVM_NONE)
      `uvm_info(get_type_name(), "          *** TEST PASSED ***", UVM_NONE)
      `uvm_info(get_type_name(), "========================================\n", UVM_NONE)
    end
  endfunction

endclass
