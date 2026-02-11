//==========================================================================
// axi4_master_seq_lib.sv - AXI4 Master Sequence Library
//==========================================================================

// ============================================================
// Base sequence
// ============================================================
class axi4_base_sequence extends uvm_sequence #(axi4_transaction);

  `uvm_object_utils(axi4_base_sequence)

  function new(string name = "axi4_base_sequence");
    super.new(name);
  endfunction

  // Helper: Create and send a write transaction
  task do_write(
    bit [`AXI4_ADDR_WIDTH-1:0] addr,
    bit [7:0]                   len    = 0,
    bit [2:0]                   size   = $clog2(`AXI4_DATA_WIDTH/8),
    axi4_burst_type_e          burst  = AXI4_INCR,
    bit [`AXI4_DATA_WIDTH-1:0] wdata[] = '{},
    bit [`AXI4_STRB_WIDTH-1:0] wstrb[] = '{},
    bit [`AXI4_ID_WIDTH-1:0]   id     = 0,
    bit                         lock   = 0,
    bit [3:0]                   qos    = 0,
    bit [3:0]                   region = 0,
    bit [3:0]                   cache  = 0,
    bit [2:0]                   prot   = 0
  );
    axi4_transaction tr;
    tr = axi4_transaction::type_id::create("wr_tr");
    
    start_item(tr);
    
    tr.txn_type = AXI4_WRITE;
    tr.id       = id;
    tr.addr     = addr;
    tr.len      = len;
    tr.size     = size;
    tr.burst    = burst;
    tr.lock     = lock;
    tr.cache    = cache;
    tr.prot     = prot;
    tr.qos      = qos;
    tr.region   = region;
    tr.user     = 0;
    tr.addr_delay = 0;
    tr.data_delay = 0;

    // Set data
    tr.data = new[len + 1];
    tr.strb = new[len + 1];

    for (int i = 0; i <= len; i++) begin
      if (i < wdata.size())
        tr.data[i] = wdata[i];
      else
        tr.data[i] = $urandom;
      
      if (i < wstrb.size())
        tr.strb[i] = wstrb[i];
      else
        tr.strb[i] = {`AXI4_STRB_WIDTH{1'b1}};
    end

    finish_item(tr);
  endtask

  // Helper: Create and send a read transaction, return read data
  task do_read(
    bit [`AXI4_ADDR_WIDTH-1:0] addr,
    bit [7:0]                   len    = 0,
    bit [2:0]                   size   = $clog2(`AXI4_DATA_WIDTH/8),
    axi4_burst_type_e          burst  = AXI4_INCR,
    bit [`AXI4_ID_WIDTH-1:0]   id     = 0,
    bit                         lock   = 0,
    bit [3:0]                   qos    = 0,
    bit [3:0]                   region = 0,
    bit [3:0]                   cache  = 0,
    bit [2:0]                   prot   = 0,
    output bit [`AXI4_DATA_WIDTH-1:0] rdata[],
    output bit [1:0] rresp[]
  );
    axi4_transaction tr;
    tr = axi4_transaction::type_id::create("rd_tr");

    start_item(tr);

    tr.txn_type = AXI4_READ;
    tr.id       = id;
    tr.addr     = addr;
    tr.len      = len;
    tr.size     = size;
    tr.burst    = burst;
    tr.lock     = lock;
    tr.cache    = cache;
    tr.prot     = prot;
    tr.qos      = qos;
    tr.region   = region;
    tr.user     = 0;
    tr.addr_delay = 0;
    tr.data_delay = 0;
    tr.data     = new[len+1]; // dummy for constraint
    tr.strb     = new[len+1];

    finish_item(tr);

    // Return read data
    rdata = tr.rdata;
    rresp = tr.rresp;
  endtask

endclass

// ============================================================
// Single write-read sequence
// ============================================================
class axi4_single_write_read_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_single_write_read_seq)

  function new(string name = "axi4_single_write_read_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];

    wdata = new[1];
    wdata[0] = 32'hDEAD_BEEF;

    `uvm_info(get_type_name(), "Starting single write-read test", UVM_LOW)

    // Write
    do_write(.addr(32'h0000_0100), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)), 
             .burst(AXI4_INCR), .wdata(wdata));

    // Read back
    do_read(.addr(32'h0000_0100), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
            .burst(AXI4_INCR), .rdata(rdata), .rresp(rresp));

    `uvm_info(get_type_name(), $sformatf("Write data: 0x%0h, Read data: 0x%0h", wdata[0], rdata[0]), UVM_LOW)
  endtask

endclass

// ============================================================
// INCR burst sequence
// ============================================================
class axi4_incr_burst_seq extends axi4_base_sequence;

  rand int unsigned burst_len;
  
  constraint c_len { burst_len inside {[1:16]}; }

  `uvm_object_utils(axi4_incr_burst_seq)

  function new(string name = "axi4_incr_burst_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];
    int len = burst_len - 1;

    wdata = new[burst_len];
    for (int i = 0; i < burst_len; i++)
      wdata[i] = (i + 1) * 32'h1111_1111;

    `uvm_info(get_type_name(), $sformatf("INCR burst: len=%0d", burst_len), UVM_LOW)

    do_write(.addr(32'h0000_0200), .len(len), .size($clog2(`AXI4_DATA_WIDTH/8)),
             .burst(AXI4_INCR), .wdata(wdata));

    do_read(.addr(32'h0000_0200), .len(len), .size($clog2(`AXI4_DATA_WIDTH/8)),
            .burst(AXI4_INCR), .rdata(rdata), .rresp(rresp));
  endtask

endclass

// ============================================================
// WRAP burst sequence
// ============================================================
class axi4_wrap_burst_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_wrap_burst_seq)

  function new(string name = "axi4_wrap_burst_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];
    int bus_bytes = `AXI4_DATA_WIDTH / 8;

    // WRAP-4 burst (len=3)
    wdata = new[4];
    for (int i = 0; i < 4; i++)
      wdata[i] = (i + 1) * 32'hAAAA_AAAA;

    `uvm_info(get_type_name(), "WRAP burst: len=4", UVM_LOW)

    // Address must be aligned to size for WRAP
    do_write(.addr(32'h0000_0300), .len(3), .size($clog2(`AXI4_DATA_WIDTH/8)),
             .burst(AXI4_WRAP), .wdata(wdata));

    do_read(.addr(32'h0000_0300), .len(3), .size($clog2(`AXI4_DATA_WIDTH/8)),
            .burst(AXI4_WRAP), .rdata(rdata), .rresp(rresp));
  endtask

endclass

// ============================================================
// FIXED burst sequence
// ============================================================
class axi4_fixed_burst_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_fixed_burst_seq)

  function new(string name = "axi4_fixed_burst_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];

    // FIXED burst with 4 beats - all write to same address
    wdata = new[4];
    for (int i = 0; i < 4; i++)
      wdata[i] = 32'hF0F0_0000 + i;

    `uvm_info(get_type_name(), "FIXED burst: len=4", UVM_LOW)

    do_write(.addr(32'h0000_0400), .len(3), .size($clog2(`AXI4_DATA_WIDTH/8)),
             .burst(AXI4_FIXED), .wdata(wdata));

    // Read back - last written value should be at the address
    do_read(.addr(32'h0000_0400), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
            .burst(AXI4_FIXED), .rdata(rdata), .rresp(rresp));
  endtask

endclass

// ============================================================
// Narrow transfer sequence
// ============================================================
class axi4_narrow_transfer_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_narrow_transfer_seq)

  function new(string name = "axi4_narrow_transfer_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_STRB_WIDTH-1:0] wstrb[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];

    `uvm_info(get_type_name(), "Narrow transfer: size=0 (1 byte)", UVM_LOW)

    // Write 4 individual bytes using size=0 (1 byte per beat)
    wdata = new[4];
    wstrb = new[4];
    
    for (int i = 0; i < 4; i++) begin
      wdata[i] = '0;
      wstrb[i] = '0;
      // Place byte at correct lane based on address
      wdata[i][((i % (`AXI4_DATA_WIDTH/8)) * 8) +: 8] = 8'hA0 + i;
      wstrb[i][i % (`AXI4_DATA_WIDTH/8)] = 1'b1;
    end

    do_write(.addr(32'h0000_0500), .len(3), .size(0),
             .burst(AXI4_INCR), .wdata(wdata), .wstrb(wstrb));

    // Read back as full-width read
    do_read(.addr(32'h0000_0500), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
            .burst(AXI4_INCR), .rdata(rdata), .rresp(rresp));

    `uvm_info(get_type_name(), $sformatf("Narrow write then full read: 0x%0h", rdata[0]), UVM_LOW)
  endtask

endclass

// ============================================================
// Unaligned transfer sequence
// ============================================================
class axi4_unaligned_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_unaligned_seq)

  function new(string name = "axi4_unaligned_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_STRB_WIDTH-1:0] wstrb[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];
    int bus_bytes = `AXI4_DATA_WIDTH / 8;

    `uvm_info(get_type_name(), "Unaligned transfer test", UVM_LOW)

    // Write at unaligned address with size=1 (2 bytes)
    // Address 0x601 is unaligned for 2-byte transfers
    wdata = new[2];
    wstrb = new[2];

    // First beat: addr=0x601, aligned=0x600, lane 1
    wdata[0] = '0;
    wstrb[0] = '0;
    wdata[0][8 +: 8] = 8'hBB; // byte at lane 1
    wstrb[0][1] = 1'b1;

    // Second beat: addr=0x602, lanes 2-3
    wdata[1] = '0;
    wstrb[1] = '0;
    wdata[1][16 +: 8] = 8'hCC; // byte at lane 2
    wdata[1][24 +: 8] = 8'hDD; // byte at lane 3
    wstrb[1][2] = 1'b1;
    wstrb[1][3] = 1'b1;

    do_write(.addr(32'h0000_0601), .len(1), .size(1),
             .burst(AXI4_INCR), .wdata(wdata), .wstrb(wstrb));

    // Read back the full word
    do_read(.addr(32'h0000_0600), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
            .burst(AXI4_INCR), .rdata(rdata), .rresp(rresp));

    `uvm_info(get_type_name(), $sformatf("Unaligned read result: 0x%0h", rdata[0]), UVM_LOW)
  endtask

endclass

// ============================================================
// Byte strobe sequence
// ============================================================
class axi4_strobe_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_strobe_seq)

  function new(string name = "axi4_strobe_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_STRB_WIDTH-1:0] wstrb[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];

    `uvm_info(get_type_name(), "Byte strobe test", UVM_LOW)

    // First write: all bytes
    wdata = new[1];
    wstrb = new[1];
    wdata[0] = 32'hFFFF_FFFF;
    wstrb[0] = {`AXI4_STRB_WIDTH{1'b1}};

    do_write(.addr(32'h0000_0700), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
             .burst(AXI4_INCR), .wdata(wdata), .wstrb(wstrb));

    // Second write: only byte 1 and 3
    wdata[0] = 32'h00AA_00BB;
    wstrb[0] = '0;
    wstrb[0][1] = 1'b1;
    wstrb[0][3] = 1'b1;

    do_write(.addr(32'h0000_0700), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
             .burst(AXI4_INCR), .wdata(wdata), .wstrb(wstrb));

    // Read back - should be FF_AA_FF_BB (bytes 0,2 unchanged, 1,3 updated)
    do_read(.addr(32'h0000_0700), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
            .burst(AXI4_INCR), .rdata(rdata), .rresp(rresp));

    `uvm_info(get_type_name(), $sformatf("Strobe test result: 0x%0h (expect bytes: FF,BB,FF,AA)", rdata[0]), UVM_LOW)
  endtask

endclass

// ============================================================
// Exclusive access sequence
// ============================================================
class axi4_exclusive_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_exclusive_seq)

  function new(string name = "axi4_exclusive_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];

    `uvm_info(get_type_name(), "Exclusive access test", UVM_LOW)

    // First: normal write to initialize
    wdata = new[1];
    wdata[0] = 32'h1234_5678;
    do_write(.addr(32'h0000_0800), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
             .burst(AXI4_INCR), .wdata(wdata), .id(1));

    // Exclusive read
    do_read(.addr(32'h0000_0800), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
            .burst(AXI4_INCR), .lock(1), .id(1), .rdata(rdata), .rresp(rresp));

    `uvm_info(get_type_name(), $sformatf("Exclusive read: data=0x%0h, resp=%0b", 
              rdata[0], rresp[0]), UVM_LOW)

    // Exclusive write (should succeed with EXOKAY)
    wdata[0] = 32'hAAAA_BBBB;
    do_write(.addr(32'h0000_0800), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
             .burst(AXI4_INCR), .wdata(wdata), .lock(1), .id(1));

    // Verify
    do_read(.addr(32'h0000_0800), .len(0), .size($clog2(`AXI4_DATA_WIDTH/8)),
            .burst(AXI4_INCR), .rdata(rdata), .rresp(rresp));

    `uvm_info(get_type_name(), $sformatf("After exclusive write: data=0x%0h", rdata[0]), UVM_LOW)
  endtask

endclass

// ============================================================
// Back-to-back sequence (multiple rapid transactions)
// ============================================================
class axi4_back2back_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_back2back_seq)

  function new(string name = "axi4_back2back_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];
    int bus_bytes = `AXI4_DATA_WIDTH / 8;

    `uvm_info(get_type_name(), "Back-to-back transactions test", UVM_LOW)

    // Multiple writes followed by multiple reads
    for (int i = 0; i < 8; i++) begin
      wdata = new[1];
      wdata[0] = 32'hB000_0000 + i;
      do_write(.addr(32'h0000_0900 + i * bus_bytes), .len(0), 
               .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR), .wdata(wdata));
    end

    for (int i = 0; i < 8; i++) begin
      do_read(.addr(32'h0000_0900 + i * bus_bytes), .len(0),
              .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR), 
              .rdata(rdata), .rresp(rresp));
    end
  endtask

endclass

// ============================================================
// QoS and Region sequence
// ============================================================
class axi4_qos_region_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_qos_region_seq)

  function new(string name = "axi4_qos_region_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];
    int bus_bytes = `AXI4_DATA_WIDTH / 8;

    `uvm_info(get_type_name(), "QoS and Region test", UVM_LOW)

    // Write with different QoS levels
    for (int q = 0; q < 4; q++) begin
      wdata = new[1];
      wdata[0] = 32'hQ000_0000 + q;
      do_write(.addr(32'h0000_0A00 + q * bus_bytes), .len(0),
               .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR), 
               .wdata(wdata), .qos(q * 4), .region(q));
    end

    // Read back
    for (int q = 0; q < 4; q++) begin
      do_read(.addr(32'h0000_0A00 + q * bus_bytes), .len(0),
              .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
              .rdata(rdata), .rresp(rresp), .qos(q * 4), .region(q));
    end
  endtask

endclass

// ============================================================
// Multi-ID outstanding sequence
// ============================================================
class axi4_outstanding_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_outstanding_seq)

  function new(string name = "axi4_outstanding_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];
    int bus_bytes = `AXI4_DATA_WIDTH / 8;

    `uvm_info(get_type_name(), "Outstanding transactions test (sequential with different IDs)", UVM_LOW)

    // Write with different IDs
    for (int id_val = 0; id_val < 4; id_val++) begin
      wdata = new[1];
      wdata[0] = 32'hID00_0000 + id_val * 32'h100;
      do_write(.addr(32'h0000_0B00 + id_val * bus_bytes), .len(0),
               .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
               .wdata(wdata), .id(id_val));
    end

    // Burst writes with different IDs
    for (int id_val = 0; id_val < 4; id_val++) begin
      wdata = new[4];
      for (int i = 0; i < 4; i++)
        wdata[i] = 32'hDD00_0000 + id_val * 32'h1000 + i;
      do_write(.addr(32'h0000_1000 + id_val * 4 * bus_bytes), .len(3),
               .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
               .wdata(wdata), .id(id_val));
    end

    // Read back all
    for (int id_val = 0; id_val < 4; id_val++) begin
      do_read(.addr(32'h0000_0B00 + id_val * bus_bytes), .len(0),
              .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
              .rdata(rdata), .rresp(rresp), .id(id_val));
    end

    for (int id_val = 0; id_val < 4; id_val++) begin
      do_read(.addr(32'h0000_1000 + id_val * 4 * bus_bytes), .len(3),
              .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
              .rdata(rdata), .rresp(rresp), .id(id_val));
    end
  endtask

endclass

// ============================================================
// Random stress sequence
// ============================================================
class axi4_random_stress_seq extends axi4_base_sequence;

  rand int unsigned num_transactions;

  constraint c_num { num_transactions inside {[20:50]}; }

  `uvm_object_utils(axi4_random_stress_seq)

  function new(string name = "axi4_random_stress_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];
    int bus_bytes = `AXI4_DATA_WIDTH / 8;

    `uvm_info(get_type_name(), $sformatf("Random stress: %0d transactions", num_transactions), UVM_LOW)

    for (int t = 0; t < num_transactions; t++) begin
      axi4_transaction tr;
      tr = axi4_transaction::type_id::create($sformatf("rand_tr_%0d", t));

      start_item(tr);
      if (!tr.randomize() with {
        addr < 32'h0000_2000;
        addr >= 32'h0000_1800;
        len <= 7;
        size <= $clog2(`AXI4_DATA_WIDTH/8);
        burst inside {AXI4_INCR, AXI4_FIXED};
        lock == 0;
        addr_delay inside {[0:1]};
        data_delay == 0;
      }) begin
        `uvm_error(get_type_name(), "Randomization failed!")
      end
      finish_item(tr);
    end

    // Read back some addresses to verify
    for (int i = 0; i < 4; i++) begin
      do_read(.addr(32'h0000_1800 + i * bus_bytes), .len(0),
              .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
              .rdata(rdata), .rresp(rresp));
    end
  endtask

endclass

// ============================================================
// Long burst sequence (test max burst length)
// ============================================================
class axi4_long_burst_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_long_burst_seq)

  function new(string name = "axi4_long_burst_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];
    int burst_len = 64; // 64 beats

    `uvm_info(get_type_name(), $sformatf("Long INCR burst: %0d beats", burst_len), UVM_LOW)

    wdata = new[burst_len];
    for (int i = 0; i < burst_len; i++)
      wdata[i] = i;

    do_write(.addr(32'h0000_2000), .len(burst_len - 1), 
             .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR), .wdata(wdata));

    do_read(.addr(32'h0000_2000), .len(burst_len - 1),
            .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
            .rdata(rdata), .rresp(rresp));
  endtask

endclass

// ============================================================
// Cache/Prot attributes sequence
// ============================================================
class axi4_cache_prot_seq extends axi4_base_sequence;

  `uvm_object_utils(axi4_cache_prot_seq)

  function new(string name = "axi4_cache_prot_seq");
    super.new(name);
  endfunction

  task body();
    bit [`AXI4_DATA_WIDTH-1:0] wdata[];
    bit [`AXI4_DATA_WIDTH-1:0] rdata[];
    bit [1:0] rresp[];
    int bus_bytes = `AXI4_DATA_WIDTH / 8;

    `uvm_info(get_type_name(), "Cache and Protection attributes test", UVM_LOW)

    wdata = new[1];

    // Test various cache attributes
    for (int c = 0; c < 16; c++) begin
      wdata[0] = 32'hCAC0_0000 + c;
      do_write(.addr(32'h0000_3000 + c * bus_bytes), .len(0),
               .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
               .wdata(wdata), .cache(c));
    end

    // Test various prot attributes
    for (int p = 0; p < 8; p++) begin
      wdata[0] = 32'hPR0T_0000 + p;
      do_write(.addr(32'h0000_3100 + p * bus_bytes), .len(0),
               .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
               .wdata(wdata), .prot(p));
    end

    // Read back
    for (int c = 0; c < 16; c++) begin
      do_read(.addr(32'h0000_3000 + c * bus_bytes), .len(0),
              .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
              .rdata(rdata), .rresp(rresp), .cache(c));
    end

    for (int p = 0; p < 8; p++) begin
      do_read(.addr(32'h0000_3100 + p * bus_bytes), .len(0),
              .size($clog2(`AXI4_DATA_WIDTH/8)), .burst(AXI4_INCR),
              .rdata(rdata), .rresp(rresp), .prot(p));
    end
  endtask

endclass
