//==========================================================================
// AXI4 Environment - Top-level UVM environment
//==========================================================================
class axi4_env extends uvm_env;

  `uvm_component_utils(axi4_env)

  axi4_master_agent   master_agent;
  axi4_slave_agent    slave_agent;
  axi4_scoreboard     scoreboard;
  axi4_coverage       wr_coverage;
  axi4_coverage       rd_coverage;

  function new(string name = "axi4_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    master_agent = axi4_master_agent::type_id::create("master_agent", this);
    slave_agent  = axi4_slave_agent::type_id::create("slave_agent", this);
    scoreboard   = axi4_scoreboard::type_id::create("scoreboard", this);
    wr_coverage  = axi4_coverage::type_id::create("wr_coverage", this);
    rd_coverage  = axi4_coverage::type_id::create("rd_coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect monitor analysis ports to scoreboard
    master_agent.monitor.write_ap.connect(scoreboard.write_imp);
    master_agent.monitor.read_ap.connect(scoreboard.read_imp);
    // Connect to coverage collectors
    master_agent.monitor.write_ap.connect(wr_coverage.analysis_export);
    master_agent.monitor.read_ap.connect(rd_coverage.analysis_export);
  endfunction

endclass
