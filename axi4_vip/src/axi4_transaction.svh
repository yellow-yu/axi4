`ifndef AXI4_TRANSACTION_SVH
`define AXI4_TRANSACTION_SVH

//==========================================================================
// AXI4 Transaction (Sequence Item)
//==========================================================================
class axi4_transaction extends uvm_sequence_item;

    // Direction
    rand axi4_dir_t                       rw;

    // Address channel fields
    rand bit [AXI4_ID_WIDTH-1:0]          id;
    rand bit [AXI4_ADDR_WIDTH-1:0]        addr;
    rand bit [7:0]                        len;      // burst length - 1
    rand bit [2:0]                        size;     // 2^size bytes per beat
    rand axi4_burst_t                     burst;
    rand bit                              lock;     // exclusive
    rand bit [3:0]                        cache;
    rand bit [2:0]                        prot;
    rand bit [3:0]                        qos;
    rand bit [3:0]                        region;
    rand bit [AXI4_USER_WIDTH-1:0]        user;

    // Write data (per beat) - randomized for writes
    rand bit [AXI4_DATA_WIDTH-1:0]        data[];
    // Byte strobes - computed in post_randomize
    bit [AXI4_STRB_WIDTH-1:0]             strb[];

    // Response data (populated after transaction completes)
    bit [AXI4_DATA_WIDTH-1:0]             rdata[];
    bit [1:0]                             resp[];
    bit [1:0]                             bresp;

    `uvm_object_utils_begin(axi4_transaction)
        `uvm_field_enum(axi4_dir_t, rw, UVM_ALL_ON)
        `uvm_field_int(id,      UVM_ALL_ON)
        `uvm_field_int(addr,    UVM_ALL_ON)
        `uvm_field_int(len,     UVM_ALL_ON)
        `uvm_field_int(size,    UVM_ALL_ON)
        `uvm_field_enum(axi4_burst_t, burst, UVM_ALL_ON)
        `uvm_field_int(lock,    UVM_ALL_ON)
        `uvm_field_int(cache,   UVM_ALL_ON)
        `uvm_field_int(prot,    UVM_ALL_ON)
        `uvm_field_int(qos,     UVM_ALL_ON)
        `uvm_field_int(region,  UVM_ALL_ON)
        `uvm_field_int(user,    UVM_ALL_ON)
        `uvm_field_int(bresp,   UVM_ALL_ON)
    `uvm_object_utils_end

    //----------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------

    // Max transfer size = data bus width
    constraint c_size_valid {
        size <= AXI4_SIZE_MAX;
    }

    // Default: full bus width
    constraint c_size_default {
        soft size == AXI4_SIZE_MAX;
    }

    // Burst type valid
    constraint c_burst_valid {
        burst inside {AXI4_BURST_FIXED, AXI4_BURST_INCR, AXI4_BURST_WRAP};
    }

    // WRAP burst: len must be 1, 3, 7, or 15 (burst lengths of 2, 4, 8, 16)
    constraint c_wrap_len {
        burst == AXI4_BURST_WRAP -> len inside {1, 3, 7, 15};
    }

    // FIXED burst: max 16 beats
    constraint c_fixed_len {
        burst == AXI4_BURST_FIXED -> len <= 15;
    }

    // Data array size matches burst length
    constraint c_data_size {
        data.size() == len + 1;
    }

    // WRAP must be aligned to transfer size
    constraint c_wrap_aligned {
        burst == AXI4_BURST_WRAP -> (addr % (1 << size)) == 0;
    }

    // Default address range (64KB for testing)
    constraint c_addr_range {
        addr < 64'h0001_0000;
    }

    // Default: aligned addresses
    constraint c_addr_aligned {
        soft (addr % (1 << size)) == 0;
    }

    // Default: short bursts
    constraint c_len_default {
        soft len <= 15;
    }

    // Default: no exclusive
    constraint c_lock_default {
        soft lock == 0;
    }

    // Default: normal cache/prot
    constraint c_cache_default {
        soft cache == 4'h0;
    }

    constraint c_prot_default {
        soft prot == 3'h0;
    }

    //----------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------
    function new(string name = "axi4_transaction");
        super.new(name);
    endfunction

    //----------------------------------------------------------------------
    // Post-randomize: compute strobes
    //----------------------------------------------------------------------
    function void post_randomize();
        compute_strobes();
    endfunction

    //----------------------------------------------------------------------
    // Compute byte strobes based on address, size, burst
    //----------------------------------------------------------------------
    function void compute_strobes();
        int num_bytes;
        bit [AXI4_ADDR_WIDTH-1:0] addrs[];
        int lower_lane;

        num_bytes = 1 << size;
        calc_beat_addresses(addrs);
        strb = new[len + 1];

        for (int i = 0; i <= len; i++) begin
            lower_lane = addrs[i] % AXI4_STRB_WIDTH;
            strb[i] = '0;
            for (int j = 0; j < num_bytes && (lower_lane + j) < AXI4_STRB_WIDTH; j++)
                strb[i][lower_lane + j] = 1'b1;
        end
    endfunction

    //----------------------------------------------------------------------
    // Calculate beat addresses for the burst
    //----------------------------------------------------------------------
    function void calc_beat_addresses(ref bit [AXI4_ADDR_WIDTH-1:0] addrs[]);
        int num_bytes;
        bit [AXI4_ADDR_WIDTH-1:0] aligned_addr;
        int burst_len;
        bit [AXI4_ADDR_WIDTH-1:0] lower_wrap, upper_wrap;
        int total_bytes;

        num_bytes    = 1 << size;
        aligned_addr = (addr / num_bytes) * num_bytes;
        burst_len    = len + 1;
        addrs        = new[burst_len];

        case (burst)
            AXI4_BURST_FIXED: begin
                for (int i = 0; i < burst_len; i++)
                    addrs[i] = addr;
            end
            AXI4_BURST_INCR: begin
                addrs[0] = addr;
                for (int i = 1; i < burst_len; i++)
                    addrs[i] = aligned_addr + i * num_bytes;
            end
            AXI4_BURST_WRAP: begin
                total_bytes = burst_len * num_bytes;
                lower_wrap  = (addr / total_bytes) * total_bytes;
                upper_wrap  = lower_wrap + total_bytes;

                addrs[0] = addr;
                for (int i = 1; i < burst_len; i++) begin
                    addrs[i] = aligned_addr + i * num_bytes;
                    if (addrs[i] >= upper_wrap)
                        addrs[i] = lower_wrap + (addrs[i] - upper_wrap);
                end
            end
            default: begin
                for (int i = 0; i < burst_len; i++)
                    addrs[i] = addr;
            end
        endcase
    endfunction

    //----------------------------------------------------------------------
    // Convert to string for debug
    //----------------------------------------------------------------------
    function string convert2string();
        string s;
        s = $sformatf("%s id=%0d addr=0x%0h len=%0d size=%0d burst=%s lock=%0b",
                      rw.name(), id, addr, len, size, burst.name(), lock);
        if (rw == AXI4_WRITE)
            s = {s, $sformatf(" bresp=%0b", bresp)};
        return s;
    endfunction

endclass

`endif
