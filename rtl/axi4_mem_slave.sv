//==========================================================================
// axi4_mem_slave.sv - Behavioral AXI4 Memory Slave
//==========================================================================
// A behavioral memory slave for AXI4 protocol verification.
// Supports: FIXED/INCR/WRAP bursts, narrow transfers, unaligned access,
//           exclusive access, byte strobes, and all response types.
//
// Note: This is a behavioral model. Read and write paths are serialized
//       (one transaction at a time per channel) for simplicity.
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
    // Write Address Channel
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
    // Write Data Channel
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,
    input  logic                    wlast,
    input  logic [USER_WIDTH-1:0]   wuser,
    input  logic                    wvalid,
    output logic                    wready,
    // Write Response Channel
    output logic [ID_WIDTH-1:0]     bid,
    output logic [1:0]              bresp,
    output logic [USER_WIDTH-1:0]   buser,
    output logic                    bvalid,
    input  logic                    bready,
    // Read Address Channel
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
    // Read Data Channel
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

    //==========================================================================
    // Memory Storage (byte-addressable associative array)
    //==========================================================================
    logic [7:0] mem [int unsigned];

    //==========================================================================
    // Exclusive Access Monitor
    //==========================================================================
    logic                  excl_valid;
    logic [ADDR_WIDTH-1:0] excl_addr;
    logic [ID_WIDTH-1:0]   excl_id;

    // Signals for exclusive monitor control (from write/read paths)
    logic excl_set_req;
    logic [ADDR_WIDTH-1:0] excl_set_addr;
    logic [ID_WIDTH-1:0]   excl_set_id;
    logic excl_clear_req;

    // Single always_ff block for exclusive monitor
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            excl_valid <= 1'b0;
            excl_addr  <= '0;
            excl_id    <= '0;
        end else begin
            // Clear has higher priority (write succeeds -> clear)
            if (excl_clear_req) begin
                excl_valid <= 1'b0;
            end else if (excl_set_req) begin
                excl_valid <= 1'b1;
                excl_addr  <= excl_set_addr;
                excl_id    <= excl_set_id;
            end
        end
    end

    //==========================================================================
    // Address Calculation Function
    //==========================================================================
    function automatic [ADDR_WIDTH-1:0] calc_beat_addr(
        input [ADDR_WIDTH-1:0] start_addr,
        input [2:0]            burst_size,
        input [1:0]            burst_type,
        input [7:0]            burst_len,
        input int              beat_num
    );
        logic [ADDR_WIDTH-1:0] aligned_addr;
        logic [ADDR_WIDTH-1:0] addr;
        logic [ADDR_WIDTH-1:0] wrap_boundary;
        int unsigned num_bytes;
        int unsigned burst_length;
        int unsigned total_bytes;

        num_bytes    = 1 << burst_size;
        burst_length = burst_len + 1;
        aligned_addr = (start_addr / num_bytes) * num_bytes;

        case (burst_type)
            2'b00: begin // FIXED
                addr = start_addr;
            end
            2'b01: begin // INCR
                if (beat_num == 0)
                    addr = start_addr;
                else
                    addr = aligned_addr + beat_num * num_bytes;
            end
            2'b10: begin // WRAP
                if (beat_num == 0)
                    addr = start_addr;
                else
                    addr = aligned_addr + beat_num * num_bytes;
                total_bytes   = num_bytes * burst_length;
                wrap_boundary = (start_addr / total_bytes) * total_bytes;
                if (addr >= wrap_boundary + total_bytes)
                    addr = addr - total_bytes;
            end
            default: addr = start_addr;
        endcase

        return addr;
    endfunction

    //==========================================================================
    // Write Path - State Machine
    //==========================================================================
    typedef enum logic [1:0] {
        WR_IDLE = 2'b00,
        WR_DATA = 2'b01,
        WR_RESP = 2'b10
    } wr_state_e;

    wr_state_e wr_state;

    logic [ID_WIDTH-1:0]   wr_id;
    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [7:0]            wr_len;
    logic [2:0]            wr_size;
    logic [1:0]            wr_burst;
    logic                  wr_lock;
    int                    wr_beat_cnt;
    logic [1:0]            wr_resp_val;
    logic                  wr_excl_pass; // exclusive write pass flag

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state    <= WR_IDLE;
            awready     <= 1'b1;
            wready      <= 1'b0;
            bvalid      <= 1'b0;
            bid         <= '0;
            bresp       <= 2'b00;
            buser       <= '0;
            wr_beat_cnt <= 0;
            wr_resp_val <= 2'b00;
            wr_excl_pass <= 1'b0;
            excl_clear_req <= 1'b0;
        end else begin
            // Default: deassert one-cycle control signals
            excl_clear_req <= 1'b0;

            case (wr_state)
                WR_IDLE: begin
                    bvalid <= 1'b0;
                    if (awvalid && awready) begin
                        wr_id    <= awid;
                        wr_addr  <= awaddr;
                        wr_len   <= awlen;
                        wr_size  <= awsize;
                        wr_burst <= awburst;
                        wr_lock  <= awlock;
                        wr_beat_cnt <= 0;

                        // Determine exclusive response
                        if (awlock) begin
                            if (excl_valid && excl_addr == awaddr && excl_id == awid) begin
                                wr_resp_val  <= 2'b01; // EXOKAY
                                wr_excl_pass <= 1'b1;
                            end else begin
                                wr_resp_val  <= 2'b00; // OKAY (fail)
                                wr_excl_pass <= 1'b0;
                            end
                        end else begin
                            wr_resp_val  <= 2'b00; // OKAY
                            wr_excl_pass <= 1'b0;
                        end

                        awready  <= 1'b0;
                        wready   <= 1'b1;
                        wr_state <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (wvalid && wready) begin
                        // Calculate beat address
                        begin
                            logic [ADDR_WIDTH-1:0] beat_addr;
                            logic [ADDR_WIDTH-1:0] base_addr;

                            beat_addr = calc_beat_addr(wr_addr, wr_size, wr_burst, wr_len, wr_beat_cnt);
                            base_addr = (beat_addr >> BUS_BYTE_BITS) << BUS_BYTE_BITS;

                            // Write data to memory (skip for failed exclusive)
                            if (!(wr_lock && !wr_excl_pass)) begin
                                for (int j = 0; j < STRB_WIDTH; j++) begin
                                    if (wstrb[j]) begin
                                        mem[base_addr + j] = wdata[j*8 +: 8];
                                    end
                                end
                            end
                        end

                        wr_beat_cnt <= wr_beat_cnt + 1;

                        if (wlast) begin
                            wready   <= 1'b0;
                            bvalid   <= 1'b1;
                            bid      <= wr_id;
                            bresp    <= wr_resp_val;
                            buser    <= '0;
                            wr_state <= WR_RESP;

                            // Clear exclusive monitor on successful exclusive write
                            if (wr_lock && wr_excl_pass) begin
                                excl_clear_req <= 1'b1;
                            end
                        end
                    end
                end

                WR_RESP: begin
                    if (bvalid && bready) begin
                        bvalid   <= 1'b0;
                        awready  <= 1'b1;
                        wr_state <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    //==========================================================================
    // Read Path - State Machine
    //==========================================================================
    typedef enum logic [1:0] {
        RD_IDLE = 2'b00,
        RD_DATA = 2'b01
    } rd_state_e;

    rd_state_e rd_state;

    logic [ID_WIDTH-1:0]   rd_id;
    logic [ADDR_WIDTH-1:0] rd_addr;
    logic [7:0]            rd_len;
    logic [2:0]            rd_size;
    logic [1:0]            rd_burst;
    logic                  rd_lock;
    int                    rd_beat_cnt;
    logic [1:0]            rd_resp_val;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state    <= RD_IDLE;
            arready     <= 1'b1;
            rvalid      <= 1'b0;
            rid         <= '0;
            rdata       <= '0;
            rresp       <= 2'b00;
            rlast       <= 1'b0;
            ruser       <= '0;
            rd_beat_cnt <= 0;
            rd_resp_val <= 2'b00;
            excl_set_req  <= 1'b0;
            excl_set_addr <= '0;
            excl_set_id   <= '0;
        end else begin
            // Default: deassert one-cycle signals
            excl_set_req <= 1'b0;

            case (rd_state)
                RD_IDLE: begin
                    if (arvalid && arready) begin
                        rd_id    <= arid;
                        rd_addr  <= araddr;
                        rd_len   <= arlen;
                        rd_size  <= arsize;
                        rd_burst <= arburst;
                        rd_lock  <= arlock;
                        rd_beat_cnt <= 0;

                        // Exclusive read: set monitor
                        if (arlock) begin
                            excl_set_req  <= 1'b1;
                            excl_set_addr <= araddr;
                            excl_set_id   <= arid;
                            rd_resp_val   <= 2'b01; // EXOKAY
                        end else begin
                            rd_resp_val <= 2'b00; // OKAY
                        end

                        arready <= 1'b0;

                        // Prepare first beat data
                        begin
                            logic [ADDR_WIDTH-1:0] beat_addr;
                            logic [ADDR_WIDTH-1:0] base_addr;
                            beat_addr = calc_beat_addr(araddr, arsize, arburst, arlen, 0);
                            base_addr = (beat_addr >> BUS_BYTE_BITS) << BUS_BYTE_BITS;
                            for (int j = 0; j < STRB_WIDTH; j++) begin
                                if (mem.exists(base_addr + j))
                                    rdata[j*8 +: 8] <= mem[base_addr + j];
                                else
                                    rdata[j*8 +: 8] <= 8'h00;
                            end
                        end

                        rid    <= arid;
                        rresp  <= arlock ? 2'b01 : 2'b00;
                        rlast  <= (arlen == 0) ? 1'b1 : 1'b0;
                        rvalid <= 1'b1;
                        ruser  <= '0;
                        rd_state <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    if (rvalid && rready) begin
                        if (rlast) begin
                            rvalid   <= 1'b0;
                            rlast    <= 1'b0;
                            arready  <= 1'b1;
                            rd_state <= RD_IDLE;
                        end else begin
                            rd_beat_cnt <= rd_beat_cnt + 1;

                            begin
                                int next_beat;
                                logic [ADDR_WIDTH-1:0] beat_addr;
                                logic [ADDR_WIDTH-1:0] base_addr;
                                next_beat = rd_beat_cnt + 1;
                                beat_addr = calc_beat_addr(rd_addr, rd_size, rd_burst, rd_len, next_beat);
                                base_addr = (beat_addr >> BUS_BYTE_BITS) << BUS_BYTE_BITS;
                                for (int j = 0; j < STRB_WIDTH; j++) begin
                                    if (mem.exists(base_addr + j))
                                        rdata[j*8 +: 8] <= mem[base_addr + j];
                                    else
                                        rdata[j*8 +: 8] <= 8'h00;
                                end
                            end

                            rid   <= rd_id;
                            rresp <= rd_resp_val;
                            rlast <= ((rd_beat_cnt + 1) == rd_len) ? 1'b1 : 1'b0;
                            rvalid <= 1'b1;
                        end
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
