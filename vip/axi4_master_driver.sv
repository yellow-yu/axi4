//==========================================================================
// AXI4 Master Driver - Drives AXI4 master transactions onto the bus
//==========================================================================
class axi4_master_driver extends uvm_driver #(axi4_seq_item);

  `uvm_component_utils(axi4_master_driver)

  virtual axi4_interface vif;

  function new(string name = "axi4_master_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4_interface)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in config DB")
  endfunction

  task run_phase(uvm_phase phase);
    axi4_seq_item item;

    // Initialize all master outputs
    reset_master_signals();

    // Wait for reset deassertion
    @(posedge vif.aresetn);
    @(posedge vif.aclk);

    forever begin
      seq_item_port.get_next_item(item);
      `uvm_info("MDRV", $sformatf("Driving: %s", item.convert2string()), UVM_MEDIUM)

      if (item.txn_type == AXI4_WRITE)
        drive_write(item);
      else
        drive_read(item);

      seq_item_port.item_done();
    end
  endtask

  //------------------------------------------------------------------------
  // Reset all master-driven signals
  //------------------------------------------------------------------------
  task reset_master_signals();
    vif.awid     <= '0;
    vif.awaddr   <= '0;
    vif.awlen    <= '0;
    vif.awsize   <= '0;
    vif.awburst  <= '0;
    vif.awlock   <= '0;
    vif.awcache  <= '0;
    vif.awprot   <= '0;
    vif.awqos    <= '0;
    vif.awregion <= '0;
    vif.awuser   <= '0;
    vif.awvalid  <= 1'b0;

    vif.wdata    <= '0;
    vif.wstrb    <= '0;
    vif.wlast    <= 1'b0;
    vif.wuser    <= '0;
    vif.wvalid   <= 1'b0;

    vif.bready   <= 1'b0;

    vif.arid     <= '0;
    vif.araddr   <= '0;
    vif.arlen    <= '0;
    vif.arsize   <= '0;
    vif.arburst  <= '0;
    vif.arlock   <= '0;
    vif.arcache  <= '0;
    vif.arprot   <= '0;
    vif.arqos    <= '0;
    vif.arregion <= '0;
    vif.aruser   <= '0;
    vif.arvalid  <= 1'b0;

    vif.rready   <= 1'b0;
  endtask

  //------------------------------------------------------------------------
  // Drive a complete write transaction (AW + W + B)
  //------------------------------------------------------------------------
  task drive_write(axi4_seq_item item);
    // Phase 1: Drive Write Address Channel
    @(posedge vif.aclk);
    vif.awid     <= item.id;
    vif.awaddr   <= item.addr;
    vif.awlen    <= item.len;
    vif.awsize   <= item.size;
    vif.awburst  <= item.burst;
    vif.awlock   <= item.lock;
    vif.awcache  <= item.cache;
    vif.awprot   <= item.prot;
    vif.awqos    <= item.qos;
    vif.awregion <= item.region;
    vif.awuser   <= item.user;
    vif.awvalid  <= 1'b1;

    // Wait for AW handshake
    @(posedge vif.aclk);
    while (!vif.awready) @(posedge vif.aclk);
    vif.awvalid  <= 1'b0;

    // Phase 2: Drive Write Data Channel
    for (int beat = 0; beat <= item.len; beat++) begin
      @(posedge vif.aclk);
      vif.wdata  <= item.data[beat];
      vif.wstrb  <= item.wstrb[beat];
      vif.wlast  <= (beat == item.len) ? 1'b1 : 1'b0;
      vif.wvalid <= 1'b1;

      // Wait for W handshake
      @(posedge vif.aclk);
      while (!vif.wready) @(posedge vif.aclk);
    end
    vif.wvalid <= 1'b0;
    vif.wlast  <= 1'b0;

    // Phase 3: Wait for Write Response
    @(posedge vif.aclk);
    vif.bready <= 1'b1;
    @(posedge vif.aclk);
    while (!vif.bvalid) @(posedge vif.aclk);
    item.resp = vif.bresp;
    vif.bready <= 1'b0;

    `uvm_info("MDRV", $sformatf("Write complete: addr=0x%0h resp=%0b", item.addr, item.resp), UVM_HIGH)
  endtask

  //------------------------------------------------------------------------
  // Drive a complete read transaction (AR + R)
  //------------------------------------------------------------------------
  task drive_read(axi4_seq_item item);
    // Phase 1: Drive Read Address Channel
    @(posedge vif.aclk);
    vif.arid     <= item.id;
    vif.araddr   <= item.addr;
    vif.arlen    <= item.len;
    vif.arsize   <= item.size;
    vif.arburst  <= item.burst;
    vif.arlock   <= item.lock;
    vif.arcache  <= item.cache;
    vif.arprot   <= item.prot;
    vif.arqos    <= item.qos;
    vif.arregion <= item.region;
    vif.aruser   <= item.user;
    vif.arvalid  <= 1'b1;

    // Wait for AR handshake
    @(posedge vif.aclk);
    while (!vif.arready) @(posedge vif.aclk);
    vif.arvalid <= 1'b0;

    // Phase 2: Receive Read Data
    item.rdata = new[item.len + 1];
    item.rresp = new[item.len + 1];
    vif.rready <= 1'b1;

    for (int beat = 0; beat <= item.len; beat++) begin
      @(posedge vif.aclk);
      while (!vif.rvalid) @(posedge vif.aclk);
      item.rdata[beat] = vif.rdata;
      item.rresp[beat] = vif.rresp;
    end
    vif.rready <= 1'b0;

    `uvm_info("MDRV", $sformatf("Read complete: addr=0x%0h %0d beats", item.addr, item.len + 1), UVM_HIGH)
  endtask

endclass
