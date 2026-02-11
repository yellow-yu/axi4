//==========================================================================
// axi4_rtl_test.sv - Standalone RTL test for axi4_mem_slave
// Validates the slave memory model without UVM
//==========================================================================
`timescale 1ns/1ps

module axi4_rtl_test;

    localparam ID_WIDTH   = 4;
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 64;
    localparam USER_WIDTH = 1;
    localparam STRB_WIDTH = DATA_WIDTH / 8;

    logic aclk, aresetn;
    // AW
    logic [ID_WIDTH-1:0]   awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;
    logic [2:0]            awsize;
    logic [1:0]            awburst;
    logic                  awlock;
    logic [3:0]            awcache, awqos, awregion;
    logic [2:0]            awprot;
    logic [USER_WIDTH-1:0] awuser;
    logic                  awvalid, awready;
    // W
    logic [DATA_WIDTH-1:0] wdata;
    logic [STRB_WIDTH-1:0] wstrb;
    logic                  wlast;
    logic [USER_WIDTH-1:0] wuser;
    logic                  wvalid, wready;
    // B
    logic [ID_WIDTH-1:0]   bid;
    logic [1:0]            bresp;
    logic [USER_WIDTH-1:0] buser;
    logic                  bvalid, bready;
    // AR
    logic [ID_WIDTH-1:0]   arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic                  arlock;
    logic [3:0]            arcache, arqos, arregion;
    logic [2:0]            arprot;
    logic [USER_WIDTH-1:0] aruser;
    logic                  arvalid, arready;
    // R
    logic [ID_WIDTH-1:0]   rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rlast;
    logic [USER_WIDTH-1:0] ruser;
    logic                  rvalid, rready;

    // Statistics
    int pass_cnt = 0;
    int fail_cnt = 0;

    axi4_mem_slave #(
        .ID_WIDTH(ID_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH), .USER_WIDTH(USER_WIDTH)
    ) dut (.*);

    // Clock
    initial begin aclk = 0; forever #5 aclk = ~aclk; end

    // Reset
    initial begin
        aresetn = 0;
        repeat (10) @(posedge aclk);
        aresetn = 1;
    end

    // Init signals
    initial begin
        awvalid = 0; awid = 0; awaddr = 0; awlen = 0; awsize = 0;
        awburst = 0; awlock = 0; awcache = 0; awprot = 0; awqos = 0;
        awregion = 0; awuser = 0;
        wvalid = 0; wdata = 0; wstrb = 0; wlast = 0; wuser = 0;
        bready = 0;
        arvalid = 0; arid = 0; araddr = 0; arlen = 0; arsize = 0;
        arburst = 0; arlock = 0; arcache = 0; arprot = 0; arqos = 0;
        arregion = 0; aruser = 0;
        rready = 0;
    end

    //------------------------------------------------------------------
    // Write Task
    //------------------------------------------------------------------
    task automatic axi_write(
        input [ADDR_WIDTH-1:0] addr,
        input [7:0]            len,
        input [2:0]            size,
        input [1:0]            burst,
        input [DATA_WIDTH-1:0] data_arr [],
        input [STRB_WIDTH-1:0] strb_arr [],
        input [ID_WIDTH-1:0]   id = 0,
        input                  lock = 0
    );
        // AW phase
        @(posedge aclk);
        awvalid <= 1; awid <= id; awaddr <= addr; awlen <= len;
        awsize <= size; awburst <= burst; awlock <= lock;
        do @(posedge aclk); while (!awready);
        awvalid <= 0;

        // W phase
        for (int i = 0; i <= len; i++) begin
            @(posedge aclk);
            wvalid <= 1;
            wdata  <= data_arr[i];
            wstrb  <= strb_arr[i];
            wlast  <= (i == len);
            do @(posedge aclk); while (!wready);
            wvalid <= 0;
        end
        wlast <= 0;

        // B phase
        bready <= 1;
        do @(posedge aclk); while (!bvalid);
        @(posedge aclk);
        bready <= 0;
    endtask

    //------------------------------------------------------------------
    // Read Task
    //------------------------------------------------------------------
    task automatic axi_read(
        input  [ADDR_WIDTH-1:0] addr,
        input  [7:0]            len,
        input  [2:0]            size,
        input  [1:0]            burst,
        output [DATA_WIDTH-1:0] data_arr [],
        input  [ID_WIDTH-1:0]   id = 0,
        input                   lock = 0
    );
        // AR phase
        @(posedge aclk);
        arvalid <= 1; arid <= id; araddr <= addr; arlen <= len;
        arsize <= size; arburst <= burst; arlock <= lock;
        do @(posedge aclk); while (!arready);
        arvalid <= 0;

        // R phase
        data_arr = new[len + 1];
        rready <= 1;
        for (int i = 0; i <= len; i++) begin
            do @(posedge aclk); while (!rvalid);
            data_arr[i] = rdata;
        end
        @(posedge aclk);
        rready <= 0;
    endtask

    //------------------------------------------------------------------
    // Check helper
    //------------------------------------------------------------------
    task automatic check_data(
        input string test_name,
        input [DATA_WIDTH-1:0] expected,
        input [DATA_WIDTH-1:0] actual,
        input int beat = 0
    );
        if (expected === actual) begin
            pass_cnt++;
        end else begin
            $display("FAIL [%s] beat=%0d exp=0x%016x act=0x%016x", test_name, beat, expected, actual);
            fail_cnt++;
        end
    endtask

    //------------------------------------------------------------------
    // Main Test
    //------------------------------------------------------------------
    initial begin
        logic [DATA_WIDTH-1:0] wd [];
        logic [STRB_WIDTH-1:0] ws [];
        logic [DATA_WIDTH-1:0] rd [];

        @(posedge aresetn);
        repeat (5) @(posedge aclk);

        //==============================================================
        // Test 1: Single write-read
        //==============================================================
        $display("\n=== Test 1: Single Write-Read ===");
        wd = new[1]; ws = new[1];
        wd[0] = 64'h1234_5678_9ABC_DEF0;
        ws[0] = 8'hFF;
        axi_write(32'h0000_0000, 0, 3, 2'b01, wd, ws);
        axi_read(32'h0000_0000, 0, 3, 2'b01, rd);
        check_data("SingleRW", wd[0], rd[0]);

        //==============================================================
        // Test 2: INCR burst (4 beats)
        //==============================================================
        $display("\n=== Test 2: INCR Burst (4 beats) ===");
        wd = new[4]; ws = new[4];
        for (int i = 0; i < 4; i++) begin
            wd[i] = {32'hAAAA_0000 + i, 32'hBBBB_0000 + i};
            ws[i] = 8'hFF;
        end
        axi_write(32'h0000_1000, 3, 3, 2'b01, wd, ws);
        axi_read(32'h0000_1000, 3, 3, 2'b01, rd);
        for (int i = 0; i < 4; i++)
            check_data("INCR_Burst", wd[i], rd[i], i);

        //==============================================================
        // Test 3: FIXED burst (3 beats) - only last data remains
        //==============================================================
        $display("\n=== Test 3: FIXED Burst (3 beats) ===");
        wd = new[3]; ws = new[3];
        for (int i = 0; i < 3; i++) begin
            wd[i] = {32'hF1CD_0000 + i, 32'hDEAD_0000 + i};
            ws[i] = 8'hFF;
        end
        axi_write(32'h0000_2000, 2, 3, 2'b00, wd, ws); // FIXED burst
        axi_read(32'h0000_2000, 0, 3, 2'b00, rd); // Single read
        check_data("FIXED_Burst", wd[2], rd[0]); // Last beat should persist

        //==============================================================
        // Test 4: Byte strobe - partial write
        //==============================================================
        $display("\n=== Test 4: Byte Strobe ===");
        wd = new[1]; ws = new[1];
        // Full write
        wd[0] = 64'hAAAA_BBBB_CCCC_DDDD;
        ws[0] = 8'hFF;
        axi_write(32'h0000_3000, 0, 3, 2'b01, wd, ws);
        // Partial overwrite (even bytes)
        wd[0] = 64'h1111_2222_3333_4444;
        ws[0] = 8'h55;
        axi_write(32'h0000_3000, 0, 3, 2'b01, wd, ws);
        axi_read(32'h0000_3000, 0, 3, 2'b01, rd);
        // Expected: AA11_BB22_CC33_DD44
        check_data("ByteStrobe", 64'hAA11_BB22_CC33_DD44, rd[0]);

        //==============================================================
        // Test 5: WRAP burst (4 beats with wrapping)
        //==============================================================
        $display("\n=== Test 5: WRAP Burst (4 beats) ===");
        wd = new[4]; ws = new[4];
        for (int i = 0; i < 4; i++) begin
            wd[i] = {32'hBEEF_0000 + i, 32'h5555_0000 + i};
            ws[i] = 8'hFF;
        end
        // 4 beats * 8 bytes = 32-byte region. Start at offset 0x10 -> wraps
        axi_write(32'h0000_4010, 3, 3, 2'b10, wd, ws); // WRAP
        axi_read(32'h0000_4010, 3, 3, 2'b10, rd);
        for (int i = 0; i < 4; i++)
            check_data("WRAP_Burst", wd[i], rd[i], i);

        //==============================================================
        // Test 6: Multiple addresses
        //==============================================================
        $display("\n=== Test 6: Multiple Addresses ===");
        for (int a = 0; a < 8; a++) begin
            wd = new[1]; ws = new[1];
            wd[0] = {32'h0000_0000 + a, 32'hFFFF_0000 + a};
            ws[0] = 8'hFF;
            axi_write(32'h0000_5000 + a * 8, 0, 3, 2'b01, wd, ws);
        end
        for (int a = 0; a < 8; a++) begin
            logic [DATA_WIDTH-1:0] expected;
            expected = {32'h0000_0000 + a, 32'hFFFF_0000 + a};
            axi_read(32'h0000_5000 + a * 8, 0, 3, 2'b01, rd);
            check_data("MultiAddr", expected, rd[0], a);
        end

        //==============================================================
        // Test 7: Narrow transfer (4-byte on 8-byte bus)
        //==============================================================
        $display("\n=== Test 7: Narrow Transfer ===");
        wd = new[2]; ws = new[2];
        // Beat 0 at addr 0x6000: lanes 0-3 active
        wd[0] = 64'h0000_0000_1234_5678;
        ws[0] = 8'h0F;
        // Beat 1 at addr 0x6004: lanes 4-7 active
        wd[1] = 64'hABCD_EF01_0000_0000;
        ws[1] = 8'hF0;
        axi_write(32'h0000_6000, 1, 2, 2'b01, wd, ws); // size=2 (4 bytes), INCR
        axi_read(32'h0000_6000, 1, 2, 2'b01, rd);
        // Beat 0: should have lanes 0-3 = 0x12345678
        check_data("Narrow_b0", 64'h0000_0000_1234_5678, rd[0] & 64'h0000_0000_FFFF_FFFF, 0);
        // Beat 1: should have lanes 4-7 = 0xABCDEF01
        check_data("Narrow_b1", 64'hABCD_EF01_0000_0000, rd[1] & 64'hFFFF_FFFF_0000_0000, 1);

        //==============================================================
        // Test 8: Long burst (16 beats)
        //==============================================================
        $display("\n=== Test 8: Long Burst (16 beats) ===");
        wd = new[16]; ws = new[16];
        for (int i = 0; i < 16; i++) begin
            wd[i] = {32'hCACE_0000 + i, 32'hBABE_0000 + i};
            ws[i] = 8'hFF;
        end
        axi_write(32'h0000_8000, 15, 3, 2'b01, wd, ws);
        axi_read(32'h0000_8000, 15, 3, 2'b01, rd);
        for (int i = 0; i < 16; i++)
            check_data("LongBurst", wd[i], rd[i], i);

        //==============================================================
        // Summary
        //==============================================================
        repeat (10) @(posedge aclk);
        $display("\n==========================================");
        $display("  RTL Test Summary");
        $display("==========================================");
        $display("  Pass: %0d", pass_cnt);
        $display("  Fail: %0d", fail_cnt);
        $display("==========================================");
        if (fail_cnt == 0)
            $display("  *** ALL RTL TESTS PASSED ***\n");
        else
            $display("  *** SOME RTL TESTS FAILED ***\n");
        $finish;
    end

    // Timeout
    initial begin
        #1_000_000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
