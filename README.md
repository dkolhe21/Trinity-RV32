# Trinity-RV32: Silicon-Proven RISC-V Processor 🚀

[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](#) [![ISA](https://img.shields.io/badge/ISA-RV32I-blue.svg)](#) [![Process](https://img.shields.io/badge/PDK-Sky130-green.svg)](#)

A meticulously designed, fully hardened 3-stage RV32I RISC-V processor built from scratch for physical tapeout on the **SkyWater SKY130 130nm Open-Source PDK**. The core is integrated via the Efabless Caravel SoC and achieves a DRC-clean and LVS-clean GDSII layout.

---

## 🏗️ Architecture

- **Instruction Set**: RV32I Base Integer (37 Instructions)
- **Pipeline**: 3-Stage, in-order scalar (Fetch ➔ Decode/Execute ➔ Memory/Writeback)
- **Memory**: 4KB Instruction Memory, 4KB Data Memory (via Sky130 SRAM macros)
- **Hazard Handling**: Data forwarding (RAW), stall on load-use, flush on control hazards
- **Testing & DFT**: IEEE 1149.1 JTAG TAP Controller & March C⁻ Memory BIST

---

## 🔬 Final Tapeout Specs (PPA)

| Metric | Value |
|--------|-------|
| Target Frequency | **20 MHz** (Caravel target) |
| Max Frequency (Fmax) | **~102.2 MHz** |
| Die Area | **6.25 mm²** |
| Standard Cell Count | **9,157 cells** |
| Layout Checks | **DRC/LVS Clean** 🟢 |

---

## ✅ Verification Methodology
The core was mathematically proven against the **official RISC-V Compliance Suite** (`rv32ui-p`).
- **Result:** Passed 37/37 tests. The processor yields bit-identical memory signatures to the RISC-V Golden Model.

It was further verified using:
1. **Module Level:** Exhaustive unit tests using Verilator C++ testbenches.
2. **Bare-Metal:** Custom hex-loaded machine code Verilog simulations (Icarus).
3. **SoC Integration:** Full Efabless Caravel management SOC simulation validating the JTAG TAP GPIO pinmux.
4. **Physical Signoff:** Netgen LVS (Layout Vs. Schematic) extraction checks to confirm the GDSII matches the RTL.

---

## 💻 Quick Start & Commands Reference
This repo comes pre-configured with verification and hardening commands via `make`.

### Run Simulation Tests
```bash
cd verilog/dv
make -f Makefile_rv32 unit          # Run all underlying module unit tests
make -f Makefile_rv32 integration   # Run core integration machine-code pipeline tests
make -f Makefile_rv32 compliance    # Run the official RISC-V test suite
```

### Physical Design (OpenLane)
```bash
# Harden the core CPU macro
cd openlane && make rv32i_top 

# Integrate the core into Caravel SoC and wire the pinframe
cd openlane && make user_project_wrapper 
```

### Layout Inspection
```bash
klayout openlane/rv32i_top/runs/<tag>/results/final/gds/rv32i_top.gds
```

---

*This software is proprietary. View the internal LICENSE file for sharing and modification restrictions.*
