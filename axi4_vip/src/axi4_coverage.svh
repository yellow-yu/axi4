`ifndef AXI4_COVERAGE_SVH
`define AXI4_COVERAGE_SVH

//==========================================================================
// AXI4 Functional Coverage Collector
//==========================================================================
class axi4_coverage extends uvm_subscriber #(axi4_transaction);

    `uvm_component_utils(axi4_coverage)

    axi4_transaction tr;

    // Coverage groups
    covergroup axi4_cg;
        // Direction
        cp_rw: coverpoint tr.rw {
            bins read  = {AXI4_READ};
            bins write = {AXI4_WRITE};
        }

        // Burst type
        cp_burst: coverpoint tr.burst {
            bins fixed = {AXI4_BURST_FIXED};
            bins incr  = {AXI4_BURST_INCR};
            bins wrap  = {AXI4_BURST_WRAP};
        }

        // Burst length
        cp_len: coverpoint tr.len {
            bins single    = {0};
            bins short_b   = {[1:3]};
            bins medium_b  = {[4:15]};
            bins long_b    = {[16:63]};
            bins very_long = {[64:254]};
            bins max_b     = {255};
        }

        // Transfer size
        cp_size: coverpoint tr.size {
            bins size_1B   = {0};
            bins size_2B   = {1};
            bins size_4B   = {2};
            bins size_8B   = {3};
            bins size_16B  = {4};
            bins size_32B  = {5};
            bins size_64B  = {6};
        }

        // Exclusive access
        cp_lock: coverpoint tr.lock {
            bins normal    = {0};
            bins exclusive = {1};
        }

        // Cache attributes
        cp_cache: coverpoint tr.cache {
            bins non_cacheable = {4'b0000};
            bins bufferable    = {4'b0001};
            bins cacheable     = {[4'b0010:4'b1111]};
        }

        // Protection
        cp_prot: coverpoint tr.prot {
            bins data_secure_unpriv   = {3'b000};
            bins data_secure_priv     = {3'b001};
            bins data_nonsec_unpriv   = {3'b010};
            bins data_nonsec_priv     = {3'b011};
            bins inst_secure_unpriv   = {3'b100};
            bins others               = default;
        }

        // QoS
        cp_qos: coverpoint tr.qos {
            bins low    = {[0:3]};
            bins medium = {[4:11]};
            bins high   = {[12:15]};
        }

        // ID
        cp_id: coverpoint tr.id {
            bins id_vals[] = {[0:15]};
        }

        // Region
        cp_region: coverpoint tr.region {
            bins region_vals[] = {[0:15]};
        }

        // Cross coverage
        cx_rw_burst: cross cp_rw, cp_burst;
        cx_rw_size: cross cp_rw, cp_size;
        cx_rw_lock: cross cp_rw, cp_lock;
        cx_burst_len: cross cp_burst, cp_len;
    endgroup

    // Write response coverage
    covergroup axi4_bresp_cg;
        cp_bresp: coverpoint tr.bresp {
            bins okay   = {2'b00};
            bins exokay = {2'b01};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        axi4_cg = new();
        axi4_bresp_cg = new();
    endfunction

    function void write(axi4_transaction t);
        tr = t;
        axi4_cg.sample();
        if (t.rw == AXI4_WRITE)
            axi4_bresp_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf(
            "Functional coverage: %.1f%%", axi4_cg.get_inst_coverage()), UVM_LOW)
    endfunction

endclass

`endif
