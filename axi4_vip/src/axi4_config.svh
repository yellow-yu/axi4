`ifndef AXI4_CONFIG_SVH
`define AXI4_CONFIG_SVH

//==========================================================================
// AXI4 VIP Configuration Object
//==========================================================================
class axi4_config extends uvm_object;

    `uvm_object_utils(axi4_config)

    // Agent activity
    uvm_active_passive_enum master_is_active = UVM_ACTIVE;
    uvm_active_passive_enum slave_is_active  = UVM_ACTIVE;

    // Enable scoreboard and coverage
    bit enable_scoreboard = 1;
    bit enable_coverage   = 1;

    // Slave response delays (in clock cycles)
    int unsigned min_aw_ready_delay = 0;
    int unsigned max_aw_ready_delay = 0;
    int unsigned min_w_ready_delay  = 0;
    int unsigned max_w_ready_delay  = 0;
    int unsigned min_ar_ready_delay = 0;
    int unsigned max_ar_ready_delay = 0;
    int unsigned min_b_valid_delay  = 1;
    int unsigned max_b_valid_delay  = 3;
    int unsigned min_r_valid_delay  = 0;
    int unsigned max_r_valid_delay  = 2;

    // Virtual interface
    virtual axi4_interface vif;

    function new(string name = "axi4_config");
        super.new(name);
    endfunction

endclass

`endif
