# AXI4 VIP (Verification IP)

A complete AXI4 Full protocol Verification IP with UVM-based verification environment and self-checking testbench.

## Features Supported

| Feature | Description |
|---------|-------------|
| Independent R/W channels | 5 independent channels: AW, W, B, AR, R |
| INCR burst | Incrementing address burst, up to 256 beats |
| WRAP burst | Wrapping burst with lengths 2, 4, 8, 16 |
| FIXED burst | Fixed address burst, up to 16 beats |
| Max burst length | Up to 256 beats (AWLEN/ARLEN = 255) |
| Narrow transfers | AWSIZE/ARSIZE smaller than data bus width |
| Unaligned transfers | First beat can have non-aligned address |
| Byte strobes | WSTRB for byte-level write control |
| Exclusive access | AWLOCK/ARLOCK with exclusive monitor |
| Outstanding transactions | Multiple pending transactions via ID tags |
| QoS | 4-bit AWQOS/ARQOS support |
| Region | 4-bit AWREGION/ARREGION support |
| User signals | Configurable-width user sideband signals |
| Cache hints | 4-bit AWCACHE/ARCACHE support |
| Protection attributes | 3-bit AWPROT/ARPROT support |
| Response types | OKAY, EXOKAY, SLVERR, DECERR |

## Directory Structure

```
axi4_vip/
├── src/                          # Source files
│   ├── axi4_if.sv               # AXI4 parameterized interface
│   ├── axi4_pkg.sv              # UVM package (includes all .svh)
│   ├── axi4_types.svh           # Type definitions
│   ├── axi4_transaction.svh     # Sequence item
│   ├── axi4_config.svh          # Configuration object
│   ├── axi4_master_driver.svh   # Master driver
│   ├── axi4_master_sequencer.svh# Master sequencer
│   ├── axi4_master_agent.svh    # Master agent
│   ├── axi4_monitor.svh         # Protocol monitor
│   ├── axi4_slave_driver.svh    # Slave driver + memory model
│   ├── axi4_slave_agent.svh     # Slave agent
│   ├── axi4_scoreboard.svh      # Reference memory scoreboard
│   ├── axi4_coverage.svh        # Functional coverage
│   ├── axi4_env.svh             # UVM environment
│   ├── axi4_sequences.svh       # All test sequences
│   ├── axi4_base_test.svh       # Base test class
│   ├── axi4_tests.svh           # All test cases
│   └── tb_top.sv                # Testbench top
├── tb/
│   └── tb_axi4_self_check.sv    # Non-UVM self-checking testbench
└── sim/
    ├── Makefile                  # QuestaSim Makefile
    ├── run_all.sh               # Run all UVM tests (QuestaSim)
    └── run_iverilog.sh          # Run self-checking TB (Icarus Verilog)
```

## Test Cases (13 UVM tests + Self-Checking TB)

| # | Test Name | Description |
|---|-----------|-------------|
| 1 | `axi4_single_write_read_test` | Single-beat write then read-back |
| 2 | `axi4_incr_burst_test` | INCR burst (4/8/16 beats) |
| 3 | `axi4_wrap_burst_test` | WRAP burst (2/4/8/16 beats) |
| 4 | `axi4_fixed_burst_test` | FIXED burst (1/4 beats) |
| 5 | `axi4_narrow_transfer_test` | Narrow transfers (1B/2B/4B) |
| 6 | `axi4_unaligned_test` | Unaligned start addresses |
| 7 | `axi4_byte_strobe_test` | Partial byte strobes |
| 8 | `axi4_outstanding_test` | 8 outstanding transactions |
| 9 | `axi4_back2back_test` | 10 back-to-back transactions |
| 10 | `axi4_max_burst_test` | 256-beat maximum burst |
| 11 | `axi4_exclusive_test` | Exclusive read/write (success + failure) |
| 12 | `axi4_mixed_rw_test` | Interleaved reads and writes |
| 13 | `axi4_random_test` | Random stress test |

## Running with QuestaSim

```bash
cd sim
make compile          # Compile all sources
make run_all          # Run all 13 tests
make run TEST=axi4_single_write_read_test  # Run specific test
make clean            # Clean work directory
```

Or use the script:
```bash
cd sim
./run_all.sh
```

## Running with Icarus Verilog (Self-Checking TB)

```bash
cd sim
./run_iverilog.sh
```

Or manually:
```bash
cd axi4_vip
iverilog -g2012 -o sim/tb_self_check tb/tb_axi4_self_check.sv
cd sim && vvp tb_self_check
```

## Interface Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ID_WIDTH` | 4 | ID signal width (1-16) |
| `ADDR_WIDTH` | 64 | Address width |
| `DATA_WIDTH` | 512 | Data width (must be 8x multiple) |
| `USER_WIDTH` | 1 | User signal width (can be 0) |

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  axi4_env                        │
│                                                  │
│  ┌──────────────────┐  ┌──────────────────────┐ │
│  │  master_agent     │  │    slave_agent        │ │
│  │ ┌──────────────┐ │  │ ┌────────────────┐   │ │
│  │ │ master_driver │ │  │ │ slave_driver    │   │ │
│  │ └──────────────┘ │  │ │ (memory model)  │   │ │
│  │ ┌──────────────┐ │  │ │ (excl monitor)  │   │ │
│  │ │  sequencer    │ │  │ └────────────────┘   │ │
│  │ └──────────────┘ │  └──────────────────────┘ │
│  └──────────────────┘                            │
│                                                  │
│  ┌──────────┐  ┌────────────┐  ┌──────────────┐│
│  │ monitor  │──│ scoreboard │  │  coverage     ││
│  └──────────┘  └────────────┘  └──────────────┘│
└─────────────────────────────────────────────────┘
                     │
              axi4_interface
```
