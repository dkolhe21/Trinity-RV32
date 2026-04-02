# RISC_CPU — Academic Project Report

> **Title:** Design, Verification, and Physical Implementation of a 3-Stage RV32I RISC-V Processor for Silicon Tape-out  
> **Author:** Durgesh Kolhe (dkolhe21)  
> **Date:** February 2026  
> **Target Technology:** SkyWater SKY130 130nm Open-Source PDK  
> **EDA Toolchain:** OpenLane v1.0.2 (Yosys, OpenROAD, Magic, Netgen, KLayout)

---

## Abstract

This report documents the end-to-end design cycle of a custom **RV32I RISC-V processor** — from architectural specification through RTL implementation, functional verification, Caravel SoC integration, and physical layout generation using the open-source SkyWater SKY130 process node. The processor implements the complete RV32I Base Integer instruction set (37 instructions) in a 3-stage in-order pipeline. Verification was performed using the official RISC-V compliance test suite, achieving a **37/37 pass rate**. The final hardened macro occupies **6.25 mm²** of silicon area with a maximum operating frequency of **~102 MHz** on the typical process corner.

---

## 1. Introduction

### 1.1 Motivation
The RISC-V instruction set architecture (ISA) is an open-standard ISA that has gained significant traction in both academia and industry. Designing a processor from scratch provides deep understanding of computer architecture concepts including pipelining, hazard detection, memory hierarchy, and physical design constraints.

### 1.2 Objectives
1. Design a synthesizable RV32I processor in Verilog HDL.
2. Implement a 3-stage pipeline (IF, ID/EX, MEM/WB) with hazard resolution.
3. Integrate DFT infrastructure (JTAG TAP controller and Built-In Self-Test).
4. Verify correctness using the official RISC-V compliance suite.
5. Integrate the processor into the Efabless Caravel SoC wrapper.
6. Generate a DRC-clean, LVS-clean GDSII layout for silicon manufacturing.

### 1.3 Scope
The design implements only the RV32I base integer instruction set. Extensions (M, C, A, F/D), branch prediction, caches, interrupts/exceptions, and multi-core support are explicitly excluded.

---

## 2. Architecture

### 2.1 Pipeline Organization

The processor uses a **3-stage in-order scalar pipeline**:

```
┌────────┐    ┌─────────┐    ┌─────────┐
│   IF   │───▶│ ID / EX │───▶│ MEM / WB│
└────────┘    └─────────┘    └─────────┘
  Fetch        Decode +        Memory +
               Execute        Writeback
```

| Parameter         | Value                        |
|-------------------|------------------------------|
| ISA               | RV32I (Base Integer)         |
| Pipeline Depth    | 3 stages                     |
| Pipeline Type     | In-order, scalar             |
| Data Width        | 32 bits                      |
| Register File     | 32 × 32-bit GPRs (x0 = 0)   |
| Endianness        | Little-endian                |
| Branch Prediction | None (resolve in ID/EX)      |

### 2.2 Stage Descriptions

**Stage 1 — Instruction Fetch (IF):**
- Maintains the Program Counter (PC) register.
- Drives the instruction memory (IMEM) address bus.
- Latches fetched instructions into a pipeline register.
- Handles flush (branch/jump taken) and stall (hazard) signals.
- Contains a delayed PC register (`pc_q_prev`) to compensate for 1-cycle synchronous SRAM read latency.

**Stage 2 — Instruction Decode / Execute (ID/EX):**
- Instantiates the Control Decoder to extract register addresses, ALU operation, immediates, and memory control signals from the 32-bit instruction word.
- Reads operands from the Register File.
- Performs MEM/WB → ID/EX data forwarding to resolve RAW (Read-After-Write) hazards without stalling.
- Executes arithmetic/logic operations through the ALU.
- Resolves branches (BEQ, BNE, BLT, BGE, BLTU, BGEU) and jumps (JAL, JALR) combinationally.
- Latches results into the EX/MEM pipeline register.

**Stage 3 — Memory Access / Writeback (MEM/WB):**
- Drives the data memory (DMEM) interface for loads and stores.
- Generates byte write masks for sub-word stores (SB, SH).
- Performs sign/zero extension for sub-word loads (LB, LBU, LH, LHU).
- Selects the writeback source: ALU result, load data, or PC+4 (for link instructions).
- Writes back to the Register File.

### 2.3 Hazard Resolution

| Hazard Type     | Detection                                    | Resolution                                      |
|-----------------|----------------------------------------------|--------------------------------------------------|
| **RAW (Data)**  | MEM/WB `rd` matches ID/EX `rs1` or `rs2`    | Operand forwarding from writeback data mux       |
| **Control**     | Branch/jump resolved taken in ID/EX          | Flush IF pipeline register, redirect PC          |
| **Structural**  | Not applicable (separate IMEM/DMEM ports)    | N/A                                              |

### 2.4 Memory Subsystem

| Memory   | Size   | Implementation                              | Interface              |
|----------|--------|---------------------------------------------|------------------------|
| IMEM     | 2 KB   | `sky130_sram_2kbyte_1rw1r_32x512_8` macro   | Synchronous, 1-cycle   |
| DMEM     | 2 KB   | `sky130_sram_2kbyte_1rw1r_32x512_8` macro   | Synchronous, 1-cycle   |

Both memories use pre-compiled Sky130 OpenRAM SRAM macros. These replace behavioral register arrays that would have synthesized into ~146,000 flip-flops, which was physically unroutable.

---

## 3. Design-for-Test (DFT) Infrastructure

### 3.1 JTAG TAP Controller
An IEEE 1149.1-compliant JTAG Test Access Port is integrated with a 5-bit instruction register supporting:
- **IDCODE** (0x01): Returns a 32-bit identification code.
- **DEBUG_ACCESS** (0x10): Provides halt/resume control and register read/write access to the core pipeline through a Debug Module bridge.
- **BIST_CTRL** (0x11): Starts/stops the Built-In Self-Test engine and reads pass/fail status.
- **BYPASS** (0x1F): Standard bypass for daisy-chaining.

### 3.2 Built-In Self-Test (BIST)
A March C⁻ memory BIST controller tests both IMEM and DMEM through a series of ascending/descending read-write patterns. The BIST also performs ALU spot-checks. It is activated either through the JTAG TAP or a dedicated external pin.

---

## 4. Module Hierarchy

```
user_project_wrapper (Caravel top)
└── rv32i_top (SoC integration)
    ├── rv32_core (CPU pipeline)
    │   ├── if_stage       — Instruction Fetch
    │   ├── idex_stage     — Decode + Execute
    │   │   ├── control    — Opcode Decoder
    │   │   └── alu        — Arithmetic Logic Unit
    │   ├── memwb_stage    — Memory + Writeback
    │   └── reg_file       — 32x32-bit Register File
    ├── imem_wrapper       — SRAM Macro (Instruction Memory)
    ├── dmem_wrapper       — SRAM Macro (Data Memory)
    ├── jtag_tap           — IEEE 1149.1 TAP Controller
    ├── debug_module       — JTAG-to-Core Debug Bridge
    └── bist_ctrl          — Built-In Self-Test Engine
```

**Total RTL modules:** 12 (all Verilator lint-clean)

---

## 5. Verification Methodology

A multi-layered verification strategy was employed:

### 5.1 Module-Level Unit Testing
Individual Verilog testbenches (compiled with Icarus Verilog) verified foundational modules in isolation:
- **ALU:** All 10 arithmetic/logic/shift operations with boundary values.
- **Control Unit:** Every RV32I opcode mapped to correct control signals.
- **Register File:** Synchronous write, asynchronous read, x0 hardwired to zero.
- **JTAG TAP:** State machine transitions and shift register operations.
- **BIST Controller:** March C⁻ sequence activation and pass/fail reporting.

### 5.2 Integration Testing
A bare-metal integration testbench (`tb_rv32_core`) loaded machine-code hex files into memory, released the reset, and verified 15 instruction execution sequences end-to-end through the full pipeline.

### 5.3 RISC-V Compliance Suite
The official `riscv-tests` compliance suite (`rv32ui-p`) was executed. This suite consists of **37 independent assembly test binaries**, each exercising a specific RV32I instruction with hundreds of edge cases including signed/unsigned overflow, zero-register writes, and inter-instruction dependencies.

**Result: 37/37 PASSED** — The processor produces bit-identical memory signatures to the RISC-V Golden Reference Model.

### 5.4 Caravel SoC Smoke Test
A full-system simulation instantiated the entire Caravel SoC (management core + user project wrapper). C-language firmware configured GPIO pads, and the testbench drove JTAG pins externally to read the IDCODE register, verifying end-to-end connectivity through the padframe.

**Result: IDCODE = 0x00000001 — PASSED**

### 5.5 Physical Signoff (LVS)
Layout Vs. Schematic verification (via Netgen) mathematically proved that the final GDSII layout is electrically equivalent to the synthesized netlist.

**Result: Design is LVS Clean**

---

## 6. Physical Implementation (OpenLane Flow)

### 6.1 Tool Stack
| Tool       | Purpose                                        |
|------------|-------------------------------------------------|
| Yosys      | RTL synthesis → gate-level netlist              |
| OpenROAD   | Floorplanning, placement, CTS, global routing   |
| TritonRoute| Detailed routing                                |
| Magic      | DRC (Design Rule Check) and parasitic extraction |
| Netgen     | LVS (Layout Vs. Schematic) verification         |
| KLayout    | GDSII streaming and DRC                         |

### 6.2 Hardening Strategy

The design was hardened in two stages:

**Stage 1 — `rv32i_top` (Core Macro):**
- Synthesized all digital logic + instantiated 2 SRAM macros.
- Die area: 2500 × 2500 µm.
- Power hooks connected SRAM macros to `vccd1`/`vssd1`.

**Stage 2 — `user_project_wrapper` (Caravel Integration):**
- Placed the hardened `rv32i_top` macro inside the Caravel wrapper.
- Synthesized the reset inverter (`~wb_rst_i` → `rst_n`) to a physical standard cell.
- Routed 128+38 Caravel interface pins around the macro.

### 6.3 Key Physical Design Challenges

| Challenge | Root Cause | Solution |
|-----------|------------|----------|
| 146K cell routing congestion | Behavioral memory arrays synthesized to flip-flops | Replaced with pre-compiled SRAM macros |
| Unmapped `$not` cell crash | `SYNTH_ELABORATE_ONLY=1` prevented technology mapping | Disabled elaborate-only mode for wrapper |
| `met4` DRC short | Wrapper routing collided with macro's internal `met4` | Extended `RT_MAX_LAYER` to `met5` |

### 6.4 Final PPA (Power, Performance, Area)

| Metric                | Value         |
|-----------------------|---------------|
| Max Frequency (Fmax)  | **~102 MHz**  |
| Setup Slack (WNS)     | +10.22 ns     |
| Hold Slack            | +0.51 ns      |
| Die Area              | 6.25 mm²      |
| Core Area             | 6.16 mm²      |
| Standard Cell Count   | 9,157 cells   |
| SRAM Macros           | 2 × 2KB       |
| DRC Violations        | **0**         |
| LVS Status            | **Clean**     |
| Final GDSII Size      | 108 MB        |

---

## 7. Caravel SoC Integration

The processor is integrated into the Efabless Caravel SoC via the `user_project_wrapper` module. The Caravel framework provides:
- Clock (`wb_clk_i`) and reset (`wb_rst_i`) from the management SoC.
- 38 user I/O pins (`mprj_io[37:0]`) accessible through the GPIO padframe.
- 128-bit Logic Analyzer interface.
- Wishbone bus interface (active but unused in this design).

### Pin Mapping

| Caravel Pin   | Signal          | Direction |
|---------------|-----------------|-----------|
| `mprj_io[0]`  | `jtag_tck`     | Input     |
| `mprj_io[1]`  | `jtag_tms`     | Input     |
| `mprj_io[2]`  | `jtag_tdi`     | Input     |
| `mprj_io[3]`  | `jtag_tdo`     | Output    |
| `mprj_io[4]`  | `jtag_trst_n`  | Input     |
| `mprj_io[5]`  | `bist_mode`    | Input     |
| `mprj_io[6]`  | `bist_done`    | Output    |
| `mprj_io[7]`  | `bist_pass`    | Output    |

---

## 8. Conclusion

A fully functional RV32I RISC-V processor was successfully designed, verified, and hardened for silicon tape-out on the SkyWater SKY130 130nm process. The design passes all 37 official RISC-V compliance tests, achieves a maximum clock frequency of ~102 MHz, and produces a DRC-clean, LVS-clean GDSII layout ready for submission to the Efabless Open MPW shuttle program.

The project demonstrates the complete ASIC design flow from architectural specification to tape-out using entirely open-source tools, making it a compelling case study for academic research in computer architecture, digital VLSI design, and open-source silicon.

---

## 9. References

1. A. Waterman and K. Asanović, "The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA," RISC-V Foundation, 2019.
2. T. Edwards et al., "Caravel Harness Documentation," Efabless Corporation, 2021.
3. SkyWater Technology, "SKY130 Open Source PDK Documentation," 2020.
4. M. Shalan and T. Edwards, "Building OpenLANE: A 130nm OpenROAD-based Digital SoC Design Platform," WOSET, 2020.
5. IEEE Standard 1149.1-2013, "IEEE Standard for Test Access Port and Boundary-Scan Architecture."
6. SRAM Compiler, "OpenRAM: An Open-Source Memory Compiler," UC Santa Cruz, 2016.

---

*End of Report*
