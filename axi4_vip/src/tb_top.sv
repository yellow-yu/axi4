//==========================================================================
// AXI4 VIP Testbench Top
//==========================================================================
`timescale 1ns/1ps

module tb_top;

    import uvm_pkg::*;
    import axi4_pkg::*;
    `include "uvm_macros.svh"

    //----------------------------------------------------------------------
    // Clock and Reset
    //----------------------------------------------------------------------
    logic clk  = 0;
    logic rstn = 0;

    always #5 clk = ~clk;  // 100 MHz clock (10ns period)

    initial begin
        rstn = 0;
        #100;
        rstn = 1;
    end

    //----------------------------------------------------------------------
    // Interface Instantiation
    //----------------------------------------------------------------------
    axi4_interface #(
        .ID_WIDTH   (4),
        .ADDR_WIDTH (64),
        .DATA_WIDTH (512),
        .USER_WIDTH (1)
    ) axi4_if (
        .aclk    (clk),
        .aresetn (rstn)
    );

    //----------------------------------------------------------------------
    // UVM Configuration and Test Start
    //----------------------------------------------------------------------
    initial begin
        uvm_config_db#(virtual axi4_interface)::set(null, "*", "vif", axi4_if);
        run_test();
    end

    //----------------------------------------------------------------------
    // Timeout watchdog
    //----------------------------------------------------------------------
    initial begin
        #50_000_000;  // 50ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

    //----------------------------------------------------------------------
    // Waveform dump (optional)
    //----------------------------------------------------------------------
    initial begin
        if ($test$plusargs("DUMP_WAVES")) begin
            $dumpfile("waves.vcd");
            $dumpvars(0, tb_top);
        end
    end

endmodule
