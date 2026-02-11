//==========================================================================
// axi4_coverage.svh - AXI4 Functional Coverage
//==========================================================================

`ifndef AXI4_COVERAGE_SVH
`define AXI4_COVERAGE_SVH

class axi4_coverage extends uvm_subscriber #(axi4_transaction);

    `uvm_component_utils(axi4_coverage)

    axi4_transaction tr;

    //----------------------------------------------------------------------
    // Covergroup
    //----------------------------------------------------------------------
    covergroup axi4_cg;

        // Transaction type
        cp_txn_type: coverpoint tr.txn_type {
            bins write = {AXI4_WRITE};
            bins read  = {AXI4_READ};
        }

        // Burst type
        cp_burst_type: coverpoint tr.burst_type {
            bins fixed = {AXI4_FIXED};
            bins incr  = {AXI4_INCR};
            bins wrap  = {AXI4_WRAP};
        }

        // Burst length
        cp_burst_len: coverpoint tr.burst_len {
            bins single    = {0};
            bins short_2   = {1};
            bins short_4   = {3};
            bins short_8   = {7};
            bins short_16  = {15};
            bins medium    = {[16:63]};
            bins long_     = {[64:254]};
            bins max_256   = {255};
        }

        // Burst size
        cp_burst_size: coverpoint tr.burst_size {
            bins size_1  = {0};  // 1 byte
            bins size_2  = {1};  // 2 bytes
            bins size_4  = {2};  // 4 bytes
            bins size_8  = {3};  // 8 bytes (full width for 64-bit)
        }

        // Lock (exclusive access)
        cp_lock: coverpoint tr.lock {
            bins normal    = {0};
            bins exclusive = {1};
        }

        // Cache attributes
        cp_cache: coverpoint tr.cache {
            bins non_cache = {4'b0000};
            bins bufferable = {4'b0001};
            bins cacheable = {4'b0010};
            bins all_bits  = {4'b1111};
            bins others    = default;
        }

        // Protection
        cp_prot: coverpoint tr.prot {
            bins data_secure_unpriv  = {3'b000};
            bins data_secure_priv   = {3'b001};
            bins data_nonsec_unpriv = {3'b010};
            bins instr_secure       = {3'b100};
            bins others             = default;
        }

        // QoS
        cp_qos: coverpoint tr.qos {
            bins low  = {[0:3]};
            bins med  = {[4:7]};
            bins high = {[8:11]};
            bins max  = {[12:15]};
        }

        // Response type
        cp_resp: coverpoint tr.resp {
            bins okay   = {2'b00};
            bins exokay = {2'b01};
        }

        // ID coverage
        cp_id: coverpoint tr.id {
            bins id[] = {[0:15]};
        }

        // Address alignment
        cp_addr_align: coverpoint (tr.addr % (1 << tr.burst_size)) {
            bins aligned   = {0};
            bins unaligned = default;
        }

        // Cross coverage: burst type x transaction type
        cx_burst_txn: cross cp_burst_type, cp_txn_type;

        // Cross coverage: burst type x burst length
        cx_burst_len: cross cp_burst_type, cp_burst_len;

        // Cross coverage: burst type x burst size
        cx_burst_size: cross cp_burst_type, cp_burst_size;

        // Cross coverage: lock x transaction type
        cx_lock_txn: cross cp_lock, cp_txn_type;

    endgroup

    //----------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------
    function new(string name = "axi4_coverage", uvm_component parent = null);
        super.new(name, parent);
        axi4_cg = new();
    endfunction

    //----------------------------------------------------------------------
    // Write method (from subscriber)
    //----------------------------------------------------------------------
    function void write(axi4_transaction t);
        tr = t;
        axi4_cg.sample();
    endfunction

    //----------------------------------------------------------------------
    // Report coverage
    //----------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("COV_REPORT", $sformatf("AXI4 Coverage: %.2f%%", axi4_cg.get_coverage()), UVM_LOW)
    endfunction

endclass

`endif
