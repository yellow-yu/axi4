`ifndef AXI4_SCOREBOARD_SVH
`define AXI4_SCOREBOARD_SVH

//==========================================================================
// Analysis imp declarations for multiple ports
//==========================================================================
`uvm_analysis_imp_decl(_write_tr)
`uvm_analysis_imp_decl(_read_tr)

//==========================================================================
// AXI4 Scoreboard - reference memory model check
//==========================================================================
class axi4_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(axi4_scoreboard)

    // Analysis imports
    uvm_analysis_imp_write_tr #(axi4_transaction, axi4_scoreboard) write_export;
    uvm_analysis_imp_read_tr  #(axi4_transaction, axi4_scoreboard) read_export;

    // Reference memory (byte addressable)
    bit [7:0] ref_mem[bit [AXI4_ADDR_WIDTH-1:0]];

    // Counters
    int unsigned write_count;
    int unsigned read_count;
    int unsigned pass_count;
    int unsigned fail_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        write_export = new("write_export", this);
        read_export  = new("read_export", this);
    endfunction

    //----------------------------------------------------------------------
    // Write transaction handler - update reference memory
    //----------------------------------------------------------------------
    function void write_write_tr(axi4_transaction tr);
        bit [AXI4_ADDR_WIDTH-1:0] beat_addrs[];
        bit [AXI4_ADDR_WIDTH-1:0] bus_base;

        write_count++;

        // Don't update memory for failed exclusive writes
        if (tr.lock && tr.bresp == AXI4_RESP_OKAY)
            return;

        tr.calc_beat_addresses(beat_addrs);

        for (int i = 0; i <= tr.len; i++) begin
            bus_base = (beat_addrs[i] >> $clog2(AXI4_STRB_WIDTH)) << $clog2(AXI4_STRB_WIDTH);
            for (int j = 0; j < AXI4_STRB_WIDTH; j++) begin
                if (tr.strb[i][j])
                    ref_mem[bus_base + j] = tr.data[i][j*8 +: 8];
            end
        end

        `uvm_info("SCB", $sformatf("WRITE #%0d stored: %s", write_count, tr.convert2string()), UVM_HIGH)
    endfunction

    //----------------------------------------------------------------------
    // Read transaction handler - check against reference memory
    //----------------------------------------------------------------------
    function void write_read_tr(axi4_transaction tr);
        bit [AXI4_ADDR_WIDTH-1:0] beat_addrs[];
        bit [AXI4_ADDR_WIDTH-1:0] bus_base;
        bit [AXI4_STRB_WIDTH-1:0] active_strb;
        bit [7:0]                 exp_byte, act_byte;
        bit                       match;
        int                       num_bytes;

        read_count++;
        match = 1;

        tr.calc_beat_addresses(beat_addrs);
        num_bytes = 1 << tr.size;

        for (int i = 0; i <= tr.len; i++) begin
            bus_base = (beat_addrs[i] >> $clog2(AXI4_STRB_WIDTH)) << $clog2(AXI4_STRB_WIDTH);

            // Compute expected active byte lanes for this beat
            begin
                int lower_lane;
                lower_lane = beat_addrs[i] % AXI4_STRB_WIDTH;
                active_strb = '0;
                for (int k = 0; k < num_bytes && (lower_lane + k) < AXI4_STRB_WIDTH; k++)
                    active_strb[lower_lane + k] = 1'b1;
            end

            // Check each active byte
            for (int j = 0; j < AXI4_STRB_WIDTH; j++) begin
                if (active_strb[j]) begin
                    exp_byte = ref_mem.exists(bus_base + j) ? ref_mem[bus_base + j] : 8'h00;
                    act_byte = tr.rdata[i][j*8 +: 8];
                    if (exp_byte !== act_byte) begin
                        `uvm_error("SCB", $sformatf(
                            "READ MISMATCH at addr=0x%0h beat=%0d lane=%0d: exp=0x%02h act=0x%02h",
                            bus_base + j, i, j, exp_byte, act_byte))
                        match = 0;
                    end
                end
            end
        end

        if (match) begin
            pass_count++;
            `uvm_info("SCB", $sformatf("READ #%0d PASS: %s", read_count, tr.convert2string()), UVM_MEDIUM)
        end else begin
            fail_count++;
            `uvm_error("SCB", $sformatf("READ #%0d FAIL: %s", read_count, tr.convert2string()))
        end
    endfunction

    //----------------------------------------------------------------------
    // Report phase
    //----------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf(
            "\n========== Scoreboard Summary ==========\n"
            + "  Writes:   %0d\n"
            + "  Reads:    %0d\n"
            + "  Passes:   %0d\n"
            + "  Failures: %0d\n"
            + "========================================",
            write_count, read_count, pass_count, fail_count), UVM_LOW)
        if (fail_count > 0)
            `uvm_error("SCB", $sformatf("%0d read mismatches detected!", fail_count))
        else if (read_count > 0)
            `uvm_info("SCB", "All read checks passed!", UVM_LOW)
    endfunction

endclass

`endif
