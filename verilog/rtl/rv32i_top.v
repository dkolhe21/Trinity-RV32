//-----------------------------------------------------------------------------
// Module: rv32i_top
// File:   rv32i_top.v
//
// Description:
//   Top-level module that wires together all RV32I CPU subsystems:
//     - rv32_core (3-stage pipeline)
//     - imem_wrapper (4KB instruction memory with BIST port)
//     - dmem_wrapper (4KB data memory with BIST port)
//     - jtag_tap (IEEE 1149.1 TAP controller)
//     - debug_module (JTAG-to-debug bridge)
//     - bist_ctrl (March C- memory self-test)
//
//   This module is instantiated by user_project_wrapper in the
//   Caravel integration.
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module rv32i_top (
    input  wire        clk,
    input  wire        rst_n,

    //--------------------------------------------------------------------------
    // JTAG pins (directly mapped to Caravel io_in/io_out)
    //--------------------------------------------------------------------------
    input  wire        jtag_tck,
    input  wire        jtag_tms,
    input  wire        jtag_tdi,
    output wire        jtag_tdo,
    input  wire        jtag_trst_n,

    //--------------------------------------------------------------------------
    // BIST external interface
    //--------------------------------------------------------------------------
    input  wire        bist_mode_ext,    // External BIST trigger
    output wire        bist_done_ext,    // BIST complete
    output wire        bist_pass_ext     // BIST result
);

    //==========================================================================
    // Internal wires: Core ↔ Memories
    //==========================================================================

    // Core → IMEM
    wire        core_imem_en;
    wire [31:0] core_imem_addr;
    wire [31:0] core_imem_rdata;

    // Core → DMEM
    wire        core_dmem_en;
    wire [31:0] core_dmem_addr;
    wire [31:0] core_dmem_wdata;
    wire [3:0]  core_dmem_wmask;
    wire        core_dmem_we;
    wire [31:0] core_dmem_rdata;

    //==========================================================================
    // Internal wires: Debug chain (JTAG → debug_module → core)
    //==========================================================================
    wire [31:0] jtag_dbg_data_out;
    wire        jtag_dbg_data_valid;
    wire [31:0] jtag_dbg_data_in;

    wire        dbg_halt;
    wire        dbg_write_en;
    wire [4:0]  dbg_reg_addr;
    wire [31:0] dbg_write_data;
    wire [31:0] dbg_read_data;

    //==========================================================================
    // Internal wires: BIST ↔ memories
    //==========================================================================
    wire        jtag_bist_start;
    wire        bist_start;
    wire        bist_done;
    wire        bist_pass;
    /* verilator lint_off UNUSEDSIGNAL */
    wire        imem_fail;
    wire        dmem_fail;
    /* verilator lint_on UNUSEDSIGNAL */

    wire        imem_bist_en;
    wire [8:0]  imem_bist_addr;
    wire [31:0] imem_bist_wdata;
    wire        imem_bist_we;
    wire [31:0] imem_bist_rdata;

    wire        dmem_bist_en;
    wire [8:0]  dmem_bist_addr;
    wire [31:0] dmem_bist_wdata;
    wire        dmem_bist_we;
    wire [31:0] dmem_bist_rdata;

    // BIST mode: either JTAG-triggered or external pin
    wire bist_active = bist_mode_ext | jtag_bist_start;

    // BIST start: combine external and JTAG triggers
    assign bist_start = bist_mode_ext | jtag_bist_start;

    // BIST outputs to external pins
    assign bist_done_ext = bist_done;
    assign bist_pass_ext = bist_pass;

    //==========================================================================
    // JTAG TAP Controller
    //==========================================================================
    jtag_tap u_jtag_tap (
        .tck            (jtag_tck),
        .tms            (jtag_tms),
        .tdi            (jtag_tdi),
        .tdo            (jtag_tdo),
        .trst_n         (jtag_trst_n),
        .dbg_data_out   (jtag_dbg_data_out),
        .dbg_data_in    (jtag_dbg_data_in),
        .dbg_data_valid (jtag_dbg_data_valid),
        .bist_start     (jtag_bist_start),
        .bist_done      (bist_done),
        .bist_pass      (bist_pass)
    );

    //==========================================================================
    // Debug Module (JTAG → Core bridge)
    //==========================================================================
    debug_module u_debug_module (
        .clk            (clk),
        .rst_n          (rst_n),
        .jtag_data      (jtag_dbg_data_out),
        .jtag_data_valid(jtag_dbg_data_valid),
        .jtag_rdata     (jtag_dbg_data_in),
        .dbg_halt       (dbg_halt),
        .dbg_write_en   (dbg_write_en),
        .dbg_reg_addr   (dbg_reg_addr),
        .dbg_write_data (dbg_write_data),
        .dbg_read_data  (dbg_read_data)
    );

    //==========================================================================
    // RV32I Core Pipeline
    //==========================================================================
    rv32_core u_rv32_core (
        .clk            (clk),
        .rst_n          (rst_n),
        // IMEM interface
        .imem_en        (core_imem_en),
        .imem_addr      (core_imem_addr),
        .imem_rdata     (core_imem_rdata),
        // DMEM interface
        .dmem_en        (core_dmem_en),
        .dmem_addr      (core_dmem_addr),
        .dmem_wdata     (core_dmem_wdata),
        .dmem_wmask     (core_dmem_wmask),
        .dmem_we        (core_dmem_we),
        .dmem_rdata     (core_dmem_rdata),
        // Debug interface
        .dbg_halt       (dbg_halt),
        .dbg_write_en   (dbg_write_en),
        .dbg_reg_addr   (dbg_reg_addr),
        .dbg_write_data (dbg_write_data),
        .dbg_read_data  (dbg_read_data)
    );

    //==========================================================================
    // Instruction Memory (4KB)
    //==========================================================================
    imem_wrapper #(
        .DEPTH     (512),
        .ADDR_BITS (9)
    ) u_imem (
        .clk        (clk),
        .rst_n      (rst_n),
        // Core fetch port
        .core_en    (core_imem_en),
        .core_addr  (core_imem_addr),
        .core_rdata (core_imem_rdata),
        // BIST port
        .bist_en    (imem_bist_en),
        .bist_addr  (imem_bist_addr),
        .bist_wdata (imem_bist_wdata),
        .bist_we    (imem_bist_we),
        .bist_rdata (imem_bist_rdata),
        // Mode select
        .bist_mode  (bist_active)
    );

    //==========================================================================
    // Data Memory (4KB)
    //==========================================================================
    dmem_wrapper #(
        .DEPTH     (512),
        .ADDR_BITS (9)
    ) u_dmem (
        .clk        (clk),
        .rst_n      (rst_n),
        // Core data port
        .core_en    (core_dmem_en),
        .core_addr  (core_dmem_addr),
        .core_wdata (core_dmem_wdata),
        .core_wmask (core_dmem_wmask),
        .core_we    (core_dmem_we),
        .core_rdata (core_dmem_rdata),
        // BIST port
        .bist_en    (dmem_bist_en),
        .bist_addr  (dmem_bist_addr),
        .bist_wdata (dmem_bist_wdata),
        .bist_we    (dmem_bist_we),
        .bist_rdata (dmem_bist_rdata),
        // Mode select
        .bist_mode  (bist_active)
    );

    //==========================================================================
    // BIST Controller
    //==========================================================================
    bist_ctrl #(
        .DEPTH     (512),
        .ADDR_BITS (9)
    ) u_bist_ctrl (
        .clk            (clk),
        .rst_n          (rst_n),
        .bist_start     (bist_start),
        .bist_done      (bist_done),
        .bist_pass      (bist_pass),
        .imem_fail      (imem_fail),
        .dmem_fail      (dmem_fail),
        // IMEM BIST port
        .imem_bist_en   (imem_bist_en),
        .imem_bist_addr (imem_bist_addr),
        .imem_bist_wdata(imem_bist_wdata),
        .imem_bist_we   (imem_bist_we),
        .imem_bist_rdata(imem_bist_rdata),
        // DMEM BIST port
        .dmem_bist_en   (dmem_bist_en),
        .dmem_bist_addr (dmem_bist_addr),
        .dmem_bist_wdata(dmem_bist_wdata),
        .dmem_bist_we   (dmem_bist_we),
        .dmem_bist_rdata(dmem_bist_rdata)
    );

endmodule

`default_nettype wire
