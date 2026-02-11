//==========================================================================
// AXI4 Master Monitor - Observes AXI4 bus transactions
//==========================================================================

// Declare analysis port suffixes for multiple ports
`uvm_analysis_imp_decl(_write)
`uvm_analysis_imp_decl(_read)

class axi4_master_monitor extends uvm_monitor;

  `uvm_component_utils(axi4_master_monitor)

  virtual axi4_interface vif;

  // Analysis ports for write and read transactions
  uvm_analysis_port #(axi4_seq_item) write_ap;
  uvm_analysis_port #(axi4_seq_item) read_ap;

  function new(string name = "axi4_master_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    write_ap = new("write_ap", this);
    read_ap  = new("read_ap", this);
    if (!uvm_config_db#(virtual axi4_interface)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in config DB")
  endfunction

  task run_phase(uvm_phase phase);
    // Wait for reset
    @(posedge vif.aresetn);
    @(posedge vif.aclk);

    fork
      monitor_write_txns();
      monitor_read_txns();
    join_none
  endtask

  //------------------------------------------------------------------------
  // Monitor complete write transactions (AW -> W beats -> B)
  //------------------------------------------------------------------------
  task monitor_write_txns();
    forever begin
      axi4_seq_item item;

      // Wait for AW handshake
      @(posedge vif.aclk);
      while (!(vif.awvalid && vif.awready)) @(posedge vif.aclk);

      // Capture AW channel
      item = axi4_seq_item::type_id::create("mon_wr_item");
      item.txn_type = AXI4_WRITE;
      item.id       = vif.awid;
      item.addr     = vif.awaddr;
      item.len      = vif.awlen;
      item.size     = vif.awsize;
      item.burst    = axi4_burst_type_e'(vif.awburst);
      item.lock     = vif.awlock;
      item.cache    = vif.awcache;
      item.prot     = vif.awprot;
      item.qos      = vif.awqos;
      item.region   = vif.awregion;
      item.data     = new[item.len + 1];
      item.wstrb    = new[item.len + 1];

      // Capture W channel beats
      for (int i = 0; i <= item.len; i++) begin
        @(posedge vif.aclk);
        while (!(vif.wvalid && vif.wready)) @(posedge vif.aclk);
        item.data[i]  = vif.wdata;
        item.wstrb[i] = vif.wstrb;
      end

      // Capture B channel
      @(posedge vif.aclk);
      while (!(vif.bvalid && vif.bready)) @(posedge vif.aclk);
      item.resp = vif.bresp;

      `uvm_info("MON", $sformatf("Write observed: %s resp=%0b", item.convert2string(), item.resp), UVM_HIGH)
      write_ap.write(item);
    end
  endtask

  //------------------------------------------------------------------------
  // Monitor complete read transactions (AR -> R beats)
  //------------------------------------------------------------------------
  task monitor_read_txns();
    forever begin
      axi4_seq_item item;

      // Wait for AR handshake
      @(posedge vif.aclk);
      while (!(vif.arvalid && vif.arready)) @(posedge vif.aclk);

      // Capture AR channel
      item = axi4_seq_item::type_id::create("mon_rd_item");
      item.txn_type = AXI4_READ;
      item.id       = vif.arid;
      item.addr     = vif.araddr;
      item.len      = vif.arlen;
      item.size     = vif.arsize;
      item.burst    = axi4_burst_type_e'(vif.arburst);
      item.lock     = vif.arlock;
      item.cache    = vif.arcache;
      item.prot     = vif.arprot;
      item.qos      = vif.arqos;
      item.region   = vif.arregion;
      item.rdata    = new[item.len + 1];
      item.rresp    = new[item.len + 1];

      // Capture R channel beats
      for (int i = 0; i <= item.len; i++) begin
        @(posedge vif.aclk);
        while (!(vif.rvalid && vif.rready)) @(posedge vif.aclk);
        item.rdata[i] = vif.rdata;
        item.rresp[i] = vif.rresp;
      end

      `uvm_info("MON", $sformatf("Read observed: %s", item.convert2string()), UVM_HIGH)
      read_ap.write(item);
    end
  endtask

endclass
