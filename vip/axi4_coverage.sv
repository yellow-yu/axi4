//==========================================================================
// AXI4 Coverage Collector
//==========================================================================
class axi4_coverage extends uvm_subscriber #(axi4_seq_item);

  `uvm_component_utils(axi4_coverage)

  // Coverage items
  axi4_seq_item cov_item;

  covergroup axi4_cg;
    // Transaction type
    cp_txn_type: coverpoint cov_item.txn_type {
      bins write = {AXI4_WRITE};
      bins read  = {AXI4_READ};
    }

    // Burst type
    cp_burst: coverpoint cov_item.burst {
      bins fixed = {AXI4_BURST_FIXED};
      bins incr  = {AXI4_BURST_INCR};
      bins wrap  = {AXI4_BURST_WRAP};
    }

    // Burst length
    cp_len: coverpoint cov_item.len {
      bins single    = {0};
      bins short_b   = {[1:3]};
      bins medium_b  = {[4:15]};
      bins long_b    = {[16:63]};
      bins very_long = {[64:255]};
    }

    // Transfer size
    cp_size: coverpoint cov_item.size {
      bins s1    = {0};  // 1 byte
      bins s2    = {1};  // 2 bytes
      bins s4    = {2};  // 4 bytes
      bins s8    = {3};  // 8 bytes
      bins s16   = {4};  // 16 bytes
      bins s32   = {5};  // 32 bytes
      bins s64   = {6};  // 64 bytes (full bus)
    }

    // ID coverage
    cp_id: coverpoint cov_item.id {
      bins id_vals[] = {[0:15]};
    }

    // Lock (exclusive access)
    cp_lock: coverpoint cov_item.lock {
      bins normal    = {0};
      bins exclusive = {1};
    }

    // Address alignment
    cp_addr_align: coverpoint (cov_item.addr % (1 << cov_item.size)) {
      bins aligned   = {0};
      bins unaligned = {[1:63]};
    }

    // Cross coverage
    cx_type_burst: cross cp_txn_type, cp_burst;
    cx_type_size:  cross cp_txn_type, cp_size;
    cx_burst_len:  cross cp_burst, cp_len;
  endgroup

  function new(string name = "axi4_coverage", uvm_component parent = null);
    super.new(name, parent);
    axi4_cg = new();
  endfunction

  function void write(axi4_seq_item t);
    cov_item = t;
    axi4_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("AXI4 Coverage: %.1f%%", axi4_cg.get_coverage()), UVM_LOW)
  endfunction

endclass
