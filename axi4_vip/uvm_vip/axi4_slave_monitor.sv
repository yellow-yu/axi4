//==========================================================================
// axi4_slave_monitor.sv - AXI4 Slave-side Monitor
//==========================================================================
// This monitor observes from the slave perspective. 
// In our testbench, the master monitor is the primary observer.
// This slave monitor can be used for additional protocol checking.

class axi4_slave_monitor extends uvm_monitor;

  virtual axi4_interface vif;

  uvm_analysis_port #(axi4_transaction) write_ap;
  uvm_analysis_port #(axi4_transaction) read_ap;

  `uvm_component_utils(axi4_slave_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    write_ap = new("write_ap", this);
    read_ap  = new("read_ap", this);
    if (!uvm_config_db#(virtual axi4_interface)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found for slave monitor")
  endfunction

  task run_phase(uvm_phase phase);
    @(posedge vif.aresetn);
    fork
      monitor_writes();
      monitor_reads();
    join
  endtask

  task monitor_writes();
    forever begin
      axi4_transaction tr;
      tr = axi4_transaction::type_id::create("slv_wr_mon");

      @(posedge vif.aclk);
      while (!(vif.awvalid && vif.awready)) @(posedge vif.aclk);

      tr.txn_type = AXI4_WRITE;
      tr.id       = vif.awid;
      tr.addr     = vif.awaddr;
      tr.len      = vif.awlen;
      tr.size     = vif.awsize;
      tr.burst    = axi4_burst_type_e'(vif.awburst);
      tr.lock     = vif.awlock;

      tr.data = new[tr.len + 1];
      tr.strb = new[tr.len + 1];

      for (int i = 0; i <= tr.len; i++) begin
        @(posedge vif.aclk);
        while (!(vif.wvalid && vif.wready)) @(posedge vif.aclk);
        tr.data[i] = vif.wdata;
        tr.strb[i] = vif.wstrb;
      end

      @(posedge vif.aclk);
      while (!(vif.bvalid && vif.bready)) @(posedge vif.aclk);
      tr.bresp = vif.bresp;

      write_ap.write(tr);
    end
  endtask

  task monitor_reads();
    forever begin
      axi4_transaction tr;
      tr = axi4_transaction::type_id::create("slv_rd_mon");

      @(posedge vif.aclk);
      while (!(vif.arvalid && vif.arready)) @(posedge vif.aclk);

      tr.txn_type = AXI4_READ;
      tr.id       = vif.arid;
      tr.addr     = vif.araddr;
      tr.len      = vif.arlen;
      tr.size     = vif.arsize;
      tr.burst    = axi4_burst_type_e'(vif.arburst);
      tr.lock     = vif.arlock;

      tr.rdata = new[tr.len + 1];
      tr.rresp = new[tr.len + 1];

      for (int i = 0; i <= tr.len; i++) begin
        @(posedge vif.aclk);
        while (!(vif.rvalid && vif.rready)) @(posedge vif.aclk);
        tr.rdata[i] = vif.rdata;
        tr.rresp[i] = vif.rresp;
      end

      read_ap.write(tr);
    end
  endtask

endclass
