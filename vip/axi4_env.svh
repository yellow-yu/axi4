//==========================================================================
// axi4_env.svh - AXI4 Environment
//==========================================================================

`ifndef AXI4_ENV_SVH
`define AXI4_ENV_SVH

class axi4_env extends uvm_env;

    `uvm_component_utils(axi4_env)

    axi4_master_agent  master_agent;
    axi4_scoreboard    scoreboard;
    axi4_coverage      wr_coverage;
    axi4_coverage      rd_coverage;

    function new(string name = "axi4_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        master_agent = axi4_master_agent::type_id::create("master_agent", this);
        scoreboard   = axi4_scoreboard::type_id::create("scoreboard", this);
        wr_coverage  = axi4_coverage::type_id::create("wr_coverage", this);
        rd_coverage  = axi4_coverage::type_id::create("rd_coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Connect monitor to scoreboard
        master_agent.monitor.write_ap.connect(scoreboard.write_export);
        master_agent.monitor.read_ap.connect(scoreboard.read_export);
        // Connect monitor to coverage
        master_agent.monitor.write_ap.connect(wr_coverage.analysis_export);
        master_agent.monitor.read_ap.connect(rd_coverage.analysis_export);
    endfunction

endclass

`endif
