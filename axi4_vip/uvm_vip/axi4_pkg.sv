//==========================================================================
// axi4_pkg.sv - AXI4 VIP Package
//==========================================================================

`include "axi4_defines.svh"

package axi4_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Analysis port with tag support for scoreboard
  `uvm_analysis_imp_decl(_WRITE)
  `uvm_analysis_imp_decl(_READ)

  // Type definitions
  `include "axi4_types.svh"

  // VIP components
  `include "axi4_transaction.sv"
  `include "axi4_master_sequencer.sv"
  `include "axi4_master_driver.sv"
  `include "axi4_master_monitor.sv"
  `include "axi4_master_agent.sv"
  `include "axi4_slave_driver.sv"
  `include "axi4_slave_monitor.sv"
  `include "axi4_slave_agent.sv"
  `include "axi4_scoreboard.sv"
  `include "axi4_coverage.sv"
  `include "axi4_env.sv"
  `include "axi4_master_seq_lib.sv"

endpackage
