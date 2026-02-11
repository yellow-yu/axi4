//==========================================================================
// axi4_transaction.svh - AXI4 Transaction (Sequence Item)
//==========================================================================

`ifndef AXI4_TRANSACTION_SVH
`define AXI4_TRANSACTION_SVH

class axi4_transaction extends uvm_sequence_item;

    //----------------------------------------------------------------------
    // Transaction type
    //----------------------------------------------------------------------
    rand axi4_txn_type_e txn_type;

    //----------------------------------------------------------------------
    // Address channel fields
    //----------------------------------------------------------------------
    rand bit [AXI4_VIP_ID_W-1:0]   id;
    rand bit [AXI4_VIP_ADDR_W-1:0] addr;
    rand bit [7:0]                  burst_len;   // 0~255 (actual beats = len+1)
    rand bit [2:0]                  burst_size;  // bytes per beat = 2^size
    rand bit [1:0]                  burst_type;  // FIXED/INCR/WRAP
    rand bit                        lock;        // exclusive access
    rand bit [3:0]                  cache;
    rand bit [2:0]                  prot;
    rand bit [3:0]                  qos;
    rand bit [3:0]                  region;
    rand bit [AXI4_VIP_USER_W-1:0] user;

    //----------------------------------------------------------------------
    // Write data fields
    //----------------------------------------------------------------------
    rand bit [AXI4_VIP_DATA_W-1:0] data[];   // dynamic array [burst_len+1]
    rand bit [AXI4_VIP_STRB_W-1:0] strb[];   // dynamic array [burst_len+1]

    //----------------------------------------------------------------------
    // Response fields (filled by driver/monitor)
    //----------------------------------------------------------------------
    bit [1:0]                       resp;       // write response or first read resp
    bit [AXI4_VIP_DATA_W-1:0]      rdata[];    // read data [burst_len+1]
    bit [1:0]                       rresp[];    // per-beat read response

    //----------------------------------------------------------------------
    // UVM field automation
    //----------------------------------------------------------------------
    `uvm_object_utils_begin(axi4_transaction)
        `uvm_field_enum(axi4_txn_type_e, txn_type, UVM_ALL_ON)
        `uvm_field_int(id,         UVM_ALL_ON)
        `uvm_field_int(addr,       UVM_ALL_ON)
        `uvm_field_int(burst_len,  UVM_ALL_ON)
        `uvm_field_int(burst_size, UVM_ALL_ON)
        `uvm_field_int(burst_type, UVM_ALL_ON)
        `uvm_field_int(lock,       UVM_ALL_ON)
        `uvm_field_int(cache,      UVM_ALL_ON)
        `uvm_field_int(prot,       UVM_ALL_ON)
        `uvm_field_int(qos,        UVM_ALL_ON)
        `uvm_field_int(region,     UVM_ALL_ON)
        `uvm_field_int(user,       UVM_ALL_ON)
        `uvm_field_array_int(data, UVM_ALL_ON)
        `uvm_field_array_int(strb, UVM_ALL_ON)
        `uvm_field_int(resp,       UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_array_int(rdata, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_array_int(rresp, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_object_utils_end

    //----------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------

    // Data & strobe array sizes must match burst length
    constraint c_array_size {
        data.size() == burst_len + 1;
        strb.size() == burst_len + 1;
    }

    // Burst size <= bus width
    constraint c_burst_size_max {
        (1 << burst_size) <= AXI4_VIP_STRB_W;
    }

    // WRAP burst length must be 2, 4, 8, or 16
    constraint c_wrap_len {
        (burst_type == AXI4_WRAP) -> burst_len inside {1, 3, 7, 15};
    }

    // WRAP start address should be aligned to size
    constraint c_wrap_addr_align {
        (burst_type == AXI4_WRAP) -> (addr % (1 << burst_size)) == 0;
    }

    // INCR burst must not cross 4KB boundary
    constraint c_4kb_boundary {
        (burst_type == AXI4_INCR) ->
            ((addr & 32'hFFFFF000) ==
             (((addr & ~((1 << burst_size) - 1)) + burst_len * (1 << burst_size)) & 32'hFFFFF000));
    }

    // Default: all bytes enabled
    constraint c_strb_default {
        foreach (strb[i]) strb[i] == {AXI4_VIP_STRB_W{1'b1}};
    }

    // Default: no exclusive
    constraint c_lock_default {
        lock == 1'b0;
    }

    // Default: short bursts
    constraint c_len_default {
        burst_len <= 15;
    }

    // Default: full-width transfers
    constraint c_size_default {
        burst_size == $clog2(AXI4_VIP_STRB_W);
    }

    // Keep addresses within a reasonable range
    constraint c_addr_range {
        addr < 32'h0010_0000; // 1MB
        addr[1:0] == 2'b00;   // word-aligned by default
    }

    //----------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------
    function new(string name = "axi4_transaction");
        super.new(name);
    endfunction

    //----------------------------------------------------------------------
    // Address calculation (same as RTL)
    //----------------------------------------------------------------------
    function automatic bit [AXI4_VIP_ADDR_W-1:0] calc_beat_addr(int beat_num);
        int unsigned num_bytes;
        int unsigned burst_length;
        bit [AXI4_VIP_ADDR_W-1:0] aligned_addr;
        bit [AXI4_VIP_ADDR_W-1:0] beat_addr;
        bit [AXI4_VIP_ADDR_W-1:0] wrap_boundary;
        int unsigned total_bytes;

        num_bytes    = 1 << burst_size;
        burst_length = burst_len + 1;
        aligned_addr = (addr / num_bytes) * num_bytes;

        case (burst_type)
            2'b00: beat_addr = addr; // FIXED
            2'b01: begin // INCR
                if (beat_num == 0)
                    beat_addr = addr;
                else
                    beat_addr = aligned_addr + beat_num * num_bytes;
            end
            2'b10: begin // WRAP
                if (beat_num == 0)
                    beat_addr = addr;
                else
                    beat_addr = aligned_addr + beat_num * num_bytes;
                total_bytes   = num_bytes * burst_length;
                wrap_boundary = (addr / total_bytes) * total_bytes;
                if (beat_addr >= wrap_boundary + total_bytes)
                    beat_addr = beat_addr - total_bytes;
            end
            default: beat_addr = addr;
        endcase

        return beat_addr;
    endfunction

    //----------------------------------------------------------------------
    // Convert to string for debug
    //----------------------------------------------------------------------
    function string convert2string();
        string s;
        s = $sformatf("%s: id=%0d addr=0x%08x len=%0d size=%0d burst=%0d lock=%0d",
                      txn_type.name(), id, addr, burst_len, burst_size, burst_type, lock);
        if (txn_type == AXI4_WRITE) begin
            for (int i = 0; i < data.size() && i < 4; i++)
                s = {s, $sformatf("\n  beat[%0d]: data=0x%016x strb=0x%02x", i, data[i], strb[i])};
            if (data.size() > 4)
                s = {s, $sformatf("\n  ... (%0d more beats)", data.size() - 4)};
        end
        return s;
    endfunction

endclass

`endif
