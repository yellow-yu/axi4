//==========================================================================
// axi4_types.svh - AXI4 VIP Type Definitions
//==========================================================================
`ifndef AXI4_TYPES_SVH
`define AXI4_TYPES_SVH

// Transaction type
typedef enum bit {
  AXI4_WRITE = 0,
  AXI4_READ  = 1
} axi4_txn_type_e;

// Burst type
typedef enum bit [1:0] {
  AXI4_FIXED = 2'b00,
  AXI4_INCR  = 2'b01,
  AXI4_WRAP  = 2'b10
} axi4_burst_type_e;

// Response type
typedef enum bit [1:0] {
  AXI4_OKAY   = 2'b00,
  AXI4_EXOKAY = 2'b01,
  AXI4_SLVERR = 2'b10,
  AXI4_DECERR = 2'b11
} axi4_resp_type_e;

// Lock type
typedef enum bit {
  AXI4_NORMAL    = 1'b0,
  AXI4_EXCLUSIVE = 1'b1
} axi4_lock_type_e;

`endif
