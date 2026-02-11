//==========================================================================
// axi4_tb_top.sv - AXI4 VIP Testbench Top
//==========================================================================

`timescale 1ns/1ps

module axi4_tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi4_vip_pkg::*;
    import axi4_test_pkg::*;

    //----------------------------------------------------------------------
    // Parameters
    //----------------------------------------------------------------------
    localparam ID_WIDTH   = 4;
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 64;
    localparam USER_WIDTH = 1;

    //----------------------------------------------------------------------
    // Clock and Reset
    //----------------------------------------------------------------------
    logic aclk;
    logic aresetn;

    // Clock generation: 100 MHz (10ns period)
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;
    end

    // Reset generation
    initial begin
        aresetn = 0;
        repeat (20) @(posedge aclk);
        aresetn = 1;
        `uvm_info("TB_TOP", "Reset deasserted", UVM_LOW)
    end

    //----------------------------------------------------------------------
    // AXI4 Interface
    //----------------------------------------------------------------------
    axi4_interface #(
        .ID_WIDTH   (ID_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .USER_WIDTH (USER_WIDTH)
    ) axi4_if (
        .aclk    (aclk),
        .aresetn (aresetn)
    );

    //----------------------------------------------------------------------
    // DUT: Memory Slave
    //----------------------------------------------------------------------
    axi4_mem_slave #(
        .ID_WIDTH   (ID_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .USER_WIDTH (USER_WIDTH)
    ) u_mem_slave (
        .aclk     (aclk),
        .aresetn  (aresetn),
        // Write Address Channel
        .awid     (axi4_if.awid),
        .awaddr   (axi4_if.awaddr),
        .awlen    (axi4_if.awlen),
        .awsize   (axi4_if.awsize),
        .awburst  (axi4_if.awburst),
        .awlock   (axi4_if.awlock),
        .awcache  (axi4_if.awcache),
        .awprot   (axi4_if.awprot),
        .awqos    (axi4_if.awqos),
        .awregion (axi4_if.awregion),
        .awuser   (axi4_if.awuser),
        .awvalid  (axi4_if.awvalid),
        .awready  (axi4_if.awready),
        // Write Data Channel
        .wdata    (axi4_if.wdata),
        .wstrb    (axi4_if.wstrb),
        .wlast    (axi4_if.wlast),
        .wuser    (axi4_if.wuser),
        .wvalid   (axi4_if.wvalid),
        .wready   (axi4_if.wready),
        // Write Response Channel
        .bid      (axi4_if.bid),
        .bresp    (axi4_if.bresp),
        .buser    (axi4_if.buser),
        .bvalid   (axi4_if.bvalid),
        .bready   (axi4_if.bready),
        // Read Address Channel
        .arid     (axi4_if.arid),
        .araddr   (axi4_if.araddr),
        .arlen    (axi4_if.arlen),
        .arsize   (axi4_if.arsize),
        .arburst  (axi4_if.arburst),
        .arlock   (axi4_if.arlock),
        .arcache  (axi4_if.arcache),
        .arprot   (axi4_if.arprot),
        .arqos    (axi4_if.arqos),
        .arregion (axi4_if.arregion),
        .aruser   (axi4_if.aruser),
        .arvalid  (axi4_if.arvalid),
        .arready  (axi4_if.arready),
        // Read Data Channel
        .rid      (axi4_if.rid),
        .rdata    (axi4_if.rdata),
        .rresp    (axi4_if.rresp),
        .rlast    (axi4_if.rlast),
        .ruser    (axi4_if.ruser),
        .rvalid   (axi4_if.rvalid),
        .rready   (axi4_if.rready)
    );

    //----------------------------------------------------------------------
    // UVM Configuration and Test Launch
    //----------------------------------------------------------------------
    initial begin
        uvm_config_db #(axi4_vif)::set(null, "uvm_test_top.env.master_agent.*", "vif", axi4_if);
        run_test();
    end

    //----------------------------------------------------------------------
    // Timeout and Waveform
    //----------------------------------------------------------------------
    initial begin
        #10_000_000; // 10ms timeout
        `uvm_fatal("TIMEOUT", "Simulation timeout!")
    end

    // Optional: VCD dump for debug
    initial begin
        if ($test$plusargs("DUMP_VCD")) begin
            $dumpfile("axi4_tb.vcd");
            $dumpvars(0, axi4_tb_top);
        end
    end

endmodule
