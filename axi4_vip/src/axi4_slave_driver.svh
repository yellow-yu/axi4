`ifndef AXI4_SLAVE_DRIVER_SVH
`define AXI4_SLAVE_DRIVER_SVH

//==========================================================================
// AXI4 Slave Driver with built-in memory model
//==========================================================================
class axi4_slave_driver extends uvm_component;

    `uvm_component_utils(axi4_slave_driver)

    virtual axi4_interface vif;
    axi4_config            cfg;

    // Byte-addressable memory model
    bit [7:0] mem[bit [AXI4_ADDR_WIDTH-1:0]];

    // Exclusive access monitor
    typedef struct {
        bit [AXI4_ADDR_WIDTH-1:0] addr;
        bit [7:0]                 len;
        bit [2:0]                 size;
        bit                       valid;
    } excl_entry_t;

    excl_entry_t excl_mon[2**AXI4_ID_WIDTH];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "Config not found")
        vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
        // Initialize slave outputs
        init_signals();

        @(posedge vif.aresetn);
        @(posedge vif.aclk);

        fork
            process_writes();
            process_reads();
        join
    endtask

    //----------------------------------------------------------------------
    // Initialize slave-driven signals
    //----------------------------------------------------------------------
    task init_signals();
        vif.awready <= 1'b0;
        vif.wready  <= 1'b0;
        vif.bvalid  <= 1'b0;
        vif.bid     <= '0;
        vif.bresp   <= '0;
        vif.buser   <= '0;
        vif.arready <= 1'b0;
        vif.rvalid  <= 1'b0;
        vif.rid     <= '0;
        vif.rdata   <= '0;
        vif.rresp   <= '0;
        vif.rlast   <= 1'b0;
        vif.ruser   <= '0;
    endtask

    //----------------------------------------------------------------------
    // Process write transactions
    //----------------------------------------------------------------------
    task process_writes();
        bit [AXI4_ID_WIDTH-1:0]   aw_id;
        bit [AXI4_ADDR_WIDTH-1:0] aw_addr;
        bit [7:0]                 aw_len;
        bit [2:0]                 aw_size;
        bit [1:0]                 aw_burst;
        bit                       aw_lock;
        bit [AXI4_ADDR_WIDTH-1:0] beat_addrs[];
        bit [AXI4_DATA_WIDTH-1:0] beat_data[];
        bit [AXI4_STRB_WIDTH-1:0] beat_strb[];
        bit [1:0]                 resp;
        int                       delay;

        forever begin
            // Accept AW handshake
            vif.awready <= 1'b1;
            do @(posedge vif.aclk); while (!vif.awvalid);
            aw_id    = vif.awid;
            aw_addr  = vif.awaddr;
            aw_len   = vif.awlen;
            aw_size  = vif.awsize;
            aw_burst = vif.awburst;
            aw_lock  = vif.awlock;
            vif.awready <= 1'b0;

            // Calculate beat addresses
            calc_addresses(aw_addr, aw_len, aw_size, aw_burst, beat_addrs);

            // Buffer W data beats
            beat_data = new[aw_len + 1];
            beat_strb = new[aw_len + 1];

            for (int i = 0; i <= aw_len; i++) begin
                vif.wready <= 1'b1;
                do @(posedge vif.aclk); while (!vif.wvalid);
                beat_data[i] = vif.wdata;
                beat_strb[i] = vif.wstrb;
                vif.wready <= 1'b0;
            end

            // Determine response and whether to write
            if (aw_lock) begin
                resp = handle_exclusive_write(aw_id, aw_addr, aw_len, aw_size);
            end else begin
                resp = AXI4_RESP_OKAY;
            end

            // Write to memory if applicable
            if (!aw_lock || resp == AXI4_RESP_EXOKAY) begin
                for (int i = 0; i <= aw_len; i++) begin
                    write_memory(beat_addrs[i], beat_data[i], beat_strb[i]);
                end
                // Invalidate overlapping exclusive monitors (for normal writes)
                if (!aw_lock)
                    invalidate_exclusive(aw_addr, aw_len, aw_size);
            end

            // Send B response with optional delay
            delay = cfg.min_b_valid_delay +
                    $urandom_range(0, cfg.max_b_valid_delay - cfg.min_b_valid_delay);
            repeat(delay) @(posedge vif.aclk);

            vif.bvalid <= 1'b1;
            vif.bid    <= aw_id;
            vif.bresp  <= resp;
            vif.buser  <= '0;
            do @(posedge vif.aclk); while (!vif.bready);
            vif.bvalid <= 1'b0;
        end
    endtask

    //----------------------------------------------------------------------
    // Process read transactions
    //----------------------------------------------------------------------
    task process_reads();
        bit [AXI4_ID_WIDTH-1:0]   ar_id;
        bit [AXI4_ADDR_WIDTH-1:0] ar_addr;
        bit [7:0]                 ar_len;
        bit [2:0]                 ar_size;
        bit [1:0]                 ar_burst;
        bit                       ar_lock;
        bit [AXI4_ADDR_WIDTH-1:0] beat_addrs[];
        bit [AXI4_DATA_WIDTH-1:0] rdata;
        bit [1:0]                 resp;
        int                       delay;

        forever begin
            // Accept AR handshake
            vif.arready <= 1'b1;
            do @(posedge vif.aclk); while (!vif.arvalid);
            ar_id    = vif.arid;
            ar_addr  = vif.araddr;
            ar_len   = vif.arlen;
            ar_size  = vif.arsize;
            ar_burst = vif.arburst;
            ar_lock  = vif.arlock;
            vif.arready <= 1'b0;

            // Calculate beat addresses
            calc_addresses(ar_addr, ar_len, ar_size, ar_burst, beat_addrs);

            // Handle exclusive read (register in monitor)
            if (ar_lock)
                handle_exclusive_read(ar_id, ar_addr, ar_len, ar_size);

            // Determine response type
            resp = ar_lock ? AXI4_RESP_EXOKAY : AXI4_RESP_OKAY;

            // Send R data beats
            for (int i = 0; i <= ar_len; i++) begin
                rdata = read_memory(beat_addrs[i]);

                delay = cfg.min_r_valid_delay +
                        $urandom_range(0, cfg.max_r_valid_delay - cfg.min_r_valid_delay);
                repeat(delay) @(posedge vif.aclk);

                vif.rvalid <= 1'b1;
                vif.rid    <= ar_id;
                vif.rdata  <= rdata;
                vif.rresp  <= resp;
                vif.rlast  <= (i == ar_len) ? 1'b1 : 1'b0;
                vif.ruser  <= '0;
                do @(posedge vif.aclk); while (!vif.rready);
                vif.rvalid <= 1'b0;
                vif.rlast  <= 1'b0;
            end
        end
    endtask

    //----------------------------------------------------------------------
    // Memory write: use WSTRB to select bytes
    //----------------------------------------------------------------------
    function void write_memory(
        bit [AXI4_ADDR_WIDTH-1:0] beat_addr,
        bit [AXI4_DATA_WIDTH-1:0] wdata,
        bit [AXI4_STRB_WIDTH-1:0] wstrb
    );
        bit [AXI4_ADDR_WIDTH-1:0] bus_base;
        bus_base = (beat_addr >> $clog2(AXI4_STRB_WIDTH)) << $clog2(AXI4_STRB_WIDTH);

        for (int j = 0; j < AXI4_STRB_WIDTH; j++) begin
            if (wstrb[j])
                mem[bus_base + j] = wdata[j*8 +: 8];
        end
    endfunction

    //----------------------------------------------------------------------
    // Memory read: return full bus width
    //----------------------------------------------------------------------
    function bit [AXI4_DATA_WIDTH-1:0] read_memory(
        bit [AXI4_ADDR_WIDTH-1:0] beat_addr
    );
        bit [AXI4_DATA_WIDTH-1:0] rdata;
        bit [AXI4_ADDR_WIDTH-1:0] bus_base;
        bus_base = (beat_addr >> $clog2(AXI4_STRB_WIDTH)) << $clog2(AXI4_STRB_WIDTH);

        rdata = '0;
        for (int j = 0; j < AXI4_STRB_WIDTH; j++) begin
            if (mem.exists(bus_base + j))
                rdata[j*8 +: 8] = mem[bus_base + j];
        end
        return rdata;
    endfunction

    //----------------------------------------------------------------------
    // Calculate burst beat addresses
    //----------------------------------------------------------------------
    function void calc_addresses(
        input  bit [AXI4_ADDR_WIDTH-1:0] start_addr,
        input  bit [7:0]                 len,
        input  bit [2:0]                 size,
        input  bit [1:0]                 burst_type,
        output bit [AXI4_ADDR_WIDTH-1:0] addrs[]
    );
        int num_bytes;
        bit [AXI4_ADDR_WIDTH-1:0] aligned_addr;
        int burst_len;
        bit [AXI4_ADDR_WIDTH-1:0] lower_wrap, upper_wrap;
        int total_bytes;

        num_bytes    = 1 << size;
        aligned_addr = (start_addr / num_bytes) * num_bytes;
        burst_len    = len + 1;
        addrs        = new[burst_len];

        case (burst_type)
            2'b00: begin // FIXED
                for (int i = 0; i < burst_len; i++)
                    addrs[i] = start_addr;
            end
            2'b01: begin // INCR
                addrs[0] = start_addr;
                for (int i = 1; i < burst_len; i++)
                    addrs[i] = aligned_addr + i * num_bytes;
            end
            2'b10: begin // WRAP
                total_bytes = burst_len * num_bytes;
                lower_wrap  = (start_addr / total_bytes) * total_bytes;
                upper_wrap  = lower_wrap + total_bytes;

                addrs[0] = start_addr;
                for (int i = 1; i < burst_len; i++) begin
                    addrs[i] = aligned_addr + i * num_bytes;
                    if (addrs[i] >= upper_wrap)
                        addrs[i] = lower_wrap + (addrs[i] - upper_wrap);
                end
            end
            default: begin
                for (int i = 0; i < burst_len; i++)
                    addrs[i] = start_addr;
            end
        endcase
    endfunction

    //----------------------------------------------------------------------
    // Exclusive access functions
    //----------------------------------------------------------------------
    function void handle_exclusive_read(
        bit [AXI4_ID_WIDTH-1:0]   id,
        bit [AXI4_ADDR_WIDTH-1:0] addr,
        bit [7:0]                 len,
        bit [2:0]                 size
    );
        excl_mon[id].addr  = addr;
        excl_mon[id].len   = len;
        excl_mon[id].size  = size;
        excl_mon[id].valid = 1;
    endfunction

    function bit [1:0] handle_exclusive_write(
        bit [AXI4_ID_WIDTH-1:0]   id,
        bit [AXI4_ADDR_WIDTH-1:0] addr,
        bit [7:0]                 len,
        bit [2:0]                 size
    );
        if (excl_mon[id].valid &&
            excl_mon[id].addr == addr &&
            excl_mon[id].len  == len &&
            excl_mon[id].size == size) begin
            excl_mon[id].valid = 0;
            return AXI4_RESP_EXOKAY;
        end else begin
            return AXI4_RESP_OKAY;
        end
    endfunction

    function void invalidate_exclusive(
        bit [AXI4_ADDR_WIDTH-1:0] addr,
        bit [7:0]                 len,
        bit [2:0]                 size
    );
        int total_bytes;
        bit [AXI4_ADDR_WIDTH-1:0] start_addr, end_addr;
        bit [AXI4_ADDR_WIDTH-1:0] excl_start, excl_end;
        int excl_bytes;

        total_bytes = (int'(len) + 1) * (1 << size);
        start_addr  = addr;
        end_addr    = addr + total_bytes - 1;

        for (int i = 0; i < 2**AXI4_ID_WIDTH; i++) begin
            if (excl_mon[i].valid) begin
                excl_bytes = (int'(excl_mon[i].len) + 1) * (1 << excl_mon[i].size);
                excl_start = excl_mon[i].addr;
                excl_end   = excl_mon[i].addr + excl_bytes - 1;
                // Check overlap
                if (start_addr <= excl_end && end_addr >= excl_start)
                    excl_mon[i].valid = 0;
            end
        end
    endfunction

endclass

`endif
