//==========================================================================
// axi4_mem_slave_simple.sv - Simplified memory slave for iverilog testing
// Uses fixed-size array instead of associative array
//==========================================================================

`timescale 1ns/1ps

module axi4_mem_slave #(
    parameter integer ID_WIDTH   = 4,
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 64,
    parameter integer USER_WIDTH = 1
)(
    input  logic                    aclk,
    input  logic                    aresetn,
    input  logic [ID_WIDTH-1:0]     awid,
    input  logic [ADDR_WIDTH-1:0]   awaddr,
    input  logic [7:0]              awlen,
    input  logic [2:0]              awsize,
    input  logic [1:0]              awburst,
    input  logic                    awlock,
    input  logic [3:0]              awcache,
    input  logic [2:0]              awprot,
    input  logic [3:0]              awqos,
    input  logic [3:0]              awregion,
    input  logic [USER_WIDTH-1:0]   awuser,
    input  logic                    awvalid,
    output logic                    awready,
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,
    input  logic                    wlast,
    input  logic [USER_WIDTH-1:0]   wuser,
    input  logic                    wvalid,
    output logic                    wready,
    output logic [ID_WIDTH-1:0]     bid,
    output logic [1:0]              bresp,
    output logic [USER_WIDTH-1:0]   buser,
    output logic                    bvalid,
    input  logic                    bready,
    input  logic [ID_WIDTH-1:0]     arid,
    input  logic [ADDR_WIDTH-1:0]   araddr,
    input  logic [7:0]              arlen,
    input  logic [2:0]              arsize,
    input  logic [1:0]              arburst,
    input  logic                    arlock,
    input  logic [3:0]              arcache,
    input  logic [2:0]              arprot,
    input  logic [3:0]              arqos,
    input  logic [3:0]              arregion,
    input  logic [USER_WIDTH-1:0]   aruser,
    input  logic                    arvalid,
    output logic                    arready,
    output logic [ID_WIDTH-1:0]     rid,
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic [1:0]              rresp,
    output logic                    rlast,
    output logic [USER_WIDTH-1:0]   ruser,
    output logic                    rvalid,
    input  logic                    rready
);

    localparam STRB_WIDTH = DATA_WIDTH / 8;
    localparam BUS_BYTE_BITS = $clog2(STRB_WIDTH);
    localparam MEM_SIZE = 1048576; // 1MB

    // Fixed-size memory
    reg [7:0] mem [0:MEM_SIZE-1];

    // Exclusive monitor
    reg                  excl_valid;
    reg [ADDR_WIDTH-1:0] excl_addr;
    reg [ID_WIDTH-1:0]   excl_id;

    // Address calculation
    function automatic [ADDR_WIDTH-1:0] calc_beat_addr(
        input [ADDR_WIDTH-1:0] start_addr,
        input [2:0]            burst_size,
        input [1:0]            burst_type,
        input [7:0]            burst_len,
        input integer          beat_num
    );
        reg [ADDR_WIDTH-1:0] aligned_addr;
        reg [ADDR_WIDTH-1:0] addr_out;
        reg [ADDR_WIDTH-1:0] wrap_boundary;
        integer num_bytes, burst_length, total_bytes;

        num_bytes    = 1 << burst_size;
        burst_length = burst_len + 1;
        aligned_addr = (start_addr / num_bytes) * num_bytes;

        case (burst_type)
            2'b00: addr_out = start_addr;
            2'b01: begin
                if (beat_num == 0) addr_out = start_addr;
                else addr_out = aligned_addr + beat_num * num_bytes;
            end
            2'b10: begin
                if (beat_num == 0) addr_out = start_addr;
                else addr_out = aligned_addr + beat_num * num_bytes;
                total_bytes   = num_bytes * burst_length;
                wrap_boundary = (start_addr / total_bytes) * total_bytes;
                if (addr_out >= wrap_boundary + total_bytes)
                    addr_out = addr_out - total_bytes;
            end
            default: addr_out = start_addr;
        endcase
        calc_beat_addr = addr_out;
    endfunction

    // Write path
    reg [1:0] wr_state;
    localparam WR_IDLE = 0, WR_DATA = 1, WR_RESP = 2;
    reg [ID_WIDTH-1:0]   wr_id;
    reg [ADDR_WIDTH-1:0] wr_addr;
    reg [7:0]            wr_len;
    reg [2:0]            wr_size;
    reg [1:0]            wr_burst;
    reg                  wr_lock;
    integer              wr_beat_cnt;
    reg [1:0]            wr_resp_val;
    reg                  wr_excl_pass;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state <= WR_IDLE;
            awready  <= 1;
            wready   <= 0;
            bvalid   <= 0;
            bid      <= 0;
            bresp    <= 0;
            buser    <= 0;
            wr_beat_cnt <= 0;
            wr_resp_val <= 0;
            wr_excl_pass <= 0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    bvalid <= 0;
                    if (awvalid && awready) begin
                        wr_id    <= awid;
                        wr_addr  <= awaddr;
                        wr_len   <= awlen;
                        wr_size  <= awsize;
                        wr_burst <= awburst;
                        wr_lock  <= awlock;
                        wr_beat_cnt <= 0;
                        if (awlock) begin
                            if (excl_valid && excl_addr == awaddr && excl_id == awid) begin
                                wr_resp_val  <= 2'b01;
                                wr_excl_pass <= 1;
                            end else begin
                                wr_resp_val  <= 2'b00;
                                wr_excl_pass <= 0;
                            end
                        end else begin
                            wr_resp_val  <= 2'b00;
                            wr_excl_pass <= 0;
                        end
                        awready  <= 0;
                        wready   <= 1;
                        wr_state <= WR_DATA;
                    end
                end
                WR_DATA: begin
                    if (wvalid && wready) begin : wr_data_blk
                        reg [ADDR_WIDTH-1:0] beat_addr;
                        reg [ADDR_WIDTH-1:0] base_addr;
                        integer j;
                        beat_addr = calc_beat_addr(wr_addr, wr_size, wr_burst, wr_len, wr_beat_cnt);
                        base_addr = (beat_addr >> BUS_BYTE_BITS) << BUS_BYTE_BITS;
                        if (!(wr_lock && !wr_excl_pass)) begin
                            for (j = 0; j < STRB_WIDTH; j = j + 1) begin
                                if (wstrb[j] && (base_addr + j) < MEM_SIZE)
                                    mem[base_addr + j] = wdata[j*8 +: 8];
                            end
                        end
                        wr_beat_cnt <= wr_beat_cnt + 1;
                        if (wlast) begin
                            wready   <= 0;
                            bvalid   <= 1;
                            bid      <= wr_id;
                            bresp    <= wr_resp_val;
                            buser    <= 0;
                            wr_state <= WR_RESP;
                            if (wr_lock && wr_excl_pass) begin
                                excl_valid <= 0;
                            end
                        end
                    end
                end
                WR_RESP: begin
                    if (bvalid && bready) begin
                        bvalid   <= 0;
                        awready  <= 1;
                        wr_state <= WR_IDLE;
                    end
                end
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // Read path
    reg [1:0] rd_state;
    localparam RD_IDLE = 0, RD_DATA = 1;
    reg [ID_WIDTH-1:0]   rd_id;
    reg [ADDR_WIDTH-1:0] rd_addr;
    reg [7:0]            rd_len;
    reg [2:0]            rd_size;
    reg [1:0]            rd_burst;
    integer              rd_beat_cnt;
    reg [1:0]            rd_resp_val;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state    <= RD_IDLE;
            arready     <= 1;
            rvalid      <= 0;
            rid         <= 0;
            rdata       <= 0;
            rresp       <= 0;
            rlast       <= 0;
            ruser       <= 0;
            rd_beat_cnt <= 0;
            rd_resp_val <= 0;
            excl_valid  <= 0;
            excl_addr   <= 0;
            excl_id     <= 0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (arvalid && arready) begin
                        rd_id    <= arid;
                        rd_addr  <= araddr;
                        rd_len   <= arlen;
                        rd_size  <= arsize;
                        rd_burst <= arburst;
                        rd_beat_cnt <= 0;
                        if (arlock) begin
                            excl_valid  <= 1;
                            excl_addr   <= araddr;
                            excl_id     <= arid;
                            rd_resp_val <= 2'b01;
                        end else begin
                            rd_resp_val <= 2'b00;
                        end
                        arready <= 0;
                        begin : rd_prep_blk
                            reg [ADDR_WIDTH-1:0] beat_addr;
                            reg [ADDR_WIDTH-1:0] base_addr;
                            integer j;
                            beat_addr = calc_beat_addr(araddr, arsize, arburst, arlen, 0);
                            base_addr = (beat_addr >> BUS_BYTE_BITS) << BUS_BYTE_BITS;
                            for (j = 0; j < STRB_WIDTH; j = j + 1) begin
                                if ((base_addr + j) < MEM_SIZE)
                                    rdata[j*8 +: 8] <= mem[base_addr + j];
                                else
                                    rdata[j*8 +: 8] <= 0;
                            end
                        end
                        rid    <= arid;
                        rresp  <= arlock ? 2'b01 : 2'b00;
                        rlast  <= (arlen == 0) ? 1'b1 : 1'b0;
                        rvalid <= 1;
                        ruser  <= 0;
                        rd_state <= RD_DATA;
                    end
                end
                RD_DATA: begin
                    if (rvalid && rready) begin
                        if (rlast) begin
                            rvalid   <= 0;
                            rlast    <= 0;
                            arready  <= 1;
                            rd_state <= RD_IDLE;
                        end else begin
                            rd_beat_cnt <= rd_beat_cnt + 1;
                            begin : rd_next_blk
                                integer next_beat;
                                reg [ADDR_WIDTH-1:0] beat_addr;
                                reg [ADDR_WIDTH-1:0] base_addr;
                                integer j;
                                next_beat = rd_beat_cnt + 1;
                                beat_addr = calc_beat_addr(rd_addr, rd_size, rd_burst, rd_len, next_beat);
                                base_addr = (beat_addr >> BUS_BYTE_BITS) << BUS_BYTE_BITS;
                                for (j = 0; j < STRB_WIDTH; j = j + 1) begin
                                    if ((base_addr + j) < MEM_SIZE)
                                        rdata[j*8 +: 8] <= mem[base_addr + j];
                                    else
                                        rdata[j*8 +: 8] <= 0;
                                end
                            end
                            rid   <= rd_id;
                            rresp <= rd_resp_val;
                            rlast <= ((rd_beat_cnt + 1) == rd_len) ? 1'b1 : 1'b0;
                            rvalid <= 1;
                        end
                    end
                end
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    // Initialize memory to 0
    integer init_i;
    initial begin
        for (init_i = 0; init_i < MEM_SIZE; init_i = init_i + 1)
            mem[init_i] = 0;
        excl_valid = 0;
    end

endmodule
