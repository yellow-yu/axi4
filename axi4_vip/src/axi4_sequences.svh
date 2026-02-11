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

    // Helper: create a transaction with specific fields and random data
    function axi4_transaction create_tr(
        string                    name,
        axi4_dir_t               dir,
        bit [AXI4_ADDR_WIDTH-1:0] tr_addr,
        bit [7:0]                 tr_len,
        bit [2:0]                 tr_size,
        axi4_burst_t             tr_burst,
        bit [AXI4_ID_WIDTH-1:0]  tr_id,
        bit                      tr_lock
    );
        axi4_transaction tr;
        tr = axi4_transaction::type_id::create(name);

        // Set specific fields directly (avoid randomize with name-collision issues)
        tr.rw      = dir;
        tr.addr    = tr_addr;
        tr.len     = tr_len;
        tr.size    = tr_size;
        tr.burst   = tr_burst;
        tr.id      = tr_id;
        tr.lock    = tr_lock;
        tr.cache   = 4'h0;
        tr.prot    = 3'h0;
        tr.qos     = 4'h0;
        tr.region  = 4'h0;
        tr.user    = '0;

        // Allocate and fill data with random values
        tr.data = new[tr_len + 1];
        foreach (tr.data[i])
            for (int j = 0; j < AXI4_DATA_WIDTH/32; j++)
                tr.data[i][j*32 +: 32] = $urandom;

        // Compute proper byte strobes
        tr.compute_strobes();

        return tr;
    endfunction

    // Helper: do a write then read-back at the same address/params
    task write_then_read(
        bit [AXI4_ADDR_WIDTH-1:0] wr_addr,
        bit [7:0]                 wr_len   = 0,
        bit [2:0]                 wr_size  = AXI4_SIZE_MAX,
        axi4_burst_t             wr_burst = AXI4_BURST_INCR,
        bit [AXI4_ID_WIDTH-1:0]  wr_id    = 0,
        bit                      wr_lock  = 0
    );
        axi4_transaction wr_tr, rd_tr;

        // WRITE
        wr_tr = create_tr("wr_tr", AXI4_WRITE, wr_addr, wr_len, wr_size, wr_burst, wr_id, wr_lock);
        start_item(wr_tr);
        finish_item(wr_tr);

        // READ (same address/params, no lock for read-back)
        rd_tr = create_tr("rd_tr", AXI4_READ, wr_addr, wr_len, wr_size, wr_burst, wr_id, 1'b0);
        start_item(rd_tr);
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
        write_then_read(.wr_addr(64'h0000), .wr_len(0), .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_INCR));
        write_then_read(.wr_addr(64'h0100), .wr_len(0), .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_INCR));
        write_then_read(.wr_addr(64'h0200), .wr_len(0), .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_INCR));
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
        write_then_read(.wr_addr(64'h1000), .wr_len(3),  .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_INCR));
        write_then_read(.wr_addr(64'h2000), .wr_len(7),  .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_INCR));
        write_then_read(.wr_addr(64'h3000), .wr_len(15), .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_INCR));
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
        write_then_read(.wr_addr(64'h4000), .wr_len(1),  .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_WRAP));
        write_then_read(.wr_addr(64'h5000), .wr_len(3),  .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_WRAP));
        write_then_read(.wr_addr(64'h6000), .wr_len(7),  .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_WRAP));
        write_then_read(.wr_addr(64'h7000), .wr_len(15), .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_WRAP));
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
        write_then_read(.wr_addr(64'h8000), .wr_len(0), .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_FIXED));
        write_then_read(.wr_addr(64'h8100), .wr_len(3), .wr_size(AXI4_SIZE_MAX), .wr_burst(AXI4_BURST_FIXED));
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
        write_then_read(.wr_addr(64'h9000), .wr_len(3), .wr_size(2), .wr_burst(AXI4_BURST_INCR));
        write_then_read(.wr_addr(64'h9100), .wr_len(7), .wr_size(3), .wr_burst(AXI4_BURST_INCR));
        write_then_read(.wr_addr(64'h9200), .wr_len(3), .wr_size(0), .wr_burst(AXI4_BURST_INCR));
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
        write_then_read(.wr_addr(64'hA002), .wr_len(3), .wr_size(2), .wr_burst(AXI4_BURST_INCR));
        write_then_read(.wr_addr(64'hA104), .wr_len(3), .wr_size(3), .wr_burst(AXI4_BURST_INCR));
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

        // Write with partial strobes - only first 8 bytes
        wr_tr = create_tr("wr_tr", AXI4_WRITE, 64'hB000, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 0, 0);
        wr_tr.strb[0] = {AXI4_STRB_WIDTH{1'b0}};
        wr_tr.strb[0][7:0] = 8'hFF;
        start_item(wr_tr);
        finish_item(wr_tr);

        // Read back
        rd_tr = create_tr("rd_tr", AXI4_READ, 64'hB000, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 0, 0);
        start_item(rd_tr);
        finish_item(rd_tr);

        // Write with even-byte-only strobe
        wr_tr = create_tr("wr_tr2", AXI4_WRITE, 64'hB100, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 0, 0);
        for (int i = 0; i < AXI4_STRB_WIDTH; i++)
            wr_tr.strb[0][i] = (i % 2 == 0) ? 1'b1 : 1'b0;
        start_item(wr_tr);
        finish_item(wr_tr);

        rd_tr = create_tr("rd_tr2", AXI4_READ, 64'hB100, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 0, 0);
        start_item(rd_tr);
        finish_item(rd_tr);
    endtask

endclass

//==========================================================================
// 8. Outstanding transactions test (sequential writes then reads)
//==========================================================================
class axi4_outstanding_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_outstanding_seq)

    function new(string name = "axi4_outstanding_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction tr;

        `uvm_info("SEQ", "Starting outstanding transactions sequence", UVM_MEDIUM)

        // Write 8 addresses
        for (int i = 0; i < 8; i++) begin
            tr = create_tr($sformatf("wr_%0d", i), AXI4_WRITE,
                           64'hC000 + i * 64'h100, 3, AXI4_SIZE_MAX,
                           AXI4_BURST_INCR, i[3:0], 0);
            start_item(tr);
            finish_item(tr);
        end

        // Read them all back
        for (int i = 0; i < 8; i++) begin
            tr = create_tr($sformatf("rd_%0d", i), AXI4_READ,
                           64'hC000 + i * 64'h100, 3, AXI4_SIZE_MAX,
                           AXI4_BURST_INCR, i[3:0], 0);
            start_item(tr);
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
            write_then_read(.wr_addr(64'hD000 + i * 64'h100),
                            .wr_len(0), .wr_size(AXI4_SIZE_MAX),
                            .wr_burst(AXI4_BURST_INCR));
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
        // 256-beat INCR burst with size=2 (4 bytes), total = 1024 bytes < 4KB
        write_then_read(.wr_addr(64'hE000), .wr_len(255), .wr_size(2), .wr_burst(AXI4_BURST_INCR));
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
        wr_tr = create_tr("normal_wr", AXI4_WRITE, 64'hF000, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 1, 0);
        start_item(wr_tr);
        finish_item(wr_tr);

        // Step 2: Exclusive read
        rd_tr = create_tr("excl_rd", AXI4_READ, 64'hF000, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 1, 1);
        start_item(rd_tr);
        finish_item(rd_tr);

        // Step 3: Exclusive write (should succeed with EXOKAY)
        wr_tr = create_tr("excl_wr", AXI4_WRITE, 64'hF000, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 1, 1);
        start_item(wr_tr);
        finish_item(wr_tr);

        if (wr_tr.bresp != AXI4_RESP_EXOKAY)
            `uvm_error("SEQ", $sformatf("Exclusive write should get EXOKAY, got %0b", wr_tr.bresp))
        else
            `uvm_info("SEQ", "Exclusive write succeeded with EXOKAY", UVM_MEDIUM)

        // Step 4: Read back to verify exclusive write
        rd_tr = create_tr("verify_rd", AXI4_READ, 64'hF000, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 1, 0);
        start_item(rd_tr);
        finish_item(rd_tr);

        // Step 5: Test exclusive failure path
        // Exclusive read with ID=2
        rd_tr = create_tr("excl_rd2", AXI4_READ, 64'hF000, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 2, 1);
        start_item(rd_tr);
        finish_item(rd_tr);

        // Normal write (invalidates exclusive monitor)
        wr_tr = create_tr("normal_wr2", AXI4_WRITE, 64'hF000, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 3, 0);
        start_item(wr_tr);
        finish_item(wr_tr);

        // Exclusive write with ID=2 (should fail - respond OKAY)
        wr_tr = create_tr("excl_wr_fail", AXI4_WRITE, 64'hF000, 0, AXI4_SIZE_MAX, AXI4_BURST_INCR, 2, 1);
        start_item(wr_tr);
        finish_item(wr_tr);

        if (wr_tr.bresp != AXI4_RESP_OKAY)
            `uvm_error("SEQ", $sformatf("Failed exclusive write should get OKAY, got %0b", wr_tr.bresp))
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
            tr = create_tr($sformatf("wr_%0d", i), AXI4_WRITE,
                           64'h0400 + i * 64'h100, i[7:0], AXI4_SIZE_MAX,
                           AXI4_BURST_INCR, i[3:0], 0);
            start_item(tr);
            finish_item(tr);
        end

        // Read them back in reverse order
        for (int i = 4; i >= 0; i--) begin
            tr = create_tr($sformatf("rd_%0d", i), AXI4_READ,
                           64'h0400 + i * 64'h100, i[7:0], AXI4_SIZE_MAX,
                           AXI4_BURST_INCR, i[3:0], 0);
            start_item(tr);
            finish_item(tr);
        end

        // Interleaved write-read
        for (int i = 0; i < 5; i++) begin
            write_then_read(.wr_addr(64'h0900 + i * 64'h100),
                            .wr_len(2), .wr_size(AXI4_SIZE_MAX),
                            .wr_burst(AXI4_BURST_INCR));
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
        bit [7:0] len_list[$];
        bit [2:0] size_list[$];
        axi4_burst_t burst_list[$];

        `uvm_info("SEQ", $sformatf("Starting random sequence with %0d transactions", num_transactions), UVM_MEDIUM)

        // Random writes with constrained randomization
        for (int i = 0; i < num_transactions; i++) begin
            bit [AXI4_ADDR_WIDTH-1:0] rnd_addr;
            bit [7:0] rnd_len;
            bit [2:0] rnd_size;
            axi4_burst_t rnd_burst;

            // Generate random params
            rnd_size  = $urandom_range(0, AXI4_SIZE_MAX);
            rnd_burst = axi4_burst_t'($urandom_range(0, 2));
            rnd_addr  = ($urandom_range(0, 64'hF000 / (1 << rnd_size))) * (1 << rnd_size);

            if (rnd_burst == AXI4_BURST_WRAP)
                rnd_len = (1 << $urandom_range(1, 4)) - 1; // 1,3,7,15
            else if (rnd_burst == AXI4_BURST_FIXED)
                rnd_len = $urandom_range(0, 15);
            else
                rnd_len = $urandom_range(0, 7);

            wr_tr = create_tr($sformatf("rnd_wr_%0d", i), AXI4_WRITE,
                              rnd_addr, rnd_len, rnd_size, rnd_burst, i[3:0], 0);
            start_item(wr_tr);
            finish_item(wr_tr);

            addr_list.push_back(rnd_addr);
            len_list.push_back(rnd_len);
            size_list.push_back(rnd_size);
            burst_list.push_back(rnd_burst);
        end

        // Read back all written addresses with matching params
        foreach (addr_list[i]) begin
            rd_tr = create_tr($sformatf("rnd_rd_%0d", i), AXI4_READ,
                              addr_list[i], len_list[i], size_list[i],
                              burst_list[i], i[3:0], 0);
            start_item(rd_tr);
            finish_item(rd_tr);
        end
    endtask

endclass

`endif
