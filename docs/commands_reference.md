# RISC_CPU — Commands Reference

This document lists every command used throughout the project, organized by phase.

---

## 1. RTL Linting (Verilator)

| Command | What It Does |
|---------|--------------|
| `verilator --lint-only -Wall -I verilog/rtl verilog/rtl/<module>.v` | Runs static lint analysis on a single Verilog module without compiling it. Catches width mismatches, unused signals, and implicit net declarations. |
| `verilator --lint-only -Wall -I verilog/rtl verilog/rtl/rv32_core.v` | Lint-checks the core top-level and all modules it instantiates, verifying port widths match across the full hierarchy. |

---

## 2. Unit Testing (Icarus Verilog)

| Command | What It Does |
|---------|--------------|
| `cd verilog/dv && make -f Makefile_rv32 unit` | Compiles and runs all 5 unit testbenches (ALU, Control, Register File, JTAG TAP, BIST) using Icarus Verilog. Each test prints PASS/FAIL to stdout. |
| `iverilog -Wall -g2012 -I../../verilog/rtl -o unit/tb_alu.vvp ../../verilog/rtl/defines_riscv.v ../../verilog/rtl/alu.v unit/tb_alu.v` | Manually compiles the ALU unit testbench into a VVP simulation binary. `-g2012` enables SystemVerilog 2012 features. `-I` sets the include search path. |
| `cd unit && vvp tb_alu.vvp` | Executes the compiled ALU testbench simulation and prints test results to the terminal. |

---

## 3. Integration Testing

| Command | What It Does |
|---------|--------------|
| `cd verilog/dv && make -f Makefile_rv32 integration` | Compiles and runs `tb_rv32_core.v`, a bare-metal integration test that loads hex machine code into IMEM, releases reset, and verifies 15 instruction executions through the full 3-stage pipeline. |

---

## 4. RISC-V Compliance Testing

| Command | What It Does |
|---------|--------------|
| `cd verilog/dv && make -f Makefile_rv32 compliance` | Clones the official `riscv-tests` repo, cross-compiles all 37 `rv32ui-p` test binaries using the RISC-V GCC toolchain, then runs each test through the core simulation and checks the TOHOST pass/fail register. |
| `riscv64-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -I env -T env/link.ld -o test.elf test.S` | Cross-compiles a single RISC-V assembly test file into a bare-metal ELF binary for the RV32I architecture with no standard library. |
| `riscv64-elf-objcopy -O verilog --verilog-data-width=4 test.elf test.hex` | Converts the ELF binary into a Verilog hex file that `$readmemh()` can load into the simulation memory array. `--verilog-data-width=4` ensures 32-bit word alignment. |
| `riscv64-elf-objdump -d test.elf` | Disassembles the ELF binary into human-readable RISC-V assembly, useful for debugging which instruction the CPU is stuck on. |

---

## 5. Caravel SoC Smoke Test

| Command | What It Does |
|---------|--------------|
| `cd verilog/dv/rv32i_jtag && make clean && make rv32i_jtag.vvp && vvp -N rv32i_jtag.vvp` | Compiles the C firmware for the Caravel management core, compiles the full-system Verilog testbench (including the entire Caravel padframe), and runs the JTAG IDCODE verification test. |

### Required Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `MCW_ROOT` | `../../mgmt_core_wrapper` | Path to the management core wrapper |
| `CARAVEL_ROOT` | `../../caravel` | Path to the Caravel harness |
| `PDK_ROOT` | `/run/media/durgesh/Code/vlsi_tools/pdks` | Path to the installed PDK |
| `PDK` | `sky130A` | Target PDK variant |
| `GCC_PATH` | `/usr/bin` | Directory containing the RISC-V GCC compiler |
| `GCC_PREFIX` | `riscv64-elf` | Compiler binary prefix (without trailing dash) |
| `SIM` | `RTL` | Simulation mode (RTL or GL for gate-level) |

---

## 6. OpenLane Physical Design Flow

| Command | What It Does |
|---------|--------------|
| `cd openlane && make rv32i_top` | Runs the complete OpenLane RTL-to-GDSII flow for the `rv32i_top` macro: synthesis → floorplanning → placement → CTS → routing → signoff (DRC + LVS). Produces `rv32i_top.gds` and `rv32i_top.lef`. |
| `cd openlane && make user_project_wrapper` | Runs the OpenLane flow for the Caravel wrapper, placing the hardened `rv32i_top` macro inside the wrapper die and routing all Caravel interface pins. Produces the final `user_project_wrapper.gds`. |
| `tail -f openlane/rv32i_top/runs/<tag>/openlane.log` | Live-monitors the OpenLane flow progress. Shows which step (synthesis, placement, routing, etc.) is currently executing. |

### Required Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `OPENLANE_ROOT` | `/run/media/durgesh/Code/vlsi_tools/OpenLane` | Path to the OpenLane installation |
| `PDK_ROOT` | `/run/media/durgesh/Code/vlsi_tools/pdks` | Path to the installed PDK |
| `PDK` | `sky130A` | Target PDK variant |
| `CARAVEL_ROOT` | `../caravel` | Path to the Caravel harness (relative to `openlane/`) |

---

## 7. Post-Layout Inspection

| Command | What It Does |
|---------|--------------|
| `klayout openlane/rv32i_top/runs/<tag>/results/final/gds/rv32i_top.gds` | Opens the final GDSII layout in KLayout for visual inspection of the placed standard cells, SRAM macros, and metal routing layers. |
| `cat openlane/rv32i_top/runs/<tag>/reports/manufacturability.rpt` | Displays the final manufacturability report including DRC violation count and LVS pass/fail status. |
| `cat openlane/rv32i_top/runs/<tag>/reports/signoff/34-rcx_sta.summary.rpt` | Shows the final Static Timing Analysis (STA) results: worst setup slack, worst hold slack, and total negative slack. |
| `cat openlane/rv32i_top/runs/<tag>/reports/metrics.csv` | Contains all numerical metrics from the run: cell count, area, wire length, power estimates, timing slack, and routing utilization percentages. |

---

## 8. Git Version Control

| Command | What It Does |
|---------|--------------|
| `git add -A && git commit -m "message"` | Stages all changes and creates a commit snapshot. |
| `git diff verilog/rtl/<file>.v` | Shows uncommitted changes to a specific RTL file, useful for reviewing edits before committing. |
| `git log --oneline -n 10` | Shows the last 10 commits in compact format. |

---

## 9. Cleanup

| Command | What It Does |
|---------|--------------|
| `cd verilog/dv && make -f Makefile_rv32 clean` | Removes all compiled simulation binaries (`.vvp`), waveforms (`.vcd`), hex files, and cloned test repos. |
