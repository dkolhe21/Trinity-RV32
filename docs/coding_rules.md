# Coding Rules

> **RISC_CPU** – RTL Coding Standards for Synthesis & Tapeout

---

## 1. Sequential Logic

All sequential (clocked) logic **MUST** follow this pattern:

```verilog
always @(posedge clk) begin
    if (!rst_n) begin
        // Reset values
        reg_q <= 1'b0;
    end else begin
        // Normal operation
        reg_q <= reg_d;
    end
end
```

### Rules:
- ✅ Use `always @(posedge clk)` — single clock edge only
- ✅ Use **non-blocking assignments** (`<=`) exclusively
- ✅ Include synchronous reset in every sequential block
- ❌ Never mix blocking and non-blocking in the same block

---

## 2. Combinational Logic

All combinational logic **MUST** follow this pattern:

```verilog
always @(*) begin
    // Default assignments first (avoid latches)
    result = 32'b0;
    
    // Conditional logic
    if (sel) begin
        result = data_a;
    end else begin
        result = data_b;
    end
end
```

### Rules:
- ✅ Use `always @(*)` for automatic sensitivity list
- ✅ Use **blocking assignments** (`=`) exclusively
- ✅ Assign default values at the start to prevent latches
- ❌ Never reference `clk` in combinational blocks

---

## 3. Prohibited Constructs

The following constructs are **FORBIDDEN** in synthesizable RTL:

| Construct | Reason |
|-----------|--------|
| `initial` blocks | Not synthesizable; simulation-only |
| `#` delays | Not synthesizable; causes simulation/synthesis mismatch |
| `force` / `release` | Not synthesizable; debug-only |
| `interface` | SystemVerilog; use explicit port lists |
| `class` | SystemVerilog OOP; not synthesizable |
| `package` | SystemVerilog; use `include or explicit parameters |

### ❌ Forbidden Examples:

```verilog
// DON'T: initial block
initial begin
    counter = 0;  // ❌ Use reset instead
end

// DON'T: delays
always @(posedge clk) begin
    #10 data_out <= data_in;  // ❌ Remove delay
end

// DON'T: force/release
force dut.internal_sig = 1'b1;  // ❌ Use proper control signals
```

---

## 4. Reset Specification

### Global Reset Signal: `rst_n`

| Property | Value |
|----------|-------|
| Name | `rst_n` |
| Polarity | **Active-low** |
| Type | **Synchronous** |
| Scope | Global (all modules) |

### Reset Template:

```verilog
module example (
    input  wire        clk,
    input  wire        rst_n,    // Active-low synchronous reset
    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out
);

always @(posedge clk) begin
    if (!rst_n) begin
        data_out <= 8'b0;
    end else begin
        data_out <= data_in;
    end
end

endmodule
```

---

## 5. Naming Conventions

### Signal Suffixes

| Suffix | Meaning | Example |
|--------|---------|---------|
| `_en` | Active-high enable | `write_en`, `fetch_en` |
| `_n` | Active-low signal | `rst_n`, `chip_sel_n`, `oe_n` |
| `_d` | Input to register (next state) | `count_d` |
| `_q` | Output of register (current state) | `count_q` |

### Module & Signal Names

| Category | Convention | Example |
|----------|------------|---------|
| Modules | `snake_case` | `alu_unit`, `reg_file`, `jtag_tap` |
| Signals | `snake_case` | `pc_next`, `mem_write_data` |
| Parameters | `UPPER_SNAKE_CASE` | `DATA_WIDTH`, `ADDR_BITS` |
| Localparams | `UPPER_SNAKE_CASE` | `STATE_IDLE`, `OPCODE_ADD` |

### Register Naming Pattern

```verilog
// Use _d for next-state, _q for current-state
wire [31:0] pc_d;    // Next PC value (combinational)
reg  [31:0] pc_q;    // Current PC value (registered)

always @(posedge clk) begin
    if (!rst_n)
        pc_q <= 32'b0;
    else
        pc_q <= pc_d;
end
```

---

## 6. Port Declaration Style

Use ANSI-style port declarations:

```verilog
module alu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [3:0]  alu_op,
    input  wire        alu_en,       // Active-high enable
    output reg  [31:0] result,
    output reg         zero_flag,
    output reg         overflow_n    // Active-low overflow
);
```

---

## 7. File Organization

### One Module Per File

- File name **MUST** match module name
- Example: `reg_file.v` contains `module reg_file`

### File Header Template

```verilog
//-----------------------------------------------------------------------------
// Module: <module_name>
// File:   <file_name>.v
// 
// Description:
//   <Brief description of module functionality>
//
// Author: <name>
// Date:   <YYYY-MM-DD>
//-----------------------------------------------------------------------------
```

---

## 8. Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                    CODING RULES SUMMARY                      │
├─────────────────────────────────────────────────────────────┤
│  SEQUENTIAL    │  always @(posedge clk) + <= only           │
│  COMBINATIONAL │  always @(*) + = only                      │
│  RESET         │  rst_n, active-low, synchronous            │
├─────────────────────────────────────────────────────────────┤
│  FORBIDDEN     │  initial, #delay, force/release            │
│                │  interface, class, package                 │
├─────────────────────────────────────────────────────────────┤
│  NAMING        │  _en = active-high enable                  │
│                │  _n  = active-low signal                   │
│                │  _d  = next state (input to FF)            │
│                │  _q  = current state (output of FF)        │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Linting & Verification

Before committing RTL:

1. **Verilator lint**: `verilator --lint-only -Wall <file>.v`
2. **sv2v conversion**: Ensure code converts cleanly if using any SV
3. **Synthesis check**: No latches, no undriven signals

---

*Last updated: 2026-02-01*
