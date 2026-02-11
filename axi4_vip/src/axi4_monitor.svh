`ifndef AXI4_MONITOR_SVH
`define AXI4_MONITOR_SVH

//==========================================================================
// AXI4 Monitor - observes all channels passively
// Uses sequential processing for write and read channels (concurrent with each other)
//==========================================================================
class axi4_monitor extends uvm_monitor;

    `uvm_component_utils(axi4_monitor)

    virtual axi4_interface vif;
    axi4_config            cfg;

    // Analysis ports for write and read transactions
    uvm_analysis_port #(axi4_transaction) write_ap;
    uvm_analysis_port #(axi4_transaction) read_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        write_ap = new("write_ap", this);
        read_ap  = new("read_ap", this);
        if (!uvm_config_db#(axi4_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "Config not found")
        vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.aresetn);
        fork
            monitor_writes();
            monitor_reads();
        join
    endtask

    //----------------------------------------------------------------------
    // Monitor write transactions (AW -> W beats -> B)
    //----------------------------------------------------------------------
    task monitor_writes();
        forever begin
            axi4_transaction tr;
            int beat_count;

            tr = axi4_transaction::type_id::create("wr_mon_tr");
            tr.rw = AXI4_WRITE;

            // Wait for AW handshake
            @(posedge vif.aclk iff (vif.awvalid && vif.awready));
            tr.id     = vif.awid;
            tr.addr   = vif.awaddr;
            tr.len    = vif.awlen;
            tr.size   = vif.awsize;
            tr.burst  = axi4_burst_t'(vif.awburst);
            tr.lock   = vif.awlock;
            tr.cache  = vif.awcache;
            tr.prot   = vif.awprot;
            tr.qos    = vif.awqos;
            tr.region = vif.awregion;
            tr.user   = vif.awuser;

            beat_count = tr.len + 1;
            tr.data = new[beat_count];
            tr.strb = new[beat_count];

            // Collect W data beats
            for (int i = 0; i < beat_count; i++) begin
                @(posedge vif.aclk iff (vif.wvalid && vif.wready));
                tr.data[i] = vif.wdata;
                tr.strb[i] = vif.wstrb;
            end

            // Wait for B response
            @(posedge vif.aclk iff (vif.bvalid && vif.bready));
            tr.bresp = vif.bresp;

            `uvm_info("MON", $sformatf("WRITE observed: %s", tr.convert2string()), UVM_HIGH)
            write_ap.write(tr);
        end
    endtask

    //----------------------------------------------------------------------
    // Monitor read transactions (AR -> R beats)
    //----------------------------------------------------------------------
    task monitor_reads();
        forever begin
            axi4_transaction tr;
            int beat_count;

            tr = axi4_transaction::type_id::create("rd_mon_tr");
            tr.rw = AXI4_READ;

            // Wait for AR handshake
            @(posedge vif.aclk iff (vif.arvalid && vif.arready));
            tr.id     = vif.arid;
            tr.addr   = vif.araddr;
            tr.len    = vif.arlen;
            tr.size   = vif.arsize;
            tr.burst  = axi4_burst_t'(vif.arburst);
            tr.lock   = vif.arlock;
            tr.cache  = vif.arcache;
            tr.prot   = vif.arprot;
            tr.qos    = vif.arqos;
            tr.region = vif.arregion;
            tr.user   = vif.aruser;

            beat_count = tr.len + 1;
            tr.rdata = new[beat_count];
            tr.resp  = new[beat_count];
            tr.compute_strobes();

            // Collect R data beats
            for (int i = 0; i < beat_count; i++) begin
                @(posedge vif.aclk iff (vif.rvalid && vif.rready));
                tr.rdata[i] = vif.rdata;
                tr.resp[i]  = vif.rresp;
            end

            `uvm_info("MON", $sformatf("READ observed: %s", tr.convert2string()), UVM_HIGH)
            read_ap.write(tr);
        end
    endtask

endclass

`endif
