//-----------------------------------------------------------------------------
// Testbench: tb_alu
// Tests all 11 ALU operations with known input/output pairs.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

`include "defines_riscv.v"

module tb_alu;

    reg  [31:0] operand_a, operand_b;
    reg  [3:0]  alu_op;
    wire [31:0] result;
    wire        zero;

    alu uut (
        .operand_a (operand_a),
        .operand_b (operand_b),
        .alu_op    (alu_op),
        .result    (result),
        .zero_flag (zero)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    task check;
        input [31:0] expected;
        input [127:0] name;  // test name as packed string
        begin
            if (result !== expected) begin
                $display("FAIL: %0s | a=%08h b=%08h op=%0d => got %08h expected %08h",
                         name, operand_a, operand_b, alu_op, result, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS: %0s", name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        $display("========================================");
        $display(" ALU Unit Test");
        $display("========================================");

        // --- ADD ---
        operand_a = 32'h0000_000A; operand_b = 32'h0000_0005; alu_op = `ALU_ADD; #10;
        check(32'h0000_000F, "ADD basic");

        operand_a = 32'hFFFF_FFFF; operand_b = 32'h0000_0001; alu_op = `ALU_ADD; #10;
        check(32'h0000_0000, "ADD overflow");

        // --- SUB ---
        operand_a = 32'h0000_000A; operand_b = 32'h0000_0003; alu_op = `ALU_SUB; #10;
        check(32'h0000_0007, "SUB basic");

        operand_a = 32'h0000_0000; operand_b = 32'h0000_0001; alu_op = `ALU_SUB; #10;
        check(32'hFFFF_FFFF, "SUB underflow");

        // --- AND ---
        operand_a = 32'hFF00_FF00; operand_b = 32'h0F0F_0F0F; alu_op = `ALU_AND; #10;
        check(32'h0F00_0F00, "AND");

        // --- OR ---
        operand_a = 32'hFF00_0000; operand_b = 32'h00FF_0000; alu_op = `ALU_OR; #10;
        check(32'hFFFF_0000, "OR");

        // --- XOR ---
        operand_a = 32'hAAAA_AAAA; operand_b = 32'h5555_5555; alu_op = `ALU_XOR; #10;
        check(32'hFFFF_FFFF, "XOR");

        // --- SLL ---
        operand_a = 32'h0000_0001; operand_b = 32'h0000_001F; alu_op = `ALU_SLL; #10;
        check(32'h8000_0000, "SLL by 31");

        operand_a = 32'h0000_0001; operand_b = 32'h0000_0000; alu_op = `ALU_SLL; #10;
        check(32'h0000_0001, "SLL by 0");

        // --- SRL ---
        operand_a = 32'h8000_0000; operand_b = 32'h0000_001F; alu_op = `ALU_SRL; #10;
        check(32'h0000_0001, "SRL by 31");

        // --- SRA ---
        operand_a = 32'h8000_0000; operand_b = 32'h0000_0004; alu_op = `ALU_SRA; #10;
        check(32'hF800_0000, "SRA negative");

        operand_a = 32'h4000_0000; operand_b = 32'h0000_0004; alu_op = `ALU_SRA; #10;
        check(32'h0400_0000, "SRA positive");

        // --- SLT ---
        operand_a = 32'hFFFF_FFFF; operand_b = 32'h0000_0001; alu_op = `ALU_SLT; #10; // -1 < 1
        check(32'h0000_0001, "SLT signed true");

        operand_a = 32'h0000_0001; operand_b = 32'hFFFF_FFFF; alu_op = `ALU_SLT; #10; // 1 < -1
        check(32'h0000_0000, "SLT signed false");

        // --- SLTU ---
        operand_a = 32'h0000_0001; operand_b = 32'hFFFF_FFFF; alu_op = `ALU_SLTU; #10;
        check(32'h0000_0001, "SLTU true");

        operand_a = 32'hFFFF_FFFF; operand_b = 32'h0000_0001; alu_op = `ALU_SLTU; #10;
        check(32'h0000_0000, "SLTU false");

        // --- PASS_B ---
        operand_a = 32'hDEAD_BEEF; operand_b = 32'hCAFE_BABE; alu_op = `ALU_PASS_B; #10;
        check(32'hCAFE_BABE, "PASS_B");

        // --- Zero flag ---
        operand_a = 32'h0000_0005; operand_b = 32'h0000_0005; alu_op = `ALU_SUB; #10;
        if (zero !== 1'b1) begin
            $display("FAIL: Zero flag not set on 5-5");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: Zero flag on SUB equal");
            pass_count = pass_count + 1;
        end

        // --- Summary ---
        $display("========================================");
        $display(" ALU: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("========================================");
        if (fail_count == 0) $display("*** ALL ALU TESTS PASSED ***");
        else $display("*** SOME ALU TESTS FAILED ***");
        $finish;
    end

endmodule
