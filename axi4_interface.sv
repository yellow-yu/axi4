//==========================================================================
// axi4_interface.sv
//==========================================================================
// 参数化的 AXI4 Full 接口定义（符合 AMBA AXI4 协议）
//
// 参数：
//   ID_WIDTH     : ID 信号宽度（典型值 1~16）
//   ADDR_WIDTH   : 地址宽度
//   DATA_WIDTH   : 数据宽度（必须为 8 的倍数，32/64/128/256/512/1024）
//   USER_WIDTH   : AWUSER/ARUSER/WUSER/BUSER/RUSER 宽度（可为 0）
// 
// 包含所有 AXI4 协议支持的信号（包括 AWREGION/ARREGION、AWQOS/ARQOS 等）
//==========================================================================

`timescale 1ns/1ps

interface axi4_interface #(
    parameter integer ID_WIDTH    = 4,
    parameter integer ADDR_WIDTH  = 64,
    parameter integer DATA_WIDTH  = 512,
    parameter integer USER_WIDTH  = 1
) (
    input logic aclk,
    input logic aresetn
);

    localparam integer STRB_WIDTH = DATA_WIDTH / 8;

    //==========================================================================
    // Write Address Channel
    //==========================================================================
    logic [ID_WIDTH-1:0]    awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;     // Burst length (0 = 1 transfer, 255 = 256 transfers)
    logic [2:0]            awsize;    // Bytes per beat (0=1, 1=2, 2=4, ..., 7=128)
    logic [1:0]            awburst;   // 2'b00=FIXED, 2'b01=INCR, 2'b10=WRAP
    logic                  awlock;    // 1'b0=Normal, 1'b1=Exclusive
    logic [3:0]            awcache;
    logic [2:0]            awprot;
    logic [3:0]            awqos;     // Quality of Service
    logic [3:0]            awregion;
    logic [USER_WIDTH-1:0] awuser;
    logic                  awvalid;
    logic                  awready;

    //==========================================================================
    // Write Data Channel (AXI4 已移除 WID)
    //==========================================================================
    logic [DATA_WIDTH-1:0] wdata;
    logic [STRB_WIDTH-1:0] wstrb;
    logic                  wlast;
    logic [USER_WIDTH-1:0] wuser;
    logic                  wvalid;
    logic                  wready;

    //==========================================================================
    // Write Response Channel
    //==========================================================================
    logic [ID_WIDTH-1:0]    bid;
    logic [1:0]            bresp;     // 2'b00=OKAY, 2'b01=EXOKAY, 2'b10=SLVERR, 2'b11=DECERR
    logic [USER_WIDTH-1:0] buser;
    logic                  bvalid;
    logic                  bready;

    //==========================================================================
    // Read Address Channel
    //==========================================================================
    logic [ID_WIDTH-1:0]    arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic                  arlock;
    logic [3:0]            arcache;
    logic [2:0]            arprot;
    logic [3:0]            arqos;
    logic [3:0]            arregion;
    logic [USER_WIDTH-1:0] aruser;
    logic                  arvalid;
    logic                  arready;

    //==========================================================================
    // Read Data Channel
    //==========================================================================
    logic [ID_WIDTH-1:0]    rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rlast;
    logic [USER_WIDTH-1:0] ruser;
    logic                  rvalid;
    logic                  rready;

    //==========================================================================
    // Modports
    //==========================================================================
    modport master (
        input  aclk, aresetn,
        output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awuser, awvalid,
        input  awready,
        output wdata, wstrb, wlast, wuser, wvalid,
        input  wready,
        input  bid, bresp, buser, bvalid,
        output bready,
        output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arregion, aruser, arvalid,
        input  arready,
        input  rid, rdata, rresp, rlast, ruser, rvalid,
        output rready
    );

    modport slave (
        input  aclk, aresetn,
        input  awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awuser, awvalid,
        output awready,
        input  wdata, wstrb, wlast, wuser, wvalid,
        output wready,
        output bid, bresp, buser, bvalid,
        input  bready,
        input  arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arregion, aruser, arvalid,
        output arready,
        output rid, rdata, rresp, rlast, ruser, rvalid,
        input  rready
    );

endinterface
