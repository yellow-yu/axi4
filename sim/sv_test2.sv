`timescale 1ns/1ps

interface axi_if #(parameter int DW = 32)(input logic clk, input logic rstn);
  logic [DW-1:0] data;
  logic valid, ready;
  
  modport master(output data, valid, input ready, clk, rstn);
  modport slave(input data, valid, output ready, clk, rstn);
endinterface

module sv_test2;
  logic clk = 0;
  logic rstn = 0;
  always #5 clk = ~clk;
  
  axi_if #(.DW(64)) aif(.clk(clk), .rstn(rstn));
  
  // Test associative arrays
  bit [7:0] mem [bit[31:0]];
  
  // Test dynamic arrays
  bit [31:0] dyn_arr[];
  
  // Test enums
  typedef enum bit [1:0] {FIXED=0, INCR=1, WRAP=2} burst_t;
  
  task automatic do_write(input bit [31:0] addr, input bit [63:0] wdata);
    @(posedge clk);
    aif.data  <= wdata;
    aif.valid <= 1;
    @(posedge clk);
    while (!aif.ready) @(posedge clk);
    aif.valid <= 0;
    // store byte by byte
    for (int i = 0; i < 8; i++) begin
      mem[addr + i] = wdata[i*8 +: 8];
    end
  endtask
  
  task automatic do_read(input bit [31:0] addr, output bit [63:0] rdata);
    rdata = 0;
    for (int i = 0; i < 8; i++) begin
      if (mem.exists(addr + i))
        rdata[i*8 +: 8] = mem[addr + i];
    end
  endtask
  
  initial begin
    burst_t bt;
    bit [63:0] rd;
    
    rstn = 0;
    #50;
    rstn = 1;
    aif.ready = 1;
    
    // Test write
    do_write(32'h100, 64'hDEADBEEF_CAFEBABE);
    
    // Test read
    do_read(32'h100, rd);
    if (rd == 64'hDEADBEEF_CAFEBABE) $display("PASS: Memory read/write");
    else $display("FAIL: Memory read/write got 0x%h", rd);
    
    // Test enum
    bt = WRAP;
    if (bt == 2'b10) $display("PASS: Enum");
    else $display("FAIL: Enum");
    
    // Test dynamic array
    dyn_arr = new[4];
    dyn_arr[0] = 32'hAAAA;
    dyn_arr[3] = 32'hBBBB;
    if (dyn_arr[0] == 32'hAAAA && dyn_arr[3] == 32'hBBBB && dyn_arr.size() == 4)
      $display("PASS: Dynamic array");
    else
      $display("FAIL: Dynamic array");
    
    $display("All basic SV tests completed");
    $finish;
  end
endmodule
