`ifndef AXI4_ENV_SVH
`define AXI4_ENV_SVH

//==========================================================================
// AXI4 Verification Environment
//==========================================================================
class axi4_env extends uvm_env;

    `uvm_component_utils(axi4_env)

    axi4_master_agent  master_agent;
    axi4_slave_agent   slave_agent;
    axi4_monitor       monitor;
    axi4_scoreboard    scoreboard;
    axi4_coverage      wr_coverage;
    axi4_coverage      rd_coverage;
    axi4_config        cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(axi4_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "Config not found")

        // Propagate config to children
        uvm_config_db#(axi4_config)::set(this, "*", "cfg", cfg);

        // Create agents
        master_agent = axi4_master_agent::type_id::create("master_agent", this);
        slave_agent  = axi4_slave_agent::type_id::create("slave_agent", this);
        monitor      = axi4_monitor::type_id::create("monitor", this);

        // Create scoreboard and coverage
        if (cfg.enable_scoreboard)
            scoreboard = axi4_scoreboard::type_id::create("scoreboard", this);

        if (cfg.enable_coverage) begin
            wr_coverage = axi4_coverage::type_id::create("wr_coverage", this);
            rd_coverage = axi4_coverage::type_id::create("rd_coverage", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect monitor to scoreboard
        if (cfg.enable_scoreboard) begin
            monitor.write_ap.connect(scoreboard.write_export);
            monitor.read_ap.connect(scoreboard.read_export);
        end

        // Connect monitor to coverage
        if (cfg.enable_coverage) begin
            monitor.write_ap.connect(wr_coverage.analysis_export);
            monitor.read_ap.connect(rd_coverage.analysis_export);
        end
    endfunction

endclass

`endif
