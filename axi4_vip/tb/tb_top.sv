//==========================================================================
// tb_top.sv - AXI4 VIP Testbench Top
//==========================================================================

`timescale 1ns/1ps

`include "axi4_defines.svh"

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import axi4_pkg::*;
  import axi4_test_pkg::*;

  // ---- Clock and Reset ----
  logic aclk;
  logic aresetn;

  // Clock generation: 100 MHz
  initial begin
    aclk = 0;
    forever #5 aclk = ~aclk;
  end

  // Reset generation
  initial begin
    aresetn = 0;
    #50;
    aresetn = 1;
  end

  // ---- AXI4 Interface Instantiation ----
  axi4_interface #(
    .ID_WIDTH   (`AXI4_ID_WIDTH),
    .ADDR_WIDTH (`AXI4_ADDR_WIDTH),
    .DATA_WIDTH (`AXI4_DATA_WIDTH),
    .USER_WIDTH (`AXI4_USER_WIDTH)
  ) axi4_if (
    .aclk    (aclk),
    .aresetn (aresetn)
  );

  // ---- Pass virtual interface to UVM config DB ----
  initial begin
    uvm_config_db#(virtual axi4_interface)::set(null, "*", "vif", axi4_if);
  end

  // ---- Start UVM test ----
  initial begin
    run_test();
  end

  // ---- Timeout watchdog ----
  initial begin
    #1000000; // 1ms timeout
    `uvm_fatal("TIMEOUT", "Simulation timed out!")
  end

  // ---- Waveform dump ----
  initial begin
    $dumpfile("axi4_vip.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
