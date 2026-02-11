//==========================================================================
// axi4_master_sequencer.sv - AXI4 Master Sequencer
//==========================================================================

class axi4_master_sequencer extends uvm_sequencer #(axi4_transaction);

  `uvm_component_utils(axi4_master_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
