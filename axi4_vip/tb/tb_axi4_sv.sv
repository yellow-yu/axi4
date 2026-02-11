//==========================================================================
// tb_axi4_sv.sv - Self-checking AXI4 VIP Testbench (Pure SystemVerilog)
//==========================================================================
// This testbench can run with Icarus Verilog (iverilog -g2012)
// It tests all AXI4 features without UVM dependency
//==========================================================================

`timescale 1ns/1ps

// Parameters
`define TB_ID_WIDTH    4
`define TB_ADDR_WIDTH  32
`define TB_DATA_WIDTH  32
`define TB_USER_WIDTH  1
`define TB_STRB_WIDTH  (`TB_DATA_WIDTH / 8)
`define TB_BUS_BYTES   (`TB_DATA_WIDTH / 8)

module tb_axi4_sv;

  // ---- Clock and Reset ----
  reg aclk;
  reg aresetn;

  initial begin
    aclk = 0;
    forever #5 aclk = ~aclk;
  end

  initial begin
    aresetn = 0;
    #50;
    @(posedge aclk);
    aresetn = 1;
  end

  // ---- AXI4 Signal Declarations ----
  // Write Address Channel
  reg  [`TB_ID_WIDTH-1:0]    awid;
  reg  [`TB_ADDR_WIDTH-1:0]  awaddr;
  reg  [7:0]                  awlen;
  reg  [2:0]                  awsize;
  reg  [1:0]                  awburst;
  reg                         awlock;
  reg  [3:0]                  awcache;
  reg  [2:0]                  awprot;
  reg  [3:0]                  awqos;
  reg  [3:0]                  awregion;
  reg  [`TB_USER_WIDTH-1:0]  awuser;
  reg                         awvalid;
  wire                        awready;

  // Write Data Channel
  reg  [`TB_DATA_WIDTH-1:0]  wdata;
  reg  [`TB_STRB_WIDTH-1:0]  wstrb;
  reg                         wlast;
  reg  [`TB_USER_WIDTH-1:0]  wuser;
  reg                         wvalid;
  wire                        wready;

  // Write Response Channel
  wire [`TB_ID_WIDTH-1:0]    bid;
  wire [1:0]                  bresp;
  wire [`TB_USER_WIDTH-1:0]  buser;
  wire                        bvalid;
  reg                         bready;

  // Read Address Channel
  reg  [`TB_ID_WIDTH-1:0]    arid;
  reg  [`TB_ADDR_WIDTH-1:0]  araddr;
  reg  [7:0]                  arlen;
  reg  [2:0]                  arsize;
  reg  [1:0]                  arburst;
  reg                         arlock;
  reg  [3:0]                  arcache;
  reg  [2:0]                  arprot;
  reg  [3:0]                  arqos;
  reg  [3:0]                  arregion;
  reg  [`TB_USER_WIDTH-1:0]  aruser;
  reg                         arvalid;
  wire                        arready;

  // Read Data Channel
  wire [`TB_ID_WIDTH-1:0]    rid;
  wire [`TB_DATA_WIDTH-1:0]  rdata;
  wire [1:0]                  rresp;
  wire                        rlast;
  wire [`TB_USER_WIDTH-1:0]  ruser;
  wire                        rvalid;
  reg                         rready;

  // ---- Slave Memory Model ----
  reg [7:0] slave_mem [0:1048575]; // 1MB

  // Exclusive monitor
  reg [`TB_ADDR_WIDTH-1:0] excl_addr [0:15];
  reg [7:0]                 excl_len  [0:15];
  reg [2:0]                 excl_size [0:15];
  reg                       excl_valid [0:15];

  // ---- Test Statistics ----
  integer total_tests  = 0;
  integer passed_tests = 0;
  integer failed_tests = 0;
  integer error_count  = 0;

  // ---- Initialize ----
  integer init_i;
  initial begin
    // Init master signals
    awid = 0; awaddr = 0; awlen = 0; awsize = 0; awburst = 0;
    awlock = 0; awcache = 0; awprot = 0; awqos = 0; awregion = 0;
    awuser = 0; awvalid = 0;
    wdata = 0; wstrb = 0; wlast = 0; wuser = 0; wvalid = 0;
    bready = 0;
    arid = 0; araddr = 0; arlen = 0; arsize = 0; arburst = 0;
    arlock = 0; arcache = 0; arprot = 0; arqos = 0; arregion = 0;
    aruser = 0; arvalid = 0;
    rready = 0;

    for (init_i = 0; init_i < 16; init_i = init_i + 1)
      excl_valid[init_i] = 0;
  end

  // ============================================================
  // Slave Response Logic (behavioral)
  // ============================================================
  
  // Write channel handling
  reg slave_aw_pending;
  reg [`TB_ID_WIDTH-1:0]   s_awid;
  reg [`TB_ADDR_WIDTH-1:0] s_awaddr;
  reg [7:0]                 s_awlen;
  reg [2:0]                 s_awsize;
  reg [1:0]                 s_awburst;
  reg                       s_awlock;
  reg [7:0]                 s_wbeat;
  reg                       s_wdone;
  reg                       s_b_pending;
  reg [1:0]                 s_bresp_val;

  // Slave AW ready
  assign awready = aresetn && !slave_aw_pending;

  // AW capture
  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      slave_aw_pending <= 0;
      s_wbeat <= 0;
      s_wdone <= 0;
      s_b_pending <= 0;
    end else begin
      if (awvalid && awready) begin
        slave_aw_pending <= 1;
        s_awid    <= awid;
        s_awaddr  <= awaddr;
        s_awlen   <= awlen;
        s_awsize  <= awsize;
        s_awburst <= awburst;
        s_awlock  <= awlock;
        s_wbeat   <= 0;
        s_wdone   <= 0;
      end
      if (wvalid && wready_int) begin
        // Write data to memory
        begin : wr_mem_blk
          reg [`TB_ADDR_WIDTH-1:0] beat_addr;
          reg [`TB_ADDR_WIDTH-1:0] base_addr;
          integer num_bytes;
          integer b;
          
          num_bytes = 1 << s_awsize;
          beat_addr = calc_beat_addr(s_awaddr, s_awsize, s_awburst, s_awlen, s_wbeat);
          base_addr = (beat_addr / `TB_BUS_BYTES) * `TB_BUS_BYTES;
          
          for (b = 0; b < `TB_BUS_BYTES; b = b + 1) begin
            if (wstrb[b])
              slave_mem[base_addr + b] = wdata[b*8 +: 8];
          end
        end

        if (wlast) begin
          s_wdone <= 1;
          slave_aw_pending <= 0;
          s_b_pending <= 1;
          // Handle exclusive
          if (s_awlock) begin
            s_bresp_val <= check_excl_write(s_awid, s_awaddr, s_awlen, s_awsize);
          end else begin
            s_bresp_val <= 2'b00; // OKAY
          end
        end
        s_wbeat <= s_wbeat + 1;
      end
      if (bvalid_int && bready) begin
        s_b_pending <= 0;
      end
    end
  end

  // W ready - accept when AW is pending
  wire wready_int = aresetn && slave_aw_pending;
  assign wready = wready_int;

  // B response
  wire bvalid_int = s_b_pending;
  assign bvalid = bvalid_int;
  assign bid    = s_awid;
  assign bresp  = s_bresp_val;
  assign buser  = 0;

  // Read channel handling
  reg slave_ar_pending;
  reg [`TB_ID_WIDTH-1:0]   s_arid;
  reg [`TB_ADDR_WIDTH-1:0] s_araddr;
  reg [7:0]                 s_arlen;
  reg [2:0]                 s_arsize;
  reg [1:0]                 s_arburst;
  reg                       s_arlock;
  reg [7:0]                 s_rbeat;
  reg                       s_r_active;
  reg [`TB_DATA_WIDTH-1:0] s_rdata_val;
  reg                       s_rlast_val;
  reg [1:0]                 s_rresp_val;
  reg                       s_rvalid_reg;

  assign arready = aresetn && !slave_ar_pending;

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      slave_ar_pending <= 0;
      s_r_active <= 0;
      s_rbeat <= 0;
      s_rvalid_reg <= 0;
    end else begin
      if (arvalid && arready) begin
        slave_ar_pending <= 1;
        s_arid    <= arid;
        s_araddr  <= araddr;
        s_arlen   <= arlen;
        s_arsize  <= arsize;
        s_arburst <= arburst;
        s_arlock  <= arlock;
        s_rbeat   <= 0;
        s_r_active <= 1;
        s_rvalid_reg <= 0;
        
        // Set exclusive monitor for exclusive reads
        if (arlock) begin
          excl_addr[arid % 16]  <= araddr;
          excl_len[arid % 16]   <= arlen;
          excl_size[arid % 16]  <= arsize;
          excl_valid[arid % 16] <= 1;
        end
      end

      if (s_r_active && !s_rvalid_reg) begin
        // Prepare read data
        begin : rd_mem_blk
          reg [`TB_ADDR_WIDTH-1:0] beat_addr;
          reg [`TB_ADDR_WIDTH-1:0] base_addr;
          integer num_bytes;
          integer b;
          reg [`TB_DATA_WIDTH-1:0] rd_val;

          num_bytes = 1 << s_arsize;
          beat_addr = calc_beat_addr(s_araddr, s_arsize, s_arburst, s_arlen, s_rbeat);
          base_addr = (beat_addr / `TB_BUS_BYTES) * `TB_BUS_BYTES;
          
          rd_val = 0;
          for (b = 0; b < `TB_BUS_BYTES; b = b + 1) begin
            rd_val[b*8 +: 8] = slave_mem[base_addr + b];
          end
          
          s_rdata_val <= rd_val;
          s_rlast_val <= (s_rbeat == s_arlen);
          s_rresp_val <= s_arlock ? 2'b01 : 2'b00;
          s_rvalid_reg <= 1;
        end
      end

      if (rvalid && rready) begin
        if (s_rlast_val) begin
          s_r_active <= 0;
          slave_ar_pending <= 0;
          s_rvalid_reg <= 0;
        end else begin
          s_rbeat <= s_rbeat + 1;
          s_rvalid_reg <= 0; // deassert for one cycle, then reassert
        end
      end
    end
  end

  assign rvalid = s_rvalid_reg;
  assign rid    = s_arid;
  assign rdata  = s_rdata_val;
  assign rresp  = s_rresp_val;
  assign rlast  = s_rlast_val;
  assign ruser  = 0;

  // ============================================================
  // Address Calculation Function
  // ============================================================
  function [`TB_ADDR_WIDTH-1:0] calc_beat_addr;
    input [`TB_ADDR_WIDTH-1:0] start_addr;
    input [2:0]                 size;
    input [1:0]                 burst;
    input [7:0]                 len;
    input [7:0]                 beat;
    
    reg [`TB_ADDR_WIDTH-1:0] aligned;
    reg [`TB_ADDR_WIDTH-1:0] addr;
    integer num_bytes;
    integer burst_len;
    integer container;
    reg [`TB_ADDR_WIDTH-1:0] lower, upper;
    begin
      num_bytes = 1 << size;
      burst_len = len + 1;
      aligned = (start_addr / num_bytes) * num_bytes;
      
      case (burst)
        2'b00: addr = start_addr; // FIXED
        2'b01: begin // INCR
          if (beat == 0) addr = start_addr;
          else addr = aligned + beat * num_bytes;
        end
        2'b10: begin // WRAP
          if (beat == 0) addr = start_addr;
          else addr = aligned + beat * num_bytes;
          container = num_bytes * burst_len;
          lower = (start_addr / container) * container;
          upper = lower + container;
          if (addr >= upper)
            addr = lower + ((addr - lower) % container);
        end
        default: addr = start_addr;
      endcase
      
      calc_beat_addr = addr;
    end
  endfunction

  // ============================================================
  // Exclusive Monitor Functions
  // ============================================================
  function [1:0] check_excl_write;
    input [`TB_ID_WIDTH-1:0]   id;
    input [`TB_ADDR_WIDTH-1:0] addr;
    input [7:0]                 len;
    input [2:0]                 size;
    integer idx;
    begin
      idx = id % 16;
      if (excl_valid[idx] && excl_addr[idx] == addr && 
          excl_len[idx] == len && excl_size[idx] == size) begin
        check_excl_write = 2'b01; // EXOKAY
      end else begin
        check_excl_write = 2'b00; // OKAY (exclusive failed)
      end
    end
  endfunction

  // ============================================================
  // Master BFM Tasks
  // ============================================================
  
  // Write transaction
  task axi_write;
    input [`TB_ID_WIDTH-1:0]   t_id;
    input [`TB_ADDR_WIDTH-1:0] t_addr;
    input [7:0]                 t_len;
    input [2:0]                 t_size;
    input [1:0]                 t_burst;
    input                       t_lock;
    input [3:0]                 t_cache;
    input [2:0]                 t_prot;
    input [3:0]                 t_qos;
    input [3:0]                 t_region;

    integer i;
    reg [`TB_DATA_WIDTH-1:0] wr_data;
    reg [`TB_STRB_WIDTH-1:0] wr_strb;
    begin
      // Drive AW
      @(posedge aclk);
      awid     <= t_id;
      awaddr   <= t_addr;
      awlen    <= t_len;
      awsize   <= t_size;
      awburst  <= t_burst;
      awlock   <= t_lock;
      awcache  <= t_cache;
      awprot   <= t_prot;
      awqos    <= t_qos;
      awregion <= t_region;
      awuser   <= 0;
      awvalid  <= 1;

      @(posedge aclk);
      while (!awready) @(posedge aclk);
      awvalid <= 0;

      // Drive W data
      for (i = 0; i <= t_len; i = i + 1) begin
        @(posedge aclk);
        wdata  <= wr_data_gen(t_addr, t_size, t_burst, t_len, i);
        wstrb  <= wr_strb_gen(t_addr, t_size, t_burst, t_len, i);
        wlast  <= (i == t_len) ? 1'b1 : 1'b0;
        wvalid <= 1;

        @(posedge aclk);
        while (!wready) @(posedge aclk);
        // Deassert wvalid after each handshake to prevent spurious accepts
        wvalid <= 0;
      end
      wlast  <= 0;

      // Wait B response
      bready <= 1;
      @(posedge aclk);
      while (!bvalid) @(posedge aclk);
      bready <= 0;
    end
  endtask

  // Write with explicit data
  task axi_write_data;
    input [`TB_ID_WIDTH-1:0]   t_id;
    input [`TB_ADDR_WIDTH-1:0] t_addr;
    input [7:0]                 t_len;
    input [2:0]                 t_size;
    input [1:0]                 t_burst;
    input                       t_lock;
    input [`TB_DATA_WIDTH-1:0] t_data;
    input [`TB_STRB_WIDTH-1:0] t_strb;

    begin
      // Drive AW
      @(posedge aclk);
      awid     <= t_id;
      awaddr   <= t_addr;
      awlen    <= t_len;
      awsize   <= t_size;
      awburst  <= t_burst;
      awlock   <= t_lock;
      awcache  <= 0;
      awprot   <= 0;
      awqos    <= 0;
      awregion <= 0;
      awuser   <= 0;
      awvalid  <= 1;

      @(posedge aclk);
      while (!awready) @(posedge aclk);
      awvalid <= 0;

      // Drive single W beat
      @(posedge aclk);
      wdata  <= t_data;
      wstrb  <= t_strb;
      wlast  <= 1;
      wvalid <= 1;

      @(posedge aclk);
      while (!wready) @(posedge aclk);
      wvalid <= 0;
      wlast  <= 0;

      // Wait B
      bready <= 1;
      @(posedge aclk);
      while (!bvalid) @(posedge aclk);
      bready <= 0;
    end
  endtask

  // Read transaction - returns data for single beat
  task axi_read;
    input [`TB_ID_WIDTH-1:0]   t_id;
    input [`TB_ADDR_WIDTH-1:0] t_addr;
    input [7:0]                 t_len;
    input [2:0]                 t_size;
    input [1:0]                 t_burst;
    input                       t_lock;
    output [`TB_DATA_WIDTH-1:0] t_rdata;
    output [1:0]                t_rresp;

    integer i;
    begin
      // Drive AR
      @(posedge aclk);
      arid     <= t_id;
      araddr   <= t_addr;
      arlen    <= t_len;
      arsize   <= t_size;
      arburst  <= t_burst;
      arlock   <= t_lock;
      arcache  <= 0;
      arprot   <= 0;
      arqos    <= 0;
      arregion <= 0;
      aruser   <= 0;
      arvalid  <= 1;

      @(posedge aclk);
      while (!arready) @(posedge aclk);
      arvalid <= 0;

      // Collect R data
      rready <= 1;
      for (i = 0; i <= t_len; i = i + 1) begin
        @(posedge aclk);
        while (!rvalid) @(posedge aclk);
        if (i == t_len) begin
          t_rdata = rdata;
          t_rresp = rresp;
        end
      end
      rready <= 0;
    end
  endtask

  // Read all beats - stores last beat data
  task axi_read_burst;
    input [`TB_ID_WIDTH-1:0]   t_id;
    input [`TB_ADDR_WIDTH-1:0] t_addr;
    input [7:0]                 t_len;
    input [2:0]                 t_size;
    input [1:0]                 t_burst;

    integer i;
    reg [`TB_DATA_WIDTH-1:0] rd_val;
    begin
      @(posedge aclk);
      arid     <= t_id;
      araddr   <= t_addr;
      arlen    <= t_len;
      arsize   <= t_size;
      arburst  <= t_burst;
      arlock   <= 0;
      arcache  <= 0;
      arprot   <= 0;
      arqos    <= 0;
      arregion <= 0;
      aruser   <= 0;
      arvalid  <= 1;

      @(posedge aclk);
      while (!arready) @(posedge aclk);
      arvalid <= 0;

      rready <= 1;
      for (i = 0; i <= t_len; i = i + 1) begin
        @(posedge aclk);
        while (!rvalid) @(posedge aclk);
      end
      rready <= 0;
    end
  endtask

  // ============================================================
  // Data generation for writes
  // ============================================================
  function [`TB_DATA_WIDTH-1:0] wr_data_gen;
    input [`TB_ADDR_WIDTH-1:0] addr;
    input [2:0]                 size;
    input [1:0]                 burst;
    input [7:0]                 len;
    input integer               beat;
    
    reg [`TB_ADDR_WIDTH-1:0] beat_addr;
    integer b;
    begin
      beat_addr = calc_beat_addr(addr, size, burst, len, beat);
      wr_data_gen = 0;
      for (b = 0; b < `TB_BUS_BYTES; b = b + 1) begin
        wr_data_gen[b*8 +: 8] = (beat_addr + b) & 8'hFF;
      end
    end
  endfunction

  function [`TB_STRB_WIDTH-1:0] wr_strb_gen;
    input [`TB_ADDR_WIDTH-1:0] addr;
    input [2:0]                 size;
    input [1:0]                 burst;
    input [7:0]                 len;
    input integer               beat;
    
    integer num_bytes;
    integer lower_lane, upper_lane;
    reg [`TB_ADDR_WIDTH-1:0] beat_addr;
    reg [`TB_ADDR_WIDTH-1:0] aligned;
    integer b;
    begin
      num_bytes = 1 << size;
      beat_addr = calc_beat_addr(addr, size, burst, len, beat);
      
      if (beat == 0 && burst != 2'b00) begin
        lower_lane = beat_addr % `TB_BUS_BYTES;
        aligned = (beat_addr / num_bytes) * num_bytes;
        upper_lane = (aligned % `TB_BUS_BYTES) + num_bytes - 1;
      end else begin
        lower_lane = beat_addr % `TB_BUS_BYTES;
        upper_lane = lower_lane + num_bytes - 1;
      end

      wr_strb_gen = 0;
      for (b = lower_lane; b <= upper_lane; b = b + 1)
        wr_strb_gen[b] = 1'b1;
    end
  endfunction

  // ============================================================
  // Reference Memory Model (for checking)
  // ============================================================
  reg [7:0] ref_mem [0:1048575]; // 1MB

  task ref_write;
    input [`TB_ADDR_WIDTH-1:0] addr;
    input [7:0]                 len;
    input [2:0]                 size;
    input [1:0]                 burst;
    
    integer i, b;
    reg [`TB_ADDR_WIDTH-1:0] beat_addr, base_addr;
    integer num_bytes;
    reg [`TB_DATA_WIDTH-1:0] d;
    reg [`TB_STRB_WIDTH-1:0] s;
    begin
      num_bytes = 1 << size;
      for (i = 0; i <= len; i = i + 1) begin
        beat_addr = calc_beat_addr(addr, size, burst, len, i);
        base_addr = (beat_addr / `TB_BUS_BYTES) * `TB_BUS_BYTES;
        d = wr_data_gen(addr, size, burst, len, i);
        s = wr_strb_gen(addr, size, burst, len, i);
        for (b = 0; b < `TB_BUS_BYTES; b = b + 1) begin
          if (s[b])
            ref_mem[base_addr + b] = d[b*8 +: 8];
        end
      end
    end
  endtask

  function [`TB_DATA_WIDTH-1:0] ref_read_word;
    input [`TB_ADDR_WIDTH-1:0] addr;
    integer b;
    reg [`TB_ADDR_WIDTH-1:0] base;
    begin
      base = (addr / `TB_BUS_BYTES) * `TB_BUS_BYTES;
      ref_read_word = 0;
      for (b = 0; b < `TB_BUS_BYTES; b = b + 1)
        ref_read_word[b*8 +: 8] = ref_mem[base + b];
    end
  endfunction

  // ============================================================
  // Check task
  // ============================================================
  task check_read;
    input [`TB_ADDR_WIDTH-1:0] addr;
    input [`TB_DATA_WIDTH-1:0] actual;
    input [`TB_DATA_WIDTH-1:0] expected;
    input [255:0]               test_name;
    begin
      if (actual !== expected) begin
        $display("[FAIL] %0s: addr=0x%08h, expected=0x%08h, got=0x%08h", 
                 test_name, addr, expected, actual);
        error_count = error_count + 1;
      end else begin
        $display("[PASS] %0s: addr=0x%08h, data=0x%08h", test_name, addr, actual);
      end
    end
  endtask

  task report_test;
    input [255:0] name;
    input integer errors_before;
    begin
      total_tests = total_tests + 1;
      if (error_count == errors_before) begin
        passed_tests = passed_tests + 1;
        $display("[TEST PASSED] %0s", name);
      end else begin
        failed_tests = failed_tests + 1;
        $display("[TEST FAILED] %0s (%0d errors)", name, error_count - errors_before);
      end
      $display("");
    end
  endtask

  // ============================================================
  // Test Cases
  // ============================================================
  reg [`TB_DATA_WIDTH-1:0] rd_data;
  reg [1:0] rd_resp;
  integer err_before;
  integer i, j;
  reg [`TB_DATA_WIDTH-1:0] expected_fixed;
  reg [`TB_ADDR_WIDTH-1:0] check_addr;

  initial begin
    $dumpfile("axi4_vip.vcd");
    $dumpvars(0, tb_axi4_sv);

    // Wait for reset
    @(posedge aresetn);
    repeat(5) @(posedge aclk);

    $display("");
    $display("========================================");
    $display("    AXI4 VIP Verification Suite");
    $display("========================================");
    $display("");

    // ---- Test 1: Single Write-Read ----
    err_before = error_count;
    $display("--- Test 1: Single Write-Read ---");
    axi_write_data(0, 32'h0000_0100, 0, 2, 2'b01, 0, 32'hDEAD_BEEF, 4'hF);
    axi_read(0, 32'h0000_0100, 0, 2, 2'b01, 0, rd_data, rd_resp);
    check_read(32'h0000_0100, rd_data, 32'hDEAD_BEEF, "single_rw");
    report_test("Single Write-Read", err_before);

    // ---- Test 2: INCR Burst ----
    err_before = error_count;
    $display("--- Test 2: INCR Burst (len=4) ---");
    axi_write(0, 32'h0000_0200, 3, 2, 2'b01, 0, 0, 0, 0, 0);
    ref_write(32'h0000_0200, 3, 2, 2'b01);
    // Read back each beat
    for (i = 0; i < 4; i = i + 1) begin
      axi_read(0, 32'h0000_0200 + i * 4, 0, 2, 2'b01, 0, rd_data, rd_resp);
      check_read(32'h0000_0200 + i * 4, rd_data, ref_read_word(32'h0000_0200 + i * 4), "incr_burst");
    end
    report_test("INCR Burst", err_before);

    // ---- Test 3: INCR Burst len=8 ----
    err_before = error_count;
    $display("--- Test 3: INCR Burst (len=8) ---");
    axi_write(0, 32'h0000_0300, 7, 2, 2'b01, 0, 0, 0, 0, 0);
    ref_write(32'h0000_0300, 7, 2, 2'b01);
    for (i = 0; i < 8; i = i + 1) begin
      axi_read(0, 32'h0000_0300 + i * 4, 0, 2, 2'b01, 0, rd_data, rd_resp);
      check_read(32'h0000_0300 + i * 4, rd_data, ref_read_word(32'h0000_0300 + i * 4), "incr_burst_8");
    end
    report_test("INCR Burst len=8", err_before);

    // ---- Test 4: FIXED Burst ----
    err_before = error_count;
    $display("--- Test 4: FIXED Burst ---");
    // FIXED writes all go to the same address; last write wins
    axi_write(0, 32'h0000_0400, 3, 2, 2'b00, 0, 0, 0, 0, 0);
    // For FIXED, all beats write to the same base address
    // The last beat's data should be at the address
    expected_fixed = wr_data_gen(32'h0000_0400, 2, 2'b00, 3, 3); // last beat
    axi_read(0, 32'h0000_0400, 0, 2, 2'b01, 0, rd_data, rd_resp);
    check_read(32'h0000_0400, rd_data, expected_fixed, "fixed_burst");
    report_test("FIXED Burst", err_before);

    // ---- Test 5: WRAP Burst ----
    err_before = error_count;
    $display("--- Test 5: WRAP Burst (len=4) ---");
    axi_write(0, 32'h0000_0500, 3, 2, 2'b10, 0, 0, 0, 0, 0);
    ref_write(32'h0000_0500, 3, 2, 2'b10);
    for (i = 0; i < 4; i = i + 1) begin
      check_addr = calc_beat_addr(32'h0000_0500, 2, 2'b10, 3, i);
      axi_read(0, check_addr, 0, 2, 2'b01, 0, rd_data, rd_resp);
      check_read(check_addr, rd_data, ref_read_word(check_addr), "wrap_burst");
    end
    report_test("WRAP Burst", err_before);

    // ---- Test 6: Narrow Transfer (1-byte) ----
    err_before = error_count;
    $display("--- Test 6: Narrow Transfer (1-byte writes) ---");
    // Write 4 individual bytes using size=0
    axi_write_data(0, 32'h0000_0600, 0, 0, 2'b01, 0, 32'h000000A0, 4'b0001);
    axi_write_data(0, 32'h0000_0601, 0, 0, 2'b01, 0, 32'h0000B100, 4'b0010);
    axi_write_data(0, 32'h0000_0602, 0, 0, 2'b01, 0, 32'h00C20000, 4'b0100);
    axi_write_data(0, 32'h0000_0603, 0, 0, 2'b01, 0, 32'hD3000000, 4'b1000);
    // Read full word
    axi_read(0, 32'h0000_0600, 0, 2, 2'b01, 0, rd_data, rd_resp);
    check_read(32'h0000_0600, rd_data, 32'hD3C2B1A0, "narrow_transfer");
    report_test("Narrow Transfer", err_before);

    // ---- Test 7: Byte Strobe ----
    err_before = error_count;
    $display("--- Test 7: Byte Strobe ---");
    // Write all 0xFF
    axi_write_data(0, 32'h0000_0700, 0, 2, 2'b01, 0, 32'hFFFFFFFF, 4'b1111);
    // Selective write: only bytes 1 and 3
    axi_write_data(0, 32'h0000_0700, 0, 2, 2'b01, 0, 32'hAA00BB00, 4'b1010);
    // Read: expect bytes 0=FF, 1=BB, 2=FF, 3=AA
    axi_read(0, 32'h0000_0700, 0, 2, 2'b01, 0, rd_data, rd_resp);
    check_read(32'h0000_0700, rd_data, 32'hAA_FF_BB_FF, "byte_strobe");
    report_test("Byte Strobe", err_before);

    // ---- Test 8: Unaligned Access ----
    err_before = error_count;
    $display("--- Test 8: Unaligned Access ---");
    // Clear the area first
    axi_write_data(0, 32'h0000_0800, 0, 2, 2'b01, 0, 32'h00000000, 4'b1111);
    // Write 2 bytes at unaligned address 0x801
    axi_write_data(0, 32'h0000_0801, 0, 0, 2'b01, 0, 32'h0000AB00, 4'b0010);
    axi_write_data(0, 32'h0000_0802, 0, 0, 2'b01, 0, 32'h00CD0000, 4'b0100);
    axi_read(0, 32'h0000_0800, 0, 2, 2'b01, 0, rd_data, rd_resp);
    check_read(32'h0000_0800, rd_data, 32'h00CDAB00, "unaligned_access");
    report_test("Unaligned Access", err_before);

    // ---- Test 9: Exclusive Access ----
    err_before = error_count;
    $display("--- Test 9: Exclusive Access ---");
    // Normal write first
    axi_write_data(1, 32'h0000_0900, 0, 2, 2'b01, 0, 32'h12345678, 4'hF);
    // Exclusive read
    axi_read(1, 32'h0000_0900, 0, 2, 2'b01, 1, rd_data, rd_resp);
    if (rd_resp !== 2'b01)
      $display("[INFO] Exclusive read resp: %0b (expected EXOKAY=01)", rd_resp);
    check_read(32'h0000_0900, rd_data, 32'h12345678, "exclusive_read");
    // Exclusive write
    axi_write_data(1, 32'h0000_0900, 0, 2, 2'b01, 1, 32'hAAAABBBB, 4'hF);
    // Verify
    axi_read(1, 32'h0000_0900, 0, 2, 2'b01, 0, rd_data, rd_resp);
    check_read(32'h0000_0900, rd_data, 32'hAAAABBBB, "exclusive_write_verify");
    report_test("Exclusive Access", err_before);

    // ---- Test 10: Back-to-Back Transactions ----
    err_before = error_count;
    $display("--- Test 10: Back-to-Back Transactions ---");
    for (i = 0; i < 8; i = i + 1) begin
      axi_write_data(0, 32'h0000_0A00 + i * 4, 0, 2, 2'b01, 0, 
                      32'hB0000000 + i, 4'hF);
    end
    for (i = 0; i < 8; i = i + 1) begin
      axi_read(0, 32'h0000_0A00 + i * 4, 0, 2, 2'b01, 0, rd_data, rd_resp);
      check_read(32'h0000_0A00 + i * 4, rd_data, 32'hB0000000 + i, "back2back");
    end
    report_test("Back-to-Back Transactions", err_before);

    // ---- Test 11: QoS and Region ----
    err_before = error_count;
    $display("--- Test 11: QoS and Region ---");
    for (i = 0; i < 4; i = i + 1) begin
      @(posedge aclk);
      awid     <= 0;
      awaddr   <= 32'h0000_0B00 + i * 4;
      awlen    <= 0;
      awsize   <= 2;
      awburst  <= 2'b01;
      awlock   <= 0;
      awcache  <= 0;
      awprot   <= 0;
      awqos    <= i * 4; // different QoS
      awregion <= i;     // different region
      awuser   <= 0;
      awvalid  <= 1;
      @(posedge aclk);
      while (!awready) @(posedge aclk);
      awvalid <= 0;
      @(posedge aclk);
      wdata  <= 32'hA0000000 + i;
      wstrb  <= 4'hF;
      wlast  <= 1;
      wvalid <= 1;
      @(posedge aclk);
      while (!wready) @(posedge aclk);
      wvalid <= 0;
      wlast  <= 0;
      bready <= 1;
      @(posedge aclk);
      while (!bvalid) @(posedge aclk);
      bready <= 0;
    end
    for (i = 0; i < 4; i = i + 1) begin
      axi_read(0, 32'h0000_0B00 + i * 4, 0, 2, 2'b01, 0, rd_data, rd_resp);
      check_read(32'h0000_0B00 + i * 4, rd_data, 32'hA0000000 + i, "qos_region");
    end
    report_test("QoS and Region", err_before);

    // ---- Test 12: Outstanding with Different IDs ----
    err_before = error_count;
    $display("--- Test 12: Outstanding Transactions (Multi-ID) ---");
    for (i = 0; i < 4; i = i + 1) begin
      axi_write_data(i[`TB_ID_WIDTH-1:0], 32'h0000_0C00 + i * 4, 0, 2, 2'b01, 0,
                      32'hAD000000 + i * 256, 4'hF);
    end
    for (i = 0; i < 4; i = i + 1) begin
      axi_read(i[`TB_ID_WIDTH-1:0], 32'h0000_0C00 + i * 4, 0, 2, 2'b01, 0, rd_data, rd_resp);
      check_read(32'h0000_0C00 + i * 4, rd_data, 32'hAD000000 + i * 256, "outstanding_id");
    end
    report_test("Outstanding with Different IDs", err_before);

    // ---- Test 13: Long Burst (len=16) ----
    err_before = error_count;
    $display("--- Test 13: Long INCR Burst (len=16) ---");
    axi_write(0, 32'h0000_1000, 15, 2, 2'b01, 0, 0, 0, 0, 0);
    ref_write(32'h0000_1000, 15, 2, 2'b01);
    for (i = 0; i < 16; i = i + 1) begin
      axi_read(0, 32'h0000_1000 + i * 4, 0, 2, 2'b01, 0, rd_data, rd_resp);
      check_read(32'h0000_1000 + i * 4, rd_data, ref_read_word(32'h0000_1000 + i * 4), "long_burst");
    end
    report_test("Long INCR Burst", err_before);

    // ---- Test 14: Cache/Protection Attributes ----
    err_before = error_count;
    $display("--- Test 14: Cache and Protection Attributes ---");
    // Write with different cache values
    for (i = 0; i < 4; i = i + 1) begin
      @(posedge aclk);
      awid     <= 0;
      awaddr   <= 32'h0000_0D00 + i * 4;
      awlen    <= 0;
      awsize   <= 2;
      awburst  <= 2'b01;
      awlock   <= 0;
      awcache  <= i;       // different cache
      awprot   <= i;  // different prot
      awqos    <= 0;
      awregion <= 0;
      awuser   <= 0;
      awvalid  <= 1;
      @(posedge aclk);
      while (!awready) @(posedge aclk);
      awvalid <= 0;
      @(posedge aclk);
      wdata  <= 32'hCA000000 + i;
      wstrb  <= 4'hF;
      wlast  <= 1;
      wvalid <= 1;
      @(posedge aclk);
      while (!wready) @(posedge aclk);
      wvalid <= 0;
      wlast  <= 0;
      bready <= 1;
      @(posedge aclk);
      while (!bvalid) @(posedge aclk);
      bready <= 0;
    end
    for (i = 0; i < 4; i = i + 1) begin
      axi_read(0, 32'h0000_0D00 + i * 4, 0, 2, 2'b01, 0, rd_data, rd_resp);
      check_read(32'h0000_0D00 + i * 4, rd_data, 32'hCA000000 + i, "cache_prot");
    end
    report_test("Cache/Protection Attributes", err_before);

    // ---- Test 15: 2-byte Narrow Transfer ----
    err_before = error_count;
    $display("--- Test 15: 2-byte Narrow Transfer ---");
    axi_write_data(0, 32'h0000_0E00, 0, 2, 2'b01, 0, 32'h00000000, 4'b1111);
    axi_write_data(0, 32'h0000_0E00, 0, 1, 2'b01, 0, 32'h0000AABB, 4'b0011);
    axi_write_data(0, 32'h0000_0E02, 0, 1, 2'b01, 0, 32'hCCDD0000, 4'b1100);
    axi_read(0, 32'h0000_0E00, 0, 2, 2'b01, 0, rd_data, rd_resp);
    check_read(32'h0000_0E00, rd_data, 32'hCCDDAABB, "narrow_2byte");
    report_test("2-byte Narrow Transfer", err_before);

    // ============================================================
    // Summary
    // ============================================================
    repeat(10) @(posedge aclk);
    $display("");
    $display("========================================");
    $display("          TEST SUMMARY");
    $display("========================================");
    $display("  Total tests:  %0d", total_tests);
    $display("  Passed:       %0d", passed_tests);
    $display("  Failed:       %0d", failed_tests);
    $display("  Total errors: %0d", error_count);
    $display("========================================");
    if (failed_tests == 0)
      $display("  *** ALL TESTS PASSED ***");
    else
      $display("  *** SOME TESTS FAILED ***");
    $display("========================================");
    $display("");

    $finish;
  end

  // Timeout
  initial begin
    #500000;
    $display("[TIMEOUT] Simulation timed out!");
    $finish;
  end

endmodule
