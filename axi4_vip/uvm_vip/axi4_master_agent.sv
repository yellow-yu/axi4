//==========================================================================
// axi4_master_agent.sv - AXI4 Master Agent
//==========================================================================

class axi4_master_agent extends uvm_agent;

  axi4_master_driver     driver;
  axi4_master_sequencer  sequencer;
  axi4_master_monitor    monitor;

  `uvm_component_utils(axi4_master_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    monitor = axi4_master_monitor::type_id::create("monitor", this);

    if (get_is_active() == UVM_ACTIVE) begin
      driver    = axi4_master_driver::type_id::create("driver", this);
      sequencer = axi4_master_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass
