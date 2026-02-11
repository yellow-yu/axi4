//==========================================================================
// AXI4 VIP Package - Contains all UVM-based VIP components
//==========================================================================
package axi4_vip_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //========================================================================
  // AXI4 VIP Parameters
  //========================================================================
  parameter int AXI4_ID_WIDTH    = 4;
  parameter int AXI4_ADDR_WIDTH  = 64;
  parameter int AXI4_DATA_WIDTH  = 512;
  parameter int AXI4_USER_WIDTH  = 1;
  parameter int AXI4_STRB_WIDTH  = AXI4_DATA_WIDTH / 8;  // 64

  //========================================================================
  // AXI4 Type Definitions
  //========================================================================
  typedef enum bit [1:0] {
    AXI4_BURST_FIXED = 2'b00,
    AXI4_BURST_INCR  = 2'b01,
    AXI4_BURST_WRAP  = 2'b10
  } axi4_burst_type_e;

  typedef enum bit [1:0] {
    AXI4_RESP_OKAY   = 2'b00,
    AXI4_RESP_EXOKAY = 2'b01,
    AXI4_RESP_SLVERR = 2'b10,
    AXI4_RESP_DECERR = 2'b11
  } axi4_resp_type_e;

  typedef enum bit {
    AXI4_READ  = 1'b0,
    AXI4_WRITE = 1'b1
  } axi4_txn_type_e;

  //========================================================================
  // Helper: Calculate beat addresses for a burst
  //========================================================================
  function automatic void axi4_calc_beat_addrs(
    input  bit [AXI4_ADDR_WIDTH-1:0] start_addr,
    input  bit [2:0]                  size,
    input  bit [1:0]                  burst,
    input  bit [7:0]                  len,
    output bit [AXI4_ADDR_WIDTH-1:0]  addrs[]
  );
    int unsigned num_bytes;
    int unsigned burst_len;
    bit [AXI4_ADDR_WIDTH-1:0] aligned_addr;
    bit [AXI4_ADDR_WIDTH-1:0] wrap_lo, wrap_hi;
    int unsigned total_size;

    num_bytes   = 1 << size;
    burst_len   = len + 1;
    aligned_addr = (start_addr / num_bytes) * num_bytes;

    addrs = new[burst_len];
    addrs[0] = start_addr;

    if (burst == AXI4_BURST_WRAP) begin
      total_size = num_bytes * burst_len;
      wrap_lo = (start_addr / total_size) * total_size;
      wrap_hi = wrap_lo + total_size;
    end

    for (int i = 1; i < burst_len; i++) begin
      case (burst)
        2'b00: addrs[i] = start_addr;  // FIXED
        2'b01: addrs[i] = aligned_addr + i * num_bytes;  // INCR
        2'b10: begin  // WRAP
          addrs[i] = aligned_addr + i * num_bytes;
          if (addrs[i] >= wrap_hi)
            addrs[i] = addrs[i] - (wrap_hi - wrap_lo);
        end
        default: addrs[i] = aligned_addr + i * num_bytes;
      endcase
    end
  endfunction

  //========================================================================
  // Helper: Calculate write strobe for a beat
  //========================================================================
  function automatic bit [AXI4_STRB_WIDTH-1:0] axi4_calc_strb(
    input bit [AXI4_ADDR_WIDTH-1:0] beat_addr,
    input bit [2:0] size
  );
    int num_bytes;
    int lower_lane;
    bit [AXI4_STRB_WIDTH-1:0] strb;

    num_bytes  = 1 << size;
    lower_lane = beat_addr % AXI4_STRB_WIDTH;
    strb = '0;

    for (int i = lower_lane; i < lower_lane + num_bytes && i < AXI4_STRB_WIDTH; i++)
      strb[i] = 1'b1;

    return strb;
  endfunction

  //========================================================================
  // Include VIP component files
  //========================================================================
  `include "axi4_seq_item.sv"
  `include "axi4_master_driver.sv"
  `include "axi4_master_monitor.sv"
  `include "axi4_master_sequencer.sv"
  `include "axi4_master_agent.sv"
  `include "axi4_slave_driver.sv"
  `include "axi4_slave_agent.sv"
  `include "axi4_scoreboard.sv"
  `include "axi4_coverage.sv"
  `include "axi4_env.sv"

endpackage
