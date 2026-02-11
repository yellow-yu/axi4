//==========================================================================
// AXI4 Slave Agent - Contains slave driver (reactive)
//==========================================================================
class axi4_slave_agent extends uvm_agent;

  `uvm_component_utils(axi4_slave_agent)

  axi4_slave_driver slave_drv;

  function new(string name = "axi4_slave_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    slave_drv = axi4_slave_driver::type_id::create("slave_drv", this);
  endfunction

endclass
