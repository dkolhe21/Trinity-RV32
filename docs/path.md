# RISC_CPU – Project Path Guide

This document maps out where all the key project files are located, from RTL source code to the final taped-out GDSII macro and wrapper files.

All paths are relative to the project root: `/run/media/durgesh/Code/visualstudio/RISC-V/RISC_CPU/`

---

## 1. Final Silicon Layouts (GDSII & LEF)

These are the final physical files that get sent to the SkyWater foundry for manufacturing. OpenLane generates them deep within its run directories.

### Hardened CPU Macro (`rv32i_top`)
*   **Final GDSII (`.gds`)**:
    `openlane/rv32i_top/runs/rv32i_top/results/final/gds/rv32i_top.gds` *(108 MB)*
*   **Final LEF (Abstract) (`.lef`)**:
    `openlane/rv32i_top/runs/rv32i_top/results/final/lef/rv32i_top.lef`
*   **Gate-Level Netlist (`.v`)**:
    `openlane/rv32i_top/runs/rv32i_top/results/signoff/rv32i_top.v`
*   **Manufacturability / DRC / LVS Reports**:
    `openlane/rv32i_top/runs/rv32i_top/reports/manufacturability.rpt`
*   **Timing / Power / Area Reports**:
    `openlane/rv32i_top/runs/rv32i_top/reports/signoff/` and `openlane/rv32i_top/runs/rv32i_top/reports/metrics.csv`

### Hardened Caravel Wrapper (`user_project_wrapper`)
*   **Final GDSII (`.gds`)**:
    `openlane/user_project_wrapper/runs/user_project_wrapper/results/final/gds/user_project_wrapper.gds` *(108 MB)*
*   **Final LEF (`.lef`)**:
    `openlane/user_project_wrapper/runs/user_project_wrapper/results/final/lef/user_project_wrapper.lef`
*   **Manufacturability / DRC / LVS Reports**:
    `openlane/user_project_wrapper/runs/user_project_wrapper/reports/manufacturability.rpt`

---

## 2. RTL Source Code (`.v` files)

All Verilog code defining the logic of the processor and its wrapper.

### Target Wrapper Files
*   **Caravel User Project Wrapper**:
    `verilog/rtl/user_project_wrapper.v`
*   **SoC-Level Top Module (Macros + Wrapper Hookup)**:
    `verilog/rtl/rv32i_top.v`
*   **Defines for I/O Pins**:
    `verilog/rtl/user_defines.v`

### CPU Core Logic (`rv32_core.v`)
*   **Top Level Interconnect**: `verilog/rtl/rv32_core.v`
*   **Fetch (IF)**: `verilog/rtl/if_stage.v`
*   **Decode/Execute (ID/EX)**: `verilog/rtl/idex_stage.v`
*   **Memory/Writeback (MEM/WB)**: `verilog/rtl/memwb_stage.v`
*   **Control Unit**: `verilog/rtl/control.v`
*   **ALU**: `verilog/rtl/alu.v`
*   **Register File**: `verilog/rtl/reg_file.v`

### Peripheral Modules
*   **JTAG TAP**: `verilog/rtl/jtag_tap.v`
*   **Debug Module**: `verilog/rtl/debug_module.v`
*   **BIST Controller**: `verilog/rtl/bist_ctrl.v`
*   **SRAM Memory Wrappers**: `verilog/rtl/imem_wrapper.v`, `verilog/rtl/dmem_wrapper.v`

### Sky130 Macro Stubs
*   **SRAM Blackbox Stub**: `macros/sky130_sram_2kbyte_1rw1r_32x512_8.v`

---

## 3. Testbenches & Verification Proofs

The test code written to prove the exact functionality of the CPU before it was sent to OpenLane.

### RISC-V Compliance Suite (The Official Proof)
*   **Test Environment Directory**: `verilog/dv/compliance/`
*   **Main Testbench**: `verilog/dv/compliance/tb_riscv_compliance.v` *(Runs the 37 binary tests)*
*   **Compiled Test Binaries (`.hex` files)**: `verilog/dv/compliance/references/`
*   **Test Signatures (The Proof output)**: `verilog/dv/compliance/signatures/`
*   **Waveforms generated during testing (`.vcd` files)**: Automatically generated inside `verilog/dv/compliance/` when running `make -f Makefile_rv32 compliance`.

### Integration Tests
*   **Bare-metal Core Testbench**: `verilog/dv/integration/tb_rv32_core.v`
*   **Caravel SoC Smoke Test** (JTAG test):
    *   **Testbench**: `verilog/dv/rv32i_jtag/rv32i_jtag_tb.v`
    *   **Management Core C Firmware**: `verilog/dv/rv32i_jtag/rv32i_jtag.c`

### Unit Tests
*   **Directory**: `verilog/dv/unit/`
*   Includes: `tb_alu.v`, `tb_bist_ctrl.v`, `tb_control.v`, `tb_jtag_tap.v`, `tb_reg_file.v`

---

## 4. OpenLane Configuration Files

The setup parameters that tell the physical design tools exactly how to shape the macro and wrapper.

*   **`rv32i_top` Macro Config**:
    `openlane/rv32i_top/config.json`
*   **`rv32i_top` Core Pin Placement**:
    `openlane/rv32i_top/pin_order.cfg`
*   **`rv32i_top` Physical Floorplan Macros**:
    `openlane/rv32i_top/macro.cfg`
*   **Caravel Wrapper Config**:
    `openlane/user_project_wrapper/config.json`
*   **Caravel Wrapper Physical Floorplan Macro Layout**:
    `openlane/user_project_wrapper/macro.cfg`
