`ifndef AXI4_MASTER_DRIVER_SVH
`define AXI4_MASTER_DRIVER_SVH

//==========================================================================
// AXI4 Master Driver
//==========================================================================
class axi4_master_driver extends uvm_driver #(axi4_transaction);

    `uvm_component_utils(axi4_master_driver)

    virtual axi4_interface vif;
    axi4_config            cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "Config not found in config_db")
        vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
        axi4_transaction tr;

        // Initialize all master outputs
        init_signals();

        // Wait for reset deassertion
        @(posedge vif.aresetn);
        @(posedge vif.aclk);

        forever begin
            seq_item_port.get_next_item(tr);
            if (tr.rw == AXI4_WRITE)
                drive_write(tr);
            else
                drive_read(tr);
            seq_item_port.item_done();
        end
    endtask

    //----------------------------------------------------------------------
    // Initialize master-driven signals to idle
    //----------------------------------------------------------------------
    task init_signals();
        vif.awvalid  <= 1'b0;
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

        vif.wvalid   <= 1'b0;
        vif.wdata    <= '0;
        vif.wstrb    <= '0;
        vif.wlast    <= 1'b0;
        vif.wuser    <= '0;

        vif.bready   <= 1'b0;

        vif.arvalid  <= 1'b0;
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

        vif.rready   <= 1'b0;
    endtask

    //----------------------------------------------------------------------
    // Drive a write transaction
    //----------------------------------------------------------------------
    task drive_write(axi4_transaction tr);
        // Drive Write Address channel
        vif.awvalid  <= 1'b1;
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

        do @(posedge vif.aclk); while (!vif.awready);
        vif.awvalid <= 1'b0;

        // Drive Write Data channel (beat by beat)
        for (int i = 0; i <= tr.len; i++) begin
            vif.wvalid <= 1'b1;
            vif.wdata  <= tr.data[i];
            vif.wstrb  <= tr.strb[i];
            vif.wlast  <= (i == tr.len) ? 1'b1 : 1'b0;
            vif.wuser  <= tr.user;
            do @(posedge vif.aclk); while (!vif.wready);
        end
        vif.wvalid <= 1'b0;
        vif.wlast  <= 1'b0;

        // Wait for Write Response
        vif.bready <= 1'b1;
        do @(posedge vif.aclk); while (!vif.bvalid);
        tr.bresp = vif.bresp;
        vif.bready <= 1'b0;

        `uvm_info("MST_DRV", $sformatf("WRITE done: %s", tr.convert2string()), UVM_MEDIUM)
    endtask

    //----------------------------------------------------------------------
    // Drive a read transaction
    //----------------------------------------------------------------------
    task drive_read(axi4_transaction tr);
        // Drive Read Address channel
        vif.arvalid  <= 1'b1;
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

        do @(posedge vif.aclk); while (!vif.arready);
        vif.arvalid <= 1'b0;

        // Collect Read Data channel
        tr.rdata = new[tr.len + 1];
        tr.resp  = new[tr.len + 1];
        vif.rready <= 1'b1;

        for (int i = 0; i <= tr.len; i++) begin
            do @(posedge vif.aclk); while (!vif.rvalid);
            tr.rdata[i] = vif.rdata;
            tr.resp[i]  = vif.rresp;
        end
        vif.rready <= 1'b0;

        `uvm_info("MST_DRV", $sformatf("READ done: %s", tr.convert2string()), UVM_MEDIUM)
    endtask

endclass

`endif
