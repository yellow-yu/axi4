`ifndef AXI4_MASTER_AGENT_SVH
`define AXI4_MASTER_AGENT_SVH

//==========================================================================
// AXI4 Master Agent
//==========================================================================
class axi4_master_agent extends uvm_agent;

    `uvm_component_utils(axi4_master_agent)

    axi4_master_driver    driver;
    axi4_master_sequencer sequencer;
    axi4_config           cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "Config not found")

        if (cfg.master_is_active == UVM_ACTIVE) begin
            driver    = axi4_master_driver::type_id::create("driver", this);
            sequencer = axi4_master_sequencer::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.master_is_active == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass

`endif
