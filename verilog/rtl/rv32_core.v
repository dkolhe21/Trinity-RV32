//-----------------------------------------------------------------------------
// Module: rv32_core
// File:   rv32_core.v
// Project: RISC_CPU
//
// Description:
//   RV32I Core Top-Level Module
//   3-stage pipeline (IF, ID/EX, MEM/WB), in-order, no speculation.
//   This is the logical core-only module - no Caravel/padframe signals.
//   JTAG TAP, SRAM macros, BIST, and Caravel pads are handled in wrappers.
//
// Author: dkolhe21
// Date:   2026-02-01
//-----------------------------------------------------------------------------

`default_nettype none

module rv32_core (
    //--------------------------------------------------------------------------
    // Clock and Reset
    //--------------------------------------------------------------------------
    input  wire        clk,             // System clock (active high)
    input  wire        rst_n,           // Active-low synchronous reset

    //--------------------------------------------------------------------------
    // Instruction Memory Interface (IMEM)
    //--------------------------------------------------------------------------
    output wire        imem_en,         // Fetch enable
    output wire [31:0] imem_addr,       // Instruction address (word-aligned PC)
    input  wire [31:0] imem_rdata,      // Instruction word returned from IMEM

    //--------------------------------------------------------------------------
    // Data Memory Interface (DMEM)
    //--------------------------------------------------------------------------
    output wire        dmem_en,         // Data access enable
    output wire [31:0] dmem_addr,       // Data address (byte address)
    output wire [31:0] dmem_wdata,      // Data to write on stores
    output wire [3:0]  dmem_wmask,      // Byte write mask
    output wire        dmem_we,         // Write enable: 1=store, 0=load
    input  wire [31:0] dmem_rdata,      // Data returned on loads

    //--------------------------------------------------------------------------
    // Debug Interface (internal side of JTAG bridge)
    //--------------------------------------------------------------------------
    input  wire        dbg_halt,        // When high, core halts
    input  wire        dbg_write_en,    // Write to register file via debug
    input  wire [4:0]  dbg_reg_addr,    // Register index (0-31)
    input  wire [31:0] dbg_write_data,  // Data written to register
    output wire [31:0] dbg_read_data    // Data read from selected register
);

    //--------------------------------------------------------------------------
    // Internal Wires: IF → ID/EX
    //--------------------------------------------------------------------------
    wire [31:0] if_pc;
    wire [31:0] if_instr;
    wire        if_valid;

    //--------------------------------------------------------------------------
    // Internal Wires: ID/EX → MEM/WB
    //--------------------------------------------------------------------------
    wire [31:0] idex_alu_result;
    wire [31:0] idex_rs2_data;
    wire [4:0]  idex_rd_addr;
    wire        idex_reg_write_en;
    wire        idex_mem_read_en;
    wire        idex_mem_write_en;
    wire        idex_mem_to_reg;
    wire [2:0]  idex_mem_size;
    wire [31:0] idex_pc_plus4;
    wire        idex_jump_en;
    wire        idex_valid;

    //--------------------------------------------------------------------------
    // Internal Wires: MEM/WB → Register File
    //--------------------------------------------------------------------------
    wire [4:0]  wb_rd_addr;
    wire [31:0] wb_rd_data;
    wire        wb_rd_write_en;

    //--------------------------------------------------------------------------
    // Internal Wires: MEM/WB → ID/EX (hazard forwarding)
    //--------------------------------------------------------------------------
    wire [4:0]  wb_rd_addr_fwd;
    wire        wb_reg_write_en_fwd;
    wire        wb_mem_to_reg_fwd;

    //--------------------------------------------------------------------------
    // Internal Wires: Register File
    //--------------------------------------------------------------------------
    wire [4:0]  rf_rs1_addr;
    wire [4:0]  rf_rs2_addr;
    wire [31:0] rf_rs1_data;
    wire [31:0] rf_rs2_data;

    //--------------------------------------------------------------------------
    // Internal Wires: Pipeline Control
    //--------------------------------------------------------------------------
    wire        stall;
    wire        flush;
    wire        branch_taken;
    wire [31:0] branch_target;

    //==========================================================================
    // IF Stage
    //==========================================================================
    if_stage u_if_stage (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall         (stall),
        .flush         (flush),
        .branch_taken  (branch_taken),
        .branch_target (branch_target),
        .imem_en       (imem_en),
        .imem_addr     (imem_addr),
        .imem_rdata    (imem_rdata),
        .pc_out        (if_pc),
        .instr_out     (if_instr),
        .valid_out     (if_valid)
    );

    //==========================================================================
    // ID/EX Stage
    //==========================================================================
    idex_stage u_idex_stage (
        .clk               (clk),
        .rst_n             (rst_n),
        .stall_in          (dbg_halt),
        .if_pc             (if_pc),
        .if_instr          (if_instr),
        .if_valid          (if_valid),
        .rf_rs1_data       (rf_rs1_data),
        .rf_rs2_data       (rf_rs2_data),
        .memwb_rd_addr     (wb_rd_addr_fwd),
        .memwb_reg_write_en(wb_reg_write_en_fwd),
        .memwb_mem_to_reg  (wb_mem_to_reg_fwd),
        .memwb_rd_data     (wb_rd_data),
        .rs1_addr_out      (rf_rs1_addr),
        .rs2_addr_out      (rf_rs2_addr),
        .branch_taken      (branch_taken),
        .branch_target     (branch_target),
        .stall_out         (stall),
        .flush_out         (flush),
        .ex_alu_result     (idex_alu_result),
        .ex_rs2_data       (idex_rs2_data),
        .ex_rd_addr        (idex_rd_addr),
        .ex_reg_write_en   (idex_reg_write_en),
        .ex_mem_read_en    (idex_mem_read_en),
        .ex_mem_write_en   (idex_mem_write_en),
        .ex_mem_to_reg     (idex_mem_to_reg),
        .ex_mem_size       (idex_mem_size),
        .ex_pc_plus4       (idex_pc_plus4),
        .ex_jump_en        (idex_jump_en),
        .ex_valid          (idex_valid)
    );

    //==========================================================================
    // MEM/WB Stage
    //==========================================================================
    memwb_stage u_memwb_stage (
        .clk               (clk),
        .rst_n             (rst_n),
        .stall             (stall),
        .ex_alu_result     (idex_alu_result),
        .ex_rs2_data       (idex_rs2_data),
        .ex_rd_addr        (idex_rd_addr),
        .ex_reg_write_en   (idex_reg_write_en),
        .ex_mem_read_en    (idex_mem_read_en),
        .ex_mem_write_en   (idex_mem_write_en),
        .ex_mem_to_reg     (idex_mem_to_reg),
        .ex_mem_size       (idex_mem_size),
        .ex_pc_plus4       (idex_pc_plus4),
        .ex_jump_en        (idex_jump_en),
        .ex_valid          (idex_valid),
        .dmem_en           (dmem_en),
        .dmem_addr         (dmem_addr),
        .dmem_wdata        (dmem_wdata),
        .dmem_wmask        (dmem_wmask),
        .dmem_we           (dmem_we),
        .dmem_rdata        (dmem_rdata),
        .wb_rd_addr        (wb_rd_addr),
        .wb_rd_data        (wb_rd_data),
        .wb_rd_write_en    (wb_rd_write_en),
        .wb_rd_addr_fwd    (wb_rd_addr_fwd),
        .wb_reg_write_en_fwd(wb_reg_write_en_fwd),
        .wb_mem_to_reg_fwd (wb_mem_to_reg_fwd)
    );

    //==========================================================================
    // Register File
    //==========================================================================
    reg_file u_reg_file (
        .clk          (clk),
        .rst_n        (rst_n),
        .rs1_addr     (rf_rs1_addr),
        .rs2_addr     (rf_rs2_addr),
        .rs1_data     (rf_rs1_data),
        .rs2_data     (rf_rs2_data),
        .rd_addr      (wb_rd_addr),
        .rd_data      (wb_rd_data),
        .rd_write_en  (wb_rd_write_en),
        .dbg_addr     (dbg_reg_addr),
        .dbg_wdata    (dbg_write_data),
        .dbg_we       (dbg_write_en),
        .dbg_rdata    (dbg_read_data)
    );

endmodule

`default_nettype wire
