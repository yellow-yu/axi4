`ifndef AXI4_SEQUENCES_SVH
`define AXI4_SEQUENCES_SVH

//==========================================================================
// Base sequence - helper utilities
//==========================================================================
class axi4_base_seq extends uvm_sequence #(axi4_transaction);

    `uvm_object_utils(axi4_base_seq)

    function new(string name = "axi4_base_seq");
        super.new(name);
    endfunction

    // Helper: do a write then read-back at the same address/params
    task write_then_read(
        bit [AXI4_ADDR_WIDTH-1:0] addr,
        bit [7:0]                 len    = 0,
        bit [2:0]                 size   = AXI4_SIZE_MAX,
        axi4_burst_t             burst  = AXI4_BURST_INCR,
        bit [AXI4_ID_WIDTH-1:0]  id     = 0,
        bit                      lock   = 0
    );
        axi4_transaction wr_tr, rd_tr;

        // WRITE
        wr_tr = axi4_transaction::type_id::create("wr_tr");
        start_item(wr_tr);
        if (!wr_tr.randomize() with {
            rw    == AXI4_WRITE;
            wr_tr.addr  == addr;
            wr_tr.len   == len;
            wr_tr.size  == size;
            wr_tr.burst == burst;
            wr_tr.id    == id;
            wr_tr.lock  == lock;
        }) `uvm_fatal("SEQ", "Write randomization failed")
        finish_item(wr_tr);

        // READ
        rd_tr = axi4_transaction::type_id::create("rd_tr");
        start_item(rd_tr);
        if (!rd_tr.randomize() with {
            rw    == AXI4_READ;
            rd_tr.addr  == addr;
            rd_tr.len   == len;
            rd_tr.size  == size;
            rd_tr.burst == burst;
            rd_tr.id    == id;
            rd_tr.lock  == lock;
        }) `uvm_fatal("SEQ", "Read randomization failed")
        finish_item(rd_tr);
    endtask

endclass

//==========================================================================
// 1. Single write-read test
//==========================================================================
class axi4_single_wr_rd_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_single_wr_rd_seq)

    function new(string name = "axi4_single_wr_rd_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "Starting single write-read sequence", UVM_MEDIUM)
        write_then_read(.addr(64'h0000), .len(0), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_INCR));
        write_then_read(.addr(64'h0100), .len(0), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_INCR));
        write_then_read(.addr(64'h0200), .len(0), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_INCR));
    endtask

endclass

//==========================================================================
// 2. INCR burst test
//==========================================================================
class axi4_incr_burst_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_incr_burst_seq)

    function new(string name = "axi4_incr_burst_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "Starting INCR burst sequence", UVM_MEDIUM)
        // 4-beat INCR burst
        write_then_read(.addr(64'h1000), .len(3), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_INCR));
        // 8-beat INCR burst
        write_then_read(.addr(64'h2000), .len(7), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_INCR));
        // 16-beat INCR burst
        write_then_read(.addr(64'h3000), .len(15), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_INCR));
    endtask

endclass

//==========================================================================
// 3. WRAP burst test
//==========================================================================
class axi4_wrap_burst_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_wrap_burst_seq)

    function new(string name = "axi4_wrap_burst_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "Starting WRAP burst sequence", UVM_MEDIUM)
        // 2-beat WRAP
        write_then_read(.addr(64'h4000), .len(1), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_WRAP));
        // 4-beat WRAP
        write_then_read(.addr(64'h5000), .len(3), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_WRAP));
        // 8-beat WRAP
        write_then_read(.addr(64'h6000), .len(7), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_WRAP));
        // 16-beat WRAP
        write_then_read(.addr(64'h7000), .len(15), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_WRAP));
    endtask

endclass

//==========================================================================
// 4. FIXED burst test
//==========================================================================
class axi4_fixed_burst_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_fixed_burst_seq)

    function new(string name = "axi4_fixed_burst_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "Starting FIXED burst sequence", UVM_MEDIUM)
        // 1-beat FIXED
        write_then_read(.addr(64'h8000), .len(0), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_FIXED));
        // 4-beat FIXED (each beat overwrites same address)
        write_then_read(.addr(64'h8100), .len(3), .size(AXI4_SIZE_MAX), .burst(AXI4_BURST_FIXED));
    endtask

endclass

//==========================================================================
// 5. Narrow transfer test
//==========================================================================
class axi4_narrow_transfer_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_narrow_transfer_seq)

    function new(string name = "axi4_narrow_transfer_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "Starting narrow transfer sequence", UVM_MEDIUM)
        // 4-byte narrow transfers (size=2)
        write_then_read(.addr(64'h9000), .len(3), .size(2), .burst(AXI4_BURST_INCR));
        // 8-byte narrow transfers (size=3)
        write_then_read(.addr(64'h9100), .len(7), .size(3), .burst(AXI4_BURST_INCR));
        // 1-byte narrow transfers (size=0)
        write_then_read(.addr(64'h9200), .len(3), .size(0), .burst(AXI4_BURST_INCR));
    endtask

endclass

//==========================================================================
// 6. Unaligned transfer test
//==========================================================================
class axi4_unaligned_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_unaligned_seq)

    function new(string name = "axi4_unaligned_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "Starting unaligned transfer sequence", UVM_MEDIUM)
        // Unaligned 4-byte INCR (address not aligned to 4B)
        write_then_read(.addr(64'hA002), .len(3), .size(2), .burst(AXI4_BURST_INCR));
        // Unaligned 8-byte INCR
        write_then_read(.addr(64'hA104), .len(3), .size(3), .burst(AXI4_BURST_INCR));
    endtask

endclass

//==========================================================================
// 7. Byte strobe test
//==========================================================================
class axi4_byte_strobe_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_byte_strobe_seq)

    function new(string name = "axi4_byte_strobe_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction wr_tr, rd_tr;

        `uvm_info("SEQ", "Starting byte strobe sequence", UVM_MEDIUM)

        // Write with partial strobes - only write some bytes
        wr_tr = axi4_transaction::type_id::create("wr_tr");
        start_item(wr_tr);
        if (!wr_tr.randomize() with {
            rw    == AXI4_WRITE;
            addr  == 64'hB000;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            lock  == 0;
        }) `uvm_fatal("SEQ", "Randomization failed")
        // Manually set partial strobe: only first 8 bytes
        wr_tr.strb[0] = {AXI4_STRB_WIDTH{1'b0}};
        wr_tr.strb[0][7:0] = 8'hFF;
        finish_item(wr_tr);

        // Read back - only the strobed bytes should match
        rd_tr = axi4_transaction::type_id::create("rd_tr");
        start_item(rd_tr);
        if (!rd_tr.randomize() with {
            rw    == AXI4_READ;
            addr  == 64'hB000;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            lock  == 0;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(rd_tr);

        // Second write with different partial strobe
        wr_tr = axi4_transaction::type_id::create("wr_tr2");
        start_item(wr_tr);
        if (!wr_tr.randomize() with {
            rw    == AXI4_WRITE;
            addr  == 64'hB100;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            lock  == 0;
        }) `uvm_fatal("SEQ", "Randomization failed")
        // Only even bytes
        for (int i = 0; i < AXI4_STRB_WIDTH; i++)
            wr_tr.strb[0][i] = (i % 2 == 0) ? 1'b1 : 1'b0;
        finish_item(wr_tr);

        rd_tr = axi4_transaction::type_id::create("rd_tr2");
        start_item(rd_tr);
        if (!rd_tr.randomize() with {
            rw    == AXI4_READ;
            addr  == 64'hB100;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            lock  == 0;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(rd_tr);
    endtask

endclass

//==========================================================================
// 8. Outstanding transactions test (sequential but rapid)
//==========================================================================
class axi4_outstanding_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_outstanding_seq)

    function new(string name = "axi4_outstanding_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction tr;

        `uvm_info("SEQ", "Starting outstanding transactions sequence", UVM_MEDIUM)

        // Write multiple addresses back-to-back
        for (int i = 0; i < 8; i++) begin
            tr = axi4_transaction::type_id::create($sformatf("wr_%0d", i));
            start_item(tr);
            if (!tr.randomize() with {
                rw    == AXI4_WRITE;
                addr  == 64'hC000 + i * 64'h100;
                len   == 3;
                size  == AXI4_SIZE_MAX;
                burst == AXI4_BURST_INCR;
                id    == i[3:0];
                lock  == 0;
            }) `uvm_fatal("SEQ", "Randomization failed")
            finish_item(tr);
        end

        // Read them all back
        for (int i = 0; i < 8; i++) begin
            tr = axi4_transaction::type_id::create($sformatf("rd_%0d", i));
            start_item(tr);
            if (!tr.randomize() with {
                rw    == AXI4_READ;
                addr  == 64'hC000 + i * 64'h100;
                len   == 3;
                size  == AXI4_SIZE_MAX;
                burst == AXI4_BURST_INCR;
                id    == i[3:0];
                lock  == 0;
            }) `uvm_fatal("SEQ", "Randomization failed")
            finish_item(tr);
        end
    endtask

endclass

//==========================================================================
// 9. Back-to-back transactions
//==========================================================================
class axi4_back2back_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_back2back_seq)

    function new(string name = "axi4_back2back_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "Starting back-to-back sequence", UVM_MEDIUM)
        for (int i = 0; i < 10; i++) begin
            write_then_read(
                .addr(64'hD000 + i * 64'h100),
                .len(0),
                .size(AXI4_SIZE_MAX),
                .burst(AXI4_BURST_INCR)
            );
        end
    endtask

endclass

//==========================================================================
// 10. Maximum burst length test (256 beats)
//==========================================================================
class axi4_max_burst_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_max_burst_seq)

    function new(string name = "axi4_max_burst_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "Starting max burst length sequence (256 beats)", UVM_MEDIUM)
        // 256-beat INCR burst with smaller size to fit in 4KB
        // size=2 (4 bytes), 256 beats = 1024 bytes < 4KB
        write_then_read(.addr(64'hE000), .len(255), .size(2), .burst(AXI4_BURST_INCR));
    endtask

endclass

//==========================================================================
// 11. Exclusive access test
//==========================================================================
class axi4_exclusive_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_exclusive_seq)

    function new(string name = "axi4_exclusive_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction wr_tr, rd_tr;

        `uvm_info("SEQ", "Starting exclusive access sequence", UVM_MEDIUM)

        // Step 1: Normal write to establish data
        wr_tr = axi4_transaction::type_id::create("normal_wr");
        start_item(wr_tr);
        if (!wr_tr.randomize() with {
            rw    == AXI4_WRITE;
            addr  == 64'hF000;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            id    == 1;
            lock  == 0;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(wr_tr);

        // Step 2: Exclusive read
        rd_tr = axi4_transaction::type_id::create("excl_rd");
        start_item(rd_tr);
        if (!rd_tr.randomize() with {
            rw    == AXI4_READ;
            addr  == 64'hF000;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            id    == 1;
            lock  == 1;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(rd_tr);

        // Step 3: Exclusive write (should succeed with EXOKAY)
        wr_tr = axi4_transaction::type_id::create("excl_wr");
        start_item(wr_tr);
        if (!wr_tr.randomize() with {
            rw    == AXI4_WRITE;
            addr  == 64'hF000;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            id    == 1;
            lock  == 1;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(wr_tr);

        // Check EXOKAY response
        if (wr_tr.bresp != AXI4_RESP_EXOKAY)
            `uvm_error("SEQ", $sformatf("Exclusive write should have EXOKAY, got %0b", wr_tr.bresp))
        else
            `uvm_info("SEQ", "Exclusive write succeeded with EXOKAY", UVM_MEDIUM)

        // Step 4: Read back to verify exclusive write
        rd_tr = axi4_transaction::type_id::create("verify_rd");
        start_item(rd_tr);
        if (!rd_tr.randomize() with {
            rw    == AXI4_READ;
            addr  == 64'hF000;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            id    == 1;
            lock  == 0;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(rd_tr);

        // Step 5: Test exclusive failure path
        // Exclusive read
        rd_tr = axi4_transaction::type_id::create("excl_rd2");
        start_item(rd_tr);
        if (!rd_tr.randomize() with {
            rw    == AXI4_READ;
            addr  == 64'hF000;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            id    == 2;
            lock  == 1;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(rd_tr);

        // Normal write (invalidates exclusive monitor)
        wr_tr = axi4_transaction::type_id::create("normal_wr2");
        start_item(wr_tr);
        if (!wr_tr.randomize() with {
            rw    == AXI4_WRITE;
            addr  == 64'hF000;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            id    == 3;
            lock  == 0;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(wr_tr);

        // Exclusive write (should fail - respond OKAY)
        wr_tr = axi4_transaction::type_id::create("excl_wr_fail");
        start_item(wr_tr);
        if (!wr_tr.randomize() with {
            rw    == AXI4_WRITE;
            addr  == 64'hF000;
            len   == 0;
            size  == AXI4_SIZE_MAX;
            burst == AXI4_BURST_INCR;
            id    == 2;
            lock  == 1;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(wr_tr);

        if (wr_tr.bresp != AXI4_RESP_OKAY)
            `uvm_error("SEQ", $sformatf("Failed exclusive write should have OKAY, got %0b", wr_tr.bresp))
        else
            `uvm_info("SEQ", "Exclusive write correctly failed with OKAY", UVM_MEDIUM)
    endtask

endclass

//==========================================================================
// 12. Mixed read/write test
//==========================================================================
class axi4_mixed_rw_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_mixed_rw_seq)

    function new(string name = "axi4_mixed_rw_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction tr;

        `uvm_info("SEQ", "Starting mixed read/write sequence", UVM_MEDIUM)

        // Write several addresses
        for (int i = 0; i < 5; i++) begin
            tr = axi4_transaction::type_id::create($sformatf("wr_%0d", i));
            start_item(tr);
            if (!tr.randomize() with {
                rw    == AXI4_WRITE;
                addr  == 64'h0400 + i * 64'h100;
                len   == i[7:0];
                size  == AXI4_SIZE_MAX;
                burst == AXI4_BURST_INCR;
                lock  == 0;
            }) `uvm_fatal("SEQ", "Randomization failed")
            finish_item(tr);
        end

        // Read them back in reverse order
        for (int i = 4; i >= 0; i--) begin
            tr = axi4_transaction::type_id::create($sformatf("rd_%0d", i));
            start_item(tr);
            if (!tr.randomize() with {
                rw    == AXI4_READ;
                addr  == 64'h0400 + i * 64'h100;
                len   == i[7:0];
                size  == AXI4_SIZE_MAX;
                burst == AXI4_BURST_INCR;
                lock  == 0;
            }) `uvm_fatal("SEQ", "Randomization failed")
            finish_item(tr);
        end

        // Interleaved write-read
        for (int i = 0; i < 5; i++) begin
            write_then_read(
                .addr(64'h0900 + i * 64'h100),
                .len(2),
                .size(AXI4_SIZE_MAX),
                .burst(AXI4_BURST_INCR)
            );
        end
    endtask

endclass

//==========================================================================
// 13. Random stress test
//==========================================================================
class axi4_random_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_random_seq)

    int unsigned num_transactions = 20;

    function new(string name = "axi4_random_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction wr_tr, rd_tr;
        bit [AXI4_ADDR_WIDTH-1:0] addr_list[$];

        `uvm_info("SEQ", $sformatf("Starting random sequence with %0d transactions", num_transactions), UVM_MEDIUM)

        // Random writes
        for (int i = 0; i < num_transactions; i++) begin
            wr_tr = axi4_transaction::type_id::create($sformatf("rnd_wr_%0d", i));
            start_item(wr_tr);
            if (!wr_tr.randomize() with {
                rw   == AXI4_WRITE;
                lock == 0;
                len  <= 7;
            }) `uvm_fatal("SEQ", "Randomization failed")
            finish_item(wr_tr);
            addr_list.push_back(wr_tr.addr);
        end

        // Read back all written addresses
        foreach (addr_list[i]) begin
            rd_tr = axi4_transaction::type_id::create($sformatf("rnd_rd_%0d", i));
            start_item(rd_tr);
            if (!rd_tr.randomize() with {
                rw    == AXI4_READ;
                addr  == addr_list[i];
                len   == 0;
                size  == AXI4_SIZE_MAX;
                burst == AXI4_BURST_INCR;
                lock  == 0;
            }) `uvm_fatal("SEQ", "Randomization failed")
            finish_item(rd_tr);
        end
    endtask

endclass

`endif
