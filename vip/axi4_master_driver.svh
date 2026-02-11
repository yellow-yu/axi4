//==========================================================================
// axi4_master_driver.svh - AXI4 Master Driver
//==========================================================================

`ifndef AXI4_MASTER_DRIVER_SVH
`define AXI4_MASTER_DRIVER_SVH

class axi4_master_driver extends uvm_driver #(axi4_transaction);

    `uvm_component_utils(axi4_master_driver)

    axi4_vif vif;

    function new(string name = "axi4_master_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4_vif)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not set for driver")
    endfunction

    task run_phase(uvm_phase phase);
        // Initialize all master-driven signals
        init_signals();

        // Wait for reset deassertion
        @(posedge vif.aresetn);
        @(posedge vif.aclk);

        forever begin
            axi4_transaction tr;
            seq_item_port.get_next_item(tr);

            if (tr.txn_type == AXI4_WRITE)
                drive_write(tr);
            else
                drive_read(tr);

            seq_item_port.item_done();
        end
    endtask

    //----------------------------------------------------------------------
    // Initialize all outputs to idle
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
    // Drive Write Transaction (AW, then W, then B)
    //----------------------------------------------------------------------
    task drive_write(axi4_transaction tr);
        `uvm_info("DRV", $sformatf("Driving WRITE: addr=0x%08x len=%0d", tr.addr, tr.burst_len), UVM_HIGH)

        // Drive AW channel first
        drive_aw(tr);
        // Then drive W channel
        drive_w(tr);
        // Then wait for B response
        drive_b(tr);
    endtask

    //----------------------------------------------------------------------
    // Drive Write Address Channel
    //----------------------------------------------------------------------
    task drive_aw(axi4_transaction tr);
        @(posedge vif.aclk);
        vif.awvalid  <= 1'b1;
        vif.awid     <= tr.id;
        vif.awaddr   <= tr.addr;
        vif.awlen    <= tr.burst_len;
        vif.awsize   <= tr.burst_size;
        vif.awburst  <= tr.burst_type;
        vif.awlock   <= tr.lock;
        vif.awcache  <= tr.cache;
        vif.awprot   <= tr.prot;
        vif.awqos    <= tr.qos;
        vif.awregion <= tr.region;
        vif.awuser   <= tr.user;

        // Wait for handshake
        do begin
            @(posedge vif.aclk);
        end while (!vif.awready);

        vif.awvalid <= 1'b0;
    endtask

    //----------------------------------------------------------------------
    // Drive Write Data Channel
    // Deasserts wvalid between beats to avoid spurious handshakes
    //----------------------------------------------------------------------
    task drive_w(axi4_transaction tr);
        for (int i = 0; i <= tr.burst_len; i++) begin
            @(posedge vif.aclk);
            vif.wvalid <= 1'b1;
            vif.wdata  <= tr.data[i];
            vif.wstrb  <= tr.strb[i];
            vif.wlast  <= (i == tr.burst_len) ? 1'b1 : 1'b0;
            vif.wuser  <= tr.user;

            // Wait for handshake
            do begin
                @(posedge vif.aclk);
            end while (!vif.wready);

            // Deassert wvalid after each beat to prevent spurious handshakes
            vif.wvalid <= 1'b0;
        end

        vif.wlast <= 1'b0;
    endtask

    //----------------------------------------------------------------------
    // Handle Write Response Channel
    //----------------------------------------------------------------------
    task drive_b(axi4_transaction tr);
        vif.bready <= 1'b1;

        // Wait for BVALID
        do begin
            @(posedge vif.aclk);
        end while (!vif.bvalid);

        tr.resp = vif.bresp;

        @(posedge vif.aclk);
        vif.bready <= 1'b0;
    endtask

    //----------------------------------------------------------------------
    // Drive Read Transaction
    //----------------------------------------------------------------------
    task drive_read(axi4_transaction tr);
        `uvm_info("DRV", $sformatf("Driving READ: addr=0x%08x len=%0d", tr.addr, tr.burst_len), UVM_HIGH)

        // Drive AR channel
        @(posedge vif.aclk);
        vif.arvalid  <= 1'b1;
        vif.arid     <= tr.id;
        vif.araddr   <= tr.addr;
        vif.arlen    <= tr.burst_len;
        vif.arsize   <= tr.burst_size;
        vif.arburst  <= tr.burst_type;
        vif.arlock   <= tr.lock;
        vif.arcache  <= tr.cache;
        vif.arprot   <= tr.prot;
        vif.arqos    <= tr.qos;
        vif.arregion <= tr.region;
        vif.aruser   <= tr.user;

        // Wait for AR handshake
        do begin
            @(posedge vif.aclk);
        end while (!vif.arready);

        vif.arvalid <= 1'b0;

        // Receive R data
        tr.rdata = new[tr.burst_len + 1];
        tr.rresp = new[tr.burst_len + 1];

        vif.rready <= 1'b1;

        for (int i = 0; i <= tr.burst_len; i++) begin
            // Wait for RVALID
            do begin
                @(posedge vif.aclk);
            end while (!vif.rvalid);

            tr.rdata[i] = vif.rdata;
            tr.rresp[i] = vif.rresp;
        end

        tr.resp = tr.rresp[0];

        @(posedge vif.aclk);
        vif.rready <= 1'b0;
    endtask

endclass

`endif
