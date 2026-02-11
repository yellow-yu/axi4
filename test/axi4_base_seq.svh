//==========================================================================
// axi4_base_seq.svh - AXI4 Base Sequence with helper tasks
//==========================================================================

`ifndef AXI4_BASE_SEQ_SVH
`define AXI4_BASE_SEQ_SVH

class axi4_base_seq extends uvm_sequence #(axi4_transaction);

    `uvm_object_utils(axi4_base_seq)

    function new(string name = "axi4_base_seq");
        super.new(name);
    endfunction

    //----------------------------------------------------------------------
    // Helper: Send a write transaction with random data
    //----------------------------------------------------------------------
    virtual task do_write(
        input bit [AXI4_VIP_ADDR_W-1:0] target_addr,
        input bit [7:0]                  target_len    = 0,
        input bit [2:0]                  target_size   = $clog2(AXI4_VIP_STRB_W),
        input bit [1:0]                  target_burst  = AXI4_INCR,
        input bit [AXI4_VIP_ID_W-1:0]   target_id     = 0,
        input bit                        target_lock   = 0
    );
        axi4_transaction tr;
        tr = axi4_transaction::type_id::create("wr_tr");

        start_item(tr);
        assert(tr.randomize() with {
            txn_type   == AXI4_WRITE;
            addr       == target_addr;
            burst_len  == target_len;
            burst_size == target_size;
            burst_type == target_burst;
            id         == target_id;
            lock       == target_lock;
        }) else `uvm_fatal("SEQ", "Write randomization failed")
        finish_item(tr);
    endtask

    //----------------------------------------------------------------------
    // Helper: Send a write transaction with specific data and strobe
    //----------------------------------------------------------------------
    virtual task do_write_data(
        input bit [AXI4_VIP_ADDR_W-1:0] target_addr,
        input bit [7:0]                  target_len,
        input bit [2:0]                  target_size,
        input bit [1:0]                  target_burst,
        input bit [AXI4_VIP_ID_W-1:0]   target_id,
        input bit                        target_lock,
        input bit [AXI4_VIP_DATA_W-1:0] wr_data[],
        input bit [AXI4_VIP_STRB_W-1:0] wr_strb[]
    );
        axi4_transaction tr;
        tr = axi4_transaction::type_id::create("wr_tr");
        tr.c_strb_default.constraint_mode(0); // Allow custom strobe

        start_item(tr);
        assert(tr.randomize() with {
            txn_type   == AXI4_WRITE;
            addr       == target_addr;
            burst_len  == target_len;
            burst_size == target_size;
            burst_type == target_burst;
            id         == target_id;
            lock       == target_lock;
        }) else `uvm_fatal("SEQ", "Write randomization failed")

        // Override data and strobe arrays
        for (int i = 0; i < tr.data.size(); i++) begin
            if (i < wr_data.size()) tr.data[i] = wr_data[i];
            if (i < wr_strb.size()) tr.strb[i] = wr_strb[i];
        end

        finish_item(tr);
    endtask

    //----------------------------------------------------------------------
    // Helper: Send a read transaction
    //----------------------------------------------------------------------
    virtual task do_read(
        input  bit [AXI4_VIP_ADDR_W-1:0] target_addr,
        input  bit [7:0]                  target_len   = 0,
        input  bit [2:0]                  target_size  = $clog2(AXI4_VIP_STRB_W),
        input  bit [1:0]                  target_burst = AXI4_INCR,
        input  bit [AXI4_VIP_ID_W-1:0]   target_id    = 0,
        input  bit                        target_lock  = 0,
        output axi4_transaction           rsp_tr
    );
        axi4_transaction tr;
        tr = axi4_transaction::type_id::create("rd_tr");

        start_item(tr);
        assert(tr.randomize() with {
            txn_type   == AXI4_READ;
            addr       == target_addr;
            burst_len  == target_len;
            burst_size == target_size;
            burst_type == target_burst;
            id         == target_id;
            lock       == target_lock;
        }) else `uvm_fatal("SEQ", "Read randomization failed")
        finish_item(tr);

        rsp_tr = tr;
    endtask

    //----------------------------------------------------------------------
    // Helper: Generate random data array
    //----------------------------------------------------------------------
    function void gen_random_data(
        input  int num_beats,
        output bit [AXI4_VIP_DATA_W-1:0] data_arr[]
    );
        data_arr = new[num_beats];
        for (int i = 0; i < num_beats; i++)
            data_arr[i] = {$urandom(), $urandom()};
    endfunction

    //----------------------------------------------------------------------
    // Helper: Generate full strobe array
    //----------------------------------------------------------------------
    function void gen_full_strb(
        input  int num_beats,
        output bit [AXI4_VIP_STRB_W-1:0] strb_arr[]
    );
        strb_arr = new[num_beats];
        for (int i = 0; i < num_beats; i++)
            strb_arr[i] = {AXI4_VIP_STRB_W{1'b1}};
    endfunction

endclass

`endif
