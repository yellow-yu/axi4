//==========================================================================
// axi4_scoreboard.svh - AXI4 Scoreboard with Reference Memory
//==========================================================================

`ifndef AXI4_SCOREBOARD_SVH
`define AXI4_SCOREBOARD_SVH

// Analysis imp declaration macros (must be before class)
`uvm_analysis_imp_decl(_write)
`uvm_analysis_imp_decl(_read)

class axi4_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(axi4_scoreboard)

    // Analysis exports
    uvm_analysis_imp_write #(axi4_transaction, axi4_scoreboard) write_export;
    uvm_analysis_imp_read  #(axi4_transaction, axi4_scoreboard) read_export;

    // Reference memory (byte-addressable)
    bit [7:0] ref_mem [int unsigned];

    // Statistics
    int unsigned write_count;
    int unsigned read_count;
    int unsigned pass_count;
    int unsigned fail_count;

    // Exclusive monitor
    bit        excl_valid;
    bit [AXI4_VIP_ADDR_W-1:0] excl_addr;
    bit [AXI4_VIP_ID_W-1:0]   excl_id;

    function new(string name = "axi4_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        write_export = new("write_export", this);
        read_export  = new("read_export", this);
        write_count = 0;
        read_count  = 0;
        pass_count  = 0;
        fail_count  = 0;
        excl_valid  = 0;
    endfunction

    //----------------------------------------------------------------------
    // Handle Write Transactions
    //----------------------------------------------------------------------
    function void write_write(axi4_transaction tr);
        int unsigned num_bytes;
        bit [AXI4_VIP_ADDR_W-1:0] beat_addr;
        bit [AXI4_VIP_ADDR_W-1:0] base_addr;

        write_count++;
        num_bytes = 1 << tr.burst_size;

        `uvm_info("SCB_WR", $sformatf("Write: addr=0x%08x len=%0d size=%0d burst=%0d resp=%0d",
                  tr.addr, tr.burst_len, tr.burst_size, tr.burst_type, tr.resp), UVM_HIGH)

        // Skip memory update for failed exclusive writes
        if (tr.lock && tr.resp == AXI4_OKAY) begin
            `uvm_info("SCB_WR", "Exclusive write failed (no EXOKAY), skipping memory update", UVM_MEDIUM)
            return;
        end

        // Update reference memory
        for (int i = 0; i <= tr.burst_len; i++) begin
            beat_addr = tr.calc_beat_addr(i);
            base_addr = (beat_addr >> $clog2(AXI4_VIP_STRB_W)) << $clog2(AXI4_VIP_STRB_W);

            for (int j = 0; j < AXI4_VIP_STRB_W; j++) begin
                if (tr.strb[i][j]) begin
                    ref_mem[base_addr + j] = tr.data[i][j*8 +: 8];
                end
            end
        end

        // Handle exclusive monitor
        if (tr.lock && tr.resp == AXI4_EXOKAY) begin
            excl_valid = 0;
        end else if (!tr.lock && excl_valid) begin
            // Check if normal write invalidates exclusive
            beat_addr = tr.calc_beat_addr(0);
            base_addr = (beat_addr >> $clog2(AXI4_VIP_STRB_W)) << $clog2(AXI4_VIP_STRB_W);
            if (base_addr == ((excl_addr >> $clog2(AXI4_VIP_STRB_W)) << $clog2(AXI4_VIP_STRB_W)))
                excl_valid = 0;
        end
    endfunction

    //----------------------------------------------------------------------
    // Handle Read Transactions
    //----------------------------------------------------------------------
    function void write_read(axi4_transaction tr);
        int unsigned num_bytes;
        bit [AXI4_VIP_ADDR_W-1:0] beat_addr;
        bit [AXI4_VIP_ADDR_W-1:0] base_addr;
        bit [AXI4_VIP_DATA_W-1:0] expected_data;
        int unsigned low_lane, high_lane;
        bit mismatch;

        read_count++;
        num_bytes = 1 << tr.burst_size;

        `uvm_info("SCB_RD", $sformatf("Read: addr=0x%08x len=%0d size=%0d burst=%0d",
                  tr.addr, tr.burst_len, tr.burst_size, tr.burst_type), UVM_HIGH)

        // Handle exclusive read
        if (tr.lock) begin
            excl_valid = 1;
            excl_addr  = tr.addr;
            excl_id    = tr.id;
        end

        // Compare read data with reference memory
        mismatch = 0;
        for (int i = 0; i <= tr.burst_len; i++) begin
            beat_addr = tr.calc_beat_addr(i);
            base_addr = (beat_addr >> $clog2(AXI4_VIP_STRB_W)) << $clog2(AXI4_VIP_STRB_W);

            // Calculate active byte lanes
            low_lane  = beat_addr & (AXI4_VIP_STRB_W - 1);
            if (i == 0 && (tr.addr % num_bytes) != 0) begin
                // First beat, unaligned
                high_lane = ((tr.addr / num_bytes) * num_bytes + num_bytes - 1) & (AXI4_VIP_STRB_W - 1);
            end else begin
                high_lane = low_lane + num_bytes - 1;
            end

            // Compare active byte lanes
            for (int j = low_lane; j <= high_lane && j < AXI4_VIP_STRB_W; j++) begin
                bit [7:0] exp_byte, act_byte;
                exp_byte = ref_mem.exists(base_addr + j) ? ref_mem[base_addr + j] : 8'h00;
                act_byte = tr.rdata[i][j*8 +: 8];

                if (exp_byte !== act_byte) begin
                    `uvm_error("SCB_MISMATCH",
                        $sformatf("Beat[%0d] Lane[%0d] addr=0x%08x: exp=0x%02x act=0x%02x",
                                  i, j, base_addr + j, exp_byte, act_byte))
                    mismatch = 1;
                end
            end
        end

        if (mismatch) begin
            fail_count++;
        end else begin
            pass_count++;
            `uvm_info("SCB_PASS", $sformatf("Read PASS: addr=0x%08x len=%0d",
                      tr.addr, tr.burst_len), UVM_MEDIUM)
        end
    endfunction

    //----------------------------------------------------------------------
    // Report
    //----------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("SCB_REPORT", $sformatf(
            "\n========================================\n" +
            "  Scoreboard Summary\n" +
            "========================================\n" +
            "  Write transactions: %0d\n" +
            "  Read transactions:  %0d\n" +
            "  Read comparisons PASS: %0d\n" +
            "  Read comparisons FAIL: %0d\n" +
            "========================================",
            write_count, read_count, pass_count, fail_count), UVM_LOW)

        if (fail_count > 0)
            `uvm_error("SCB_FAIL", $sformatf("Scoreboard detected %0d failures!", fail_count))
        else if (read_count > 0)
            `uvm_info("SCB_PASS", "All read comparisons PASSED!", UVM_LOW)
    endfunction

endclass

`endif
