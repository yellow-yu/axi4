//==========================================================================
// AXI4 Self-Checking Testbench (for Icarus Verilog / non-UVM)
//==========================================================================
// Tests all AXI4 protocol features:
//   1. Single write/read        2. INCR burst
//   3. FIXED burst              4. WRAP burst
//   5. Narrow transfers         6. Unaligned transfers
//   7. Byte strobes             8. Multiple IDs / Outstanding
//   9. Exclusive access        10. Back-to-back transactions
//==========================================================================
`timescale 1ns/1ps

module axi4_tb_top_iv;

  //------------------------------------------------------------------------
  // Parameters
  //------------------------------------------------------------------------
  parameter integer ID_WIDTH    = 4;
  parameter integer ADDR_WIDTH  = 64;
  parameter integer DATA_WIDTH  = 512;
  parameter integer USER_WIDTH  = 1;
  parameter integer STRB_WIDTH  = DATA_WIDTH / 8;  // 64
  parameter integer MAX_BURST   = 256;

  //------------------------------------------------------------------------
  // Clock and Reset
  //------------------------------------------------------------------------
  reg aclk = 0;
  reg aresetn = 0;
  always #5 aclk = ~aclk;

  //------------------------------------------------------------------------
  // AXI4 Interface Instance
  //------------------------------------------------------------------------
  axi4_interface #(
    .ID_WIDTH   (ID_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .USER_WIDTH (USER_WIDTH)
  ) axi4_if (
    .aclk    (aclk),
    .aresetn (aresetn)
  );

  //------------------------------------------------------------------------
  // Memory models (byte-addressable, fixed-size)
  //------------------------------------------------------------------------
  reg [7:0] slave_mem  [0:131071];  // 128KB
  reg [7:0] ref_mem    [0:131071];
  reg       ref_written[0:131071];

  //------------------------------------------------------------------------
  // Shared data buffers (module-level for iverilog compatibility)
  //------------------------------------------------------------------------
  reg [DATA_WIDTH-1:0] wr_buf   [0:MAX_BURST-1];
  reg [STRB_WIDTH-1:0] strb_buf [0:MAX_BURST-1];
  reg [DATA_WIDTH-1:0] rd_buf   [0:MAX_BURST-1];
  reg [ADDR_WIDTH-1:0] addr_buf [0:MAX_BURST-1];

  //------------------------------------------------------------------------
  // Statistics
  //------------------------------------------------------------------------
  integer total_tests   = 0;
  integer passed_tests  = 0;
  integer failed_tests  = 0;
  integer total_writes  = 0;
  integer total_reads   = 0;

  //------------------------------------------------------------------------
  // Burst types
  //------------------------------------------------------------------------
  localparam [1:0] BURST_FIXED = 2'b00;
  localparam [1:0] BURST_INCR  = 2'b01;
  localparam [1:0] BURST_WRAP  = 2'b10;

  //========================================================================
  // Beat address calculation (results stored in addr_buf)
  //========================================================================
  task automatic calc_beat_addrs(
    input  [ADDR_WIDTH-1:0] start_addr,
    input  [2:0]            size,
    input  [1:0]            burst,
    input  [7:0]            len
  );
    integer num_bytes, burst_len, total_size, i;
    reg [ADDR_WIDTH-1:0] aligned_addr, wrap_lo, wrap_hi;

    num_bytes    = 1 << size;
    burst_len    = len + 1;
    aligned_addr = (start_addr / num_bytes) * num_bytes;
    addr_buf[0] = start_addr;

    if (burst == BURST_WRAP) begin
      total_size = num_bytes * burst_len;
      wrap_lo    = (start_addr / total_size) * total_size;
      wrap_hi    = wrap_lo + total_size;
    end

    for (i = 1; i < burst_len; i = i + 1) begin
      case (burst)
        BURST_FIXED: addr_buf[i] = start_addr;
        BURST_INCR:  addr_buf[i] = aligned_addr + i * num_bytes;
        BURST_WRAP: begin
          addr_buf[i] = aligned_addr + i * num_bytes;
          if (addr_buf[i] >= wrap_hi)
            addr_buf[i] = addr_buf[i] - (wrap_hi - wrap_lo);
        end
        default: addr_buf[i] = aligned_addr + i * num_bytes;
      endcase
    end
  endtask

  //========================================================================
  // Calculate strobe for narrow/unaligned
  //========================================================================
  function [STRB_WIDTH-1:0] calc_strb(
    input [ADDR_WIDTH-1:0] beat_addr,
    input [2:0]            size
  );
    integer num_bytes, lower_lane, i;
    reg [STRB_WIDTH-1:0] strb;
    num_bytes  = 1 << size;
    lower_lane = beat_addr % STRB_WIDTH;
    strb = {STRB_WIDTH{1'b0}};
    for (i = 0; i < num_bytes && (lower_lane + i) < STRB_WIDTH; i = i + 1)
      strb[lower_lane + i] = 1'b1;
    calc_strb = strb;
  endfunction

  //========================================================================
  // SLAVE: Handle Write Transactions (AW -> W beats -> B)
  //========================================================================
  task automatic slave_handle_writes();
    reg [ID_WIDTH-1:0]   s_aw_id;
    reg [ADDR_WIDTH-1:0] s_aw_addr;
    reg [7:0]            s_aw_len;
    reg [2:0]            s_aw_size;
    reg [1:0]            s_aw_burst;
    reg                  s_aw_lock;
    reg [ADDR_WIDTH-1:0] s_beat_addr, s_aligned_addr;
    reg [ADDR_WIDTH-1:0] s_wrap_lo, s_wrap_hi;
    reg [DATA_WIDTH-1:0] s_wdata;
    reg [STRB_WIDTH-1:0] s_wstrb;
    integer              s_num_bytes, s_total_size, s_base_addr;
    integer              s_beat, s_b;

    forever begin
      //--- Accept Write Address ---
      axi4_if.awready <= 1'b1;
      @(posedge aclk);
      while (!axi4_if.awvalid) @(posedge aclk);

      s_aw_id    = axi4_if.awid;
      s_aw_addr  = axi4_if.awaddr;
      s_aw_len   = axi4_if.awlen;
      s_aw_size  = axi4_if.awsize;
      s_aw_burst = axi4_if.awburst;
      s_aw_lock  = axi4_if.awlock;
      axi4_if.awready <= 1'b0;

      s_num_bytes    = 1 << s_aw_size;
      s_aligned_addr = (s_aw_addr / s_num_bytes) * s_num_bytes;

      if (s_aw_burst == BURST_WRAP) begin
        s_total_size = s_num_bytes * (s_aw_len + 1);
        s_wrap_lo    = (s_aw_addr / s_total_size) * s_total_size;
        s_wrap_hi    = s_wrap_lo + s_total_size;
      end

      //--- Accept Write Data Beats ---
      // Drive wready immediately (same cycle as AW handshake)
      axi4_if.wready <= 1'b1;
      for (s_beat = 0; s_beat <= s_aw_len; s_beat = s_beat + 1) begin
        // Wait for wvalid
        @(posedge aclk);
        while (!axi4_if.wvalid) @(posedge aclk);

        // Capture data to local variables (avoid part-select on arrays)
        s_wdata = axi4_if.wdata;
        s_wstrb = axi4_if.wstrb;

        // Calculate beat address
        if (s_beat == 0)
          s_beat_addr = s_aw_addr;
        else begin
          case (s_aw_burst)
            BURST_FIXED: s_beat_addr = s_aw_addr;
            BURST_INCR:  s_beat_addr = s_aligned_addr + s_beat * s_num_bytes;
            BURST_WRAP: begin
              s_beat_addr = s_aligned_addr + s_beat * s_num_bytes;
              if (s_beat_addr >= s_wrap_hi)
                s_beat_addr = s_beat_addr - (s_wrap_hi - s_wrap_lo);
            end
            default: s_beat_addr = s_aligned_addr + s_beat * s_num_bytes;
          endcase
        end

        // Store data using strobe
        s_base_addr = (s_beat_addr / STRB_WIDTH) * STRB_WIDTH;
        for (s_b = 0; s_b < STRB_WIDTH; s_b = s_b + 1) begin
          if (s_wstrb[s_b] && (s_base_addr + s_b) < 131072)
            slave_mem[s_base_addr + s_b] = s_wdata[s_b*8 +: 8];
        end
      end
      axi4_if.wready <= 1'b0;

      //--- Send Write Response ---
      // Drive immediately (same cycle as last W beat handshake)
      axi4_if.bid    <= s_aw_id;
      axi4_if.bresp  <= (s_aw_lock) ? 2'b01 : 2'b00;
      axi4_if.bvalid <= 1'b1;
      @(posedge aclk);
      while (!axi4_if.bready) @(posedge aclk);
      axi4_if.bvalid <= 1'b0;
    end
  endtask

  //========================================================================
  // SLAVE: Handle Read Transactions (AR -> R beats)
  //========================================================================
  task automatic slave_handle_reads();
    reg [ID_WIDTH-1:0]   s_ar_id;
    reg [ADDR_WIDTH-1:0] s_ar_addr;
    reg [7:0]            s_ar_len;
    reg [2:0]            s_ar_size;
    reg [1:0]            s_ar_burst;
    reg                  s_ar_lock;
    reg [ADDR_WIDTH-1:0] s_beat_addr, s_aligned_addr;
    reg [ADDR_WIDTH-1:0] s_wrap_lo, s_wrap_hi;
    reg [DATA_WIDTH-1:0] s_rdata;
    integer              s_num_bytes, s_total_size, s_base_addr;
    integer              s_beat, s_b;

    forever begin
      //--- Accept Read Address ---
      axi4_if.arready <= 1'b1;
      @(posedge aclk);
      while (!axi4_if.arvalid) @(posedge aclk);

      s_ar_id    = axi4_if.arid;
      s_ar_addr  = axi4_if.araddr;
      s_ar_len   = axi4_if.arlen;
      s_ar_size  = axi4_if.arsize;
      s_ar_burst = axi4_if.arburst;
      s_ar_lock  = axi4_if.arlock;
      axi4_if.arready <= 1'b0;

      s_num_bytes    = 1 << s_ar_size;
      s_aligned_addr = (s_ar_addr / s_num_bytes) * s_num_bytes;

      if (s_ar_burst == BURST_WRAP) begin
        s_total_size = s_num_bytes * (s_ar_len + 1);
        s_wrap_lo    = (s_ar_addr / s_total_size) * s_total_size;
        s_wrap_hi    = s_wrap_lo + s_total_size;
      end

      //--- Send Read Data Beats ---
      // Drive data immediately for each beat (no extra wait cycle)
      for (s_beat = 0; s_beat <= s_ar_len; s_beat = s_beat + 1) begin
        // Calculate beat address
        if (s_beat == 0)
          s_beat_addr = s_ar_addr;
        else begin
          case (s_ar_burst)
            BURST_FIXED: s_beat_addr = s_ar_addr;
            BURST_INCR:  s_beat_addr = s_aligned_addr + s_beat * s_num_bytes;
            BURST_WRAP: begin
              s_beat_addr = s_aligned_addr + s_beat * s_num_bytes;
              if (s_beat_addr >= s_wrap_hi)
                s_beat_addr = s_beat_addr - (s_wrap_hi - s_wrap_lo);
            end
            default: s_beat_addr = s_aligned_addr + s_beat * s_num_bytes;
          endcase
        end

        // Read from memory
        s_base_addr = (s_beat_addr / STRB_WIDTH) * STRB_WIDTH;
        s_rdata = {DATA_WIDTH{1'b0}};
        for (s_b = 0; s_b < STRB_WIDTH; s_b = s_b + 1) begin
          if ((s_base_addr + s_b) < 131072)
            s_rdata[s_b*8 +: 8] = slave_mem[s_base_addr + s_b];
        end

        // Drive R channel signals immediately
        axi4_if.rid    <= s_ar_id;
        axi4_if.rdata  <= s_rdata;
        axi4_if.rresp  <= (s_ar_lock) ? 2'b01 : 2'b00;
        axi4_if.rlast  <= (s_beat == s_ar_len) ? 1'b1 : 1'b0;
        axi4_if.rvalid <= 1'b1;

        // Wait for handshake
        @(posedge aclk);
        while (!axi4_if.rready) @(posedge aclk);
      end
      axi4_if.rvalid <= 1'b0;
      axi4_if.rlast  <= 1'b0;
    end
  endtask

  //========================================================================
  // MASTER: Write Transaction
  // Uses wr_buf[0..len] and strb_buf[0..len]
  //========================================================================
  task automatic master_write(
    input [ADDR_WIDTH-1:0] addr,
    input [7:0]            len,
    input [2:0]            size,
    input [1:0]            burst,
    input [ID_WIDTH-1:0]   id,
    input                  lock
  );
    integer beat;

    //--- AW Channel ---
    @(posedge aclk);
    axi4_if.awid     <= id;
    axi4_if.awaddr   <= addr;
    axi4_if.awlen    <= len;
    axi4_if.awsize   <= size;
    axi4_if.awburst  <= burst;
    axi4_if.awlock   <= lock;
    axi4_if.awcache  <= 4'b0;
    axi4_if.awprot   <= 3'b0;
    axi4_if.awqos    <= 4'b0;
    axi4_if.awregion <= 4'b0;
    axi4_if.awuser   <= 1'b0;
    axi4_if.awvalid  <= 1'b1;

    @(posedge aclk);
    while (!axi4_if.awready) @(posedge aclk);
    axi4_if.awvalid  <= 1'b0;

    //--- W Channel ---
    // Drive data immediately after AW handshake (no extra posedge wait)
    for (beat = 0; beat <= len; beat = beat + 1) begin
      axi4_if.wdata  <= wr_buf[beat];
      axi4_if.wstrb  <= strb_buf[beat];
      axi4_if.wlast  <= (beat == len) ? 1'b1 : 1'b0;
      axi4_if.wvalid <= 1'b1;
      @(posedge aclk);
      while (!axi4_if.wready) @(posedge aclk);
    end
    axi4_if.wvalid <= 1'b0;
    axi4_if.wlast  <= 1'b0;

    //--- B Channel ---
    // Drive bready immediately (same cycle as last W handshake)
    axi4_if.bready <= 1'b1;
    @(posedge aclk);
    while (!axi4_if.bvalid) @(posedge aclk);
    axi4_if.bready <= 1'b0;

    total_writes = total_writes + 1;
  endtask

  //========================================================================
  // MASTER: Read Transaction
  // Results stored in rd_buf[0..len]
  //========================================================================
  task automatic master_read(
    input  [ADDR_WIDTH-1:0] addr,
    input  [7:0]            len,
    input  [2:0]            size,
    input  [1:0]            burst,
    input  [ID_WIDTH-1:0]   id,
    input                   lock
  );
    integer beat;

    //--- AR Channel ---
    @(posedge aclk);
    axi4_if.arid     <= id;
    axi4_if.araddr   <= addr;
    axi4_if.arlen    <= len;
    axi4_if.arsize   <= size;
    axi4_if.arburst  <= burst;
    axi4_if.arlock   <= lock;
    axi4_if.arcache  <= 4'b0;
    axi4_if.arprot   <= 3'b0;
    axi4_if.arqos    <= 4'b0;
    axi4_if.arregion <= 4'b0;
    axi4_if.aruser   <= 1'b0;
    axi4_if.arvalid  <= 1'b1;

    @(posedge aclk);
    while (!axi4_if.arready) @(posedge aclk);
    axi4_if.arvalid <= 1'b0;

    //--- R Channel ---
    // Drive rready immediately (same cycle as AR handshake)
    axi4_if.rready <= 1'b1;
    for (beat = 0; beat <= len; beat = beat + 1) begin
      @(posedge aclk);
      while (!axi4_if.rvalid) @(posedge aclk);
      rd_buf[beat] = axi4_if.rdata;
    end
    axi4_if.rready <= 1'b0;

    total_reads = total_reads + 1;
  endtask

  //========================================================================
  // Reference model: update ref_mem from wr_buf/strb_buf
  //========================================================================
  task automatic update_ref_mem(
    input [ADDR_WIDTH-1:0] addr,
    input [7:0]            len,
    input [2:0]            size,
    input [1:0]            burst
  );
    integer num_bytes, total_size, base_addr;
    reg [ADDR_WIDTH-1:0] beat_addr, aligned_addr, wrap_lo, wrap_hi;
    reg [DATA_WIDTH-1:0] wd;
    reg [STRB_WIDTH-1:0] ws;
    integer beat, b;

    num_bytes    = 1 << size;
    aligned_addr = (addr / num_bytes) * num_bytes;

    if (burst == BURST_WRAP) begin
      total_size = num_bytes * (len + 1);
      wrap_lo    = (addr / total_size) * total_size;
      wrap_hi    = wrap_lo + total_size;
    end

    for (beat = 0; beat <= len; beat = beat + 1) begin
      if (beat == 0)
        beat_addr = addr;
      else begin
        case (burst)
          BURST_FIXED: beat_addr = addr;
          BURST_INCR:  beat_addr = aligned_addr + beat * num_bytes;
          BURST_WRAP: begin
            beat_addr = aligned_addr + beat * num_bytes;
            if (beat_addr >= wrap_hi)
              beat_addr = beat_addr - (wrap_hi - wrap_lo);
          end
          default: beat_addr = aligned_addr + beat * num_bytes;
        endcase
      end

      wd = wr_buf[beat];
      ws = strb_buf[beat];
      base_addr = (beat_addr / STRB_WIDTH) * STRB_WIDTH;
      for (b = 0; b < STRB_WIDTH; b = b + 1) begin
        if (ws[b] && (base_addr + b) < 131072) begin
          ref_mem[base_addr + b]    = wd[b*8 +: 8];
          ref_written[base_addr + b] = 1'b1;
        end
      end
    end
  endtask

  //========================================================================
  // Check: compare rd_buf with reference memory
  //========================================================================
  task automatic check_read_data(
    input  [ADDR_WIDTH-1:0] addr,
    input  [7:0]            len,
    input  [2:0]            size,
    input  [1:0]            burst,
    output integer          errors
  );
    integer num_bytes, total_size, base_addr;
    reg [ADDR_WIDTH-1:0] beat_addr, aligned_addr, wrap_lo, wrap_hi;
    reg [DATA_WIDTH-1:0] rd;
    reg [7:0] expected_byte, actual_byte;
    integer beat, b;

    errors = 0;
    num_bytes    = 1 << size;
    aligned_addr = (addr / num_bytes) * num_bytes;

    if (burst == BURST_WRAP) begin
      total_size = num_bytes * (len + 1);
      wrap_lo    = (addr / total_size) * total_size;
      wrap_hi    = wrap_lo + total_size;
    end

    for (beat = 0; beat <= len; beat = beat + 1) begin
      if (beat == 0)
        beat_addr = addr;
      else begin
        case (burst)
          BURST_FIXED: beat_addr = addr;
          BURST_INCR:  beat_addr = aligned_addr + beat * num_bytes;
          BURST_WRAP: begin
            beat_addr = aligned_addr + beat * num_bytes;
            if (beat_addr >= wrap_hi)
              beat_addr = beat_addr - (wrap_hi - wrap_lo);
          end
          default: beat_addr = aligned_addr + beat * num_bytes;
        endcase
      end

      rd = rd_buf[beat];
      base_addr = (beat_addr / STRB_WIDTH) * STRB_WIDTH;
      for (b = 0; b < STRB_WIDTH; b = b + 1) begin
        if ((base_addr + b) < 131072 && ref_written[base_addr + b]) begin
          expected_byte = ref_mem[base_addr + b];
          actual_byte   = rd[b*8 +: 8];
          if (expected_byte !== actual_byte) begin
            if (errors < 5)
              $display("  ERROR: beat=%0d addr=0x%0h byte[%0d] exp=0x%02h got=0x%02h",
                       beat, beat_addr, b, expected_byte, actual_byte);
            errors = errors + 1;
          end
        end
      end
    end
  endtask

  //========================================================================
  // Generate random write data into wr_buf/strb_buf
  //========================================================================
  task automatic gen_write_data(input [7:0] len);
    integer i, w;
    reg [DATA_WIDTH-1:0] d;
    for (i = 0; i <= len; i = i + 1) begin
      d = {DATA_WIDTH{1'b0}};
      for (w = 0; w < DATA_WIDTH / 32; w = w + 1)
        d[w*32 +: 32] = $urandom;
      wr_buf[i]   = d;
      strb_buf[i] = {STRB_WIDTH{1'b1}};
    end
  endtask

  //========================================================================
  // Write + Check helper
  //========================================================================
  task automatic write_and_check(
    input [8*32-1:0]       test_name,
    input [ADDR_WIDTH-1:0] addr,
    input [7:0]            len,
    input [2:0]            size,
    input [1:0]            burst,
    input [ID_WIDTH-1:0]   id,
    input                  lock
  );
    integer errors;

    master_write(addr, len, size, burst, id, lock);
    update_ref_mem(addr, len, size, burst);
    master_read(addr, len, size, burst, id, lock);
    check_read_data(addr, len, size, burst, errors);

    total_tests = total_tests + 1;
    if (errors == 0) begin
      passed_tests = passed_tests + 1;
      $display("  [PASS] %0s (addr=0x%0h len=%0d size=%0d burst=%0d)",
               test_name, addr, len, size, burst);
    end else begin
      failed_tests = failed_tests + 1;
      $display("  [FAIL] %0s (addr=0x%0h len=%0d size=%0d burst=%0d) - %0d errors",
               test_name, addr, len, size, burst, errors);
    end
  endtask

  //========================================================================
  // TEST 1: Single Write/Read
  //========================================================================
  task automatic test_single_write_read();
    $display("\n=== TEST 1: Single Write/Read ===");
    gen_write_data(0);
    write_and_check("single_wr_rd_1", 64'h0000_1000, 0, 6, BURST_INCR, 0, 0);
    gen_write_data(0);
    write_and_check("single_wr_rd_2", 64'h0000_1040, 0, 6, BURST_INCR, 1, 0);
  endtask

  //========================================================================
  // TEST 2: INCR Burst
  //========================================================================
  task automatic test_incr_burst();
    $display("\n=== TEST 2: INCR Burst ===");
    gen_write_data(3);
    write_and_check("incr_4beat", 64'h0000_2000, 3, 6, BURST_INCR, 0, 0);
    gen_write_data(7);
    write_and_check("incr_8beat", 64'h0000_3000, 7, 6, BURST_INCR, 0, 0);
    gen_write_data(15);
    write_and_check("incr_16beat", 64'h0000_4000, 15, 6, BURST_INCR, 0, 0);
  endtask

  //========================================================================
  // TEST 3: FIXED Burst
  //========================================================================
  task automatic test_fixed_burst();
    integer errors;
    $display("\n=== TEST 3: FIXED Burst ===");

    gen_write_data(3);
    master_write(64'h0000_5000, 3, 6, BURST_FIXED, 0, 0);
    update_ref_mem(64'h0000_5000, 3, 6, BURST_FIXED);
    master_read(64'h0000_5000, 0, 6, BURST_INCR, 0, 0);
    check_read_data(64'h0000_5000, 0, 6, BURST_INCR, errors);
    total_tests = total_tests + 1;
    if (errors == 0) begin passed_tests = passed_tests + 1; $display("  [PASS] fixed_4beat"); end
    else begin failed_tests = failed_tests + 1; $display("  [FAIL] fixed_4beat - %0d errors", errors); end

    gen_write_data(7);
    master_write(64'h0000_5040, 7, 6, BURST_FIXED, 0, 0);
    update_ref_mem(64'h0000_5040, 7, 6, BURST_FIXED);
    master_read(64'h0000_5040, 0, 6, BURST_INCR, 0, 0);
    check_read_data(64'h0000_5040, 0, 6, BURST_INCR, errors);
    total_tests = total_tests + 1;
    if (errors == 0) begin passed_tests = passed_tests + 1; $display("  [PASS] fixed_8beat"); end
    else begin failed_tests = failed_tests + 1; $display("  [FAIL] fixed_8beat - %0d errors", errors); end
  endtask

  //========================================================================
  // TEST 4: WRAP Burst
  //========================================================================
  task automatic test_wrap_burst();
    integer i;
    $display("\n=== TEST 4: WRAP Burst ===");

    gen_write_data(3);
    write_and_check("wrap_4beat_s6", 64'h0000_6040, 3, 6, BURST_WRAP, 0, 0);

    gen_write_data(1);
    write_and_check("wrap_2beat_s6", 64'h0000_7040, 1, 6, BURST_WRAP, 0, 0);

    gen_write_data(7);
    calc_beat_addrs(64'h0000_8010, 3, BURST_WRAP, 7);
    for (i = 0; i <= 7; i = i + 1)
      strb_buf[i] = calc_strb(addr_buf[i], 3);
    write_and_check("wrap_8beat_s3", 64'h0000_8010, 7, 3, BURST_WRAP, 0, 0);
  endtask

  //========================================================================
  // TEST 5: Narrow Transfer
  //========================================================================
  task automatic test_narrow_transfer();
    integer i;
    $display("\n=== TEST 5: Narrow Transfer ===");

    gen_write_data(3);
    calc_beat_addrs(64'h0000_9000, 2, BURST_INCR, 3);
    for (i = 0; i <= 3; i = i + 1) strb_buf[i] = calc_strb(addr_buf[i], 2);
    write_and_check("narrow_4byte", 64'h0000_9000, 3, 2, BURST_INCR, 0, 0);

    gen_write_data(3);
    calc_beat_addrs(64'h0000_A000, 3, BURST_INCR, 3);
    for (i = 0; i <= 3; i = i + 1) strb_buf[i] = calc_strb(addr_buf[i], 3);
    write_and_check("narrow_8byte", 64'h0000_A000, 3, 3, BURST_INCR, 0, 0);

    gen_write_data(1);
    calc_beat_addrs(64'h0000_B000, 4, BURST_INCR, 1);
    for (i = 0; i <= 1; i = i + 1) strb_buf[i] = calc_strb(addr_buf[i], 4);
    write_and_check("narrow_16byte", 64'h0000_B000, 1, 4, BURST_INCR, 0, 0);
  endtask

  //========================================================================
  // TEST 6: Unaligned Transfer
  //========================================================================
  task automatic test_unaligned_transfer();
    integer i;
    $display("\n=== TEST 6: Unaligned Transfer ===");

    gen_write_data(3);
    calc_beat_addrs(64'h0000_C003, 2, BURST_INCR, 3);
    for (i = 0; i <= 3; i = i + 1) strb_buf[i] = calc_strb(addr_buf[i], 2);
    write_and_check("unaligned_4B", 64'h0000_C003, 3, 2, BURST_INCR, 0, 0);

    gen_write_data(1);
    calc_beat_addrs(64'h0000_D005, 3, BURST_INCR, 1);
    for (i = 0; i <= 1; i = i + 1) strb_buf[i] = calc_strb(addr_buf[i], 3);
    write_and_check("unaligned_8B", 64'h0000_D005, 1, 3, BURST_INCR, 0, 0);
  endtask

  //========================================================================
  // TEST 7: Byte Strobe
  //========================================================================
  task automatic test_byte_strobe();
    integer b;
    $display("\n=== TEST 7: Byte Strobe ===");

    gen_write_data(0);
    strb_buf[0] = {STRB_WIDTH{1'b0}};
    for (b = 0; b < STRB_WIDTH; b = b + 2) strb_buf[0][b] = 1'b1;
    write_and_check("strobe_alt", 64'h0000_E000, 0, 6, BURST_INCR, 0, 0);

    gen_write_data(0);
    strb_buf[0] = {STRB_WIDTH{1'b0}};
    strb_buf[0][7:0] = 8'hFF;
    write_and_check("strobe_first8", 64'h0000_E040, 0, 6, BURST_INCR, 0, 0);

    gen_write_data(0);
    strb_buf[0] = {STRB_WIDTH{1'b0}};
    strb_buf[0][STRB_WIDTH-1 -: 8] = 8'hFF;
    write_and_check("strobe_last8", 64'h0000_E080, 0, 6, BURST_INCR, 0, 0);
  endtask

  //========================================================================
  // TEST 8: Multiple IDs
  //========================================================================
  task automatic test_multi_id();
    integer i;
    $display("\n=== TEST 8: Multiple IDs / Outstanding ===");
    for (i = 0; i < 8; i = i + 1) begin
      gen_write_data(1);
      write_and_check("multi_id", 64'h0000_F000 + i * 64'h100, 1, 6, BURST_INCR, i[3:0], 0);
    end
  endtask

  //========================================================================
  // TEST 9: Exclusive Access
  //========================================================================
  task automatic test_exclusive_access();
    $display("\n=== TEST 9: Exclusive Access ===");
    gen_write_data(0);
    write_and_check("exclusive_wr", 64'h0001_0000, 0, 6, BURST_INCR, 0, 1);
    gen_write_data(0);
    write_and_check("normal_wr", 64'h0001_0000, 0, 6, BURST_INCR, 0, 0);
  endtask

  //========================================================================
  // TEST 10: Back-to-Back
  //========================================================================
  task automatic test_back2back();
    integer i;
    $display("\n=== TEST 10: Back-to-Back ===");
    for (i = 0; i < 10; i = i + 1) begin
      gen_write_data(0);
      write_and_check("b2b", 64'h0001_1000 + i * 64'h80, 0, 6, BURST_INCR, 0, 0);
    end
  endtask

  //========================================================================
  // Initialize
  //========================================================================
  task automatic init_all();
    integer i;

    axi4_if.awid <= 0; axi4_if.awaddr <= 0; axi4_if.awlen <= 0;
    axi4_if.awsize <= 0; axi4_if.awburst <= 0; axi4_if.awlock <= 0;
    axi4_if.awcache <= 0; axi4_if.awprot <= 0; axi4_if.awqos <= 0;
    axi4_if.awregion <= 0; axi4_if.awuser <= 0; axi4_if.awvalid <= 0;
    axi4_if.wdata <= 0; axi4_if.wstrb <= 0; axi4_if.wlast <= 0;
    axi4_if.wuser <= 0; axi4_if.wvalid <= 0; axi4_if.bready <= 0;
    axi4_if.arid <= 0; axi4_if.araddr <= 0; axi4_if.arlen <= 0;
    axi4_if.arsize <= 0; axi4_if.arburst <= 0; axi4_if.arlock <= 0;
    axi4_if.arcache <= 0; axi4_if.arprot <= 0; axi4_if.arqos <= 0;
    axi4_if.arregion <= 0; axi4_if.aruser <= 0; axi4_if.arvalid <= 0;
    axi4_if.rready <= 0;
    axi4_if.awready <= 0; axi4_if.wready <= 0;
    axi4_if.bid <= 0; axi4_if.bresp <= 0; axi4_if.buser <= 0; axi4_if.bvalid <= 0;
    axi4_if.arready <= 0;
    axi4_if.rid <= 0; axi4_if.rdata <= 0; axi4_if.rresp <= 0;
    axi4_if.rlast <= 0; axi4_if.ruser <= 0; axi4_if.rvalid <= 0;

    for (i = 0; i < 131072; i = i + 1) begin
      slave_mem[i]   = 8'h00;
      ref_mem[i]     = 8'h00;
      ref_written[i] = 1'b0;
    end
  endtask

  //========================================================================
  // MAIN
  //========================================================================
  initial begin
    $display("=========================================================");
    $display(" AXI4 VIP Self-Checking Testbench");
    $display(" DATA_WIDTH=%0d  ADDR_WIDTH=%0d  ID_WIDTH=%0d",
             DATA_WIDTH, ADDR_WIDTH, ID_WIDTH);
    $display("=========================================================");

    init_all();
    aresetn = 0;
    repeat (20) @(posedge aclk);
    aresetn = 1;
    repeat (5) @(posedge aclk);

    fork
      slave_handle_writes();
      slave_handle_reads();
    join_none

    repeat (5) @(posedge aclk);

    test_single_write_read();
    test_incr_burst();
    test_fixed_burst();
    test_wrap_burst();
    test_narrow_transfer();
    test_unaligned_transfer();
    test_byte_strobe();
    test_multi_id();
    test_exclusive_access();
    test_back2back();

    repeat (10) @(posedge aclk);
    $display("\n=========================================================");
    $display(" TEST SUMMARY");
    $display("=========================================================");
    $display("  Total Tests:   %0d", total_tests);
    $display("  Passed:        %0d", passed_tests);
    $display("  Failed:        %0d", failed_tests);
    $display("  Total Writes:  %0d", total_writes);
    $display("  Total Reads:   %0d", total_reads);
    $display("=========================================================");
    if (failed_tests == 0)
      $display("  *** ALL TESTS PASSED ***");
    else
      $display("  *** %0d TEST(S) FAILED ***", failed_tests);
    $display("=========================================================\n");
    $finish;
  end

  initial begin
    #10_000_000;
    $display("ERROR: Simulation timeout!");
    $finish;
  end

endmodule
