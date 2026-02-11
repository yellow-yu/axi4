//==========================================================================
// AXI4 VIP Package
//==========================================================================
package axi4_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Types and parameters
    `include "axi4_types.svh"

    // Transaction
    `include "axi4_transaction.svh"

    // Configuration
    `include "axi4_config.svh"

    // Master components
    `include "axi4_master_driver.svh"
    `include "axi4_master_sequencer.svh"
    `include "axi4_master_agent.svh"

    // Monitor
    `include "axi4_monitor.svh"

    // Slave components
    `include "axi4_slave_driver.svh"
    `include "axi4_slave_agent.svh"

    // Scoreboard and coverage
    `include "axi4_scoreboard.svh"
    `include "axi4_coverage.svh"

    // Environment
    `include "axi4_env.svh"

    // Sequences
    `include "axi4_sequences.svh"

    // Tests
    `include "axi4_base_test.svh"
    `include "axi4_tests.svh"

endpackage
