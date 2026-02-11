//==========================================================================
// AXI4 Sequence Item - Transaction class for AXI4 protocol
//==========================================================================
class axi4_seq_item extends uvm_sequence_item;

  //------------------------------------------------------------------------
  // Transaction type
  //------------------------------------------------------------------------
  rand axi4_txn_type_e txn_type;

  //------------------------------------------------------------------------
  // Address channel fields
  //------------------------------------------------------------------------
  rand bit [AXI4_ID_WIDTH-1:0]    id;
  rand bit [AXI4_ADDR_WIDTH-1:0]  addr;
  rand bit [7:0]                   len;     // burst length = len + 1
  rand bit [2:0]                   size;    // bytes per beat = 2^size
  rand axi4_burst_type_e           burst;
  rand bit                         lock;
  rand bit [3:0]                   cache;
  rand bit [2:0]                   prot;
  rand bit [3:0]                   qos;
  rand bit [3:0]                   region;
  rand bit [AXI4_USER_WIDTH-1:0]  user;

  //------------------------------------------------------------------------
  // Write data (per beat) - set in post_randomize or by sequences
  //------------------------------------------------------------------------
  bit [AXI4_DATA_WIDTH-1:0]  data[];
  bit [AXI4_STRB_WIDTH-1:0]  wstrb[];

  //------------------------------------------------------------------------
  // Response fields (filled after transaction completes)
  //------------------------------------------------------------------------
  bit [1:0]                   resp;      // Write response
  bit [AXI4_DATA_WIDTH-1:0]  rdata[];   // Read data per beat
  bit [1:0]                   rresp[];   // Read response per beat

  //------------------------------------------------------------------------
  // UVM automation
  //------------------------------------------------------------------------
  `uvm_object_utils_begin(axi4_seq_item)
    `uvm_field_enum(axi4_txn_type_e, txn_type, UVM_ALL_ON)
    `uvm_field_int(id,     UVM_ALL_ON)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(len,    UVM_ALL_ON)
    `uvm_field_int(size,   UVM_ALL_ON)
    `uvm_field_enum(axi4_burst_type_e, burst, UVM_ALL_ON)
    `uvm_field_int(lock,   UVM_ALL_ON)
    `uvm_field_int(cache,  UVM_ALL_ON)
    `uvm_field_int(prot,   UVM_ALL_ON)
    `uvm_field_int(qos,    UVM_ALL_ON)
    `uvm_field_int(region, UVM_ALL_ON)
  `uvm_object_utils_end

  //------------------------------------------------------------------------
  // Constraints
  //------------------------------------------------------------------------

  // Size must not exceed data bus width
  constraint c_valid_size {
    size <= $clog2(AXI4_DATA_WIDTH / 8);  // <= 6 for 512-bit bus
  }

  // Burst type validity
  constraint c_burst_type {
    burst inside {AXI4_BURST_FIXED, AXI4_BURST_INCR, AXI4_BURST_WRAP};
  }

  // FIXED burst max 16 beats; WRAP burst lengths: 2, 4, 8, 16
  constraint c_burst_len_fixed {
    (burst == AXI4_BURST_FIXED) -> (len inside {[0:15]});
  }

  constraint c_burst_len_wrap {
    (burst == AXI4_BURST_WRAP) -> (len inside {1, 3, 7, 15});
  }

  // WRAP burst start address must be aligned to size boundary
  constraint c_wrap_aligned {
    (burst == AXI4_BURST_WRAP) -> ((addr % (1 << size)) == 0);
  }

  // Keep address in a reasonable test range
  constraint c_addr_range {
    addr < 64'h0001_0000;
  }

  // Default soft constraints
  constraint c_defaults {
    soft lock   == 0;
    soft cache  == 0;
    soft prot   == 0;
    soft qos    == 0;
    soft region == 0;
    soft user   == 0;
    soft size   == $clog2(AXI4_DATA_WIDTH / 8);  // full bus width
    soft burst  == AXI4_BURST_INCR;
    soft len    inside {[0:15]};
  }

  //------------------------------------------------------------------------
  // Constructor
  //------------------------------------------------------------------------
  function new(string name = "axi4_seq_item");
    super.new(name);
  endfunction

  //------------------------------------------------------------------------
  // Post-randomize: allocate and fill data/wstrb arrays
  //------------------------------------------------------------------------
  function void post_randomize();
    if (txn_type == AXI4_WRITE) begin
      data  = new[len + 1];
      wstrb = new[len + 1];
      for (int i = 0; i <= len; i++) begin
        for (int w = 0; w < AXI4_DATA_WIDTH / 32; w++)
          data[i][w*32 +: 32] = $urandom;
        wstrb[i] = {AXI4_STRB_WIDTH{1'b1}};  // Default: all bytes active
      end
    end else begin
      data  = new[0];
      wstrb = new[0];
    end
  endfunction

  //------------------------------------------------------------------------
  // Convert to string for display
  //------------------------------------------------------------------------
  function string convert2string();
    string s;
    s = $sformatf("%s id=%0d addr=0x%0h len=%0d size=%0d burst=%s",
                  txn_type.name(), id, addr, len, size, burst.name());
    if (txn_type == AXI4_WRITE)
      s = {s, $sformatf(" [WRITE %0d beats]", len + 1)};
    else
      s = {s, $sformatf(" [READ %0d beats]", len + 1)};
    return s;
  endfunction

endclass
