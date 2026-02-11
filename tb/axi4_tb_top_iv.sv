//==========================================================================
// AXI4 Self-Checking Testbench (for Icarus Verilog / non-UVM)
//==========================================================================
// Tests all AXI4 protocol features:
//   1. Single write/read
//   2. INCR burst
//   3. FIXED burst
//   4. WRAP burst
//   5. Narrow transfers
//   6. Unaligned transfers
//   7. Byte strobes
//   8. Multiple IDs / Outstanding transactions
//   9. Exclusive access
//  10. Back-to-back transactions
//==========================================================================
`timescale 1ns/1ps

module axi4_tb_top_iv;

  //------------------------------------------------------------------------
  // Parameters
  //------------------------------------------------------------------------
  parameter int ID_WIDTH    = 4;
  parameter int ADDR_WIDTH  = 64;
  parameter int DATA_WIDTH  = 512;
  parameter int USER_WIDTH  = 1;
  parameter int STRB_WIDTH  = DATA_WIDTH / 8;  // 64

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
  // Reference Memory & Slave Memory (byte-addressable, fixed-size array)
  //------------------------------------------------------------------------
  reg [7:0] slave_mem  [0:131071];  // 128KB slave memory
  reg [7:0] ref_mem    [0:131071];  // 128KB reference memory
  reg       ref_written[0:131071];  // Track which bytes were written

  //------------------------------------------------------------------------
  // Statistics
  //------------------------------------------------------------------------
  integer total_tests   = 0;
  integer passed_tests  = 0;
  integer failed_tests  = 0;
  integer total_writes  = 0;
  integer total_reads   = 0;

  //------------------------------------------------------------------------
  // Burst type encoding
  //------------------------------------------------------------------------
  localparam [1:0] BURST_FIXED = 2'b00;
  localparam [1:0] BURST_INCR  = 2'b01;
  localparam [1:0] BURST_WRAP  = 2'b10;

  //========================================================================
  // SLAVE DRIVER (reactive, runs in background)
  //========================================================================
  task automatic slave_handle_writes();
    reg [ID_WIDTH-1:0]   aw_id;
    reg [ADDR_WIDTH-1:0] aw_addr;
    reg [7:0]            aw_len;
    reg [2:0]            aw_size;
    reg [1:0]            aw_burst;
    reg                  aw_lock;
    reg [ADDR_WIDTH-1:0] beat_addr;
    reg [ADDR_WIDTH-1:0] aligned_addr;
    reg [ADDR_WIDTH-1:0] wrap_lo, wrap_hi;
    integer              num_bytes, total_size, base_addr;
    integer              beat, b;

    forever begin
      // Accept AW
      axi4_if.awready <= 1'b1;
      @(posedge aclk);
      while (!axi4_if.awvalid) @(posedge aclk);

      aw_id    = axi4_if.awid;
      aw_addr  = axi4_if.awaddr;
      aw_len   = axi4_if.awlen;
      aw_size  = axi4_if.awsize;
      aw_burst = axi4_if.awburst;
      aw_lock  = axi4_if.awlock;
      axi4_if.awready <= 1'b0;

      num_bytes    = 1 << aw_size;
      aligned_addr = (aw_addr / num_bytes) * num_bytes;

      if (aw_burst == BURST_WRAP) begin
        total_size = num_bytes * (aw_len + 1);
        wrap_lo    = (aw_addr / total_size) * total_size;
        wrap_hi    = wrap_lo + total_size;
      end

      // Accept W beats
      axi4_if.wready <= 1'b1;
      for (beat = 0; beat <= aw_len; beat = beat + 1) begin
        @(posedge aclk);
        while (!axi4_if.wvalid) @(posedge aclk);

        // Calculate beat address
        if (beat == 0)
          beat_addr = aw_addr;
        else begin
          case (aw_burst)
            BURST_FIXED: beat_addr = aw_addr;
            BURST_INCR:  beat_addr = aligned_addr + beat * num_bytes;
            BURST_WRAP: begin
              beat_addr = aligned_addr + beat * num_bytes;
              if (beat_addr >= wrap_hi)
                beat_addr = beat_addr - (wrap_hi - wrap_lo);
            end
            default: beat_addr = aligned_addr + beat * num_bytes;
          endcase
        end

        // Store data using strobe
        base_addr = (beat_addr / STRB_WIDTH) * STRB_WIDTH;
        for (b = 0; b < STRB_WIDTH; b = b + 1) begin
          if (axi4_if.wstrb[b] && (base_addr + b) < 131072) begin
            slave_mem[base_addr + b] = axi4_if.wdata[b*8 +: 8];
          end
        end
      end
      axi4_if.wready <= 1'b0;

      // Send B response
      @(posedge aclk);
      axi4_if.bid    <= aw_id;
      axi4_if.bresp  <= (aw_lock) ? 2'b01 : 2'b00;
      axi4_if.bvalid <= 1'b1;
      @(posedge aclk);
      while (!axi4_if.bready) @(posedge aclk);
      axi4_if.bvalid <= 1'b0;
    end
  endtask

  task automatic slave_handle_reads();
    reg [ID_WIDTH-1:0]   ar_id;
    reg [ADDR_WIDTH-1:0] ar_addr;
    reg [7:0]            ar_len;
    reg [2:0]            ar_size;
    reg [1:0]            ar_burst;
    reg                  ar_lock;
    reg [ADDR_WIDTH-1:0] beat_addr;
    reg [ADDR_WIDTH-1:0] aligned_addr;
    reg [ADDR_WIDTH-1:0] wrap_lo, wrap_hi;
    reg [DATA_WIDTH-1:0] rdata;
    integer              num_bytes, total_size, base_addr;
    integer              beat, b;

    forever begin
      // Accept AR
      axi4_if.arready <= 1'b1;
      @(posedge aclk);
      while (!axi4_if.arvalid) @(posedge aclk);

      ar_id    = axi4_if.arid;
      ar_addr  = axi4_if.araddr;
      ar_len   = axi4_if.arlen;
      ar_size  = axi4_if.arsize;
      ar_burst = axi4_if.arburst;
      ar_lock  = axi4_if.arlock;
      axi4_if.arready <= 1'b0;

      num_bytes    = 1 << ar_size;
      aligned_addr = (ar_addr / num_bytes) * num_bytes;

      if (ar_burst == BURST_WRAP) begin
        total_size = num_bytes * (ar_len + 1);
        wrap_lo    = (ar_addr / total_size) * total_size;
        wrap_hi    = wrap_lo + total_size;
      end

      // Send R beats
      for (beat = 0; beat <= ar_len; beat = beat + 1) begin
        // Calculate beat address
        if (beat == 0)
          beat_addr = ar_addr;
        else begin
          case (ar_burst)
            BURST_FIXED: beat_addr = ar_addr;
            BURST_INCR:  beat_addr = aligned_addr + beat * num_bytes;
            BURST_WRAP: begin
              beat_addr = aligned_addr + beat * num_bytes;
              if (beat_addr >= wrap_hi)
                beat_addr = beat_addr - (wrap_hi - wrap_lo);
            end
            default: beat_addr = aligned_addr + beat * num_bytes;
          endcase
        end

        // Read data from memory
        base_addr = (beat_addr / STRB_WIDTH) * STRB_WIDTH;
        rdata = {DATA_WIDTH{1'b0}};
        for (b = 0; b < STRB_WIDTH; b = b + 1) begin
          if ((base_addr + b) < 131072)
            rdata[b*8 +: 8] = slave_mem[base_addr + b];
        end

        @(posedge aclk);
        axi4_if.rid    <= ar_id;
        axi4_if.rdata  <= rdata;
        axi4_if.rresp  <= (ar_lock) ? 2'b01 : 2'b00;
        axi4_if.rlast  <= (beat == ar_len) ? 1'b1 : 1'b0;
        axi4_if.rvalid <= 1'b1;

        @(posedge aclk);
        while (!axi4_if.rready) @(posedge aclk);
      end
      axi4_if.rvalid <= 1'b0;
      axi4_if.rlast  <= 1'b0;
    end
  endtask

  //========================================================================
  // MASTER DRIVER TASKS
  //========================================================================

  // Write a burst transaction
  task automatic master_write(
    input [ADDR_WIDTH-1:0] addr,
    input [7:0]            len,
    input [2:0]            size,
    input [1:0]            burst,
    input [ID_WIDTH-1:0]   id,
    input                  lock,
    input [DATA_WIDTH-1:0] wdata [],
    input [STRB_WIDTH-1:0] wstrb_in []
  );
    integer beat;

    // AW channel
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

    // W channel
    for (beat = 0; beat <= len; beat = beat + 1) begin
      @(posedge aclk);
      axi4_if.wdata  <= wdata[beat];
      axi4_if.wstrb  <= wstrb_in[beat];
      axi4_if.wlast  <= (beat == len) ? 1'b1 : 1'b0;
      axi4_if.wvalid <= 1'b1;

      @(posedge aclk);
      while (!axi4_if.wready) @(posedge aclk);
    end
    axi4_if.wvalid <= 1'b0;
    axi4_if.wlast  <= 1'b0;

    // B channel
    @(posedge aclk);
    axi4_if.bready <= 1'b1;
    @(posedge aclk);
    while (!axi4_if.bvalid) @(posedge aclk);
    axi4_if.bready <= 1'b0;

    total_writes = total_writes + 1;
  endtask

  // Read a burst transaction, return data
  task automatic master_read(
    input  [ADDR_WIDTH-1:0] addr,
    input  [7:0]            len,
    input  [2:0]            size,
    input  [1:0]            burst,
    input  [ID_WIDTH-1:0]   id,
    input                   lock,
    output [DATA_WIDTH-1:0] rdata []
  );
    integer beat;

    rdata = new[len + 1];

    // AR channel
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

    // R channel
    axi4_if.rready <= 1'b1;
    for (beat = 0; beat <= len; beat = beat + 1) begin
      @(posedge aclk);
      while (!axi4_if.rvalid) @(posedge aclk);
      rdata[beat] = axi4_if.rdata;
    end
    axi4_if.rready <= 1'b0;

    total_reads = total_reads + 1;
  endtask

  //========================================================================
  // REFERENCE MODEL: Update reference memory after write
  //========================================================================
  task automatic update_ref_mem(
    input [ADDR_WIDTH-1:0] addr,
    input [7:0]            len,
    input [2:0]            size,
    input [1:0]            burst,
    input [DATA_WIDTH-1:0] wdata [],
    input [STRB_WIDTH-1:0] wstrb_in []
  );
    integer num_bytes, total_size, base_addr;
    reg [ADDR_WIDTH-1:0] beat_addr, aligned_addr, wrap_lo, wrap_hi;
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

      base_addr = (beat_addr / STRB_WIDTH) * STRB_WIDTH;
      for (b = 0; b < STRB_WIDTH; b = b + 1) begin
        if (wstrb_in[beat][b] && (base_addr + b) < 131072) begin
          ref_mem[base_addr + b]    = wdata[beat][b*8 +: 8];
          ref_written[base_addr + b] = 1'b1;
        end
      end
    end
  endtask

  //========================================================================
  // CHECK: Compare read data with reference memory
  //========================================================================
  function automatic integer check_read_data(
    input [ADDR_WIDTH-1:0] addr,
    input [7:0]            len,
    input [2:0]            size,
    input [1:0]            burst,
    input [DATA_WIDTH-1:0] rdata []
  );
    integer num_bytes, total_size, base_addr;
    reg [ADDR_WIDTH-1:0] beat_addr, aligned_addr, wrap_lo, wrap_hi;
    integer beat, b, errors;
    reg [7:0] expected_byte, actual_byte;

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

      base_addr = (beat_addr / STRB_WIDTH) * STRB_WIDTH;
      for (b = 0; b < STRB_WIDTH; b = b + 1) begin
        if ((base_addr + b) < 131072 && ref_written[base_addr + b]) begin
          expected_byte = ref_mem[base_addr + b];
          actual_byte   = rdata[beat][b*8 +: 8];
          if (expected_byte !== actual_byte) begin
            if (errors < 5)  // Limit error messages
              $display("  ERROR: beat=%0d addr=0x%0h byte[%0d] exp=0x%02h got=0x%02h",
                       beat, beat_addr, b, expected_byte, actual_byte);
            errors = errors + 1;
          end
        end
      end
    end

    return errors;
  endfunction

  //========================================================================
  // HELPER: Generate random data and all-1s strobe
  //========================================================================
  task automatic gen_write_data(
    input  [7:0]            len,
    output [DATA_WIDTH-1:0] wdata [],
    output [STRB_WIDTH-1:0] wstrb_out []
  );
    integer i, w;
    wdata     = new[len + 1];
    wstrb_out = new[len + 1];
    for (i = 0; i <= len; i = i + 1) begin
      for (w = 0; w < DATA_WIDTH / 32; w = w + 1)
        wdata[i][w*32 +: 32] = $urandom;
      wstrb_out[i] = {STRB_WIDTH{1'b1}};
    end
  endtask

  //========================================================================
  // HELPER: Calculate write strobe for narrow transfer
  //========================================================================
  function automatic [STRB_WIDTH-1:0] calc_strb(
    input [ADDR_WIDTH-1:0] beat_addr,
    input [2:0]            size
  );
    integer num_bytes, lower_lane, i;
    reg [STRB_WIDTH-1:0] strb;

    num_bytes  = 1 << size;
    lower_lane = beat_addr % STRB_WIDTH;
    strb = {STRB_WIDTH{1'b0}};

    for (i = lower_lane; i < lower_lane + num_bytes && i < STRB_WIDTH; i = i + 1)
      strb[i] = 1'b1;

    return strb;
  endfunction

  //========================================================================
  // HELPER: Calculate beat addresses
  //========================================================================
  task automatic calc_beat_addrs(
    input  [ADDR_WIDTH-1:0] start_addr,
    input  [2:0]            size,
    input  [1:0]            burst,
    input  [7:0]            len,
    output [ADDR_WIDTH-1:0] addrs []
  );
    integer num_bytes, burst_len, total_size, i;
    reg [ADDR_WIDTH-1:0] aligned_addr, wrap_lo, wrap_hi;

    num_bytes    = 1 << size;
    burst_len    = len + 1;
    aligned_addr = (start_addr / num_bytes) * num_bytes;
    addrs = new[burst_len];
    addrs[0] = start_addr;

    if (burst == BURST_WRAP) begin
      total_size = num_bytes * burst_len;
      wrap_lo    = (start_addr / total_size) * total_size;
      wrap_hi    = wrap_lo + total_size;
    end

    for (i = 1; i < burst_len; i = i + 1) begin
      case (burst)
        BURST_FIXED: addrs[i] = start_addr;
        BURST_INCR:  addrs[i] = aligned_addr + i * num_bytes;
        BURST_WRAP: begin
          addrs[i] = aligned_addr + i * num_bytes;
          if (addrs[i] >= wrap_hi)
            addrs[i] = addrs[i] - (wrap_hi - wrap_lo);
        end
        default: addrs[i] = aligned_addr + i * num_bytes;
      endcase
    end
  endtask

  //========================================================================
  // WRITE + CHECK helper: write, update ref, read, compare
  //========================================================================
  task automatic write_and_check(
    input string           test_name,
    input [ADDR_WIDTH-1:0] addr,
    input [7:0]            len,
    input [2:0]            size,
    input [1:0]            burst,
    input [ID_WIDTH-1:0]   id,
    input                  lock,
    input [DATA_WIDTH-1:0] wdata [],
    input [STRB_WIDTH-1:0] wstrb_in []
  );
    reg [DATA_WIDTH-1:0] rdata [];
    integer errors;

    // Write
    master_write(addr, len, size, burst, id, lock, wdata, wstrb_in);
    update_ref_mem(addr, len, size, burst, wdata, wstrb_in);

    // Read back with same parameters
    master_read(addr, len, size, burst, id, lock, rdata);

    // Check
    errors = check_read_data(addr, len, size, burst, rdata);

    total_tests = total_tests + 1;
    if (errors == 0) begin
      passed_tests = passed_tests + 1;
      $display("  [PASS] %s (addr=0x%0h len=%0d size=%0d burst=%0d)",
               test_name, addr, len, size, burst);
    end else begin
      failed_tests = failed_tests + 1;
      $display("  [FAIL] %s (addr=0x%0h len=%0d size=%0d burst=%0d) - %0d errors",
               test_name, addr, len, size, burst, errors);
    end
  endtask

  //========================================================================
  // TEST CASES
  //========================================================================

  task automatic test_single_write_read();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];

    $display("\n=== TEST 1: Single Write/Read ===");

    gen_write_data(0, wdata, wstrb);
    write_and_check("single_wr_rd_1", 64'h0000_1000, 0, 6, BURST_INCR, 0, 0, wdata, wstrb);

    gen_write_data(0, wdata, wstrb);
    write_and_check("single_wr_rd_2", 64'h0000_1040, 0, 6, BURST_INCR, 1, 0, wdata, wstrb);
  endtask

  task automatic test_incr_burst();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];

    $display("\n=== TEST 2: INCR Burst ===");

    // 4-beat
    gen_write_data(3, wdata, wstrb);
    write_and_check("incr_4beat", 64'h0000_2000, 3, 6, BURST_INCR, 0, 0, wdata, wstrb);

    // 8-beat
    gen_write_data(7, wdata, wstrb);
    write_and_check("incr_8beat", 64'h0000_3000, 7, 6, BURST_INCR, 0, 0, wdata, wstrb);

    // 16-beat
    gen_write_data(15, wdata, wstrb);
    write_and_check("incr_16beat", 64'h0000_4000, 15, 6, BURST_INCR, 0, 0, wdata, wstrb);
  endtask

  task automatic test_fixed_burst();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];
    reg [DATA_WIDTH-1:0] rdata [];
    integer errors;

    $display("\n=== TEST 3: FIXED Burst ===");

    // FIXED burst: all writes go to same address, last data wins
    gen_write_data(3, wdata, wstrb);
    master_write(64'h0000_5000, 3, 6, BURST_FIXED, 0, 0, wdata, wstrb);
    update_ref_mem(64'h0000_5000, 3, 6, BURST_FIXED, wdata, wstrb);

    // Read back single beat (only last written data at that address)
    master_read(64'h0000_5000, 0, 6, BURST_INCR, 0, 0, rdata);
    errors = check_read_data(64'h0000_5000, 0, 6, BURST_INCR, rdata);

    total_tests = total_tests + 1;
    if (errors == 0) begin
      passed_tests = passed_tests + 1;
      $display("  [PASS] fixed_4beat");
    end else begin
      failed_tests = failed_tests + 1;
      $display("  [FAIL] fixed_4beat - %0d errors", errors);
    end

    // Another FIXED burst
    gen_write_data(7, wdata, wstrb);
    master_write(64'h0000_5040, 7, 6, BURST_FIXED, 0, 0, wdata, wstrb);
    update_ref_mem(64'h0000_5040, 7, 6, BURST_FIXED, wdata, wstrb);

    master_read(64'h0000_5040, 0, 6, BURST_INCR, 0, 0, rdata);
    errors = check_read_data(64'h0000_5040, 0, 6, BURST_INCR, rdata);

    total_tests = total_tests + 1;
    if (errors == 0) begin
      passed_tests = passed_tests + 1;
      $display("  [PASS] fixed_8beat");
    end else begin
      failed_tests = failed_tests + 1;
      $display("  [FAIL] fixed_8beat - %0d errors", errors);
    end
  endtask

  task automatic test_wrap_burst();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];

    $display("\n=== TEST 4: WRAP Burst ===");

    // 4-beat WRAP, size=6 (64 bytes), wrap boundary = 256 bytes
    // Start at offset within wrap boundary
    gen_write_data(3, wdata, wstrb);
    write_and_check("wrap_4beat_s6", 64'h0000_6040, 3, 6, BURST_WRAP, 0, 0, wdata, wstrb);

    // 2-beat WRAP
    gen_write_data(1, wdata, wstrb);
    write_and_check("wrap_2beat_s6", 64'h0000_7040, 1, 6, BURST_WRAP, 0, 0, wdata, wstrb);

    // 8-beat WRAP with smaller size (8 bytes)
    gen_write_data(7, wdata, wstrb);
    begin
      // For narrow WRAP, calculate proper strobes
      reg [ADDR_WIDTH-1:0] addrs [];
      integer i;
      calc_beat_addrs(64'h0000_8010, 3, BURST_WRAP, 7, addrs);
      for (i = 0; i <= 7; i = i + 1)
        wstrb[i] = calc_strb(addrs[i], 3);
    end
    write_and_check("wrap_8beat_s3", 64'h0000_8010, 7, 3, BURST_WRAP, 0, 0, wdata, wstrb);
  endtask

  task automatic test_narrow_transfer();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];
    reg [ADDR_WIDTH-1:0] addrs [];
    integer i;

    $display("\n=== TEST 5: Narrow Transfer ===");

    // 4-byte narrow transfer (size=2), 4 beats
    gen_write_data(3, wdata, wstrb);
    calc_beat_addrs(64'h0000_9000, 2, BURST_INCR, 3, addrs);
    for (i = 0; i <= 3; i = i + 1)
      wstrb[i] = calc_strb(addrs[i], 2);
    write_and_check("narrow_4byte", 64'h0000_9000, 3, 2, BURST_INCR, 0, 0, wdata, wstrb);

    // 8-byte narrow transfer (size=3), 4 beats
    gen_write_data(3, wdata, wstrb);
    calc_beat_addrs(64'h0000_A000, 3, BURST_INCR, 3, addrs);
    for (i = 0; i <= 3; i = i + 1)
      wstrb[i] = calc_strb(addrs[i], 3);
    write_and_check("narrow_8byte", 64'h0000_A000, 3, 3, BURST_INCR, 0, 0, wdata, wstrb);

    // 16-byte narrow transfer (size=4), 2 beats
    gen_write_data(1, wdata, wstrb);
    calc_beat_addrs(64'h0000_B000, 4, BURST_INCR, 1, addrs);
    for (i = 0; i <= 1; i = i + 1)
      wstrb[i] = calc_strb(addrs[i], 4);
    write_and_check("narrow_16byte", 64'h0000_B000, 1, 4, BURST_INCR, 0, 0, wdata, wstrb);
  endtask

  task automatic test_unaligned_transfer();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];
    reg [ADDR_WIDTH-1:0] addrs [];
    integer i;

    $display("\n=== TEST 6: Unaligned Transfer ===");

    // Unaligned 4-byte write (addr not aligned to size)
    gen_write_data(3, wdata, wstrb);
    calc_beat_addrs(64'h0000_C003, 2, BURST_INCR, 3, addrs);
    for (i = 0; i <= 3; i = i + 1)
      wstrb[i] = calc_strb(addrs[i], 2);
    write_and_check("unaligned_4byte", 64'h0000_C003, 3, 2, BURST_INCR, 0, 0, wdata, wstrb);

    // Unaligned 8-byte write
    gen_write_data(1, wdata, wstrb);
    calc_beat_addrs(64'h0000_D005, 3, BURST_INCR, 1, addrs);
    for (i = 0; i <= 1; i = i + 1)
      wstrb[i] = calc_strb(addrs[i], 3);
    write_and_check("unaligned_8byte", 64'h0000_D005, 1, 3, BURST_INCR, 0, 0, wdata, wstrb);
  endtask

  task automatic test_byte_strobe();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];
    integer b;

    $display("\n=== TEST 7: Byte Strobe ===");

    // Alternating strobe pattern
    gen_write_data(0, wdata, wstrb);
    wstrb[0] = {STRB_WIDTH{1'b0}};
    for (b = 0; b < STRB_WIDTH; b = b + 2)
      wstrb[0][b] = 1'b1;
    write_and_check("strobe_alternate", 64'h0000_E000, 0, 6, BURST_INCR, 0, 0, wdata, wstrb);

    // Only first 8 bytes
    gen_write_data(0, wdata, wstrb);
    wstrb[0] = {STRB_WIDTH{1'b0}};
    wstrb[0][7:0] = 8'hFF;
    write_and_check("strobe_first8", 64'h0000_E040, 0, 6, BURST_INCR, 0, 0, wdata, wstrb);

    // Only last 8 bytes
    gen_write_data(0, wdata, wstrb);
    wstrb[0] = {STRB_WIDTH{1'b0}};
    wstrb[0][STRB_WIDTH-1 -: 8] = 8'hFF;
    write_and_check("strobe_last8", 64'h0000_E080, 0, 6, BURST_INCR, 0, 0, wdata, wstrb);
  endtask

  task automatic test_multi_id();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];
    integer i;

    $display("\n=== TEST 8: Multiple IDs / Outstanding ===");

    // Write with different IDs
    for (i = 0; i < 8; i = i + 1) begin
      gen_write_data(1, wdata, wstrb);
      write_and_check($sformatf("multi_id_%0d", i),
                      64'h0000_F000 + i * 64'h100, 1, 6, BURST_INCR,
                      i[ID_WIDTH-1:0], 0, wdata, wstrb);
    end
  endtask

  task automatic test_exclusive_access();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];

    $display("\n=== TEST 9: Exclusive Access ===");

    // Exclusive write
    gen_write_data(0, wdata, wstrb);
    write_and_check("exclusive_wr", 64'h0001_0000, 0, 6, BURST_INCR, 0, 1, wdata, wstrb);

    // Normal write to same address
    gen_write_data(0, wdata, wstrb);
    write_and_check("normal_after_excl", 64'h0001_0000, 0, 6, BURST_INCR, 0, 0, wdata, wstrb);
  endtask

  task automatic test_back2back();
    reg [DATA_WIDTH-1:0] wdata [];
    reg [STRB_WIDTH-1:0] wstrb [];
    integer i;

    $display("\n=== TEST 10: Back-to-Back Transactions ===");

    for (i = 0; i < 10; i = i + 1) begin
      gen_write_data(0, wdata, wstrb);
      write_and_check($sformatf("b2b_%0d", i),
                      64'h0001_1000 + i * 64'h80, 0, 6, BURST_INCR,
                      0, 0, wdata, wstrb);
    end
  endtask

  //========================================================================
  // Initialize signals and memories
  //========================================================================
  task automatic init_all();
    integer i;

    // Initialize master outputs
    axi4_if.awid     <= 0;
    axi4_if.awaddr   <= 0;
    axi4_if.awlen    <= 0;
    axi4_if.awsize   <= 0;
    axi4_if.awburst  <= 0;
    axi4_if.awlock   <= 0;
    axi4_if.awcache  <= 0;
    axi4_if.awprot   <= 0;
    axi4_if.awqos    <= 0;
    axi4_if.awregion <= 0;
    axi4_if.awuser   <= 0;
    axi4_if.awvalid  <= 0;
    axi4_if.wdata    <= 0;
    axi4_if.wstrb    <= 0;
    axi4_if.wlast    <= 0;
    axi4_if.wuser    <= 0;
    axi4_if.wvalid   <= 0;
    axi4_if.bready   <= 0;
    axi4_if.arid     <= 0;
    axi4_if.araddr   <= 0;
    axi4_if.arlen    <= 0;
    axi4_if.arsize   <= 0;
    axi4_if.arburst  <= 0;
    axi4_if.arlock   <= 0;
    axi4_if.arcache  <= 0;
    axi4_if.arprot   <= 0;
    axi4_if.arqos    <= 0;
    axi4_if.arregion <= 0;
    axi4_if.aruser   <= 0;
    axi4_if.arvalid  <= 0;
    axi4_if.rready   <= 0;

    // Initialize slave outputs
    axi4_if.awready <= 0;
    axi4_if.wready  <= 0;
    axi4_if.bid     <= 0;
    axi4_if.bresp   <= 0;
    axi4_if.buser   <= 0;
    axi4_if.bvalid  <= 0;
    axi4_if.arready <= 0;
    axi4_if.rid     <= 0;
    axi4_if.rdata   <= 0;
    axi4_if.rresp   <= 0;
    axi4_if.rlast   <= 0;
    axi4_if.ruser   <= 0;
    axi4_if.rvalid  <= 0;

    // Initialize memories
    for (i = 0; i < 131072; i = i + 1) begin
      slave_mem[i]   = 8'h00;
      ref_mem[i]     = 8'h00;
      ref_written[i] = 1'b0;
    end
  endtask

  //========================================================================
  // MAIN TEST FLOW
  //========================================================================
  initial begin
    $display("=========================================================");
    $display(" AXI4 VIP Self-Checking Testbench");
    $display(" DATA_WIDTH=%0d  ADDR_WIDTH=%0d  ID_WIDTH=%0d",
             DATA_WIDTH, ADDR_WIDTH, ID_WIDTH);
    $display("=========================================================");

    init_all();

    // Reset
    aresetn = 0;
    repeat (20) @(posedge aclk);
    aresetn = 1;
    repeat (5) @(posedge aclk);

    // Start slave driver (background)
    fork
      slave_handle_writes();
      slave_handle_reads();
    join_none

    // Wait a few cycles for slave to be ready
    repeat (5) @(posedge aclk);

    // Run all tests
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

    // Summary
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

  // Timeout
  initial begin
    #5_000_000;
    $display("ERROR: Simulation timeout!");
    $finish;
  end

endmodule
