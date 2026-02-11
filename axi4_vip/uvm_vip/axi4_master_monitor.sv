//==========================================================================
// axi4_master_monitor.sv - AXI4 Master-side Monitor
//==========================================================================

class axi4_master_monitor extends uvm_monitor;

  virtual axi4_interface vif;

  uvm_analysis_port #(axi4_transaction) write_ap;
  uvm_analysis_port #(axi4_transaction) read_ap;

  `uvm_component_utils(axi4_master_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    write_ap = new("write_ap", this);
    read_ap  = new("read_ap", this);
    if (!uvm_config_db#(virtual axi4_interface)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found for master monitor")
  endfunction

  task run_phase(uvm_phase phase);
    @(posedge vif.aresetn);
    fork
      monitor_writes();
      monitor_reads();
    join
  endtask

  // ============================================================
  // Monitor Write Transactions
  // ============================================================
  task monitor_writes();
    forever begin
      axi4_transaction tr;
      tr = axi4_transaction::type_id::create("wr_mon_tr");

      // Wait for AW handshake
      @(posedge vif.aclk);
      while (!(vif.awvalid && vif.awready)) @(posedge vif.aclk);

      tr.txn_type = AXI4_WRITE;
      tr.id       = vif.awid;
      tr.addr     = vif.awaddr;
      tr.len      = vif.awlen;
      tr.size     = vif.awsize;
      tr.burst    = axi4_burst_type_e'(vif.awburst);
      tr.lock     = vif.awlock;
      tr.cache    = vif.awcache;
      tr.prot     = vif.awprot;
      tr.qos      = vif.awqos;
      tr.region   = vif.awregion;
      tr.user     = vif.awuser;

      // Collect W data beats
      tr.data = new[tr.len + 1];
      tr.strb = new[tr.len + 1];

      for (int i = 0; i <= tr.len; i++) begin
        @(posedge vif.aclk);
        while (!(vif.wvalid && vif.wready)) @(posedge vif.aclk);
        tr.data[i] = vif.wdata;
        tr.strb[i] = vif.wstrb;
      end

      // Wait for B handshake
      @(posedge vif.aclk);
      while (!(vif.bvalid && vif.bready)) @(posedge vif.aclk);
      tr.bresp = vif.bresp;

      `uvm_info(get_type_name(), $sformatf("MON WR: addr=0x%0h, len=%0d, bresp=%0d", 
                tr.addr, tr.len, tr.bresp), UVM_HIGH)
      write_ap.write(tr);
    end
  endtask

  // ============================================================
  // Monitor Read Transactions
  // ============================================================
  task monitor_reads();
    forever begin
      axi4_transaction tr;
      tr = axi4_transaction::type_id::create("rd_mon_tr");

      // Wait for AR handshake
      @(posedge vif.aclk);
      while (!(vif.arvalid && vif.arready)) @(posedge vif.aclk);

      tr.txn_type = AXI4_READ;
      tr.id       = vif.arid;
      tr.addr     = vif.araddr;
      tr.len      = vif.arlen;
      tr.size     = vif.arsize;
      tr.burst    = axi4_burst_type_e'(vif.arburst);
      tr.lock     = vif.arlock;
      tr.cache    = vif.arcache;
      tr.prot     = vif.arprot;
      tr.qos      = vif.arqos;
      tr.region   = vif.arregion;
      tr.user     = vif.aruser;

      // Collect R data beats
      tr.rdata = new[tr.len + 1];
      tr.rresp = new[tr.len + 1];

      for (int i = 0; i <= tr.len; i++) begin
        @(posedge vif.aclk);
        while (!(vif.rvalid && vif.rready)) @(posedge vif.aclk);
        tr.rdata[i] = vif.rdata;
        tr.rresp[i] = vif.rresp;
      end

      `uvm_info(get_type_name(), $sformatf("MON RD: addr=0x%0h, len=%0d", 
                tr.addr, tr.len), UVM_HIGH)
      read_ap.write(tr);
    end
  endtask

endclass
