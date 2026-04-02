//-----------------------------------------------------------------------------
// Testbench: tb_control
// Tests the instruction decoder for all RV32I instruction types.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

`include "defines_riscv.v"

module tb_control;

    reg  [31:0] instr;

    // Actual ports of control module
    wire [4:0]  rd_addr, rs1_addr, rs2_addr;
    wire [3:0]  alu_op;
    wire        alu_src;
    wire [31:0] imm;
    wire        mem_read_en, mem_write_en, mem_to_reg;
    wire [2:0]  mem_size;
    wire        branch_en, jump_en, jalr_en;
    wire        reg_write_en;

    control uut (
        .instr        (instr),
        .rs1_addr     (rs1_addr),
        .rs2_addr     (rs2_addr),
        .rd_addr      (rd_addr),
        .alu_op       (alu_op),
        .alu_src      (alu_src),
        .imm          (imm),
        .mem_read_en  (mem_read_en),
        .mem_write_en (mem_write_en),
        .mem_to_reg   (mem_to_reg),
        .mem_size     (mem_size),
        .branch_en    (branch_en),
        .jump_en      (jump_en),
        .jalr_en      (jalr_en),
        .reg_write_en (reg_write_en)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    task check_signal;
        input [31:0] got;
        input [31:0] expected;
        input [127:0] name;
        begin
            if (got !== expected) begin
                $display("  FAIL: %0s = %08h (expected %08h)", name, got, expected);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_control.vcd");
        $dumpvars(0, tb_control);

        $display("========================================");
        $display(" Control Unit Test");
        $display("========================================");

        // --- R-type: ADD x1, x2, x3 ---
        instr = {7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011}; #10;
        $display("-- ADD x1, x2, x3 --");
        check_signal({27'b0, rd_addr},  32'd1, "rd");
        check_signal({27'b0, rs1_addr}, 32'd2, "rs1");
        check_signal({27'b0, rs2_addr}, 32'd3, "rs2");
        check_signal({28'b0, alu_op}, {28'b0, `ALU_ADD}, "alu_op");
        check_signal({31'b0, alu_src},  32'd0, "alu_src (reg)");
        check_signal({31'b0, reg_write_en}, 32'd1, "reg_write");
        check_signal({31'b0, mem_write_en}, 32'd0, "mem_write");

        // --- R-type: SUB x4, x5, x6 ---
        instr = {7'b0100000, 5'd6, 5'd5, 3'b000, 5'd4, 7'b0110011}; #10;
        $display("-- SUB x4, x5, x6 --");
        check_signal({28'b0, alu_op}, {28'b0, `ALU_SUB}, "alu_op");
        check_signal({31'b0, reg_write_en}, 32'd1, "reg_write");

        // --- I-type: ADDI x7, x8, -5 ---
        instr = {12'hFFB, 5'd8, 3'b000, 5'd7, 7'b0010011}; #10;
        $display("-- ADDI x7, x8, -5 --");
        check_signal(imm, 32'hFFFF_FFFB, "imm (-5)");
        check_signal({31'b0, alu_src}, 32'd1, "alu_src (imm)");
        check_signal({28'b0, alu_op}, {28'b0, `ALU_ADD}, "alu_op");
        check_signal({31'b0, reg_write_en}, 32'd1, "reg_write");

        // --- S-type: SW x9, 16(x10) ---
        instr = {7'b0000000, 5'd9, 5'd10, 3'b010, 5'b10000, 7'b0100011}; #10;
        $display("-- SW x9, 16(x10) --");
        check_signal(imm, 32'h0000_0010, "imm (16)");
        check_signal({31'b0, mem_write_en}, 32'd1, "mem_write_en");
        check_signal({31'b0, reg_write_en}, 32'd0, "reg_write (off)");

        // --- LOAD: LW x11, 8(x12) ---
        instr = {12'h008, 5'd12, 3'b010, 5'd11, 7'b0000011}; #10;
        $display("-- LW x11, 8(x12) --");
        check_signal(imm, 32'h0000_0008, "imm (8)");
        check_signal({31'b0, mem_read_en}, 32'd1, "mem_read_en");
        check_signal({31'b0, mem_to_reg}, 32'd1, "mem_to_reg");
        check_signal({31'b0, reg_write_en}, 32'd1, "reg_write");

        // --- B-type: BEQ x1, x2, +8 ---
        instr = {1'b0, 6'b000000, 5'd2, 5'd1, 3'b000, 4'b0100, 1'b0, 7'b1100011}; #10;
        $display("-- BEQ x1, x2, +8 --");
        check_signal(imm, 32'h0000_0008, "imm (8)");
        check_signal({31'b0, branch_en}, 32'd1, "branch_en");
        check_signal({31'b0, reg_write_en}, 32'd0, "reg_write (off)");

        // --- U-type: LUI x13, 0xDEADB ---
        instr = {20'hDEADB, 5'd13, 7'b0110111}; #10;
        $display("-- LUI x13, 0xDEADB --");
        check_signal(imm, 32'hDEADB000, "imm (upper)");
        check_signal({31'b0, reg_write_en}, 32'd1, "reg_write");

        // --- J-type: JAL x15, +0 ---
        instr = {1'b0, 10'b0, 1'b0, 8'b0, 5'd15, 7'b1101111}; #10;
        $display("-- JAL x15 --");
        check_signal({31'b0, jump_en}, 32'd1, "jump_en");
        check_signal({31'b0, reg_write_en}, 32'd1, "reg_write");

        // --- JALR x14, x1, 100 ---
        instr = {12'd100, 5'd1, 3'b000, 5'd14, 7'b1100111}; #10;
        $display("-- JALR x14, x1, 100 --");
        check_signal(imm, 32'h0000_0064, "imm (100)");
        check_signal({31'b0, jump_en}, 32'd1, "jump_en");
        check_signal({31'b0, jalr_en}, 32'd1, "jalr_en");

        // --- AUIPC x16, 0x12345 ---
        instr = {20'h12345, 5'd16, 7'b0010111}; #10;
        $display("-- AUIPC x16, 0x12345 --");
        check_signal(imm, 32'h12345000, "imm (upper)");
        check_signal({31'b0, reg_write_en}, 32'd1, "reg_write");

        // --- Summary ---
        $display("========================================");
        $display(" Control: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("========================================");
        if (fail_count == 0) $display("*** ALL CONTROL TESTS PASSED ***");
        else $display("*** SOME CONTROL TESTS FAILED ***");
        $finish;
    end

endmodule
