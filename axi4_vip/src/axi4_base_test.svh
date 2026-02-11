`ifndef AXI4_BASE_TEST_SVH
`define AXI4_BASE_TEST_SVH

//==========================================================================
// AXI4 Base Test
//==========================================================================
class axi4_base_test extends uvm_test;

    `uvm_component_utils(axi4_base_test)

    axi4_env    env;
    axi4_config cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create and configure
        cfg = axi4_config::type_id::create("cfg");

        // Get virtual interface
        if (!uvm_config_db#(virtual axi4_interface)::get(this, "", "vif", cfg.vif))
            `uvm_fatal("NOVIF", "Virtual interface not found in config_db")

        // Set config for all children
        uvm_config_db#(axi4_config)::set(this, "*", "cfg", cfg);

        // Create environment
        env = axi4_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        run_test_sequence(phase);
        // Allow time for final transactions to complete
        #1000;
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

`endif
