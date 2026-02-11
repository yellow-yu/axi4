//==========================================================================
// axi4_master_driver.sv - AXI4 Master Driver
//==========================================================================

class axi4_master_driver extends uvm_driver #(axi4_transaction);

  virtual axi4_interface vif;

  `uvm_component_utils(axi4_master_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4_interface)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found for master driver")
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    @(posedge vif.aresetn);
    @(posedge vif.aclk);

    forever begin
      axi4_transaction tr;
      seq_item_port.get_next_item(tr);
      `uvm_info(get_type_name(), $sformatf("Driving %s transaction: addr=0x%0h, len=%0d, size=%0d, burst=%s",
                tr.txn_type.name(), tr.addr, tr.len, tr.size, tr.burst.name()), UVM_MEDIUM)
      case (tr.txn_type)
        AXI4_WRITE: drive_write(tr);
        AXI4_READ:  drive_read(tr);
      endcase
      seq_item_port.item_done();
    end
  endtask

  // ---- Reset all master-driven signals ----
  task reset_signals();
    vif.awvalid  <= 0;
    vif.awid     <= 0;
    vif.awaddr   <= 0;
    vif.awlen    <= 0;
    vif.awsize   <= 0;
    vif.awburst  <= 0;
    vif.awlock   <= 0;
    vif.awcache  <= 0;
    vif.awprot   <= 0;
    vif.awqos    <= 0;
    vif.awregion <= 0;
    vif.awuser   <= 0;

    vif.wvalid   <= 0;
    vif.wdata    <= 0;
    vif.wstrb    <= 0;
    vif.wlast    <= 0;
    vif.wuser    <= 0;

    vif.bready   <= 0;

    vif.arvalid  <= 0;
    vif.arid     <= 0;
    vif.araddr   <= 0;
    vif.arlen    <= 0;
    vif.arsize   <= 0;
    vif.arburst  <= 0;
    vif.arlock   <= 0;
    vif.arcache  <= 0;
    vif.arprot   <= 0;
    vif.arqos    <= 0;
    vif.arregion <= 0;
    vif.aruser   <= 0;

    vif.rready   <= 0;
  endtask

  // ============================================================
  // Write Transaction
  // ============================================================
  task drive_write(axi4_transaction tr);
    fork
      drive_aw_channel(tr);
      drive_w_channel(tr);
    join
    collect_b_response(tr);
  endtask

  task drive_aw_channel(axi4_transaction tr);
    // Optional delay before address
    repeat(tr.addr_delay) @(posedge vif.aclk);

    @(posedge vif.aclk);
    vif.awid     <= tr.id;
    vif.awaddr   <= tr.addr;
    vif.awlen    <= tr.len;
    vif.awsize   <= tr.size;
    vif.awburst  <= tr.burst;
    vif.awlock   <= tr.lock;
    vif.awcache  <= tr.cache;
    vif.awprot   <= tr.prot;
    vif.awqos    <= tr.qos;
    vif.awregion <= tr.region;
    vif.awuser   <= tr.user;
    vif.awvalid  <= 1;

    @(posedge vif.aclk);
    while (!vif.awready) @(posedge vif.aclk);

    vif.awvalid <= 0;
  endtask

  task drive_w_channel(axi4_transaction tr);
    for (int i = 0; i <= tr.len; i++) begin
      // Optional delay between beats
      if (i > 0) repeat(tr.data_delay) @(posedge vif.aclk);

      @(posedge vif.aclk);
      vif.wdata  <= tr.data[i];
      vif.wstrb  <= tr.strb[i];
      vif.wlast  <= (i == tr.len) ? 1'b1 : 1'b0;
      vif.wuser  <= tr.user;
      vif.wvalid <= 1;

      @(posedge vif.aclk);
      while (!vif.wready) @(posedge vif.aclk);
      // Deassert wvalid after handshake to prevent spurious accepts
      vif.wvalid <= 0;
    end

    vif.wlast  <= 0;
  endtask

  task collect_b_response(axi4_transaction tr);
    vif.bready <= 1;
    @(posedge vif.aclk);
    while (!vif.bvalid) @(posedge vif.aclk);
    tr.bresp = vif.bresp;
    @(posedge vif.aclk);
    vif.bready <= 0;
  endtask

  // ============================================================
  // Read Transaction
  // ============================================================
  task drive_read(axi4_transaction tr);
    drive_ar_channel(tr);
    collect_r_data(tr);
  endtask

  task drive_ar_channel(axi4_transaction tr);
    repeat(tr.addr_delay) @(posedge vif.aclk);

    @(posedge vif.aclk);
    vif.arid     <= tr.id;
    vif.araddr   <= tr.addr;
    vif.arlen    <= tr.len;
    vif.arsize   <= tr.size;
    vif.arburst  <= tr.burst;
    vif.arlock   <= tr.lock;
    vif.arcache  <= tr.cache;
    vif.arprot   <= tr.prot;
    vif.arqos    <= tr.qos;
    vif.arregion <= tr.region;
    vif.aruser   <= tr.user;
    vif.arvalid  <= 1;

    @(posedge vif.aclk);
    while (!vif.arready) @(posedge vif.aclk);

    vif.arvalid <= 0;
  endtask

  task collect_r_data(axi4_transaction tr);
    tr.rdata = new[tr.len + 1];
    tr.rresp = new[tr.len + 1];

    vif.rready <= 1;

    for (int i = 0; i <= tr.len; i++) begin
      @(posedge vif.aclk);
      while (!vif.rvalid) @(posedge vif.aclk);
      tr.rdata[i] = vif.rdata;
      tr.rresp[i] = vif.rresp;
    end

    @(posedge vif.aclk);
    vif.rready <= 0;
  endtask

endclass
