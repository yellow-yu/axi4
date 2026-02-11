//==========================================================================
// AXI4 Test Sequences
//==========================================================================

//--------------------------------------------------------------------------
// Base Sequence
//--------------------------------------------------------------------------
class axi4_base_seq extends uvm_sequence #(axi4_seq_item);
  `uvm_object_utils(axi4_base_seq)

  function new(string name = "axi4_base_seq");
    super.new(name);
  endfunction

  // Helper: perform a write transaction
  task do_write(
    input bit [AXI4_ADDR_WIDTH-1:0] addr,
    input bit [7:0]                  len,
    input bit [2:0]                  size,
    input axi4_burst_type_e          burst,
    input bit [AXI4_ID_WIDTH-1:0]   id = 0,
    input bit                        lock = 0,
    input bit [AXI4_DATA_WIDTH-1:0] wr_data[] = {},
    input bit [AXI4_STRB_WIDTH-1:0] wr_strb[] = {}
  );
    axi4_seq_item item = axi4_seq_item::type_id::create("wr_item");
    start_item(item);
    assert(item.randomize() with {
      txn_type == AXI4_WRITE;
      item.addr  == addr;
      item.len   == len;
      item.size  == size;
      item.burst == burst;
      item.id    == id;
      item.lock  == lock;
    }) else `uvm_error("SEQ", "Write item randomization failed")

    // Override data/strobe if provided
    if (wr_data.size() > 0) item.data = wr_data;
    if (wr_strb.size() > 0) item.wstrb = wr_strb;

    finish_item(item);
  endtask

  // Helper: perform a read transaction
  task do_read(
    input  bit [AXI4_ADDR_WIDTH-1:0] addr,
    input  bit [7:0]                  len,
    input  bit [2:0]                  size,
    input  axi4_burst_type_e          burst,
    input  bit [AXI4_ID_WIDTH-1:0]   id = 0,
    input  bit                        lock = 0
  );
    axi4_seq_item item = axi4_seq_item::type_id::create("rd_item");
    start_item(item);
    assert(item.randomize() with {
      txn_type == AXI4_READ;
      item.addr  == addr;
      item.len   == len;
      item.size  == size;
      item.burst == burst;
      item.id    == id;
      item.lock  == lock;
    }) else `uvm_error("SEQ", "Read item randomization failed")
    finish_item(item);
  endtask
endclass

//--------------------------------------------------------------------------
// 1. Single Write/Read Sequence
//--------------------------------------------------------------------------
class axi4_single_wr_rd_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_single_wr_rd_seq)

  function new(string name = "axi4_single_wr_rd_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SEQ", "=== Single Write/Read Test ===", UVM_LOW)

    // Single beat write at aligned address
    do_write(.addr(64'h0000_1000), .len(0), .size(6), .burst(AXI4_BURST_INCR));
    // Read back
    do_read(.addr(64'h0000_1000), .len(0), .size(6), .burst(AXI4_BURST_INCR));

    // Another single write at different address
    do_write(.addr(64'h0000_2000), .len(0), .size(6), .burst(AXI4_BURST_INCR));
    do_read(.addr(64'h0000_2000), .len(0), .size(6), .burst(AXI4_BURST_INCR));

    `uvm_info("SEQ", "=== Single Write/Read Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 2. INCR Burst Sequence
//--------------------------------------------------------------------------
class axi4_incr_burst_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_incr_burst_seq)

  function new(string name = "axi4_incr_burst_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SEQ", "=== INCR Burst Test ===", UVM_LOW)

    // 4-beat INCR burst (full width)
    do_write(.addr(64'h0000_3000), .len(3), .size(6), .burst(AXI4_BURST_INCR));
    do_read(.addr(64'h0000_3000), .len(3), .size(6), .burst(AXI4_BURST_INCR));

    // 8-beat INCR burst
    do_write(.addr(64'h0000_4000), .len(7), .size(6), .burst(AXI4_BURST_INCR));
    do_read(.addr(64'h0000_4000), .len(7), .size(6), .burst(AXI4_BURST_INCR));

    // 16-beat INCR burst
    do_write(.addr(64'h0000_5000), .len(15), .size(6), .burst(AXI4_BURST_INCR));
    do_read(.addr(64'h0000_5000), .len(15), .size(6), .burst(AXI4_BURST_INCR));

    `uvm_info("SEQ", "=== INCR Burst Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 3. FIXED Burst Sequence
//--------------------------------------------------------------------------
class axi4_fixed_burst_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_fixed_burst_seq)

  function new(string name = "axi4_fixed_burst_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SEQ", "=== FIXED Burst Test ===", UVM_LOW)

    // 4-beat FIXED burst (all writes go to same address)
    do_write(.addr(64'h0000_6000), .len(3), .size(6), .burst(AXI4_BURST_FIXED));
    // Read back: only last write data is in memory for FIXED
    do_read(.addr(64'h0000_6000), .len(0), .size(6), .burst(AXI4_BURST_INCR));

    // 8-beat FIXED burst
    do_write(.addr(64'h0000_7000), .len(7), .size(6), .burst(AXI4_BURST_FIXED));
    do_read(.addr(64'h0000_7000), .len(0), .size(6), .burst(AXI4_BURST_INCR));

    `uvm_info("SEQ", "=== FIXED Burst Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 4. WRAP Burst Sequence
//--------------------------------------------------------------------------
class axi4_wrap_burst_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_wrap_burst_seq)

  function new(string name = "axi4_wrap_burst_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SEQ", "=== WRAP Burst Test ===", UVM_LOW)

    // 4-beat WRAP burst (64 bytes each = 256 byte wrap boundary)
    // Address must be size-aligned
    do_write(.addr(64'h0000_8040), .len(3), .size(6), .burst(AXI4_BURST_WRAP));
    do_read(.addr(64'h0000_8040), .len(3), .size(6), .burst(AXI4_BURST_WRAP));

    // 2-beat WRAP burst
    do_write(.addr(64'h0000_9040), .len(1), .size(6), .burst(AXI4_BURST_WRAP));
    do_read(.addr(64'h0000_9040), .len(1), .size(6), .burst(AXI4_BURST_WRAP));

    // 8-beat WRAP burst with smaller size
    do_write(.addr(64'h0000_A010), .len(7), .size(3), .burst(AXI4_BURST_WRAP));
    do_read(.addr(64'h0000_A010), .len(7), .size(3), .burst(AXI4_BURST_WRAP));

    `uvm_info("SEQ", "=== WRAP Burst Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 5. Narrow Transfer Sequence
//--------------------------------------------------------------------------
class axi4_narrow_transfer_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_narrow_transfer_seq)

  function new(string name = "axi4_narrow_transfer_seq");
    super.new(name);
  endfunction

  task body();
    bit [AXI4_DATA_WIDTH-1:0] wr_data[];
    bit [AXI4_STRB_WIDTH-1:0] wr_strb[];
    bit [AXI4_ADDR_WIDTH-1:0] beat_addrs[];

    `uvm_info("SEQ", "=== Narrow Transfer Test ===", UVM_LOW)

    // 4-byte narrow transfer (size=2), 4 beats
    begin
      bit [2:0] sz = 2;  // 4 bytes per beat
      bit [7:0] ln = 3;  // 4 beats
      bit [63:0] addr = 64'h0000_B000;

      wr_data = new[ln + 1];
      wr_strb = new[ln + 1];
      axi4_calc_beat_addrs(addr, sz, AXI4_BURST_INCR, ln, beat_addrs);

      for (int i = 0; i <= ln; i++) begin
        // Randomize data
        for (int w = 0; w < AXI4_DATA_WIDTH / 32; w++)
          wr_data[i][w*32 +: 32] = $urandom;
        // Set proper strobe for narrow transfer
        wr_strb[i] = axi4_calc_strb(beat_addrs[i], sz);
      end

      do_write(.addr(addr), .len(ln), .size(sz), .burst(AXI4_BURST_INCR),
               .wr_data(wr_data), .wr_strb(wr_strb));
      do_read(.addr(addr), .len(ln), .size(sz), .burst(AXI4_BURST_INCR));
    end

    // 8-byte narrow transfer (size=3), 2 beats
    begin
      bit [2:0] sz = 3;  // 8 bytes per beat
      bit [7:0] ln = 1;  // 2 beats
      bit [63:0] addr = 64'h0000_C000;

      wr_data = new[ln + 1];
      wr_strb = new[ln + 1];
      axi4_calc_beat_addrs(addr, sz, AXI4_BURST_INCR, ln, beat_addrs);

      for (int i = 0; i <= ln; i++) begin
        for (int w = 0; w < AXI4_DATA_WIDTH / 32; w++)
          wr_data[i][w*32 +: 32] = $urandom;
        wr_strb[i] = axi4_calc_strb(beat_addrs[i], sz);
      end

      do_write(.addr(addr), .len(ln), .size(sz), .burst(AXI4_BURST_INCR),
               .wr_data(wr_data), .wr_strb(wr_strb));
      do_read(.addr(addr), .len(ln), .size(sz), .burst(AXI4_BURST_INCR));
    end

    `uvm_info("SEQ", "=== Narrow Transfer Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 6. Unaligned Transfer Sequence
//--------------------------------------------------------------------------
class axi4_unaligned_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_unaligned_seq)

  function new(string name = "axi4_unaligned_seq");
    super.new(name);
  endfunction

  task body();
    bit [AXI4_DATA_WIDTH-1:0] wr_data[];
    bit [AXI4_STRB_WIDTH-1:0] wr_strb[];
    bit [AXI4_ADDR_WIDTH-1:0] beat_addrs[];

    `uvm_info("SEQ", "=== Unaligned Transfer Test ===", UVM_LOW)

    // Unaligned 4-byte write at odd address
    begin
      bit [2:0] sz = 2;  // 4 bytes
      bit [7:0] ln = 3;  // 4 beats
      bit [63:0] addr = 64'h0000_D003;  // Unaligned

      wr_data = new[ln + 1];
      wr_strb = new[ln + 1];
      axi4_calc_beat_addrs(addr, sz, AXI4_BURST_INCR, ln, beat_addrs);

      for (int i = 0; i <= ln; i++) begin
        for (int w = 0; w < AXI4_DATA_WIDTH / 32; w++)
          wr_data[i][w*32 +: 32] = $urandom;
        wr_strb[i] = axi4_calc_strb(beat_addrs[i], sz);
      end

      do_write(.addr(addr), .len(ln), .size(sz), .burst(AXI4_BURST_INCR),
               .wr_data(wr_data), .wr_strb(wr_strb));
      do_read(.addr(addr), .len(ln), .size(sz), .burst(AXI4_BURST_INCR));
    end

    // Unaligned 8-byte write
    begin
      bit [2:0] sz = 3;  // 8 bytes
      bit [7:0] ln = 1;  // 2 beats
      bit [63:0] addr = 64'h0000_E005;  // Unaligned

      wr_data = new[ln + 1];
      wr_strb = new[ln + 1];
      axi4_calc_beat_addrs(addr, sz, AXI4_BURST_INCR, ln, beat_addrs);

      for (int i = 0; i <= ln; i++) begin
        for (int w = 0; w < AXI4_DATA_WIDTH / 32; w++)
          wr_data[i][w*32 +: 32] = $urandom;
        wr_strb[i] = axi4_calc_strb(beat_addrs[i], sz);
      end

      do_write(.addr(addr), .len(ln), .size(sz), .burst(AXI4_BURST_INCR),
               .wr_data(wr_data), .wr_strb(wr_strb));
      do_read(.addr(addr), .len(ln), .size(sz), .burst(AXI4_BURST_INCR));
    end

    `uvm_info("SEQ", "=== Unaligned Transfer Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 7. Byte Strobe Sequence
//--------------------------------------------------------------------------
class axi4_byte_strobe_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_byte_strobe_seq)

  function new(string name = "axi4_byte_strobe_seq");
    super.new(name);
  endfunction

  task body();
    bit [AXI4_DATA_WIDTH-1:0] wr_data[];
    bit [AXI4_STRB_WIDTH-1:0] wr_strb[];

    `uvm_info("SEQ", "=== Byte Strobe Test ===", UVM_LOW)

    // Write with partial strobes (only every other byte)
    begin
      bit [63:0] addr = 64'h0000_F000;
      wr_data = new[1];
      wr_strb = new[1];
      for (int w = 0; w < AXI4_DATA_WIDTH / 32; w++)
        wr_data[0][w*32 +: 32] = $urandom;
      // Set alternating strobe pattern
      wr_strb[0] = '0;
      for (int b = 0; b < AXI4_STRB_WIDTH; b += 2)
        wr_strb[0][b] = 1'b1;

      do_write(.addr(addr), .len(0), .size(6), .burst(AXI4_BURST_INCR),
               .wr_data(wr_data), .wr_strb(wr_strb));
      do_read(.addr(addr), .len(0), .size(6), .burst(AXI4_BURST_INCR));
    end

    // Write with only first 8 bytes strobed
    begin
      bit [63:0] addr = 64'h0000_F040;
      wr_data = new[1];
      wr_strb = new[1];
      for (int w = 0; w < AXI4_DATA_WIDTH / 32; w++)
        wr_data[0][w*32 +: 32] = $urandom;
      wr_strb[0] = '0;
      wr_strb[0][7:0] = 8'hFF;  // Only first 8 bytes

      do_write(.addr(addr), .len(0), .size(6), .burst(AXI4_BURST_INCR),
               .wr_data(wr_data), .wr_strb(wr_strb));
      do_read(.addr(addr), .len(0), .size(6), .burst(AXI4_BURST_INCR));
    end

    `uvm_info("SEQ", "=== Byte Strobe Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 8. Multiple ID / Outstanding Sequence
//--------------------------------------------------------------------------
class axi4_multi_id_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_multi_id_seq)

  function new(string name = "axi4_multi_id_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SEQ", "=== Multi-ID / Outstanding Test ===", UVM_LOW)

    // Write with different IDs to different addresses
    for (int i = 0; i < 8; i++) begin
      do_write(.addr(64'h0001_0000 + i * 64'h100),
               .len(1), .size(6), .burst(AXI4_BURST_INCR),
               .id(i[3:0]));
    end

    // Read back with same IDs
    for (int i = 0; i < 8; i++) begin
      do_read(.addr(64'h0001_0000 + i * 64'h100),
              .len(1), .size(6), .burst(AXI4_BURST_INCR),
              .id(i[3:0]));
    end

    `uvm_info("SEQ", "=== Multi-ID / Outstanding Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 9. Exclusive Access Sequence
//--------------------------------------------------------------------------
class axi4_exclusive_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_exclusive_seq)

  function new(string name = "axi4_exclusive_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SEQ", "=== Exclusive Access Test ===", UVM_LOW)

    // Exclusive write
    do_write(.addr(64'h0001_1000), .len(0), .size(6), .burst(AXI4_BURST_INCR), .lock(1));
    // Exclusive read
    do_read(.addr(64'h0001_1000), .len(0), .size(6), .burst(AXI4_BURST_INCR), .lock(1));

    // Normal write to same address
    do_write(.addr(64'h0001_1000), .len(0), .size(6), .burst(AXI4_BURST_INCR), .lock(0));
    do_read(.addr(64'h0001_1000), .len(0), .size(6), .burst(AXI4_BURST_INCR), .lock(0));

    `uvm_info("SEQ", "=== Exclusive Access Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 10. Back-to-Back Sequence
//--------------------------------------------------------------------------
class axi4_back2back_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_back2back_seq)

  function new(string name = "axi4_back2back_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SEQ", "=== Back-to-Back Test ===", UVM_LOW)

    // Rapid sequence of writes and reads
    for (int i = 0; i < 10; i++) begin
      do_write(.addr(64'h0001_2000 + i * 64'h80),
               .len(0), .size(6), .burst(AXI4_BURST_INCR));
      do_read(.addr(64'h0001_2000 + i * 64'h80),
              .len(0), .size(6), .burst(AXI4_BURST_INCR));
    end

    `uvm_info("SEQ", "=== Back-to-Back Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 11. Random Stress Sequence
//--------------------------------------------------------------------------
class axi4_random_stress_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_random_stress_seq)

  int num_txns = 20;

  function new(string name = "axi4_random_stress_seq");
    super.new(name);
  endfunction

  task body();
    axi4_seq_item item;

    `uvm_info("SEQ", $sformatf("=== Random Stress Test (%0d transactions) ===", num_txns * 2), UVM_LOW)

    // Random writes
    for (int i = 0; i < num_txns; i++) begin
      item = axi4_seq_item::type_id::create($sformatf("rand_wr_%0d", i));
      start_item(item);
      assert(item.randomize() with {
        txn_type == AXI4_WRITE;
        addr < 64'h0002_0000;
        addr >= 64'h0001_8000;
        addr[5:0] == 0;  // Keep aligned for simplicity
        size == 6;
        burst == AXI4_BURST_INCR;
        len inside {[0:7]};
      }) else `uvm_error("SEQ", "Random write randomization failed")
      finish_item(item);
    end

    // Random reads from same address range
    for (int i = 0; i < num_txns; i++) begin
      item = axi4_seq_item::type_id::create($sformatf("rand_rd_%0d", i));
      start_item(item);
      assert(item.randomize() with {
        txn_type == AXI4_READ;
        addr < 64'h0002_0000;
        addr >= 64'h0001_8000;
        addr[5:0] == 0;
        size == 6;
        burst == AXI4_BURST_INCR;
        len inside {[0:7]};
      }) else `uvm_error("SEQ", "Random read randomization failed")
      finish_item(item);
    end

    `uvm_info("SEQ", "=== Random Stress Test Complete ===", UVM_LOW)
  endtask
endclass

//--------------------------------------------------------------------------
// 12. All Features Combined Sequence
//--------------------------------------------------------------------------
class axi4_all_features_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_all_features_seq)

  function new(string name = "axi4_all_features_seq");
    super.new(name);
  endfunction

  task body();
    axi4_single_wr_rd_seq   single_seq;
    axi4_incr_burst_seq     incr_seq;
    axi4_fixed_burst_seq    fixed_seq;
    axi4_wrap_burst_seq     wrap_seq;
    axi4_narrow_transfer_seq narrow_seq;
    axi4_unaligned_seq      unalign_seq;
    axi4_byte_strobe_seq    strobe_seq;
    axi4_multi_id_seq       multi_id_seq;
    axi4_exclusive_seq      excl_seq;
    axi4_back2back_seq      b2b_seq;

    `uvm_info("SEQ", "========================================", UVM_LOW)
    `uvm_info("SEQ", "  ALL FEATURES COMBINED TEST", UVM_LOW)
    `uvm_info("SEQ", "========================================", UVM_LOW)

    single_seq  = axi4_single_wr_rd_seq::type_id::create("single_seq");
    incr_seq    = axi4_incr_burst_seq::type_id::create("incr_seq");
    fixed_seq   = axi4_fixed_burst_seq::type_id::create("fixed_seq");
    wrap_seq    = axi4_wrap_burst_seq::type_id::create("wrap_seq");
    narrow_seq  = axi4_narrow_transfer_seq::type_id::create("narrow_seq");
    unalign_seq = axi4_unaligned_seq::type_id::create("unalign_seq");
    strobe_seq  = axi4_byte_strobe_seq::type_id::create("strobe_seq");
    multi_id_seq = axi4_multi_id_seq::type_id::create("multi_id_seq");
    excl_seq    = axi4_exclusive_seq::type_id::create("excl_seq");
    b2b_seq     = axi4_back2back_seq::type_id::create("b2b_seq");

    single_seq.start(m_sequencer);
    incr_seq.start(m_sequencer);
    fixed_seq.start(m_sequencer);
    wrap_seq.start(m_sequencer);
    narrow_seq.start(m_sequencer);
    unalign_seq.start(m_sequencer);
    strobe_seq.start(m_sequencer);
    multi_id_seq.start(m_sequencer);
    excl_seq.start(m_sequencer);
    b2b_seq.start(m_sequencer);

    `uvm_info("SEQ", "========================================", UVM_LOW)
    `uvm_info("SEQ", "  ALL FEATURES TEST COMPLETE", UVM_LOW)
    `uvm_info("SEQ", "========================================", UVM_LOW)
  endtask
endclass
