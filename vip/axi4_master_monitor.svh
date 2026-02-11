//==========================================================================
// axi4_master_monitor.svh - AXI4 Monitor
//==========================================================================

`ifndef AXI4_MASTER_MONITOR_SVH
`define AXI4_MASTER_MONITOR_SVH

class axi4_master_monitor extends uvm_monitor;

    `uvm_component_utils(axi4_master_monitor)

    axi4_vif vif;

    // Analysis ports
    uvm_analysis_port #(axi4_transaction) write_ap;
    uvm_analysis_port #(axi4_transaction) read_ap;

    function new(string name = "axi4_master_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        write_ap = new("write_ap", this);
        read_ap  = new("read_ap", this);
        if (!uvm_config_db#(axi4_vif)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not set for monitor")
    endfunction

    task run_phase(uvm_phase phase);
        // Wait for reset deassertion
        @(posedge vif.aresetn);
        @(posedge vif.aclk);

        fork
            monitor_write();
            monitor_read();
        join
    endtask

    //----------------------------------------------------------------------
    // Monitor Write Transactions (AW + W + B)
    //----------------------------------------------------------------------
    task monitor_write();
        axi4_transaction tr;

        forever begin
            // Wait for AW handshake
            do begin
                @(posedge vif.aclk);
            end while (!(vif.awvalid && vif.awready));

            tr = axi4_transaction::type_id::create("wr_mon_tr");
            tr.txn_type   = AXI4_WRITE;
            tr.id         = vif.awid;
            tr.addr       = vif.awaddr;
            tr.burst_len  = vif.awlen;
            tr.burst_size = vif.awsize;
            tr.burst_type = vif.awburst;
            tr.lock       = vif.awlock;
            tr.cache      = vif.awcache;
            tr.prot       = vif.awprot;
            tr.qos        = vif.awqos;
            tr.region     = vif.awregion;
            tr.user       = vif.awuser;

            tr.data = new[tr.burst_len + 1];
            tr.strb = new[tr.burst_len + 1];

            // Collect W data beats
            for (int i = 0; i <= tr.burst_len; i++) begin
                do begin
                    @(posedge vif.aclk);
                end while (!(vif.wvalid && vif.wready));

                tr.data[i] = vif.wdata;
                tr.strb[i] = vif.wstrb;
            end

            // Wait for B response
            do begin
                @(posedge vif.aclk);
            end while (!(vif.bvalid && vif.bready));

            tr.resp = vif.bresp;

            `uvm_info("MON_WR", tr.convert2string(), UVM_HIGH)
            write_ap.write(tr);
        end
    endtask

    //----------------------------------------------------------------------
    // Monitor Read Transactions (AR + R)
    //----------------------------------------------------------------------
    task monitor_read();
        axi4_transaction tr;

        forever begin
            // Wait for AR handshake
            do begin
                @(posedge vif.aclk);
            end while (!(vif.arvalid && vif.arready));

            tr = axi4_transaction::type_id::create("rd_mon_tr");
            tr.txn_type   = AXI4_READ;
            tr.id         = vif.arid;
            tr.addr       = vif.araddr;
            tr.burst_len  = vif.arlen;
            tr.burst_size = vif.arsize;
            tr.burst_type = vif.arburst;
            tr.lock       = vif.arlock;
            tr.cache      = vif.arcache;
            tr.prot       = vif.arprot;
            tr.qos        = vif.arqos;
            tr.region     = vif.arregion;
            tr.user       = vif.aruser;

            tr.rdata = new[tr.burst_len + 1];
            tr.rresp = new[tr.burst_len + 1];

            // Collect R data beats
            for (int i = 0; i <= tr.burst_len; i++) begin
                do begin
                    @(posedge vif.aclk);
                end while (!(vif.rvalid && vif.rready));

                tr.rdata[i] = vif.rdata;
                tr.rresp[i] = vif.rresp;
            end

            tr.resp = tr.rresp[0];

            `uvm_info("MON_RD", $sformatf("READ: id=%0d addr=0x%08x len=%0d",
                      tr.id, tr.addr, tr.burst_len), UVM_HIGH)
            read_ap.write(tr);
        end
    endtask

endclass

`endif
