`ifndef AXI4_SLAVE_AGENT_SVH
`define AXI4_SLAVE_AGENT_SVH

//==========================================================================
// AXI4 Slave Agent
//==========================================================================
class axi4_slave_agent extends uvm_agent;

    `uvm_component_utils(axi4_slave_agent)

    axi4_slave_driver driver;
    axi4_config       cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "Config not found")

        if (cfg.slave_is_active == UVM_ACTIVE) begin
            driver = axi4_slave_driver::type_id::create("driver", this);
        end
    endfunction

endclass

`endif
