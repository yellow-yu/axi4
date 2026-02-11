//==========================================================================
// axi4_coverage.sv - AXI4 Functional Coverage Collector
//==========================================================================

class axi4_coverage extends uvm_subscriber #(axi4_transaction);

  axi4_transaction tr;

  // Coverage group for write transactions
  covergroup axi4_write_cg;
    option.per_instance = 1;

    cp_burst_type: coverpoint tr.burst {
      bins fixed = {AXI4_FIXED};
      bins incr  = {AXI4_INCR};
      bins wrap  = {AXI4_WRAP};
    }

    cp_burst_len: coverpoint tr.len {
      bins single    = {0};
      bins short_b   = {[1:3]};
      bins medium_b  = {[4:15]};
      bins long_b    = {[16:63]};
      bins max_b     = {[64:255]};
    }

    cp_size: coverpoint tr.size {
      bins byte_1  = {0};
      bins byte_2  = {1};
      bins byte_4  = {2};
    }

    cp_lock: coverpoint tr.lock {
      bins normal    = {0};
      bins exclusive = {1};
    }

    cp_resp: coverpoint tr.bresp {
      bins okay   = {2'b00};
      bins exokay = {2'b01};
      bins slverr = {2'b10};
      bins decerr = {2'b11};
    }

    cp_addr_align: coverpoint (tr.addr % (1 << tr.size)) {
      bins aligned   = {0};
      bins unaligned = {[1:$]};
    }

    cp_qos: coverpoint tr.qos {
      bins low    = {[0:3]};
      bins medium = {[4:11]};
      bins high   = {[12:15]};
    }

    // Cross coverage
    cx_burst_len: cross cp_burst_type, cp_burst_len {
      // FIXED max length is 16
      ignore_bins fixed_long = binsof(cp_burst_type.fixed) && binsof(cp_burst_len.long_b);
      ignore_bins fixed_max  = binsof(cp_burst_type.fixed) && binsof(cp_burst_len.max_b);
      // WRAP lengths are 2,4,8,16
      ignore_bins wrap_med   = binsof(cp_burst_type.wrap) && binsof(cp_burst_len.medium_b);
      ignore_bins wrap_long  = binsof(cp_burst_type.wrap) && binsof(cp_burst_len.long_b);
      ignore_bins wrap_max   = binsof(cp_burst_type.wrap) && binsof(cp_burst_len.max_b);
    }

    cx_burst_size: cross cp_burst_type, cp_size;
  endgroup

  // Coverage group for read transactions
  covergroup axi4_read_cg;
    option.per_instance = 1;

    cp_burst_type: coverpoint tr.burst {
      bins fixed = {AXI4_FIXED};
      bins incr  = {AXI4_INCR};
      bins wrap  = {AXI4_WRAP};
    }

    cp_burst_len: coverpoint tr.len {
      bins single    = {0};
      bins short_b   = {[1:3]};
      bins medium_b  = {[4:15]};
      bins long_b    = {[16:63]};
      bins max_b     = {[64:255]};
    }

    cp_size: coverpoint tr.size {
      bins byte_1  = {0};
      bins byte_2  = {1};
      bins byte_4  = {2};
    }

    cp_lock: coverpoint tr.lock {
      bins normal    = {0};
      bins exclusive = {1};
    }

    cx_burst_len: cross cp_burst_type, cp_burst_len {
      ignore_bins fixed_long = binsof(cp_burst_type.fixed) && binsof(cp_burst_len.long_b);
      ignore_bins fixed_max  = binsof(cp_burst_type.fixed) && binsof(cp_burst_len.max_b);
      ignore_bins wrap_med   = binsof(cp_burst_type.wrap) && binsof(cp_burst_len.medium_b);
      ignore_bins wrap_long  = binsof(cp_burst_type.wrap) && binsof(cp_burst_len.long_b);
      ignore_bins wrap_max   = binsof(cp_burst_type.wrap) && binsof(cp_burst_len.max_b);
    }
  endgroup

  `uvm_component_utils(axi4_coverage)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    axi4_write_cg = new();
    axi4_read_cg  = new();
  endfunction

  function void write(axi4_transaction t);
    tr = t;
    if (t.txn_type == AXI4_WRITE)
      axi4_write_cg.sample();
    else
      axi4_read_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Write coverage: %.1f%%", axi4_write_cg.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Read coverage:  %.1f%%", axi4_read_cg.get_coverage()), UVM_LOW)
  endfunction

endclass
