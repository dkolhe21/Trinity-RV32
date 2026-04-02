# Interface Specification

> **rv32_core** – Top-Level Core Interface Contract (RISC_CPU)  
> **Version:** 1.0 (LOCKED)  
> **Date:** 2026-02-01

---

## Overview

This document defines the **fixed interface contract** for `rv32_core`. All internal modules (pipeline stages, register file, ALU) and external wrappers (JTAG bridge, SRAM wrappers, BIST arbiter) must conform to this interface.

---

## Block Diagram

```
                          ┌─────────────────────────────────────────┐
                          │             rv32_core                    │
                          │                                          │
       clk ──────────────▶│  ┌────────┐  ┌─────────┐  ┌──────────┐  │
       rst_n ────────────▶│  │   IF   │─▶│  ID/EX  │─▶│  MEM/WB  │  │
                          │  └───┬────┘  └────┬────┘  └────┬─────┘  │
                          │      │            │            │         │
                          │      ▼            │            ▼         │
  ┌──────────┐            │  ┌───────┐        │       ┌────────┐    │            ┌──────────┐
  │   IMEM   │◀───────────│◀─│ imem_ │        │       │ dmem_  │───▶│───────────▶│   DMEM   │
  │  (SRAM)  │───────────▶│─▶│  bus  │        │       │  bus   │◀───│◀───────────│  (SRAM)  │
  └──────────┘            │  └───────┘        │       └────────┘    │            └──────────┘
                          │                   ▼                      │
                          │              ┌─────────┐                 │
                          │              │ RegFile │◀────────────────│◀─── dbg_* (Debug)
                          │              └─────────┘                 │
                          └─────────────────────────────────────────┘
```

---

## Port List

### Clock and Reset

| Port | Width | Dir | Description |
|------|-------|-----|-------------|
| `clk` | 1 | in | System clock (positive edge, 20 MHz target) |
| `rst_n` | 1 | in | Active-low synchronous reset |

### Instruction Memory Interface (IMEM)

| Port | Width | Dir | Description |
|------|-------|-----|-------------|
| `imem_en` | 1 | out | Fetch enable (high = requesting instruction) |
| `imem_addr` | 32 | out | PC / instruction address (word-aligned) |
| `imem_rdata` | 32 | in | Fetched instruction word |

**Timing:** Single-cycle. `imem_rdata` valid on cycle after `imem_en` asserted.

### Data Memory Interface (DMEM)

| Port | Width | Dir | Description |
|------|-------|-----|-------------|
| `dmem_en` | 1 | out | Memory access enable (high = load or store) |
| `dmem_addr` | 32 | out | Byte address for load/store |
| `dmem_wdata` | 32 | out | Write data (aligned to word boundary) |
| `dmem_wmask` | 4 | out | Byte write mask: `4'b0001`=byte0, `4'b1111`=word |
| `dmem_we` | 1 | out | Write enable: 1=store, 0=load |
| `dmem_rdata` | 32 | in | Read data (valid cycle after access) |

**Byte Mask Encoding:**

| Operation | `dmem_wmask` |
|-----------|--------------|
| SB (byte 0) | `4'b0001` |
| SB (byte 1) | `4'b0010` |
| SB (byte 2) | `4'b0100` |
| SB (byte 3) | `4'b1000` |
| SH (half 0) | `4'b0011` |
| SH (half 1) | `4'b1100` |
| SW (word) | `4'b1111` |

### Debug Interface

| Port | Width | Dir | Description |
|------|-------|-----|-------------|
| `dbg_halt` | 1 | in | Halt core (pipeline freezes) |
| `dbg_write_en` | 1 | in | Write to register file via debug |
| `dbg_reg_addr` | 5 | in | Register index (0-31) |
| `dbg_write_data` | 32 | in | Data to write |
| `dbg_read_data` | 32 | out | Data read from register |

**Debug Operation:**
- When `dbg_halt=1`: Pipeline stalls, no forward progress
- When `dbg_write_en=1`: Write `dbg_write_data` to `x[dbg_reg_addr]`
- `dbg_read_data` always reflects `x[dbg_reg_addr]` (combinational)

---

## Interface Waveforms

### Instruction Fetch

```
         ┌───┐   ┌───┐   ┌───┐   ┌───┐
clk      │   │   │   │   │   │   │   │
      ───┘   └───┘   └───┘   └───┘   └───

              ┌───────────────────────────
imem_en  ─────┘

         ─────┬───────┬───────┬───────────
imem_addr     │ PC=0  │ PC=4  │ PC=8
              └───────┴───────┴───────────

                   ┌───────┬───────┬──────
imem_rdata ────────│instr0 │instr1 │instr2
                   └───────┴───────┴──────
```

### Data Store (SW)

```
         ┌───┐   ┌───┐   ┌───┐
clk      │   │   │   │   │   │
      ───┘   └───┘   └───┘   └───

              ┌───────┐
dmem_en  ─────┘       └───────────────────

         ─────┬───────┬───────────────────
dmem_addr     │ addr  │
              └───────┴───────────────────

              ┌───────┐
dmem_we  ─────┘       └───────────────────

         ─────┬───────┬───────────────────
dmem_wmask    │ 4'b1111│
              └───────┴───────────────────
```

---

## Integration Notes

### SRAM Wrapper Requirements

The IMEM/DMEM wrappers must:
1. Provide single-cycle read latency
2. Support byte-enable writes (DMEM)
3. Mux between core access and BIST access

### JTAG Bridge Requirements

The JTAG bridge must:
1. Convert JTAG serial protocol to parallel debug interface
2. Manage `dbg_halt` based on JTAG commands
3. Serialize `dbg_read_data` for TDO

---

## Module Hierarchy

```
rv32_core
├── if_stage          # Instruction Fetch
├── idex_stage        # Decode + Execute
├── memwb_stage       # Memory + Writeback
├── reg_file          # 32x32-bit register file
├── alu               # Arithmetic Logic Unit
└── control           # Instruction decoder
```

---

*This interface is frozen. Changes require spec review.*
