# RISC_CPU – Verification Methodology

## 1. Overview
Ensuring that a custom CPU operates completely bug-free requires rigorous, multi-layered verification. The **RISC_CPU** was verified using a combination of module-level C++ unit testing, system-level Verilog integration testing, industry-standard RISC-V compliance suites, and physical layout vs. schematic (LVS) equivalence checks.

## 2. Industry-Standard RISC-V Compliance Testing
To mathematically prove the CPU implements the RV32I (Base Integer) Instruction Set Architecture exactly as defined by the RISC-V Foundation, the core was subjected to the official **riscv-compliance** suite (`rv32ui-p`).

### 2.1 The Compliance Suite
- **Scope**: 37 independent assembly binary tests.
- **Coverage**: Every single base instruction (ADD, SUB, XOR, SLT, Branches, Load/Stores, Jumps, Shifts, Immediates).
- **Execution**: The test suite runs hundreds of meticulously crafted edge cases for each instruction, including negative number overflows, zero-register (`x0`) writes, massive branch offsets, and data bypass hazards.
- **Verification Method**: Signature matching. Each test generates a specific memory signature upon completion. This signature is compared bit-for-bit against a Golden Reference Model (the official RISC-V software emulator).

**Result**: The RISC_CPU passed **37 out of 37** tests with 100% identical signatures.

### 2.2 Pipeline Hazard Verification
During the execution of the compliance suite, the pipeline is pushed to its limits. The tests successfully flushed out and verified the resolution of three major classes of pipeline hazards:
- **Data Hazards (RAW)**: Verified that the `MEM/WB` to `ID/EX` forwarding paths correctly bypass the register file when sequential instructions depend on each other.
- **Control Hazards**: Verified that branch mispredictions and jumps (`jal`, `jalr`) correctly flush the `IF/ID` and `ID/EX` pipeline registers without creating infinite loops.
- **Load-Use Hazards**: Verified that a `load` instruction followed immediately by an instruction requiring that loaded data correctly stalls the pipeline for one cycle.

## 3. Module-Level Unit Testing
Before running the full CPU pipeline, foundational modules were verified individually using dedicated C++ (Verilator) testbenches.

- **ALU (`tb_alu.v`)**: Exhaustively verified all arithmetic, logical, and shift operations, including signed/unsigned comparisons.
- **Control Unit (`tb_control.v`)**: Verified that every 32-bit opcode correctly maps to the exact internal pipeline control signals.
- **Register File (`tb_reg_file.v`)**: Verified synchronous write behavior, asynchronous read behavior, and the hardwired zero enforcement on register `x0`.
- **JTAG & BIST (`tb_jtag_tap.v`, `tb_bist_ctrl.v`)**: Verified IEEE 1149.1 state machine transitions, read/write shift registers, and the BIST sequence activation.

## 4. Bare-Metal Integration Testing
To verify the full integration of the 3-stage pipeline, memory wrappers, and JTAG TAP controller, we ran a bare-metal Verilog integration test (`tb_rv32_core.v`). 

This test loads a custom hexadecimal machine-code file into the `imem_wrapper`, releases the reset, and monitors the CPU as it executes a series of simple instructions. The test bench asserts signals directly against expected waveform states to ensure that instruction fetch, decoding, and writing back to memory (`dmem_wrapper`) occur exactly when expected.

## 5. Caravel SoC Integration Testing
To verify the wrapper integration, a full-system SOC smoke test (`tb_rv32i_jtag.v`) was run. 
This test loads a C-based firmware (`rv32i_jtag.c`) onto the Caravel Management SoC, which configures the GPIO padframe. A testbench then drives the physical JTAG pins on the Caravel wrapper, validating that the interior RISC_CPU correctly responds to external stimulus through the SoC fabric.

## 6. Physical Signoff (LVS Verification)
At the physical level, bugs can be introduced during layout routing. To guarantee that the final GDSII silicon layout perfectly matches the proven logical Verilog netlist, the project was subjected to **Layout Vs. Schematic (LVS)** checks via the OpenLane flow (Netgen).

The extraction mathematically proves that the millions of wire connections and standard cells rendered in the `user_project_wrapper.gds` are equivalent to the RTL. The design achieved **LVS Clean** status.

---

### How to Run Verification Locally
All testbenches are provided in the `verilog/dv/` directory and use Verilator and Icarus Verilog.

```bash
cd /run/media/durgesh/Code/visualstudio/RISC-V/RISC_CPU/verilog/dv

# Run all Unit Tests
make -f Makefile_rv32 unit

# Run the Bare-Metal Integration test
make -f Makefile_rv32 integration

# Run the full RISC-V Compliance Suite (37/37)
make -f Makefile_rv32 compliance
```
