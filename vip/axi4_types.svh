//==========================================================================
// axi4_types.svh - AXI4 type definitions
//==========================================================================

`ifndef AXI4_TYPES_SVH
`define AXI4_TYPES_SVH

typedef enum bit {
    AXI4_WRITE = 1'b0,
    AXI4_READ  = 1'b1
} axi4_txn_type_e;

typedef enum bit [1:0] {
    AXI4_FIXED = 2'b00,
    AXI4_INCR  = 2'b01,
    AXI4_WRAP  = 2'b10
} axi4_burst_type_e;

typedef enum bit [1:0] {
    AXI4_OKAY   = 2'b00,
    AXI4_EXOKAY = 2'b01,
    AXI4_SLVERR = 2'b10,
    AXI4_DECERR = 2'b11
} axi4_resp_e;

// VIP Configuration Parameters (used across all components)
parameter AXI4_VIP_ID_W   = 4;
parameter AXI4_VIP_ADDR_W = 32;
parameter AXI4_VIP_DATA_W = 64;
parameter AXI4_VIP_USER_W = 1;
parameter AXI4_VIP_STRB_W = AXI4_VIP_DATA_W / 8;

// Virtual interface typedef
typedef virtual axi4_interface #(
    .ID_WIDTH   (AXI4_VIP_ID_W),
    .ADDR_WIDTH (AXI4_VIP_ADDR_W),
    .DATA_WIDTH (AXI4_VIP_DATA_W),
    .USER_WIDTH (AXI4_VIP_USER_W)
) axi4_vif;

`endif
