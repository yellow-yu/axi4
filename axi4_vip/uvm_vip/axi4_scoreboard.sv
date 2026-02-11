//==========================================================================
// axi4_scoreboard.sv - AXI4 Scoreboard
//==========================================================================

class axi4_scoreboard extends uvm_scoreboard;

  // Analysis exports
  uvm_analysis_imp_tag #(axi4_transaction, axi4_scoreboard, "WRITE") write_export;
  uvm_analysis_imp_tag #(axi4_transaction, axi4_scoreboard, "READ")  read_export;

  // Reference memory model (byte-addressable)
  bit [7:0] ref_mem[bit [`AXI4_ADDR_WIDTH-1:0]];

  // Statistics
  int unsigned write_count = 0;
  int unsigned read_count  = 0;
  int unsigned pass_count  = 0;
  int unsigned fail_count  = 0;

  `uvm_component_utils(axi4_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    write_export = new("write_export", this);
    read_export  = new("read_export", this);
  endfunction

  // ============================================================
  // Write transaction handler
  // ============================================================
  function void write_WRITE(axi4_transaction tr);
    int unsigned bus_bytes = `AXI4_DATA_WIDTH / 8;
    write_count++;

    `uvm_info(get_type_name(), $sformatf("SCB WR #%0d: addr=0x%0h, len=%0d, size=%0d, burst=%s",
              write_count, tr.addr, tr.len, tr.size, tr.burst.name()), UVM_HIGH)

    // Update reference memory
    for (int i = 0; i <= tr.len; i++) begin
      bit [`AXI4_ADDR_WIDTH-1:0] beat_addr = tr.get_beat_addr(i);
      bit [`AXI4_ADDR_WIDTH-1:0] base_addr = (beat_addr / bus_bytes) * bus_bytes;

      for (int b = 0; b < bus_bytes; b++) begin
        if (tr.strb[i][b])
          ref_mem[base_addr + b] = tr.data[i][b*8 +: 8];
      end
    end
  endfunction

  // ============================================================
  // Read transaction handler - check against reference
  // ============================================================
  function void write_READ(axi4_transaction tr);
    int unsigned bus_bytes = `AXI4_DATA_WIDTH / 8;
    int unsigned num_bytes = 1 << tr.size;
    bit error = 0;
    read_count++;

    `uvm_info(get_type_name(), $sformatf("SCB RD #%0d: addr=0x%0h, len=%0d, size=%0d, burst=%s",
              read_count, tr.addr, tr.len, tr.size, tr.burst.name()), UVM_HIGH)

    // Compare read data with reference memory
    for (int i = 0; i <= tr.len; i++) begin
      bit [`AXI4_ADDR_WIDTH-1:0] beat_addr = tr.get_beat_addr(i);
      bit [`AXI4_ADDR_WIDTH-1:0] base_addr = (beat_addr / bus_bytes) * bus_bytes;
      int lower_lane, upper_lane;

      // Get active byte lanes for this beat
      tr.get_byte_lanes(i, lower_lane, upper_lane);

      for (int b = lower_lane; b <= upper_lane; b++) begin
        bit [7:0] expected_byte;
        bit [7:0] actual_byte;

        if (ref_mem.exists(base_addr + b))
          expected_byte = ref_mem[base_addr + b];
        else
          expected_byte = 8'h00;

        actual_byte = tr.rdata[i][b*8 +: 8];

        if (actual_byte !== expected_byte) begin
          `uvm_error(get_type_name(), 
            $sformatf("DATA MISMATCH: beat=%0d, addr=0x%0h, lane=%0d, expected=0x%02h, got=0x%02h",
                      i, base_addr + b, b, expected_byte, actual_byte))
          error = 1;
        end
      end
    end

    if (error)
      fail_count++;
    else
      pass_count++;
  endfunction

  // ============================================================
  // Report phase - summarize results
  // ============================================================
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "========================================", UVM_LOW)
    `uvm_info(get_type_name(), "         SCOREBOARD SUMMARY", UVM_LOW)
    `uvm_info(get_type_name(), "========================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Write transactions: %0d", write_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Read transactions:  %0d", read_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Read checks PASS:   %0d", pass_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Read checks FAIL:   %0d", fail_count), UVM_LOW)
    `uvm_info(get_type_name(), "========================================", UVM_LOW)

    if (fail_count > 0)
      `uvm_error(get_type_name(), $sformatf("TEST FAILED: %0d read mismatches detected!", fail_count))
    else if (read_count > 0)
      `uvm_info(get_type_name(), "TEST PASSED: All read data matched!", UVM_LOW)
    else
      `uvm_warning(get_type_name(), "No read transactions observed!")
  endfunction

endclass
