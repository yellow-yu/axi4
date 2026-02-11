//==========================================================================
// AXI4 Scoreboard - Verifies read data matches written data
//==========================================================================
class axi4_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(axi4_scoreboard)

  // Analysis imports for write and read transactions
  uvm_analysis_imp_write #(axi4_seq_item, axi4_scoreboard) write_imp;
  uvm_analysis_imp_read  #(axi4_seq_item, axi4_scoreboard) read_imp;

  // Reference memory model (byte-addressable)
  bit [7:0] ref_mem[int unsigned];

  // Statistics
  int write_count = 0;
  int read_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  function new(string name = "axi4_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    write_imp = new("write_imp", this);
    read_imp  = new("read_imp", this);
  endfunction

  //------------------------------------------------------------------------
  // Write callback: update reference memory
  //------------------------------------------------------------------------
  function void write_write(axi4_seq_item item);
    bit [AXI4_ADDR_WIDTH-1:0] addrs[];
    int unsigned base_addr;

    axi4_calc_beat_addrs(item.addr, item.size, item.burst, item.len, addrs);

    for (int beat = 0; beat <= item.len; beat++) begin
      base_addr = (addrs[beat] / AXI4_STRB_WIDTH) * AXI4_STRB_WIDTH;
      for (int b = 0; b < AXI4_STRB_WIDTH; b++) begin
        if (item.wstrb[beat][b]) begin
          ref_mem[base_addr + b] = item.data[beat][b*8 +: 8];
        end
      end
    end

    write_count++;
    `uvm_info("SCB", $sformatf("Write #%0d recorded: addr=0x%0h len=%0d burst=%s",
              write_count, item.addr, item.len, item.burst.name()), UVM_HIGH)
  endfunction

  //------------------------------------------------------------------------
  // Read callback: compare read data with reference memory
  //------------------------------------------------------------------------
  function void write_read(axi4_seq_item item);
    bit [AXI4_ADDR_WIDTH-1:0] addrs[];
    int unsigned base_addr;
    int beat_errors;
    bit [7:0] expected_byte, actual_byte;

    axi4_calc_beat_addrs(item.addr, item.size, item.burst, item.len, addrs);
    beat_errors = 0;

    for (int beat = 0; beat <= item.len; beat++) begin
      base_addr = (addrs[beat] / AXI4_STRB_WIDTH) * AXI4_STRB_WIDTH;

      // Compare all bytes in the bus word
      for (int b = 0; b < AXI4_STRB_WIDTH; b++) begin
        expected_byte = ref_mem.exists(base_addr + b) ? ref_mem[base_addr + b] : 8'h00;
        actual_byte   = item.rdata[beat][b*8 +: 8];

        if (expected_byte !== actual_byte) begin
          `uvm_error("SCB", $sformatf(
            "MISMATCH beat=%0d addr=0x%0h byte[%0d]: exp=0x%02h act=0x%02h",
            beat, addrs[beat], b, expected_byte, actual_byte))
          beat_errors++;
        end
      end
    end

    read_count++;
    if (beat_errors == 0) begin
      pass_count++;
      `uvm_info("SCB", $sformatf("Read #%0d PASSED: addr=0x%0h len=%0d burst=%s",
                read_count, item.addr, item.len, item.burst.name()), UVM_MEDIUM)
    end else begin
      error_count++;
      `uvm_error("SCB", $sformatf("Read #%0d FAILED: addr=0x%0h %0d byte mismatches",
                 read_count, item.addr, beat_errors))
    end
  endfunction

  //------------------------------------------------------------------------
  // Report phase: summary statistics
  //------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", "============================================", UVM_LOW)
    `uvm_info("SCB", "         SCOREBOARD SUMMARY", UVM_LOW)
    `uvm_info("SCB", "============================================", UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Writes:  %0d", write_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Reads:   %0d", read_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Read PASS:     %0d", pass_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Read FAIL:     %0d", error_count), UVM_LOW)
    `uvm_info("SCB", "============================================", UVM_LOW)

    if (error_count > 0)
      `uvm_error("SCB", $sformatf("TEST FAILED: %0d read comparison errors", error_count))
    else if (read_count > 0)
      `uvm_info("SCB", "TEST PASSED: All read data matched", UVM_LOW)
    else
      `uvm_warning("SCB", "No read transactions observed")
  endfunction

endclass
