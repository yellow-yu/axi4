//==========================================================================
// AXI4 Testbench Top (UVM-based, for QuestaSim)
//==========================================================================
`timescale 1ns/1ps

module axi4_tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi4_vip_pkg::*;
  import axi4_test_pkg::*;

  //------------------------------------------------------------------------
  // Clock and Reset
  //------------------------------------------------------------------------
  logic aclk   = 0;
  logic aresetn = 0;

  // 100MHz clock (10ns period)
  always #5 aclk = ~aclk;

  // Reset sequence
  initial begin
    aresetn = 0;
    repeat (20) @(posedge aclk);
    aresetn = 1;
  end

  //------------------------------------------------------------------------
  // AXI4 Interface Instance
  //------------------------------------------------------------------------
  axi4_interface #(
    .ID_WIDTH   (4),
    .ADDR_WIDTH (64),
    .DATA_WIDTH (512),
    .USER_WIDTH (1)
  ) axi4_if (
    .aclk    (aclk),
    .aresetn (aresetn)
  );

  //------------------------------------------------------------------------
  // UVM Configuration and Test Launch
  //------------------------------------------------------------------------
  initial begin
    uvm_config_db#(virtual axi4_interface)::set(null, "*", "vif", axi4_if);
    run_test();
  end

  //------------------------------------------------------------------------
  // Timeout watchdog
  //------------------------------------------------------------------------
  initial begin
    #10_000_000;  // 10ms timeout
    $display("ERROR: Simulation timeout!");
    $finish;
  end

endmodule
