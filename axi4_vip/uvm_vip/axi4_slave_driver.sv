//==========================================================================
// axi4_slave_driver.sv - AXI4 Slave Driver with Memory Model
//==========================================================================

class axi4_slave_driver extends uvm_component;

  virtual axi4_interface vif;

  // Byte-addressable memory model
  bit [7:0] mem[bit [`AXI4_ADDR_WIDTH-1:0]];

  // Exclusive access monitor
  bit [`AXI4_ADDR_WIDTH-1:0] excl_addr  [`AXI4_MAX_OUTSTANDING];
  bit [7:0]                   excl_len   [`AXI4_MAX_OUTSTANDING];
  bit [2:0]                   excl_size  [`AXI4_MAX_OUTSTANDING];
  bit                         excl_valid [`AXI4_MAX_OUTSTANDING];

  // Response delay
  int unsigned resp_delay = 1;

  `uvm_component_utils(axi4_slave_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    foreach (excl_valid[i]) excl_valid[i] = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4_interface)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found for slave driver")
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    @(posedge vif.aresetn);
    @(posedge vif.aclk);

    fork
      handle_writes();
      handle_reads();
    join
  endtask

  // ---- Reset slave-driven signals ----
  task reset_signals();
    vif.awready <= 0;
    vif.wready  <= 0;
    vif.bvalid  <= 0;
    vif.bid     <= 0;
    vif.bresp   <= 0;
    vif.buser   <= 0;
    vif.arready <= 0;
    vif.rvalid  <= 0;
    vif.rid     <= 0;
    vif.rdata   <= 0;
    vif.rresp   <= 0;
    vif.rlast   <= 0;
    vif.ruser   <= 0;
  endtask

  // ============================================================
  // Handle Write Transactions
  // ============================================================
  task handle_writes();
    forever begin
      // Local variables for this transaction
      bit [`AXI4_ID_WIDTH-1:0]   aw_id;
      bit [`AXI4_ADDR_WIDTH-1:0] aw_addr;
      bit [7:0]                   aw_len;
      bit [2:0]                   aw_size;
      bit [1:0]                   aw_burst;
      bit                         aw_lock;
      bit [1:0]                   resp;

      // Accept AW
      vif.awready <= 1;
      @(posedge vif.aclk);
      while (!vif.awvalid) @(posedge vif.aclk);
      
      aw_id    = vif.awid;
      aw_addr  = vif.awaddr;
      aw_len   = vif.awlen;
      aw_size  = vif.awsize;
      aw_burst = vif.awburst;
      aw_lock  = vif.awlock;
      vif.awready <= 0;

      // Accept W data beats
      for (int i = 0; i <= aw_len; i++) begin
        vif.wready <= 1;
        @(posedge vif.aclk);
        while (!vif.wvalid) @(posedge vif.aclk);

        begin
          // Calculate beat address
          bit [`AXI4_ADDR_WIDTH-1:0] beat_addr;
          int unsigned num_bytes = 1 << aw_size;
          int unsigned bus_bytes = `AXI4_DATA_WIDTH / 8;
          bit [`AXI4_ADDR_WIDTH-1:0] aligned_addr = (aw_addr / num_bytes) * num_bytes;
          bit [`AXI4_ADDR_WIDTH-1:0] base_addr;

          // Calculate beat address based on burst type
          case (aw_burst)
            2'b00: beat_addr = aw_addr; // FIXED
            2'b01: begin // INCR
              if (i == 0) beat_addr = aw_addr;
              else beat_addr = aligned_addr + i * num_bytes;
            end
            2'b10: begin // WRAP
              if (i == 0) beat_addr = aw_addr;
              else beat_addr = aligned_addr + i * num_bytes;
              begin
                int unsigned container = num_bytes * (aw_len + 1);
                bit [`AXI4_ADDR_WIDTH-1:0] lower = (aw_addr / container) * container;
                bit [`AXI4_ADDR_WIDTH-1:0] upper = lower + container;
                if (beat_addr >= upper)
                  beat_addr = lower + (beat_addr - lower) % container;
              end
            end
            default: beat_addr = aw_addr;
          endcase

          base_addr = (beat_addr / bus_bytes) * bus_bytes;

          // Write bytes based on WSTRB
          for (int b = 0; b < bus_bytes; b++) begin
            if (vif.wstrb[b])
              mem[base_addr + b] = vif.wdata[b*8 +: 8];
          end
        end

        vif.wready <= 0;
      end

      // Determine response
      if (aw_lock) begin
        // Exclusive write - check exclusive monitor
        resp = check_exclusive_write(aw_id, aw_addr, aw_len, aw_size);
      end else begin
        resp = 2'b00; // OKAY
        // Clear exclusive monitor for this address range
        clear_exclusive(aw_addr, aw_len, aw_size);
      end

      // Send B response
      repeat(resp_delay) @(posedge vif.aclk);
      @(posedge vif.aclk);
      vif.bid    <= aw_id;
      vif.bresp  <= resp;
      vif.buser  <= 0;
      vif.bvalid <= 1;

      @(posedge vif.aclk);
      while (!vif.bready) @(posedge vif.aclk);
      vif.bvalid <= 0;
    end
  endtask

  // ============================================================
  // Handle Read Transactions
  // ============================================================
  task handle_reads();
    forever begin
      bit [`AXI4_ID_WIDTH-1:0]   ar_id;
      bit [`AXI4_ADDR_WIDTH-1:0] ar_addr;
      bit [7:0]                   ar_len;
      bit [2:0]                   ar_size;
      bit [1:0]                   ar_burst;
      bit                         ar_lock;

      // Accept AR
      vif.arready <= 1;
      @(posedge vif.aclk);
      while (!vif.arvalid) @(posedge vif.aclk);

      ar_id    = vif.arid;
      ar_addr  = vif.araddr;
      ar_len   = vif.arlen;
      ar_size  = vif.arsize;
      ar_burst = vif.arburst;
      ar_lock  = vif.arlock;
      vif.arready <= 0;

      // Set exclusive monitor for exclusive reads
      if (ar_lock) begin
        set_exclusive(ar_id, ar_addr, ar_len, ar_size);
      end

      // Send R data beats
      for (int i = 0; i <= ar_len; i++) begin
        bit [`AXI4_ADDR_WIDTH-1:0] beat_addr;
        bit [`AXI4_DATA_WIDTH-1:0] rdata_val;
        int unsigned num_bytes = 1 << ar_size;
        int unsigned bus_bytes = `AXI4_DATA_WIDTH / 8;
        bit [`AXI4_ADDR_WIDTH-1:0] aligned_addr = (ar_addr / num_bytes) * num_bytes;
        bit [`AXI4_ADDR_WIDTH-1:0] base_addr;

        // Calculate beat address
        case (ar_burst)
          2'b00: beat_addr = ar_addr;
          2'b01: begin
            if (i == 0) beat_addr = ar_addr;
            else beat_addr = aligned_addr + i * num_bytes;
          end
          2'b10: begin
            if (i == 0) beat_addr = ar_addr;
            else beat_addr = aligned_addr + i * num_bytes;
            begin
              int unsigned container = num_bytes * (ar_len + 1);
              bit [`AXI4_ADDR_WIDTH-1:0] lower = (ar_addr / container) * container;
              bit [`AXI4_ADDR_WIDTH-1:0] upper = lower + container;
              if (beat_addr >= upper)
                beat_addr = lower + (beat_addr - lower) % container;
            end
          end
          default: beat_addr = ar_addr;
        endcase

        base_addr = (beat_addr / bus_bytes) * bus_bytes;

        // Read bytes from memory
        rdata_val = '0;
        for (int b = 0; b < bus_bytes; b++) begin
          if (mem.exists(base_addr + b))
            rdata_val[b*8 +: 8] = mem[base_addr + b];
          else
            rdata_val[b*8 +: 8] = 8'h00;
        end

        repeat(resp_delay) @(posedge vif.aclk);
        @(posedge vif.aclk);
        vif.rid    <= ar_id;
        vif.rdata  <= rdata_val;
        vif.rlast  <= (i == ar_len) ? 1'b1 : 1'b0;
        vif.ruser  <= 0;

        // Response: EXOKAY for exclusive, OKAY otherwise
        if (ar_lock)
          vif.rresp <= 2'b01; // EXOKAY
        else
          vif.rresp <= 2'b00; // OKAY

        vif.rvalid <= 1;

        @(posedge vif.aclk);
        while (!vif.rready) @(posedge vif.aclk);
        vif.rvalid <= 0;
        vif.rlast  <= 0;
      end
    end
  endtask

  // ============================================================
  // Exclusive Access Support
  // ============================================================
  function void set_exclusive(bit [`AXI4_ID_WIDTH-1:0] id, 
                              bit [`AXI4_ADDR_WIDTH-1:0] addr,
                              bit [7:0] len, bit [2:0] size);
    int idx = id % `AXI4_MAX_OUTSTANDING;
    excl_addr[idx]  = addr;
    excl_len[idx]   = len;
    excl_size[idx]  = size;
    excl_valid[idx] = 1;
  endfunction

  function bit [1:0] check_exclusive_write(bit [`AXI4_ID_WIDTH-1:0] id,
                                            bit [`AXI4_ADDR_WIDTH-1:0] addr,
                                            bit [7:0] len, bit [2:0] size);
    int idx = id % `AXI4_MAX_OUTSTANDING;
    if (excl_valid[idx] && excl_addr[idx] == addr && 
        excl_len[idx] == len && excl_size[idx] == size) begin
      excl_valid[idx] = 0;
      return 2'b01; // EXOKAY
    end else begin
      return 2'b00; // OKAY (exclusive failed)
    end
  endfunction

  function void clear_exclusive(bit [`AXI4_ADDR_WIDTH-1:0] addr,
                                bit [7:0] len, bit [2:0] size);
    for (int i = 0; i < `AXI4_MAX_OUTSTANDING; i++) begin
      if (excl_valid[i] && excl_addr[i] == addr)
        excl_valid[i] = 0;
    end
  endfunction

  // ============================================================
  // Memory access methods (for scoreboard)
  // ============================================================
  function void write_mem(bit [`AXI4_ADDR_WIDTH-1:0] addr, bit [7:0] data);
    mem[addr] = data;
  endfunction

  function bit [7:0] read_mem(bit [`AXI4_ADDR_WIDTH-1:0] addr);
    if (mem.exists(addr))
      return mem[addr];
    else
      return 8'h00;
  endfunction

  function void clear_mem();
    mem.delete();
  endfunction

endclass
