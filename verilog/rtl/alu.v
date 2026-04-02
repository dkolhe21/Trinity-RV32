//-----------------------------------------------------------------------------
// Module: alu
// File:   alu.v
//
// Description:
//   RV32I Arithmetic Logic Unit. Pure combinational — no clock.
//   Supports all RV32I ALU operations: ADD, SUB, AND, OR, XOR,
//   SLL, SRL, SRA, SLT, SLTU, and PASS_B (for LUI).
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module alu (
    input  wire [31:0] operand_a,    // First operand  (rs1 or PC)
    input  wire [31:0] operand_b,    // Second operand (rs2 or immediate)
    input  wire [3:0]  alu_op,       // ALU operation select
    output reg  [31:0] result,       // ALU result
    output wire        zero_flag     // 1 when result == 0
);

    

    //--------------------------------------------------------------------------
    // Combinational ALU logic
    //--------------------------------------------------------------------------
    always @(*) begin
        // Default to prevent latches
        result = 32'b0;

        case (alu_op)
            `ALU_ADD:    result = operand_a + operand_b;
            `ALU_SUB:    result = operand_a - operand_b;
            `ALU_AND:    result = operand_a & operand_b;
            `ALU_OR:     result = operand_a | operand_b;
            `ALU_XOR:    result = operand_a ^ operand_b;
            `ALU_SLL:    result = operand_a << operand_b[4:0];
            `ALU_SRL:    result = operand_a >> operand_b[4:0];
            `ALU_SRA:    result = $signed(operand_a) >>> operand_b[4:0];
            `ALU_SLT:    result = {31'b0, ($signed(operand_a) < $signed(operand_b))};
            `ALU_SLTU:   result = {31'b0, (operand_a < operand_b)};
            `ALU_PASS_B: result = operand_b;
            default:    result = 32'b0;
        endcase
    end

    //--------------------------------------------------------------------------
    // Zero flag (combinational)
    //--------------------------------------------------------------------------
    assign zero_flag = (result == 32'b0);

endmodule

`default_nettype wire
