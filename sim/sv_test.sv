`timescale 1ns/1ps

interface simple_if(input logic clk);
  logic [7:0] data;
  logic valid;
  logic ready;
endinterface

module sv_test;
  logic clk = 0;
  always #5 clk = ~clk;
  
  simple_if sif(.clk(clk));
  
  initial begin
    sif.valid = 0;
    sif.data = 0;
    sif.ready = 1;
    #20;
    sif.valid = 1;
    sif.data = 8'hAB;
    #10;
    @(posedge clk);
    if (sif.data == 8'hAB) $display("PASS: Interface test");
    else $display("FAIL: Interface test");
    $finish;
  end
endmodule
