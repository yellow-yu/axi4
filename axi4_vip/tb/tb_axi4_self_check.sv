//==========================================================================
// Self-checking AXI4 Testbench (non-UVM, compatible with Icarus Verilog)
// Uses module-level shared arrays to work around iverilog limitations.
//==========================================================================
`timescale 1ns/1ps

module tb_axi4_self_check;

    //----------------------------------------------------------------------
    // Parameters
    //----------------------------------------------------------------------
    parameter ID_W    = 4;
    parameter ADDR_W  = 32;
    parameter DATA_W  = 64;
    parameter STRB_W  = DATA_W / 8;  // 8

    //----------------------------------------------------------------------
    // Clock and Reset
    //----------------------------------------------------------------------
    reg clk = 0;
    reg rstn = 0;
    always #5 clk = ~clk;

    //----------------------------------------------------------------------
    // AXI4 Bus Signals
    //----------------------------------------------------------------------
    reg  [ID_W-1:0]   awid, arid;
    reg  [ADDR_W-1:0] awaddr, araddr;
    reg  [7:0]        awlen, arlen;
    reg  [2:0]        awsize, arsize;
    reg  [1:0]        awburst, arburst;
    reg               awlock, arlock;
    reg  [3:0]        awcache, arcache;
    reg  [2:0]        awprot, arprot;
    reg  [3:0]        awqos, arqos;
    reg  [3:0]        awregion, arregion;
    reg               awvalid, arvalid;
    reg  [DATA_W-1:0] wdata;
    reg  [STRB_W-1:0] wstrb;
    reg               wlast, wvalid;
    reg               bready, rready;

    // Slave-driven signals
    reg               s_awready, s_wready, s_arready;
    reg  [ID_W-1:0]   s_bid, s_rid;
    reg  [1:0]        s_bresp, s_rresp;
    reg               s_bvalid, s_rvalid, s_rlast;
    reg  [DATA_W-1:0] s_rdata;

    wire              awready = s_awready;
    wire              wready  = s_wready;
    wire [ID_W-1:0]   bid     = s_bid;
    wire [1:0]        bresp   = s_bresp;
    wire              bvalid  = s_bvalid;
    wire              arready = s_arready;
    wire [ID_W-1:0]   rid     = s_rid;
    wire [DATA_W-1:0] rdata   = s_rdata;
    wire [1:0]        rresp   = s_rresp;
    wire              rlast   = s_rlast;
    wire              rvalid  = s_rvalid;

    //----------------------------------------------------------------------
    // Memories
    //----------------------------------------------------------------------
    reg [7:0] slave_mem [0:65535];
    reg [7:0] ref_mem   [0:65535];

    // Exclusive monitor
    reg [ADDR_W-1:0] excl_addr [0:15];
    reg [7:0]        excl_len  [0:15];
    reg [2:0]        excl_size [0:15];
    reg              excl_valid[0:15];

    //----------------------------------------------------------------------
    // Shared data arrays for master/checker communication
    //----------------------------------------------------------------------
    reg [DATA_W-1:0] shared_wdata [0:255];
    reg [STRB_W-1:0] shared_wstrb [0:255];
    reg [DATA_W-1:0] shared_rdata [0:255];
    reg [1:0]        shared_rresp [0:255];
    reg [1:0]        shared_bresp_val;

    // Shared parameters for current transaction
    reg [ID_W-1:0]   cur_id;
    reg [ADDR_W-1:0] cur_addr;
    reg [7:0]        cur_len;
    reg [2:0]        cur_size;
    reg [1:0]        cur_burst;
    reg              cur_lock;

    //----------------------------------------------------------------------
    // Test counters
    //----------------------------------------------------------------------
    integer test_pass = 0;
    integer test_fail = 0;
    integer test_num  = 0;

    //----------------------------------------------------------------------
    // Init
    //----------------------------------------------------------------------
    integer init_i;
    initial begin
        awid = 0; awaddr = 0; awlen = 0; awsize = 0; awburst = 0;
        awlock = 0; awcache = 0; awprot = 0; awqos = 0; awregion = 0;
        awvalid = 0;
        wdata = 0; wstrb = 0; wlast = 0; wvalid = 0;
        bready = 0;
        arid = 0; araddr = 0; arlen = 0; arsize = 0; arburst = 0;
        arlock = 0; arcache = 0; arprot = 0; arqos = 0; arregion = 0;
        arvalid = 0;
        rready = 0;
        s_awready = 0; s_wready = 0;
        s_bvalid = 0; s_bid = 0; s_bresp = 0;
        s_arready = 0; s_rvalid = 0; s_rid = 0;
        s_rdata = 0; s_rresp = 0; s_rlast = 0;
        for (init_i = 0; init_i < 65536; init_i = init_i + 1) begin
            slave_mem[init_i] = 8'h00;
            ref_mem[init_i]   = 8'h00;
        end
        for (init_i = 0; init_i < 16; init_i = init_i + 1)
            excl_valid[init_i] = 0;
    end

    initial begin
        rstn = 0; #100; rstn = 1;
    end

    initial begin
        #5_000_000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

    //----------------------------------------------------------------------
    // Address calculation function
    //----------------------------------------------------------------------
    function [ADDR_W-1:0] calc_addr;
        input [ADDR_W-1:0] start_addr;
        input [7:0]        len;
        input [2:0]        size;
        input [1:0]        burst;
        input integer      beat;
        integer nb;
        reg [ADDR_W-1:0] al, lw, uw, a;
        integer total;
    begin
        nb = 1 << size;
        al = (start_addr / nb) * nb;
        if (burst == 2'b00) begin
            a = start_addr;
        end else if (burst == 2'b01) begin
            if (beat == 0) a = start_addr;
            else           a = al + beat * nb;
        end else begin
            total = (len + 1) * nb;
            lw = (start_addr / total) * total;
            uw = lw + total;
            if (beat == 0) a = start_addr;
            else begin
                a = al + beat * nb;
                if (a >= uw) a = lw + (a - uw);
            end
        end
        calc_addr = a;
    end
    endfunction

    //======================================================================
    // SLAVE WRITE HANDLER
    //======================================================================
    task slave_write_handler;
        reg [ID_W-1:0]   sw_id;
        reg [ADDR_W-1:0] sw_addr;
        reg [7:0]        sw_len;
        reg [2:0]        sw_size;
        reg [1:0]        sw_burst;
        reg              sw_lock;
        integer si, sj;
        integer snb;
        reg [ADDR_W-1:0] sba, sbb;
        reg [DATA_W-1:0] swd;
        reg [STRB_W-1:0] sws;
        reg [1:0] sresp;
    begin
        forever begin
            s_awready <= 1'b1;
            @(posedge clk);
            while (!awvalid) @(posedge clk);
            sw_id    = awid;
            sw_addr  = awaddr;
            sw_len   = awlen;
            sw_size  = awsize;
            sw_burst = awburst;
            sw_lock  = awlock;
            s_awready <= 1'b0;

            snb = 1 << sw_size;

            for (si = 0; si <= sw_len; si = si + 1) begin
                s_wready <= 1'b1;
                @(posedge clk);
                while (!wvalid) @(posedge clk);
                swd = wdata;
                sws = wstrb;
                s_wready <= 1'b0;

                sba = calc_addr(sw_addr, sw_len, sw_size, sw_burst, si);
                sbb = (sba / STRB_W) * STRB_W;
                for (sj = 0; sj < STRB_W; sj = sj + 1) begin
                    if (sws[sj] && (sbb + sj) < 65536)
                        slave_mem[sbb + sj] = swd[sj*8 +: 8];
                end
            end

            if (sw_lock) begin
                if (excl_valid[sw_id] &&
                    excl_addr[sw_id] == sw_addr &&
                    excl_len[sw_id]  == sw_len &&
                    excl_size[sw_id] == sw_size) begin
                    sresp = 2'b01;
                    excl_valid[sw_id] = 0;
                end else begin
                    sresp = 2'b00;
                end
            end else begin
                sresp = 2'b00;
                // Invalidate overlapping exclusive monitors
                for (sj = 0; sj < 16; sj = sj + 1) begin
                    if (excl_valid[sj] && excl_addr[sj] == sw_addr)
                        excl_valid[sj] = 0;
                end
            end

            @(posedge clk);
            s_bvalid <= 1'b1;
            s_bid    <= sw_id;
            s_bresp  <= sresp;
            @(posedge clk);
            while (!bready) @(posedge clk);
            s_bvalid <= 1'b0;
        end
    end
    endtask

    //======================================================================
    // SLAVE READ HANDLER
    //======================================================================
    task slave_read_handler;
        reg [ID_W-1:0]   sr_id;
        reg [ADDR_W-1:0] sr_addr;
        reg [7:0]        sr_len;
        reg [2:0]        sr_size;
        reg [1:0]        sr_burst;
        reg              sr_lock;
        integer si, sj;
        reg [ADDR_W-1:0] sba, sbb;
        reg [DATA_W-1:0] srd;
        reg [1:0] sresp;
    begin
        forever begin
            s_arready <= 1'b1;
            @(posedge clk);
            while (!arvalid) @(posedge clk);
            sr_id    = arid;
            sr_addr  = araddr;
            sr_len   = arlen;
            sr_size  = arsize;
            sr_burst = arburst;
            sr_lock  = arlock;
            s_arready <= 1'b0;

            if (sr_lock) begin
                excl_addr[sr_id]  = sr_addr;
                excl_len[sr_id]   = sr_len;
                excl_size[sr_id]  = sr_size;
                excl_valid[sr_id] = 1;
                sresp = 2'b01;
            end else begin
                sresp = 2'b00;
            end

            for (si = 0; si <= sr_len; si = si + 1) begin
                sba = calc_addr(sr_addr, sr_len, sr_size, sr_burst, si);
                sbb = (sba / STRB_W) * STRB_W;
                srd = {DATA_W{1'b0}};
                for (sj = 0; sj < STRB_W; sj = sj + 1) begin
                    if ((sbb + sj) < 65536)
                        srd[sj*8 +: 8] = slave_mem[sbb + sj];
                end

                @(posedge clk);
                s_rvalid <= 1'b1;
                s_rid    <= sr_id;
                s_rdata  <= srd;
                s_rresp  <= sresp;
                s_rlast  <= (si == sr_len) ? 1'b1 : 1'b0;
                @(posedge clk);
                while (!rready) @(posedge clk);
                s_rvalid <= 1'b0;
                s_rlast  <= 1'b0;
            end
        end
    end
    endtask

    //======================================================================
    // MASTER WRITE: uses shared_wdata/shared_wstrb, cur_* params
    //======================================================================
    task master_write;
        integer mi;
    begin
        awvalid  <= 1'b1;
        awid     <= cur_id;
        awaddr   <= cur_addr;
        awlen    <= cur_len;
        awsize   <= cur_size;
        awburst  <= cur_burst;
        awlock   <= cur_lock;
        awcache  <= 4'h0;
        awprot   <= 3'h0;
        awqos    <= 4'h0;
        awregion <= 4'h0;
        @(posedge clk);
        while (!awready) @(posedge clk);
        awvalid <= 1'b0;

        for (mi = 0; mi <= cur_len; mi = mi + 1) begin
            wvalid <= 1'b1;
            wdata  <= shared_wdata[mi];
            wstrb  <= shared_wstrb[mi];
            wlast  <= (mi == cur_len) ? 1'b1 : 1'b0;
            @(posedge clk);
            while (!wready) @(posedge clk);
        end
        wvalid <= 1'b0;
        wlast  <= 1'b0;

        bready <= 1'b1;
        @(posedge clk);
        while (!bvalid) @(posedge clk);
        shared_bresp_val = bresp;
        bready <= 1'b0;
    end
    endtask

    //======================================================================
    // MASTER READ: stores results in shared_rdata/shared_rresp
    //======================================================================
    task master_read;
        integer mi;
    begin
        arvalid  <= 1'b1;
        arid     <= cur_id;
        araddr   <= cur_addr;
        arlen    <= cur_len;
        arsize   <= cur_size;
        arburst  <= cur_burst;
        arlock   <= cur_lock;
        arcache  <= 4'h0;
        arprot   <= 3'h0;
        arqos    <= 4'h0;
        arregion <= 4'h0;
        @(posedge clk);
        while (!arready) @(posedge clk);
        arvalid <= 1'b0;

        rready <= 1'b1;
        for (mi = 0; mi <= cur_len; mi = mi + 1) begin
            @(posedge clk);
            while (!rvalid) @(posedge clk);
            shared_rdata[mi] = rdata;
            shared_rresp[mi] = rresp;
        end
        rready <= 1'b0;
    end
    endtask

    //======================================================================
    // HELPER: Generate data and strobes, store in shared arrays
    //======================================================================
    task gen_data;
        integer gi, gj;
        integer gnb;
        reg [ADDR_W-1:0] gba;
        integer glane;
    begin
        gnb = 1 << cur_size;
        for (gi = 0; gi <= cur_len; gi = gi + 1) begin
            shared_wdata[gi] = {DATA_W{1'b0}};
            for (gj = 0; gj < STRB_W; gj = gj + 1)
                shared_wdata[gi][gj*8 +: 8] = (cur_addr[7:0] + gi * 7 + gj * 13 + 1) & 8'hFF;

            gba = calc_addr(cur_addr, cur_len, cur_size, cur_burst, gi);
            glane = gba % STRB_W;
            shared_wstrb[gi] = {STRB_W{1'b0}};
            for (gj = 0; gj < gnb && (glane + gj) < STRB_W; gj = gj + 1)
                shared_wstrb[gi][glane + gj] = 1'b1;
        end
    end
    endtask

    //======================================================================
    // HELPER: Update reference memory from shared arrays
    //======================================================================
    task update_ref;
        integer ui, uj;
        reg [ADDR_W-1:0] uba, ubb;
    begin
        for (ui = 0; ui <= cur_len; ui = ui + 1) begin
            uba = calc_addr(cur_addr, cur_len, cur_size, cur_burst, ui);
            ubb = (uba / STRB_W) * STRB_W;
            for (uj = 0; uj < STRB_W; uj = uj + 1) begin
                if (shared_wstrb[ui][uj] && (ubb + uj) < 65536)
                    ref_mem[ubb + uj] = shared_wdata[ui][uj*8 +: 8];
            end
        end
    end
    endtask

    //======================================================================
    // HELPER: Check read data against reference
    //======================================================================
    task check_data;
        input [8*32-1:0] tname;  // string as packed array
        integer ci, cj;
        integer cnb, clane;
        reg [ADDR_W-1:0] cba, cbb;
        reg [7:0] exp_b, act_b;
        integer errs;
    begin
        cnb = 1 << cur_size;
        errs = 0;
        for (ci = 0; ci <= cur_len; ci = ci + 1) begin
            cba   = calc_addr(cur_addr, cur_len, cur_size, cur_burst, ci);
            cbb   = (cba / STRB_W) * STRB_W;
            clane = cba % STRB_W;
            for (cj = 0; cj < cnb && (clane + cj) < STRB_W; cj = cj + 1) begin
                if ((cbb + clane + cj) < 65536) begin
                    exp_b = ref_mem[cbb + clane + cj];
                    act_b = shared_rdata[ci][(clane+cj)*8 +: 8];
                    if (exp_b !== act_b) begin
                        $display("  ERR: beat=%0d lane=%0d addr=0x%0h exp=0x%02h act=0x%02h",
                                 ci, clane+cj, cbb+clane+cj, exp_b, act_b);
                        errs = errs + 1;
                    end
                end
            end
        end

        test_num = test_num + 1;
        if (errs == 0) begin
            $display("  [PASS] %0s (#%0d)", tname, test_num);
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] %0s (#%0d) %0d mismatches", tname, test_num, errs);
            test_fail = test_fail + 1;
        end
    end
    endtask

    //======================================================================
    // Slave processes
    //======================================================================
    initial begin
        @(posedge rstn);
        fork
            slave_write_handler;
            slave_read_handler;
        join
    end

    //======================================================================
    // MAIN TEST
    //======================================================================
    integer t_i;

    initial begin
        @(posedge rstn);
        repeat(5) @(posedge clk);

        $display("");
        $display("==============================================");
        $display(" AXI4 VIP Self-Checking Testbench");
        $display("==============================================");
        $display("");

        // ---- Test 1: Single write-read ----
        $display("--- Test 1: Single Write-Read ---");
        cur_id = 0; cur_addr = 32'h0000; cur_len = 0; cur_size = 3;
        cur_burst = 2'b01; cur_lock = 0;
        gen_data; master_write; update_ref;
        master_read; check_data("single_wr_rd_1");

        cur_addr = 32'h0100;
        gen_data; master_write; update_ref;
        master_read; check_data("single_wr_rd_2");

        cur_addr = 32'h0200;
        gen_data; master_write; update_ref;
        master_read; check_data("single_wr_rd_3");

        // ---- Test 2: INCR burst ----
        $display("--- Test 2: INCR Burst ---");
        cur_addr = 32'h1000; cur_len = 3; cur_size = 3; cur_burst = 2'b01;
        gen_data; master_write; update_ref;
        master_read; check_data("incr_4beat");

        cur_addr = 32'h2000; cur_len = 7;
        gen_data; master_write; update_ref;
        master_read; check_data("incr_8beat");

        cur_addr = 32'h3000; cur_len = 15;
        gen_data; master_write; update_ref;
        master_read; check_data("incr_16beat");

        // ---- Test 3: WRAP burst ----
        $display("--- Test 3: WRAP Burst ---");
        cur_burst = 2'b10;
        cur_addr = 32'h4000; cur_len = 1;
        gen_data; master_write; update_ref;
        master_read; check_data("wrap_2beat");

        cur_addr = 32'h5000; cur_len = 3;
        gen_data; master_write; update_ref;
        master_read; check_data("wrap_4beat");

        cur_addr = 32'h6000; cur_len = 7;
        gen_data; master_write; update_ref;
        master_read; check_data("wrap_8beat");

        cur_addr = 32'h7000; cur_len = 15;
        gen_data; master_write; update_ref;
        master_read; check_data("wrap_16beat");

        // ---- Test 4: FIXED burst ----
        $display("--- Test 4: FIXED Burst ---");
        cur_burst = 2'b00;
        cur_addr = 32'h8000; cur_len = 0;
        gen_data; master_write; update_ref;
        master_read; check_data("fixed_1beat");

        cur_addr = 32'h8100; cur_len = 3;
        gen_data; master_write; update_ref;
        master_read; check_data("fixed_4beat");

        // ---- Test 5: Narrow transfers ----
        $display("--- Test 5: Narrow Transfers ---");
        cur_burst = 2'b01;
        cur_addr = 32'h9000; cur_len = 3; cur_size = 2;
        gen_data; master_write; update_ref;
        master_read; check_data("narrow_4B");

        cur_addr = 32'h9100; cur_size = 1;
        gen_data; master_write; update_ref;
        master_read; check_data("narrow_2B");

        cur_addr = 32'h9200; cur_size = 0;
        gen_data; master_write; update_ref;
        master_read; check_data("narrow_1B");

        // ---- Test 6: Unaligned ----
        $display("--- Test 6: Unaligned Transfers ---");
        cur_addr = 32'hA002; cur_len = 3; cur_size = 2; cur_burst = 2'b01;
        gen_data; master_write; update_ref;
        master_read; check_data("unaligned_4B");

        cur_addr = 32'hA101; cur_size = 1;
        gen_data; master_write; update_ref;
        master_read; check_data("unaligned_2B");

        // ---- Test 7: Byte strobes ----
        $display("--- Test 7: Byte Strobes ---");
        cur_addr = 32'hB000; cur_len = 0; cur_size = 3; cur_burst = 2'b01;
        gen_data;
        shared_wstrb[0] = 8'h0F;  // only lower 4 bytes
        master_write;
        // Update ref with partial strobe
        begin
            integer bi;
            reg [ADDR_W-1:0] baddr;
            baddr = (cur_addr / STRB_W) * STRB_W;
            for (bi = 0; bi < STRB_W; bi = bi + 1) begin
                if (shared_wstrb[0][bi])
                    ref_mem[baddr + bi] = shared_wdata[0][bi*8 +: 8];
            end
        end
        master_read; check_data("byte_strobe");

        // ---- Test 8: Outstanding ----
        $display("--- Test 8: Outstanding Transactions ---");
        cur_size = 3; cur_burst = 2'b01; cur_lock = 0;
        for (t_i = 0; t_i < 8; t_i = t_i + 1) begin
            cur_id = t_i[3:0];
            cur_addr = 32'hC000 + t_i * 32'h100;
            cur_len = 3;
            gen_data; master_write; update_ref;
        end
        for (t_i = 0; t_i < 8; t_i = t_i + 1) begin
            cur_id = t_i[3:0];
            cur_addr = 32'hC000 + t_i * 32'h100;
            cur_len = 3;
            master_read; check_data("outstanding");
        end

        // ---- Test 9: Back-to-back ----
        $display("--- Test 9: Back-to-Back ---");
        cur_id = 0; cur_len = 0; cur_size = 3; cur_burst = 2'b01;
        for (t_i = 0; t_i < 10; t_i = t_i + 1) begin
            cur_addr = 32'hD000 + t_i * 32'h100;
            gen_data; master_write; update_ref;
            master_read; check_data("back2back");
        end

        // ---- Test 10: Max burst ----
        $display("--- Test 10: Max Burst (256 beats) ---");
        cur_addr = 32'hE000; cur_len = 255; cur_size = 0; cur_burst = 2'b01;
        gen_data; master_write; update_ref;
        master_read; check_data("max_burst_256");

        // ---- Test 11: Exclusive access ----
        $display("--- Test 11: Exclusive Access ---");

        // Normal write
        cur_id = 1; cur_addr = 32'hF000; cur_len = 0; cur_size = 3;
        cur_burst = 2'b01; cur_lock = 0;
        gen_data; master_write; update_ref;

        // Exclusive read
        cur_lock = 1;
        master_read;
        test_num = test_num + 1;
        if (shared_rresp[0] == 2'b01) begin
            $display("  [PASS] excl_read_resp (#%0d)", test_num);
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] excl_read_resp (#%0d) got %0b", test_num, shared_rresp[0]);
            test_fail = test_fail + 1;
        end

        // Exclusive write (should succeed)
        gen_data; master_write;
        test_num = test_num + 1;
        if (shared_bresp_val == 2'b01) begin
            $display("  [PASS] excl_write_ok (#%0d)", test_num);
            test_pass = test_pass + 1;
            update_ref;
        end else begin
            $display("  [FAIL] excl_write_ok (#%0d) got %0b", test_num, shared_bresp_val);
            test_fail = test_fail + 1;
        end

        // Exclusive read with different ID
        cur_id = 2; cur_lock = 1;
        master_read;

        // Normal write invalidates exclusive
        cur_id = 3; cur_lock = 0;
        gen_data; master_write; update_ref;

        // Exclusive write should fail
        cur_id = 2; cur_lock = 1;
        gen_data; master_write;
        test_num = test_num + 1;
        if (shared_bresp_val == 2'b00) begin
            $display("  [PASS] excl_write_fail (#%0d)", test_num);
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] excl_write_fail (#%0d) got %0b", test_num, shared_bresp_val);
            test_fail = test_fail + 1;
        end

        // ---- Test 12: Mixed R/W ----
        $display("--- Test 12: Mixed Read/Write ---");
        cur_lock = 0; cur_burst = 2'b01; cur_size = 3;
        for (t_i = 0; t_i < 5; t_i = t_i + 1) begin
            cur_id = t_i[3:0];
            cur_addr = 32'h0400 + t_i * 32'h40;
            cur_len = t_i[7:0];
            gen_data; master_write; update_ref;
            master_read; check_data("mixed_rw");
        end

        // ---- Summary ----
        repeat(20) @(posedge clk);
        $display("");
        $display("==============================================");
        $display(" Test Summary");
        $display("==============================================");
        $display("  Total:  %0d", test_pass + test_fail);
        $display("  Passed: %0d", test_pass);
        $display("  Failed: %0d", test_fail);
        $display("==============================================");
        if (test_fail == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");
        $display("");
        $finish;
    end

    initial begin
        $dumpfile("tb_axi4_self_check.vcd");
        $dumpvars(0, tb_axi4_self_check);
    end

endmodule
