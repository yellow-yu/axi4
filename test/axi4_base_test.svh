//==========================================================================
// axi4_base_test.svh - AXI4 Base Test
//==========================================================================

`ifndef AXI4_BASE_TEST_SVH
`define AXI4_BASE_TEST_SVH

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
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        // Wait for reset
        #200ns;

        run_test_sequence(phase);

        // Drain time
        #500ns;
        phase.drop_objection(this);
    endtask

    // Override this in derived tests
    virtual task run_test_sequence(uvm_phase phase);
        `uvm_info("TEST", "Base test - no sequence to run", UVM_LOW)
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server rs = uvm_report_server::get_server();
        int unsigned error_cnt = rs.get_severity_count(UVM_ERROR);
        int unsigned fatal_cnt = rs.get_severity_count(UVM_FATAL);

        if (error_cnt == 0 && fatal_cnt == 0)
            `uvm_info("TEST_RESULT", "\n\n***** TEST PASSED *****\n", UVM_NONE)
        else
            `uvm_info("TEST_RESULT", $sformatf(
                "\n\n***** TEST FAILED ***** (errors=%0d, fatals=%0d)\n",
                error_cnt, fatal_cnt), UVM_NONE)
    endfunction

endclass

`endif
