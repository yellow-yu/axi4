`timescale 1ns/1ps

interface axi_if #(parameter int DW = 32)(input logic clk, input logic rstn);
  logic [DW-1:0] data;
  logic valid, ready;
  
  modport master(output data, valid, input ready, clk, rstn);
  modport slave(input data, valid, output ready, clk, rstn);
endinterface

module sv_test3;
  logic clk = 0;
  logic rstn = 0;
  always #5 clk = ~clk;
  
  axi_if #(.DW(64)) aif(.clk(clk), .rstn(rstn));
  
  // Use regular array for memory (limited address range)
  reg [7:0] mem [0:65535];
  
  // Test dynamic arrays
  reg [31:0] dyn_arr [];
  
  // Test enums
  typedef enum logic [1:0] {FIXED=0, INCR=1, WRAP=2} burst_t;
  
  task automatic do_write(input [31:0] addr, input [63:0] wdata);
    @(posedge clk);
    aif.data  <= wdata;
    aif.valid <= 1;
    @(posedge clk);
    while (!aif.ready) @(posedge clk);
    aif.valid <= 0;
    begin : wr_block
      integer i;
      for (i = 0; i < 8; i = i + 1) begin
        mem[addr[15:0] + i] = wdata[i*8 +: 8];
      end
    end
  endtask
  
  task automatic do_read(input [31:0] addr, output [63:0] rdata);
    begin : rd_block
      integer i;
      rdata = 0;
      for (i = 0; i < 8; i = i + 1) begin
        rdata[i*8 +: 8] = mem[addr[15:0] + i];
      end
    end
  endtask
  
  initial begin
    burst_t bt;
    reg [63:0] rd;
    
    rstn = 0;
    #50;
    rstn = 1;
    aif.ready = 1;
    
    do_write(32'h100, 64'hDEADBEEF_CAFEBABE);
    do_read(32'h100, rd);
    if (rd == 64'hDEADBEEF_CAFEBABE) $display("PASS: Memory read/write");
    else $display("FAIL: Memory read/write got 0x%h", rd);
    
    bt = WRAP;
    if (bt == 2'b10) $display("PASS: Enum");
    else $display("FAIL: Enum");
    
    dyn_arr = new[4];
    dyn_arr[0] = 32'hAAAA;
    dyn_arr[3] = 32'hBBBB;
    if (dyn_arr[0] == 32'hAAAA && dyn_arr[3] == 32'hBBBB && dyn_arr.size() == 4)
      $display("PASS: Dynamic array");
    else
      $display("FAIL: Dynamic array");
    
    $display("All tests completed");
    $finish;
  end
endmodule
