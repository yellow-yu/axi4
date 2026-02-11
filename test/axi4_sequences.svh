//==========================================================================
// axi4_sequences.svh - All AXI4 Test Sequences
//==========================================================================

`ifndef AXI4_SEQUENCES_SVH
`define AXI4_SEQUENCES_SVH

//==========================================================================
// 1. Single Write-Read Sequence
//==========================================================================
class axi4_single_rw_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_single_rw_seq)

    function new(string name = "axi4_single_rw_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction rsp;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting single write-read sequence", UVM_MEDIUM)

        for (int i = 0; i < 10; i++) begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr;
            target_addr = (i * 32) & 32'hFFFFFFF8; // 8-byte aligned

            gen_random_data(1, wdata);
            gen_full_strb(1, wstrb);
            do_write_data(target_addr, 0, $clog2(AXI4_VIP_STRB_W), AXI4_INCR,
                          i[3:0], 0, wdata, wstrb);
            do_read(target_addr, 0, $clog2(AXI4_VIP_STRB_W), AXI4_INCR,
                    i[3:0], 0, rsp);
        end

        `uvm_info("SEQ", "Single write-read sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 2. INCR Burst Sequence
//==========================================================================
class axi4_incr_burst_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_incr_burst_seq)

    function new(string name = "axi4_incr_burst_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction rsp;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting INCR burst sequence", UVM_MEDIUM)

        for (int len = 0; len < 16; len++) begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr;
            target_addr = 32'h0001_0000 + len * 256;
            target_addr = target_addr & 32'hFFFFFFF8;

            gen_random_data(len + 1, wdata);
            gen_full_strb(len + 1, wstrb);
            do_write_data(target_addr, len[7:0], $clog2(AXI4_VIP_STRB_W),
                          AXI4_INCR, 0, 0, wdata, wstrb);
            do_read(target_addr, len[7:0], $clog2(AXI4_VIP_STRB_W),
                    AXI4_INCR, 0, 0, rsp);
        end

        `uvm_info("SEQ", "INCR burst sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 3. WRAP Burst Sequence
//==========================================================================
class axi4_wrap_burst_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_wrap_burst_seq)

    function new(string name = "axi4_wrap_burst_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction rsp;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];
        int wrap_lens[4] = '{1, 3, 7, 15};

        `uvm_info("SEQ", "Starting WRAP burst sequence", UVM_MEDIUM)

        for (int i = 0; i < 4; i++) begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr;
            int wlen = wrap_lens[i];
            // Address aligned to burst_size (8 bytes)
            target_addr = 32'h0002_0000 + i * 256;
            target_addr = target_addr & 32'hFFFFFFF8;

            gen_random_data(wlen + 1, wdata);
            gen_full_strb(wlen + 1, wstrb);
            do_write_data(target_addr, wlen[7:0], $clog2(AXI4_VIP_STRB_W),
                          AXI4_WRAP, 0, 0, wdata, wstrb);
            do_read(target_addr, wlen[7:0], $clog2(AXI4_VIP_STRB_W),
                    AXI4_WRAP, 0, 0, rsp);
        end

        `uvm_info("SEQ", "WRAP burst sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 4. FIXED Burst Sequence
//==========================================================================
class axi4_fixed_burst_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_fixed_burst_seq)

    function new(string name = "axi4_fixed_burst_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction rsp;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting FIXED burst sequence", UVM_MEDIUM)

        // FIXED: all beats access same address; last beat data is final
        for (int len = 0; len < 4; len++) begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr;
            target_addr = 32'h0003_0000 + len * 64;
            target_addr = target_addr & 32'hFFFFFFF8;

            gen_random_data(len + 1, wdata);
            gen_full_strb(len + 1, wstrb);
            do_write_data(target_addr, len[7:0], $clog2(AXI4_VIP_STRB_W),
                          AXI4_FIXED, 0, 0, wdata, wstrb);
            // Read 1 beat from same address; should match last written data
            do_read(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                    AXI4_FIXED, 0, 0, rsp);
        end

        `uvm_info("SEQ", "FIXED burst sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 5. Narrow Transfer Sequence
//==========================================================================
class axi4_narrow_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_narrow_seq)

    function new(string name = "axi4_narrow_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction rsp, tr;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting narrow transfer sequence", UVM_MEDIUM)

        // Test: 4-byte narrow on 8-byte bus, multi-beat INCR
        begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr = 32'h0004_0000;
            int sz = 2; // 4 bytes
            int target_len = 3; // 4 beats
            int num_bytes = 1 << sz;

            wdata = new[target_len + 1];
            wstrb = new[target_len + 1];

            for (int i = 0; i <= target_len; i++) begin
                bit [AXI4_VIP_ADDR_W-1:0] beat_addr;
                int low_lane;
                bit [AXI4_VIP_ADDR_W-1:0] aligned_addr;

                aligned_addr = (target_addr / num_bytes) * num_bytes;
                if (i == 0)
                    beat_addr = target_addr;
                else
                    beat_addr = aligned_addr + i * num_bytes;

                low_lane = beat_addr % AXI4_VIP_STRB_W;
                wdata[i] = '0;
                wstrb[i] = '0;
                for (int j = 0; j < num_bytes; j++) begin
                    wdata[i][(low_lane + j) * 8 +: 8] = (i * 16 + j + 1);
                    wstrb[i][low_lane + j] = 1'b1;
                end
            end

            // Create transaction with constraints disabled
            tr = axi4_transaction::type_id::create("narrow_wr");
            tr.c_strb_default.constraint_mode(0);
            tr.c_size_default.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_WRITE;
                addr       == target_addr;
                burst_len  == target_len[7:0];
                burst_size == sz[2:0];
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 0;
            }) else `uvm_fatal("SEQ", "Narrow write randomization failed")

            for (int i = 0; i <= target_len; i++) begin
                tr.data[i] = wdata[i];
                tr.strb[i] = wstrb[i];
            end
            finish_item(tr);

            // Read back with same narrow params
            tr = axi4_transaction::type_id::create("narrow_rd");
            tr.c_size_default.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_READ;
                addr       == target_addr;
                burst_len  == target_len[7:0];
                burst_size == sz[2:0];
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 0;
            }) else `uvm_fatal("SEQ", "Narrow read randomization failed")
            finish_item(tr);
        end

        // Test: 2-byte narrow
        begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr = 32'h0004_0100;
            int sz = 1; // 2 bytes
            int target_len = 3; // 4 beats
            int num_bytes = 1 << sz;

            wdata = new[target_len + 1];
            wstrb = new[target_len + 1];

            for (int i = 0; i <= target_len; i++) begin
                bit [AXI4_VIP_ADDR_W-1:0] beat_addr;
                int low_lane;
                bit [AXI4_VIP_ADDR_W-1:0] aligned_addr;

                aligned_addr = (target_addr / num_bytes) * num_bytes;
                if (i == 0)
                    beat_addr = target_addr;
                else
                    beat_addr = aligned_addr + i * num_bytes;

                low_lane = beat_addr % AXI4_VIP_STRB_W;
                wdata[i] = '0;
                wstrb[i] = '0;
                for (int j = 0; j < num_bytes; j++) begin
                    wdata[i][(low_lane + j) * 8 +: 8] = (i * 16 + j + 1);
                    wstrb[i][low_lane + j] = 1'b1;
                end
            end

            tr = axi4_transaction::type_id::create("narrow_wr2");
            tr.c_strb_default.constraint_mode(0);
            tr.c_size_default.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_WRITE;
                addr       == target_addr;
                burst_len  == target_len[7:0];
                burst_size == sz[2:0];
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 0;
            }) else `uvm_fatal("SEQ", "Narrow write2 randomization failed")

            for (int i = 0; i <= target_len; i++) begin
                tr.data[i] = wdata[i];
                tr.strb[i] = wstrb[i];
            end
            finish_item(tr);

            tr = axi4_transaction::type_id::create("narrow_rd2");
            tr.c_size_default.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_READ;
                addr       == target_addr;
                burst_len  == target_len[7:0];
                burst_size == sz[2:0];
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 0;
            }) else `uvm_fatal("SEQ", "Narrow read2 randomization failed")
            finish_item(tr);
        end

        `uvm_info("SEQ", "Narrow transfer sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 6. Unaligned Transfer Sequence
//==========================================================================
class axi4_unaligned_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_unaligned_seq)

    function new(string name = "axi4_unaligned_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction rsp, tr;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting unaligned transfer sequence", UVM_MEDIUM)

        // Unaligned INCR burst: size=4 bytes, start addr offset by 4
        begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr = 32'h0005_0004;
            int sz = 2; // 4 bytes
            int target_len = 3; // 4 beats
            int num_bytes = 1 << sz;
            bit [AXI4_VIP_ADDR_W-1:0] aligned_addr;

            aligned_addr = (target_addr / num_bytes) * num_bytes;

            wdata = new[target_len + 1];
            wstrb = new[target_len + 1];

            for (int i = 0; i <= target_len; i++) begin
                bit [AXI4_VIP_ADDR_W-1:0] beat_addr;
                int low_lane, high_lane;

                if (i == 0)
                    beat_addr = target_addr;
                else
                    beat_addr = aligned_addr + i * num_bytes;

                low_lane = beat_addr % AXI4_VIP_STRB_W;
                if (i == 0) begin
                    // First beat: from unaligned addr to aligned+size-1
                    high_lane = (aligned_addr + num_bytes - 1) % AXI4_VIP_STRB_W;
                end else begin
                    high_lane = low_lane + num_bytes - 1;
                end

                wdata[i] = '0;
                wstrb[i] = '0;
                for (int j = low_lane; j <= high_lane && j < AXI4_VIP_STRB_W; j++) begin
                    wdata[i][j * 8 +: 8] = (i * 16 + j + 1);
                    wstrb[i][j] = 1'b1;
                end
            end

            tr = axi4_transaction::type_id::create("unaligned_wr");
            tr.c_strb_default.constraint_mode(0);
            tr.c_size_default.constraint_mode(0);
            tr.c_addr_range.constraint_mode(0);
            tr.c_4kb_boundary.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_WRITE;
                addr       == target_addr;
                burst_len  == target_len[7:0];
                burst_size == sz[2:0];
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 0;
            }) else `uvm_fatal("SEQ", "Unaligned write randomization failed")

            for (int i = 0; i <= target_len; i++) begin
                tr.data[i] = wdata[i];
                tr.strb[i] = wstrb[i];
            end
            finish_item(tr);

            // Read back
            tr = axi4_transaction::type_id::create("unaligned_rd");
            tr.c_size_default.constraint_mode(0);
            tr.c_addr_range.constraint_mode(0);
            tr.c_4kb_boundary.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_READ;
                addr       == target_addr;
                burst_len  == target_len[7:0];
                burst_size == sz[2:0];
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 0;
            }) else `uvm_fatal("SEQ", "Unaligned read randomization failed")
            finish_item(tr);
        end

        `uvm_info("SEQ", "Unaligned transfer sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 7. Outstanding Transactions Sequence
//==========================================================================
class axi4_outstanding_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_outstanding_seq)

    function new(string name = "axi4_outstanding_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction rsp;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting outstanding transactions sequence", UVM_MEDIUM)

        // Write 8 burst transactions with different IDs
        for (int i = 0; i < 8; i++) begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr;
            target_addr = 32'h0006_0000 + i * 64;
            target_addr = target_addr & 32'hFFFFFFF8;

            gen_random_data(4, wdata);
            gen_full_strb(4, wstrb);
            do_write_data(target_addr, 3, $clog2(AXI4_VIP_STRB_W),
                          AXI4_INCR, i[3:0], 0, wdata, wstrb);
        end

        // Read back in reverse order
        for (int i = 7; i >= 0; i--) begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr;
            target_addr = 32'h0006_0000 + i * 64;
            target_addr = target_addr & 32'hFFFFFFF8;

            do_read(target_addr, 3, $clog2(AXI4_VIP_STRB_W),
                    AXI4_INCR, i[3:0], 0, rsp);
        end

        `uvm_info("SEQ", "Outstanding transactions sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 8. Byte Strobe Sequence
//==========================================================================
class axi4_byte_strobe_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_byte_strobe_seq)

    function new(string name = "axi4_byte_strobe_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction rsp;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting byte strobe sequence", UVM_MEDIUM)

        // Test 1: Full write then partial overwrite
        begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr = 32'h0007_0000;

            // Full write
            wdata = new[1];
            wstrb = new[1];
            wdata[0] = 64'hAAAA_BBBB_CCCC_DDDD;
            wstrb[0] = 8'hFF;
            do_write_data(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                          AXI4_INCR, 0, 0, wdata, wstrb);

            // Partial overwrite: even bytes only
            wdata[0] = 64'h1111_2222_3333_4444;
            wstrb[0] = 8'h55; // bytes 0, 2, 4, 6
            do_write_data(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                          AXI4_INCR, 0, 0, wdata, wstrb);

            // Read and verify (scoreboard checks)
            do_read(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                    AXI4_INCR, 0, 0, rsp);
        end

        // Test 2: Write with single byte strobe at each lane
        for (int b = 0; b < AXI4_VIP_STRB_W; b++) begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr;
            target_addr = 32'h0007_0100 + b * 8;
            target_addr = target_addr & 32'hFFFFFFF8;

            wdata = new[1];
            wstrb = new[1];
            wdata[0] = '0;
            wdata[0][b*8 +: 8] = 8'hAB;
            wstrb[0] = 1 << b;
            do_write_data(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                          AXI4_INCR, 0, 0, wdata, wstrb);
            do_read(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                    AXI4_INCR, 0, 0, rsp);
        end

        `uvm_info("SEQ", "Byte strobe sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 9. Max Burst Length Sequence (256 beats)
//==========================================================================
class axi4_max_burst_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_max_burst_seq)

    function new(string name = "axi4_max_burst_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction tr;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting max burst length (256) sequence", UVM_MEDIUM)

        begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr = 32'h0008_0000;

            gen_random_data(256, wdata);
            gen_full_strb(256, wstrb);

            // Write with constraints disabled
            tr = axi4_transaction::type_id::create("max_wr");
            tr.c_len_default.constraint_mode(0);
            tr.c_4kb_boundary.constraint_mode(0);
            tr.c_strb_default.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_WRITE;
                addr       == target_addr;
                burst_len  == 8'd255;
                burst_size == $clog2(AXI4_VIP_STRB_W);
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 0;
            }) else `uvm_fatal("SEQ", "Max burst write randomization failed")

            for (int i = 0; i < 256; i++) begin
                tr.data[i] = wdata[i];
                tr.strb[i] = wstrb[i];
            end
            finish_item(tr);

            // Read back
            tr = axi4_transaction::type_id::create("max_rd");
            tr.c_len_default.constraint_mode(0);
            tr.c_4kb_boundary.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_READ;
                addr       == target_addr;
                burst_len  == 8'd255;
                burst_size == $clog2(AXI4_VIP_STRB_W);
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 0;
            }) else `uvm_fatal("SEQ", "Max burst read randomization failed")
            finish_item(tr);
        end

        `uvm_info("SEQ", "Max burst length sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 10. Exclusive Access Sequence
//==========================================================================
class axi4_exclusive_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_exclusive_seq)

    function new(string name = "axi4_exclusive_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction tr, rsp;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting exclusive access sequence", UVM_MEDIUM)

        begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr = 32'h0009_0000;

            // Step 1: Normal write to initialize
            wdata = new[1];
            wstrb = new[1];
            wdata[0] = 64'hDEAD_BEEF_CAFE_BABE;
            wstrb[0] = 8'hFF;
            do_write_data(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                          AXI4_INCR, 0, 0, wdata, wstrb);

            // Step 2: Exclusive read
            tr = axi4_transaction::type_id::create("excl_rd");
            tr.c_lock_default.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_READ;
                addr       == target_addr;
                burst_len  == 0;
                burst_size == $clog2(AXI4_VIP_STRB_W);
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 1;
            }) else `uvm_fatal("SEQ", "Exclusive read randomization failed")
            finish_item(tr);

            // Step 3: Exclusive write
            wdata[0] = 64'h1234_5678_9ABC_DEF0;
            wstrb[0] = 8'hFF;

            tr = axi4_transaction::type_id::create("excl_wr");
            tr.c_lock_default.constraint_mode(0);
            tr.c_strb_default.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize() with {
                txn_type   == AXI4_WRITE;
                addr       == target_addr;
                burst_len  == 0;
                burst_size == $clog2(AXI4_VIP_STRB_W);
                burst_type == AXI4_INCR;
                id         == 0;
                lock       == 1;
            }) else `uvm_fatal("SEQ", "Exclusive write randomization failed")
            tr.data[0] = wdata[0];
            tr.strb[0] = wstrb[0];
            finish_item(tr);

            // Step 4: Normal read to verify
            do_read(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                    AXI4_INCR, 0, 0, rsp);
        end

        `uvm_info("SEQ", "Exclusive access sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 11. Random Test Sequence
//==========================================================================
class axi4_random_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_random_seq)

    int unsigned num_transactions = 30;

    function new(string name = "axi4_random_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction tr;
        bit [AXI4_VIP_ADDR_W-1:0] written_addrs[$];
        bit [7:0]                  written_lens[$];

        `uvm_info("SEQ", $sformatf("Starting random sequence (%0d txns)", num_transactions), UVM_MEDIUM)

        // Phase 1: Random writes
        for (int i = 0; i < num_transactions; i++) begin
            tr = axi4_transaction::type_id::create("rand_wr");
            start_item(tr);
            assert(tr.randomize() with {
                txn_type == AXI4_WRITE;
                burst_type == AXI4_INCR;
                burst_len <= 7;
                lock == 0;
                // Full-width, aligned
                burst_size == $clog2(AXI4_VIP_STRB_W);
                addr[2:0] == 3'b000;
                addr >= 32'h000A_0000;
                addr <  32'h000B_0000;
            }) else `uvm_fatal("SEQ", "Random write randomization failed")
            finish_item(tr);

            written_addrs.push_back(tr.addr);
            written_lens.push_back(tr.burst_len);
        end

        // Phase 2: Read back
        for (int i = 0; i < written_addrs.size(); i++) begin
            axi4_transaction rsp;
            do_read(written_addrs[i], written_lens[i], $clog2(AXI4_VIP_STRB_W),
                    AXI4_INCR, 0, 0, rsp);
        end

        `uvm_info("SEQ", "Random sequence complete", UVM_MEDIUM)
    endtask
endclass

//==========================================================================
// 12. Back-to-Back Sequence
//==========================================================================
class axi4_back2back_seq extends axi4_base_seq;
    `uvm_object_utils(axi4_back2back_seq)

    function new(string name = "axi4_back2back_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction rsp;
        bit [AXI4_VIP_DATA_W-1:0] wdata[];
        bit [AXI4_VIP_STRB_W-1:0] wstrb[];

        `uvm_info("SEQ", "Starting back-to-back sequence", UVM_MEDIUM)

        for (int i = 0; i < 20; i++) begin
            bit [AXI4_VIP_ADDR_W-1:0] target_addr;
            target_addr = 32'h000B_0000 + i * 8;

            gen_random_data(1, wdata);
            gen_full_strb(1, wstrb);
            do_write_data(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                          AXI4_INCR, 0, 0, wdata, wstrb);
            do_read(target_addr, 0, $clog2(AXI4_VIP_STRB_W),
                    AXI4_INCR, 0, 0, rsp);
        end

        `uvm_info("SEQ", "Back-to-back sequence complete", UVM_MEDIUM)
    endtask
endclass

`endif
