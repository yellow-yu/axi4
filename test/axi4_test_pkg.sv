//==========================================================================
// axi4_test_pkg.sv - AXI4 Test Package
//==========================================================================

package axi4_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import axi4_vip_pkg::*;

    // Sequences
    `include "axi4_base_seq.svh"
    `include "axi4_sequences.svh"

    // Tests
    `include "axi4_base_test.svh"
    `include "axi4_tests.svh"

endpackage
