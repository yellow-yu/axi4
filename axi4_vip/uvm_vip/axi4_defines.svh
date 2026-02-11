//==========================================================================
// axi4_defines.svh - AXI4 VIP Parameter Definitions
//==========================================================================
`ifndef AXI4_DEFINES_SVH
`define AXI4_DEFINES_SVH

// Default AXI4 parameters - can be overridden before including
`ifndef AXI4_ID_WIDTH
  `define AXI4_ID_WIDTH    4
`endif

`ifndef AXI4_ADDR_WIDTH
  `define AXI4_ADDR_WIDTH  32
`endif

`ifndef AXI4_DATA_WIDTH
  `define AXI4_DATA_WIDTH  32
`endif

`ifndef AXI4_USER_WIDTH
  `define AXI4_USER_WIDTH  1
`endif

`define AXI4_STRB_WIDTH (`AXI4_DATA_WIDTH / 8)

// Maximum outstanding transactions
`ifndef AXI4_MAX_OUTSTANDING
  `define AXI4_MAX_OUTSTANDING 16
`endif

// Memory size for slave (4MB)
`ifndef AXI4_MEM_SIZE
  `define AXI4_MEM_SIZE 32'h0040_0000
`endif

`endif
