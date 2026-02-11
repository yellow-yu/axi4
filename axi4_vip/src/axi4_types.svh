`ifndef AXI4_TYPES_SVH
`define AXI4_TYPES_SVH

//==========================================================================
// AXI4 VIP Type Definitions
//==========================================================================

// AXI4 default parameters (matching axi4_interface defaults)
parameter int AXI4_ID_WIDTH    = 4;
parameter int AXI4_ADDR_WIDTH  = 64;
parameter int AXI4_DATA_WIDTH  = 512;
parameter int AXI4_STRB_WIDTH  = AXI4_DATA_WIDTH / 8; // 64
parameter int AXI4_USER_WIDTH  = 1;
parameter int AXI4_SIZE_MAX    = $clog2(AXI4_STRB_WIDTH); // 6

// Burst types
typedef enum bit [1:0] {
    AXI4_BURST_FIXED = 2'b00,
    AXI4_BURST_INCR  = 2'b01,
    AXI4_BURST_WRAP  = 2'b10
} axi4_burst_t;

// Response types
typedef enum bit [1:0] {
    AXI4_RESP_OKAY   = 2'b00,
    AXI4_RESP_EXOKAY = 2'b01,
    AXI4_RESP_SLVERR = 2'b10,
    AXI4_RESP_DECERR = 2'b11
} axi4_resp_t;

// Transaction direction
typedef enum bit {
    AXI4_READ  = 1'b0,
    AXI4_WRITE = 1'b1
} axi4_dir_t;

`endif
