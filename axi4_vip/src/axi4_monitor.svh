`ifndef AXI4_MONITOR_SVH
`define AXI4_MONITOR_SVH

//==========================================================================
// AXI4 Monitor - observes all channels passively
//==========================================================================
class axi4_monitor extends uvm_monitor;

    `uvm_component_utils(axi4_monitor)

    virtual axi4_interface vif;
    axi4_config            cfg;

    // Analysis ports for write and read transactions
    uvm_analysis_port #(axi4_transaction) write_ap;
    uvm_analysis_port #(axi4_transaction) read_ap;

    // Internal queues for assembling transactions
    typedef struct {
        bit [AXI4_ID_WIDTH-1:0]   id;
        bit [AXI4_ADDR_WIDTH-1:0] addr;
        bit [7:0]                 len;
        bit [2:0]                 size;
        bit [1:0]                 burst;
        bit                       lock;
        bit [3:0]                 cache;
        bit [2:0]                 prot;
        bit [3:0]                 qos;
        bit [3:0]                 region;
        bit [AXI4_USER_WIDTH-1:0] user;
    } addr_info_t;

    addr_info_t                              aw_queue[$];
    bit [AXI4_DATA_WIDTH-1:0]                w_data_queue[$];
    bit [AXI4_STRB_WIDTH-1:0]               w_strb_queue[$];

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
            monitor_aw_channel();
            monitor_w_channel();
            monitor_b_channel();
            monitor_ar_channel();
            monitor_r_channel();
        join
    endtask

    //----------------------------------------------------------------------
    // Monitor Write Address channel
    //----------------------------------------------------------------------
    task monitor_aw_channel();
        addr_info_t info;
        forever begin
            @(posedge vif.aclk iff (vif.awvalid && vif.awready));
            info.id     = vif.awid;
            info.addr   = vif.awaddr;
            info.len    = vif.awlen;
            info.size   = vif.awsize;
            info.burst  = vif.awburst;
            info.lock   = vif.awlock;
            info.cache  = vif.awcache;
            info.prot   = vif.awprot;
            info.qos    = vif.awqos;
            info.region = vif.awregion;
            info.user   = vif.awuser;
            aw_queue.push_back(info);
        end
    endtask

    //----------------------------------------------------------------------
    // Monitor Write Data channel - collect beats and assemble transactions
    //----------------------------------------------------------------------
    task monitor_w_channel();
        forever begin
            @(posedge vif.aclk iff (vif.wvalid && vif.wready));
            w_data_queue.push_back(vif.wdata);
            w_strb_queue.push_back(vif.wstrb);
        end
    endtask

    //----------------------------------------------------------------------
    // Monitor Write Response channel - assemble complete write transaction
    //----------------------------------------------------------------------
    task monitor_b_channel();
        forever begin
            addr_info_t aw_info;
            axi4_transaction tr;
            int beat_count;

            @(posedge vif.aclk iff (vif.bvalid && vif.bready));

            // Wait for AW info to be available
            while (aw_queue.size() == 0) @(posedge vif.aclk);
            aw_info = aw_queue.pop_front();

            beat_count = aw_info.len + 1;

            // Create transaction
            tr = axi4_transaction::type_id::create("wr_mon_tr");
            tr.rw     = AXI4_WRITE;
            tr.id     = aw_info.id;
            tr.addr   = aw_info.addr;
            tr.len    = aw_info.len;
            tr.size   = aw_info.size;
            tr.burst  = axi4_burst_t'(aw_info.burst);
            tr.lock   = aw_info.lock;
            tr.cache  = aw_info.cache;
            tr.prot   = aw_info.prot;
            tr.qos    = aw_info.qos;
            tr.region = aw_info.region;
            tr.user   = aw_info.user;
            tr.bresp  = vif.bresp;

            tr.data = new[beat_count];
            tr.strb = new[beat_count];

            // Collect W data from queue
            for (int i = 0; i < beat_count; i++) begin
                while (w_data_queue.size() == 0) @(posedge vif.aclk);
                tr.data[i] = w_data_queue.pop_front();
                tr.strb[i] = w_strb_queue.pop_front();
            end

            `uvm_info("MON", $sformatf("WRITE observed: %s", tr.convert2string()), UVM_HIGH)
            write_ap.write(tr);
        end
    endtask

    //----------------------------------------------------------------------
    // Monitor Read Address channel
    //----------------------------------------------------------------------
    task monitor_ar_channel();
        forever begin
            addr_info_t info;
            @(posedge vif.aclk iff (vif.arvalid && vif.arready));
            info.id     = vif.arid;
            info.addr   = vif.araddr;
            info.len    = vif.arlen;
            info.size   = vif.arsize;
            info.burst  = vif.arburst;
            info.lock   = vif.arlock;
            info.cache  = vif.arcache;
            info.prot   = vif.arprot;
            info.qos    = vif.arqos;
            info.region = vif.arregion;
            info.user   = vif.aruser;

            // Start read collection process
            fork
                collect_read_data(info);
            join_none
        end
    endtask

    //----------------------------------------------------------------------
    // Collect read data beats and assemble transaction
    //----------------------------------------------------------------------
    task collect_read_data(addr_info_t ar_info);
        axi4_transaction tr;
        int beat_count;

        beat_count = ar_info.len + 1;

        tr = axi4_transaction::type_id::create("rd_mon_tr");
        tr.rw     = AXI4_READ;
        tr.id     = ar_info.id;
        tr.addr   = ar_info.addr;
        tr.len    = ar_info.len;
        tr.size   = ar_info.size;
        tr.burst  = axi4_burst_t'(ar_info.burst);
        tr.lock   = ar_info.lock;
        tr.cache  = ar_info.cache;
        tr.prot   = ar_info.prot;
        tr.qos    = ar_info.qos;
        tr.region = ar_info.region;
        tr.user   = ar_info.user;

        tr.rdata = new[beat_count];
        tr.resp  = new[beat_count];
        tr.compute_strobes();

        for (int i = 0; i < beat_count; i++) begin
            @(posedge vif.aclk iff (vif.rvalid && vif.rready && (vif.rid == ar_info.id)));
            tr.rdata[i] = vif.rdata;
            tr.resp[i]  = vif.rresp;
        end

        `uvm_info("MON", $sformatf("READ observed: %s", tr.convert2string()), UVM_HIGH)
        read_ap.write(tr);
    endtask

    //----------------------------------------------------------------------
    // Monitor Read Data channel (just for R beat tracking)
    //----------------------------------------------------------------------
    task monitor_r_channel();
        // R channel is handled by collect_read_data tasks
        // This task is a placeholder for protocol checking
        forever begin
            @(posedge vif.aclk iff (vif.rvalid && vif.rready));
            // Could add protocol assertions here
        end
    endtask

endclass

`endif
