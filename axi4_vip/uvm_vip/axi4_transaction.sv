//==========================================================================
// axi4_transaction.sv - AXI4 Transaction Item
//==========================================================================

class axi4_transaction extends uvm_sequence_item;

  // ---- Transaction type ----
  rand axi4_txn_type_e txn_type;

  // ---- Address channel fields ----
  rand bit [`AXI4_ID_WIDTH-1:0]    id;
  rand bit [`AXI4_ADDR_WIDTH-1:0]  addr;
  rand bit [7:0]                    len;     // burst length - 1
  rand bit [2:0]                    size;    // 2^size bytes per beat
  rand axi4_burst_type_e           burst;
  rand bit                          lock;    // 0=normal, 1=exclusive
  rand bit [3:0]                    cache;
  rand bit [2:0]                    prot;
  rand bit [3:0]                    qos;
  rand bit [3:0]                    region;
  rand bit [`AXI4_USER_WIDTH-1:0]  user;

  // ---- Write data (one entry per beat) ----
  rand bit [`AXI4_DATA_WIDTH-1:0]  data[];
  rand bit [`AXI4_STRB_WIDTH-1:0]  strb[];

  // ---- Response data (filled by driver/monitor) ----
  bit [`AXI4_DATA_WIDTH-1:0]       rdata[];
  bit [1:0]                         rresp[];
  bit [1:0]                         bresp;

  // ---- Delay controls ----
  rand int unsigned addr_delay;   // cycles before address valid
  rand int unsigned data_delay;   // cycles between data beats

  // ============================================================
  // Constraints
  // ============================================================
  
  // Size cannot exceed bus width
  constraint c_valid_size {
    size <= $clog2(`AXI4_DATA_WIDTH / 8);
  }

  // Burst type
  constraint c_burst_type {
    burst inside {AXI4_FIXED, AXI4_INCR, AXI4_WRAP};
  }

  // WRAP burst: length must be 2, 4, 8, or 16
  constraint c_wrap_len {
    (burst == AXI4_WRAP) -> len inside {1, 3, 7, 15};
  }

  // FIXED burst: max length is 16
  constraint c_fixed_len {
    (burst == AXI4_FIXED) -> len <= 15;
  }

  // Data and strb arrays must match burst length
  constraint c_data_size {
    data.size() == len + 1;
    strb.size() == len + 1;
  }

  // WRAP burst: start address must be aligned to transfer size
  constraint c_wrap_addr_align {
    (burst == AXI4_WRAP) -> (addr % (1 << size)) == 0;
  }

  // INCR burst must not cross 4KB boundary
  constraint c_4k_boundary {
    (burst == AXI4_INCR) -> 
      ((addr & 32'hFFFFF000) == (((addr & 32'hFFFFF000) + ((len + 1) << size) - 1) & 32'hFFFFF000));
  }

  // Reasonable address range
  constraint c_addr_range {
    addr < `AXI4_MEM_SIZE;
    addr + ((len + 1) << size) <= `AXI4_MEM_SIZE;
  }

  // Delay constraints
  constraint c_delay {
    addr_delay inside {[0:3]};
    data_delay inside {[0:2]};
  }

  // Default strb is all ones
  constraint c_default_strb {
    foreach (strb[i]) strb[i] == {`AXI4_STRB_WIDTH{1'b1}};
  }

  // ============================================================
  // UVM Automation
  // ============================================================
  `uvm_object_utils_begin(axi4_transaction)
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
    `uvm_field_int(user,   UVM_ALL_ON)
    `uvm_field_array_int(data, UVM_ALL_ON)
    `uvm_field_array_int(strb, UVM_ALL_ON)
    `uvm_field_array_int(rdata, UVM_ALL_ON)
    `uvm_field_array_int(rresp, UVM_ALL_ON)
    `uvm_field_int(bresp,  UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "axi4_transaction");
    super.new(name);
  endfunction

  // ============================================================
  // Helper: Calculate beat address
  // ============================================================
  function bit [`AXI4_ADDR_WIDTH-1:0] get_beat_addr(int beat);
    int unsigned num_bytes  = 1 << size;
    int unsigned burst_len  = len + 1;
    bit [`AXI4_ADDR_WIDTH-1:0] aligned_addr = (addr / num_bytes) * num_bytes;
    bit [`AXI4_ADDR_WIDTH-1:0] beat_addr;

    case (burst)
      AXI4_FIXED: begin
        beat_addr = addr;
      end
      AXI4_INCR: begin
        if (beat == 0)
          beat_addr = addr;
        else
          beat_addr = aligned_addr + beat * num_bytes;
      end
      AXI4_WRAP: begin
        if (beat == 0)
          beat_addr = addr;
        else
          beat_addr = aligned_addr + beat * num_bytes;
        // Apply wrap
        begin
          int unsigned container = num_bytes * burst_len;
          bit [`AXI4_ADDR_WIDTH-1:0] lower = (addr / container) * container;
          bit [`AXI4_ADDR_WIDTH-1:0] upper = lower + container;
          if (beat_addr >= upper)
            beat_addr = lower + (beat_addr - lower) % container;
        end
      end
      default: beat_addr = addr;
    endcase

    return beat_addr;
  endfunction

  // ============================================================
  // Helper: Get byte lane range for a beat
  // Returns {upper_lane, lower_lane}
  // ============================================================
  function void get_byte_lanes(int beat, output int lower_lane, output int upper_lane);
    int unsigned num_bytes  = 1 << size;
    int unsigned bus_bytes  = `AXI4_DATA_WIDTH / 8;
    bit [`AXI4_ADDR_WIDTH-1:0] beat_addr = get_beat_addr(beat);

    if (beat == 0 && burst != AXI4_FIXED) begin
      // First beat - potentially unaligned
      lower_lane = beat_addr % bus_bytes;
      upper_lane = ((beat_addr / num_bytes) * num_bytes) % bus_bytes + num_bytes - 1;
    end else begin
      lower_lane = beat_addr % bus_bytes;
      upper_lane = lower_lane + num_bytes - 1;
    end
  endfunction

  // ============================================================
  // Helper: Generate WSTRB for a beat based on address and size
  // ============================================================
  function bit [`AXI4_STRB_WIDTH-1:0] calc_strb(int beat);
    int lower_lane, upper_lane;
    bit [`AXI4_STRB_WIDTH-1:0] s = 0;
    get_byte_lanes(beat, lower_lane, upper_lane);
    for (int i = lower_lane; i <= upper_lane; i++)
      s[i] = 1'b1;
    return s;
  endfunction

endclass
