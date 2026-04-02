//-----------------------------------------------------------------------------
// File:   defines_riscv.v
//
// Description:
//   RV32I ISA constants: opcodes, funct3, funct7, ALU operation codes.
//   Uses `define macros for cross-module visibility during multi-file
//   compilation. Included via -I flag or `include.
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`ifndef DEFINES_RISCV_V
`define DEFINES_RISCV_V

//=============================================================================
// RV32I Opcodes (bits [6:0] of instruction)
//=============================================================================
`define OPC_LUI      7'b0110111
`define OPC_AUIPC    7'b0010111
`define OPC_JAL      7'b1101111
`define OPC_JALR     7'b1100111
`define OPC_BRANCH   7'b1100011
`define OPC_LOAD     7'b0000011
`define OPC_STORE    7'b0100011
`define OPC_OP_IMM   7'b0010011
`define OPC_OP       7'b0110011

//=============================================================================
// funct3 Encodings
//=============================================================================

// ALU R-type and I-type (funct3)
`define F3_ADD_SUB   3'b000
`define F3_SLL       3'b001
`define F3_SLT       3'b010
`define F3_SLTU      3'b011
`define F3_XOR       3'b100
`define F3_SRL_SRA   3'b101
`define F3_OR        3'b110
`define F3_AND       3'b111

// Branch (funct3)
`define F3_BEQ       3'b000
`define F3_BNE       3'b001
`define F3_BLT       3'b100
`define F3_BGE       3'b101
`define F3_BLTU      3'b110
`define F3_BGEU      3'b111

// Load/Store (funct3)
`define F3_LB_SB     3'b000
`define F3_LH_SH     3'b001
`define F3_LW_SW     3'b010
`define F3_LBU       3'b100
`define F3_LHU       3'b101

//=============================================================================
// funct7 Encodings
//=============================================================================
`define F7_NORMAL    7'b0000000
`define F7_ALT       7'b0100000

//=============================================================================
// ALU Operation Codes (internal, 4-bit)
//=============================================================================
`define ALU_ADD      4'd0
`define ALU_SUB      4'd1
`define ALU_AND      4'd2
`define ALU_OR       4'd3
`define ALU_XOR      4'd4
`define ALU_SLL      4'd5
`define ALU_SRL      4'd6
`define ALU_SRA      4'd7
`define ALU_SLT      4'd8
`define ALU_SLTU     4'd9
`define ALU_PASS_B   4'd10

`endif // DEFINES_RISCV_V
