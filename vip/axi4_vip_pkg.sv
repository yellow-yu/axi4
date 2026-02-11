//==========================================================================
// axi4_vip_pkg.sv - AXI4 VIP Package
//==========================================================================

package axi4_vip_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Type definitions and virtual interface typedef
    `include "axi4_types.svh"

    // VIP Components
    `include "axi4_transaction.svh"
    `include "axi4_master_driver.svh"
    `include "axi4_master_monitor.svh"
    `include "axi4_master_agent.svh"
    `include "axi4_scoreboard.svh"
    `include "axi4_coverage.svh"
    `include "axi4_env.svh"

endpackage
