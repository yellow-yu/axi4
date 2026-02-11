//==========================================================================
// axi4_slave_agent.sv - AXI4 Slave Agent
//==========================================================================

class axi4_slave_agent extends uvm_agent;

  axi4_slave_driver   driver;
  axi4_slave_monitor  monitor;

  `uvm_component_utils(axi4_slave_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = axi4_slave_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      driver = axi4_slave_driver::type_id::create("driver", this);
    end
  endfunction

endclass
