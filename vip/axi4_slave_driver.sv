//==========================================================================
// AXI4 Slave Driver - Reactive slave with internal memory model
//==========================================================================
class axi4_slave_driver extends uvm_component;

  `uvm_component_utils(axi4_slave_driver)

  virtual axi4_interface vif;

  // Internal byte-addressable memory model
  bit [7:0] mem[int unsigned];

  // Configuration
  bit       enable_random_delay = 0;
  int       max_delay = 3;

  function new(string name = "axi4_slave_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4_interface)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in config DB")
  endfunction

  task run_phase(uvm_phase phase);
    // Initialize slave outputs
    reset_slave_signals();

    // Wait for reset
    @(posedge vif.aresetn);
    @(posedge vif.aclk);

    fork
      handle_writes();
      handle_reads();
    join_none
  endtask

  //------------------------------------------------------------------------
  // Reset all slave-driven signals
  //------------------------------------------------------------------------
  task reset_slave_signals();
    vif.awready <= 1'b0;
    vif.wready  <= 1'b0;
    vif.bid     <= '0;
    vif.bresp   <= '0;
    vif.buser   <= '0;
    vif.bvalid  <= 1'b0;
    vif.arready <= 1'b0;
    vif.rid     <= '0;
    vif.rdata   <= '0;
    vif.rresp   <= '0;
    vif.rlast   <= 1'b0;
    vif.ruser   <= '0;
    vif.rvalid  <= 1'b0;
  endtask

  //------------------------------------------------------------------------
  // Handle write transactions (AW -> W -> B)
  //------------------------------------------------------------------------
  task handle_writes();
    bit [AXI4_ID_WIDTH-1:0]   aw_id;
    bit [AXI4_ADDR_WIDTH-1:0] aw_addr;
    bit [7:0]                  aw_len;
    bit [2:0]                  aw_size;
    bit [1:0]                  aw_burst;
    bit                        aw_lock;
    bit [AXI4_ADDR_WIDTH-1:0] beat_addrs[];

    forever begin
      // === Accept Write Address ===
      vif.awready <= 1'b1;
      @(posedge vif.aclk);
      while (!vif.awvalid) @(posedge vif.aclk);

      // Capture AW info
      aw_id    = vif.awid;
      aw_addr  = vif.awaddr;
      aw_len   = vif.awlen;
      aw_size  = vif.awsize;
      aw_burst = vif.awburst;
      aw_lock  = vif.awlock;
      vif.awready <= 1'b0;

      // Calculate beat addresses
      axi4_calc_beat_addrs(aw_addr, aw_size, aw_burst, aw_len, beat_addrs);

      // === Accept Write Data ===
      vif.wready <= 1'b1;
      for (int beat = 0; beat <= aw_len; beat++) begin
        @(posedge vif.aclk);
        while (!vif.wvalid) @(posedge vif.aclk);

        // Store data based on strobe
        store_beat_data(beat_addrs[beat], aw_size, vif.wdata, vif.wstrb);
      end
      vif.wready <= 1'b0;

      // Optional delay before response
      if (enable_random_delay) begin
        repeat ($urandom_range(0, max_delay)) @(posedge vif.aclk);
      end

      // === Send Write Response ===
      // Drive immediately (same cycle as last W handshake)
      vif.bid    <= aw_id;
      vif.bresp  <= (aw_lock) ? 2'b01 : 2'b00;  // EXOKAY for exclusive, OKAY otherwise
      vif.bvalid <= 1'b1;
      @(posedge vif.aclk);
      while (!vif.bready) @(posedge vif.aclk);
      vif.bvalid <= 1'b0;
    end
  endtask

  //------------------------------------------------------------------------
  // Handle read transactions (AR -> R)
  //------------------------------------------------------------------------
  task handle_reads();
    bit [AXI4_ID_WIDTH-1:0]   ar_id;
    bit [AXI4_ADDR_WIDTH-1:0] ar_addr;
    bit [7:0]                  ar_len;
    bit [2:0]                  ar_size;
    bit [1:0]                  ar_burst;
    bit                        ar_lock;
    bit [AXI4_ADDR_WIDTH-1:0] beat_addrs[];

    forever begin
      // === Accept Read Address ===
      vif.arready <= 1'b1;
      @(posedge vif.aclk);
      while (!vif.arvalid) @(posedge vif.aclk);

      // Capture AR info
      ar_id    = vif.arid;
      ar_addr  = vif.araddr;
      ar_len   = vif.arlen;
      ar_size  = vif.arsize;
      ar_burst = vif.arburst;
      ar_lock  = vif.arlock;
      vif.arready <= 1'b0;

      // Calculate beat addresses
      axi4_calc_beat_addrs(ar_addr, ar_size, ar_burst, ar_len, beat_addrs);

      // === Send Read Data ===
      // Drive data immediately for each beat (no extra wait cycle)
      for (int beat = 0; beat <= ar_len; beat++) begin
        // Optional delay
        if (enable_random_delay) begin
          repeat ($urandom_range(0, max_delay)) @(posedge vif.aclk);
        end

        vif.rid    <= ar_id;
        vif.rdata  <= read_beat_data(beat_addrs[beat], ar_size);
        vif.rresp  <= (ar_lock) ? 2'b01 : 2'b00;
        vif.rlast  <= (beat == ar_len) ? 1'b1 : 1'b0;
        vif.rvalid <= 1'b1;

        @(posedge vif.aclk);
        while (!vif.rready) @(posedge vif.aclk);
      end
      vif.rvalid <= 1'b0;
      vif.rlast  <= 1'b0;
    end
  endtask

  //------------------------------------------------------------------------
  // Store one beat of data into memory
  //------------------------------------------------------------------------
  function void store_beat_data(
    input bit [AXI4_ADDR_WIDTH-1:0]  beat_addr,
    input bit [2:0]                   size,
    input bit [AXI4_DATA_WIDTH-1:0]  wdata,
    input bit [AXI4_STRB_WIDTH-1:0]  wstrb
  );
    int unsigned base_addr;
    base_addr = (beat_addr / AXI4_STRB_WIDTH) * AXI4_STRB_WIDTH;

    for (int b = 0; b < AXI4_STRB_WIDTH; b++) begin
      if (wstrb[b]) begin
        mem[base_addr + b] = wdata[b*8 +: 8];
      end
    end
  endfunction

  //------------------------------------------------------------------------
  // Read one beat of data from memory
  //------------------------------------------------------------------------
  function bit [AXI4_DATA_WIDTH-1:0] read_beat_data(
    input bit [AXI4_ADDR_WIDTH-1:0]  beat_addr,
    input bit [2:0]                   size
  );
    bit [AXI4_DATA_WIDTH-1:0] rdata;
    int unsigned base_addr;

    base_addr = (beat_addr / AXI4_STRB_WIDTH) * AXI4_STRB_WIDTH;
    rdata = '0;

    for (int b = 0; b < AXI4_STRB_WIDTH; b++) begin
      if (mem.exists(base_addr + b))
        rdata[b*8 +: 8] = mem[base_addr + b];
    end

    return rdata;
  endfunction

endclass
