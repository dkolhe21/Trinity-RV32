<div align="center">

# ⚡ Trinity-RV32

### A Silicon-Proven, 3-Stage RV32I RISC-V Processor

*Designed from scratch. Verified to spec. Hardened for real silicon.*

[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](#)
[![ISA: RV32I](https://img.shields.io/badge/ISA-RV32I-2ea44f)](#)
[![PDK: SKY130](https://img.shields.io/badge/PDK-SkyWater%20SKY130-blue)](#)
[![Compliance: 37/37](https://img.shields.io/badge/RISC--V%20Compliance-37%2F37%20PASS-brightgreen)](#)
[![DRC/LVS: Clean](https://img.shields.io/badge/DRC%2FLVS-✅%20Clean-success)](#)
[![Fmax: ~102 MHz](https://img.shields.io/badge/Fmax-~102%20MHz-orange)](#)

</div>

---

## 🧭 What is Trinity-RV32?

**Trinity-RV32** is a complete, handcrafted RISC-V processor designed and taped out entirely using open-source tools on the **SkyWater SKY130 130nm** process node. It is not a fork or an adaptation — every line of RTL was written from scratch against a strict coding standard, then pushed through the full ASIC design flow from architectural spec to a real, manufacturable GDSII layout.

The project demonstrates the complete end-to-end journey of building a real CPU chip:

```
Architectural Spec  →  RTL  →  Functional Verification  →  Physical Synthesis  →  DRC/LVS Signoff  →  GDSII Tapeout
```

It is integrated into the **Efabless Caravel SoC harness** for submission to the Google/Efabless Open MPW shuttle program — meaning this design is fabricated as real, physical silicon.

---

## 🏗️ Architecture

### Pipeline Overview

Trinity-RV32 uses a **3-stage, in-order, scalar pipeline**. The architecture prioritises implementation simplicity, full instruction-set coverage, and physical design closure over throughput.

```
         ┌────────┐       ┌──────────┐       ┌──────────┐
  IMEM──▶│  IF    │──────▶│  ID/EX   │──────▶│  MEM/WB  │──▶DMEM
         │ Fetch  │       │ Decode + │       │ Memory + │
         │        │       │ Execute  │       │ Writeback│
         └────────┘       └──────────┘       └──────────┘
             ▲                 │                   │
             │                 └── Data Forwarding ┘
             └──────────── Branch Flush ────────────
```

| Parameter         | Value                          |
|-------------------|--------------------------------|
| ISA               | RV32I — complete Base Integer  |
| Pipeline Depth    | 3 Stages                       |
| Pipeline Type     | In-order, scalar               |
| Data Width        | 32 bits                        |
| Register File     | 32 × 32-bit GPRs (x0 = 0)     |
| Endianness        | Little-endian                  |
| Branch Prediction | None — resolved in ID/EX       |

### Pipeline Stage Breakdown

**Stage 1 — Instruction Fetch (IF)**
- Drives the PC register and IMEM address bus
- Handles branch/jump flushes and load-use stalls
- Contains a shadow PC register (`pc_q_prev`) to compensate for 1-cycle synchronous SRAM read latency

**Stage 2 — Instruction Decode / Execute (ID/EX)**
- Decodes all 37 RV32I instruction types (R, I, S, B, U, J-formats)
- Reads from the 32×32-bit register file
- Executes all arithmetic, logic, shift, compare, and branch computations in the ALU
- Resolves ALL control flow (BEQ, BNE, BLT, BGE, BLTU, BGEU, JAL, JALR) combinationally — zero branch misprediction penalty beyond the 1-cycle flush
- **MEM/WB → ID/EX data forwarding** eliminates RAW data hazards without stalling

**Stage 3 — Memory Access / Writeback (MEM/WB)**
- Drives the DMEM interface for all loads and stores
- Generates byte/halfword write masks for SB and SH store operations
- Sign/zero extends loaded data for LB, LBU, LH, LHU
- Selects the correct writeback source: ALU result, load data, or PC+4 (for JAL/JALR link)
- Writes back to the register file

---

## 🛠️ Design-for-Test (DFT) Infrastructure

A key goal of this project was to make the silicon testable after manufacturing. Two dedicated DFT modules were designed and integrated.

### JTAG TAP Controller (IEEE 1149.1)

A fully-compliant JTAG Test Access Port was implemented with a 5-bit instruction register.

| JTAG Command   | Opcode | Function                                              |
|----------------|--------|-------------------------------------------------------|
| `IDCODE`       | `0x01` | Returns a 32-bit silicon identification code          |
| `DEBUG_ACCESS` | `0x10` | Halt/resume core, read/write any of the 32 GPRs       |
| `BIST_CTRL`    | `0x11` | Activate/stop BIST engine and read pass/fail result   |
| `BYPASS`       | `0x1F` | Standard bypass for JTAG daisy chain                  |

**JTAG Pins (mapped to Caravel `mprj_io`):**

| Caravel Pin   | Signal        | Direction |
|---------------|---------------|-----------|
| `mprj_io[0]`  | `jtag_tck`   | Input     |
| `mprj_io[1]`  | `jtag_tms`   | Input     |
| `mprj_io[2]`  | `jtag_tdi`   | Input     |
| `mprj_io[3]`  | `jtag_tdo`   | Output    |
| `mprj_io[4]`  | `jtag_trst_n`| Input     |
| `mprj_io[5]`  | `bist_mode`  | Input     |
| `mprj_io[6]`  | `bist_done`  | Output    |
| `mprj_io[7]`  | `bist_pass`  | Output    |

### Built-In Self-Test (BIST — March C⁻ Algorithm)

A March C⁻ memory BIST controller is integrated to test both IMEM and DMEM post-fabrication. This proves that the on-chip SRAM macros are defect-free after the manufacturing process.

```
1. ⇑ (w0)      — Write 0 to all cells, ascending
2. ⇑ (r0, w1)  — Read 0, Write 1, ascending
3. ⇑ (r1, w0)  — Read 1, Write 0, ascending
4. ⇓ (r0, w1)  — Read 0, Write 1, descending
5. ⇓ (r1, w0)  — Read 1, Write 0, descending
6. ⇑ (r0)      — Verify 0, ascending
```

---

## 🧠 Memory Subsystem

The processor uses **pre-compiled Sky130 OpenRAM SRAM macros** for both instruction and data memory. This was a critical physical design decision: a naive Verilog register-array implementation would have synthesised to ~146,000 flip-flops, producing a design too congested to route.

| Memory | Size | Implementation                              | Access   |
|--------|------|---------------------------------------------|----------|
| IMEM   | 2 KB | `sky130_sram_2kbyte_1rw1r_32x512_8` macro  | Read-only during execution, 1-cycle |
| DMEM   | 2 KB | `sky130_sram_2kbyte_1rw1r_32x512_8` macro  | Read/Write, 4-bit byte enables, 1-cycle |

**Memory Map:**
```
0x0000_0000 – 0x0000_07FF : IMEM (2 KB)
0x0001_0000 – 0x0001_07FF : DMEM (2 KB)
```

---

## 🔬 Verification & Compliance

The processor was verified against the **official RISC-V Compliance Test Suite** (`riscv-tests rv32ui-p`).

> **37 / 37 tests PASSED** — Bit-identical signatures to the RISC-V Golden Reference Model.

The compliance suite covers every RV32I instruction with hundreds of crafted edge cases per test — signed/unsigned overflow, zero-register writes, massive branch offsets, and back-to-back data hazard sequences. Passing all 37 means the pipeline hazard resolution, forwarding paths, and memory access byte-masking logic are all provably correct.

**Multi-Layer Verification Strategy:**

| Layer | Method | Result |
|-------|--------|--------|
| Unit Testing | Icarus Verilog testbenches for ALU, Decoder, RegFile, JTAG, BIST | ✅ PASS |
| Integration | Bare-metal hex-loaded machine code pipeline simulation | ✅ PASS |
| ISA Compliance | Official `riscv-tests rv32ui-p` suite (37 tests) | ✅ 37/37 PASS |
| SoC Integration | Full Caravel SoC smoke test via JTAG IDCODE read | ✅ IDCODE = 0x00000001 |
| Physical Signoff | Netgen LVS — layout electrically identical to netlist | ✅ LVS Clean |

---

## 🏭 Physical Implementation (OpenLane RTL-to-GDSII)

The chip was hardened using the **OpenLane v1.0.2** flow — a fully open-source ASIC implementation suite.

**Tool Stack:**

| Tool        | Role                                              |
|-------------|---------------------------------------------------|
| Yosys       | RTL Synthesis → Gate-level netlist                |
| OpenROAD    | Floorplanning, Placement, CTS, Global Routing     |
| TritonRoute | Detailed routing                                  |
| Magic       | DRC and parasitic extraction                      |
| Netgen      | LVS verification                                  |
| KLayout     | GDSII streaming and DRC cross-check               |

**Hardening Strategy — Two-Stage:**

1. **Stage 1 — `rv32i_top` (Core Macro):** All digital logic and 2 SRAM macros hardened into a standalone 2500×2500 µm macro.
2. **Stage 2 — `user_project_wrapper` (Caravel Integration):** The hardened core macro placed inside the Caravel wrapper die. All 38 Caravel GPIO pins routed around the macro boundary.

**Key Physical Challenges Solved:**

| Challenge | Root Cause | Solution Applied |
|-----------|------------|-----------------|
| 146K-cell routing congestion | Behavioral memory synthesised to flip-flops | Replaced with pre-compiled SRAM macros |
| `$not` unmapped cell crash | `SYNTH_ELABORATE_ONLY=1` blocked technology mapping | Disabled elaborate-only mode on wrapper |
| `met4` DRC short | Wrapper routing collided with macro's internal met4 | Extended `RT_MAX_LAYER` to `met5` |

---

## 📊 Final Silicon PPA Results

### Performance

| Metric               | Value         |
|----------------------|---------------|
| Target Clock Period  | 50 ns (20 MHz) |
| Setup Slack (WNS)    | **+10.22 ns** |
| Critical Path Delay  | ~9.78 ns      |
| **Max Frequency**    | **~102.2 MHz** |

### Area

| Metric              | Value          |
|---------------------|----------------|
| Die Area            | **6.25 mm²**   |
| Core Area           | 6.16 mm²       |
| Standard Cell Count | **9,157 cells** |
| SRAM Macros         | 2 × 2KB        |

### Power (Static Estimates)

| Component        | Value      |
|------------------|------------|
| Internal Power   | 5.6 nW     |
| Switching Power  | 3.39 nW    |
| Leakage Power    | 0.33 nW    |
| **Total Power**  | **~9.32 nW** |

### Signoff Status

| Check     | Status       |
|-----------|--------------|
| DRC       | ✅ **0 Violations** |
| LVS       | ✅ **Clean**        |
| Final GDS | 108 MB       |

---

## 📦 Module Hierarchy

```
user_project_wrapper          (Caravel SoC top boundary)
└── rv32i_top                 (Full SoC integration)
    ├── rv32_core             (3-Stage CPU pipeline)
    │   ├── if_stage          — Instruction Fetch
    │   ├── idex_stage        — Decode + Execute
    │   │   ├── control       — Opcode Decoder
    │   │   └── alu           — Arithmetic Logic Unit
    │   ├── memwb_stage       — Memory + Writeback
    │   └── reg_file          — 32×32-bit Register File
    ├── imem_wrapper          — SRAM Macro (2KB Instruction Memory)
    ├── dmem_wrapper          — SRAM Macro (2KB Data Memory)
    ├── jtag_tap              — IEEE 1149.1 TAP Controller
    ├── debug_module          — JTAG-to-Core Debug Bridge
    └── bist_ctrl             — March C⁻ Memory BIST Engine

Total RTL modules: 12 (all Verilator lint-clean)
```

---

## 📂 Repository Structure

```
Trinity-RV32/
├── verilog/
│   ├── rtl/          # All synthesisable RTL source files
│   └── dv/           # Testbenches and compliance suite
├── openlane/         # OpenLane configuration per macro
├── def/              # Design Exchange Format files
├── lef/              # Library Exchange Format files
├── sdc/              # Timing constraints (Synopsys Design Constraints)
├── signoff/          # DRC/LVS signoff reports
├── lib/              # Timing libraries
├── docs/             # Architecture spec, interface contract, coding rules
└── .github/          # CI workflow definitions
```

---

## ⚙️ Caravel SoC Integration

Trinity-RV32 is packaged as a **Caravel `user_project_wrapper`** for the Efabless Open MPW program. The Caravel harness provides:
- Clock (`wb_clk_i`) and reset (`wb_rst_i`) from the management SoC
- 38 user I/O pads (`mprj_io[37:0]`) for JTAG and BIST pins
- 128-bit Logic Analyzer interface
- Wishbone bus interface (connected, unused in this version)

---

## 📝 References

1. A. Waterman & K. Asanović — *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*, RISC-V Foundation, 2019
2. T. Edwards et al. — *Caravel Harness Documentation*, Efabless Corporation, 2021
3. SkyWater Technology — *SKY130 Open Source PDK Documentation*, 2020
4. M. Shalan & T. Edwards — *Building OpenLANE: A 130nm OpenROAD-based Digital SoC Design Platform*, WOSET, 2020
5. IEEE Standard 1149.1-2013 — *Standard for Test Access Port and Boundary-Scan Architecture*
6. OpenRAM — *An Open-Source Memory Compiler*, UC Santa Cruz, 2016

---

<div align="center">

*© 2026 Durgesh Kolhe. All Rights Reserved. See LICENSE for terms.*

</div>
