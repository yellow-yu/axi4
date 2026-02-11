//==========================================================================
// axi4_test_pkg.sv - AXI4 Test Package
//==========================================================================

`include "axi4_defines.svh"

package axi4_test_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import axi4_pkg::*;

  `include "axi4_base_test.sv"
  `include "axi4_test_lib.sv"

endpackage
