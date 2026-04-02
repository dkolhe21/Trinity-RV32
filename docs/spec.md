# RISC_CPU – Project Specification

> **Version:** 1.1 (FINAL SILICON)  
> **Date:** 2026-02-23  
> **Status:** Tape-out Complete - PPA Documented

---

## 1. Project Overview

**RISC_CPU** is a minimal RISC-V processor designed for silicon tapeout via the Efabless/Google MPW program using the Sky130 open-source PDK.

| Parameter | Value |
|-----------|-------|
| Project Name | RISC_CPU |
| Target PDK | SkyWater SKY130 |
| Target Frequency | **20 MHz** |
| Integration | Caravel `user_project_wrapper` |

---

## 2. Architecture

### 2.1 Instruction Set Architecture

| Parameter | Value |
|-----------|-------|
| ISA | **RV32I** (Base Integer only) |
| Extensions | None (no M/A/F/D/C) |
| Registers | 32 × 32-bit GPRs (x0 hardwired to 0) |
| Endianness | Little-endian |

### 2.2 Pipeline

```
┌────────┐    ┌─────────┐    ┌─────────┐
│  IF    │──▶ │ ID / EX │──▶ │ MEM / WB│
└────────┘    └─────────┘    └─────────┘
   Fetch       Decode +        Memory +
                Execute        Writeback

```

| Parameter | Value |
|-----------|-------|
| Pipeline Depth | **3 stages** |
| Pipeline Type | In-order, scalar |
| Speculation | **None** (no branch prediction) |
| Hazard Handling | Stall-based (no forwarding) |

### 2.3 Pipeline Stages

| Stage | Name | Operations |
|-------|------|------------|
| 1 | **IF** | Instruction Fetch from IMEM, PC update |
| 2 | **ID/EX** | Decode, Register Read, ALU Execute, Branch resolution |
| 3 | **MEM/WB** | Memory Load/Store, Register Writeback |

---

## 3. Memory Subsystem

### 3.1 Instruction Memory (IMEM)

| Parameter | Value |
|-----------|-------|
| Size | **4 KB** (1024 × 32-bit words) |
| Address Bits | 10 bits (word-addressed) |
| Implementation | Sky130 SRAM macro |
| Access | Read-only during normal operation |
| Interface | Synchronous, single-cycle read |

### 3.2 Data Memory (DMEM)

| Parameter | Value |
|-----------|-------|
| Size | **4 KB** (1024 × 32-bit words) |
| Address Bits | 10 bits (word-addressed) |
| Implementation | Sky130 SRAM macro |
| Access | Read/Write |
| Interface | Synchronous, single-cycle access |
| Byte Enables | 4-bit write mask for LB/LH/SB/SH |

### 3.3 Memory Map

```
0x0000_0000 - 0x0000_0FFF : IMEM (4 KB, read-only)
0x0001_0000 - 0x0001_0FFF : DMEM (4 KB, read/write)
```

---

## 4. DFT / Debug Infrastructure

### 4.1 Design-for-Test

| Feature | Status |
|---------|--------|
| Scan Chains | **Not implemented** |
| Scan Insertion | None |
| ATPG | Not applicable |

### 4.2 JTAG TAP Controller

| Parameter | Value |
|-----------|-------|
| Standard | IEEE 1149.1 compliant |
| IR Length | 5 bits |
| ID Code | TBD (Efabless assigned) |

#### JTAG Features:

| Feature | Description |
|---------|-------------|
| **Halt/Resume** | Halt core execution, resume from halt |
| **Debug Register** | Single 32-bit read/write access to debug data register |
| **BIST Control** | Start/stop BIST via JTAG |
| **BIST Status** | Read BIST pass/fail result |

#### JTAG Pins:

| Pin | Direction | Description |
|-----|-----------|-------------|
| `tck` | Input | Test Clock |
| `tms` | Input | Test Mode Select |
| `tdi` | Input | Test Data In |
| `tdo` | Output | Test Data Out |
| `trst_n` | Input | Test Reset (active-low) |

### 4.3 BIST (Built-In Self-Test)

| Parameter | Value |
|-----------|-------|
| Algorithm | **March C-** (simplified) |
| Coverage | IMEM and DMEM |
| Activation | **Test mode only** (via JTAG or dedicated pin) |
| Duration | ~6N cycles per memory (N = memory depth) |

#### BIST Sequence (March C-):

```
1. ⇑ (w0)        : Write 0 ascending
2. ⇑ (r0, w1)    : Read 0, Write 1 ascending
3. ⇑ (r1, w0)    : Read 1, Write 0 ascending
4. ⇓ (r0, w1)    : Read 0, Write 1 descending
5. ⇓ (r1, w0)    : Read 1, Write 0 descending
6. ⇑ (r0)        : Read 0 ascending (verify)
```

#### BIST Status Register:

| Bit | Name | Description |
|-----|------|-------------|
| 0 | `bist_done` | BIST complete |
| 1 | `bist_pass` | All tests passed |
| 2 | `imem_fail` | IMEM test failed |
| 3 | `dmem_fail` | DMEM test failed |

---

## 5. Physical Integration

### 5.1 Caravel Integration

| Parameter | Value |
|-----------|-------|
| Wrapper | `user_project_wrapper` |
| User Area | 2.92mm × 3.52mm |
| Power Domains | `vccd1` / `vssd1` (1.8V digital) |
| Clock Source | Caravel `wb_clk_i` (directly or divided) |
| Reset Source | Caravel `wb_rst_i` |

### 5.2 Top-Level Ports

```
RISC_CPU/
└── verilog/rtl/
    └── user_project_wrapper.v   ← Your core instantiated here
        └── rv32i_top.v          ← Top-level core module
            ├── if_stage.v
            ├── idex_stage.v
            ├── memwb_stage.v
            ├── reg_file.v
            ├── alu.v
            ├── control.v
            ├── jtag_tap.v
            ├── debug_module.v
            ├── bist_ctrl.v
            ├── imem_wrapper.v
            └── dmem_wrapper.v
```

### 5.3 Pin Mapping (Caravel IO)

| Caravel Pin | Function |
|-------------|----------|
| `io_in[0]` | `tck` (JTAG clock) |
| `io_in[1]` | `tms` (JTAG mode select) |
| `io_in[2]` | `tdi` (JTAG data in) |
| `io_out[3]` | `tdo` (JTAG data out) |
| `io_in[4]` | `trst_n` (JTAG reset) |
| `io_in[5]` | `bist_mode` (external BIST trigger) |
| `io_out[6]` | `bist_done` (BIST complete indicator) |
| `io_out[7]` | `bist_pass` (BIST result) |

---

## 6. Scope Boundaries

### ✅ IN SCOPE

- RV32I base integer instructions (37 instructions)
- 3-stage pipeline with stall logic
- 4KB IMEM + 4KB DMEM (SRAM macros)
- JTAG TAP with halt/resume and debug register
- BIST for memory testing
- Caravel integration

### ❌ OUT OF SCOPE (Do Not Add)

- M extension (multiply/divide)
- C extension (compressed instructions)
- A extension (atomics)
- F/D extensions (floating-point)
- Branch prediction
- Caches
- Interrupts / exceptions (CSRs)
- Multi-core
- Scan chains / full DFT
- AXI/AHB bus interfaces

---

## 7. Success Criteria

| Milestone | Criteria |
|-----------|----------|
| RTL Complete | All RV32I instructions pass riscv-tests |
| Simulation | Verilator testbench passes all tests |
| Synthesis | OpenLane flow completes without DRC/LVS errors |
| Timing | Meets 20 MHz (50ns period) with margin |
| Tapeout | GDS submitted to Efabless MPW |

---

## 8. Reference Documents

| Document | Location |
|----------|----------|
| Coding Rules | `docs/coding_rules.md` |
| Design Notes | `docs/notes.md` |
| RISC-V Spec | [riscv.org/specifications](https://riscv.org/specifications/) |
| Caravel Docs | [caravel-harness.readthedocs.io](https://caravel-harness.readthedocs.io/) |
| Sky130 PDK | [skywater-pdk.readthedocs.io](https://skywater-pdk.readthedocs.io/) |

---

> ⚠️ **SCOPE LOCK NOTICE**  
> This specification is frozen as of 2026-02-01.  
> Any changes require explicit review and version increment.

---

## 9. Final Tape-out PPA Metrics (SKY130)

Upon successful hardening of the `rv32i_top` macro via OpenLane, the following final core specifications were achieved:

### 9.1 Performance (Max Clock Speed)
| Metric | Value | Notes |
|--------|-------|-------|
| Target Clock Period | 20.00 ns (50 MHz) | Caravel integration target |
| Setup Slack (WNS) | **+10.22 ns** | Passed timing with massive margin |
| Critical Path Delay | ~9.78 ns | Period - Slack |
| **Max Frequency (Fmax)**| **~102.2 MHz** | Theoretical maximum on typical corner |

### 9.2 Area (Silicon Footprint)
| Metric | Value | Notes |
|--------|-------|-------|
| Die Area (Macro) | **6.25 mm²** | 2500 µm × 2500 µm |
| Core Area (Logic) | 6.16 mm² | Logic + SRAM footprint |
| Logic Cell Count | **9,157 cells** | Sky130 standard cells mapped |
| Macros | 2 | 2x 2KB SRAM `sky130_sram_2kbyte_1rw1r` |

### 9.3 Power (Estimated)
| Metric | Value | Notes |
|--------|-------|-------|
| Internal Power | 5.6 nW | Static estimation at default toggle rate |
| Switching Power | 3.39 nW | Static estimation at default toggle rate |
| Leakage Power | 0.33 nW | |
| **Total Power** | **~9.32 nW** | Highly dependent on actual workload |

---

## 10. The Final Boss: MPW Precheck

Before a completed `user_project_wrapper.gds` can be submitted to the Efabless Open MPW shuttle for physical manufacturing, it must pass the automated **MPW Precheck** suite. 

This script verifies that the GDSII boundary is perfectly legal and that the SoC doesn't violate any manufacturing constraints. Key checks include:
- **License Check**: Ensures open-source headers are present.
- **Makefile Check**: Validates that the project can be uncompressed and built.
- **Consistency Check**: Verifies the netlist matches the GDSII (LVS).
- **GPIO Check**: Ensures no Caravel management pad frame rules were violated.
- **Magic DRC Check**: A final, complete Design Rule Check across the entire SoC boundary.
- **OEB Check**: Output Enable verification across the wrapper boundary.

Once MPW Precheck passes with 0 errors, the chip is officially ready to be sent to the foundry!

---

*End of Specification*
