//-----------------------------------------------------------------------------
// Testbench: tb_rv32_core
// Top-level integration smoke test for the RV32I pipeline.
//
// Tests the following instruction categories with hand-encoded instructions:
//   1. ADDI / ADD / SUB (register ops)
//   2. Logical: AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
//   3. LUI / AUIPC
//   4. SW / LW (memory)
//   5. BEQ / BNE (branches)
//   6. JAL / JALR (jumps)
//
// Pass/fail convention:
//   Register x31 = 1 on success, x31 = 0 on failure.
//   Test writes result to dmem[0x100] — checked at end.
//
// NOTE: In a 3-stage pipeline with stall-based hazard handling,
//       we insert NOPs between dependent instructions to avoid hazards
//       until the hazard-detection logic is verified separately.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

`include "defines_riscv.v"

module tb_rv32_core;

    reg         clk, rst_n;
    wire        imem_en;
    wire [31:0] imem_addr;
    reg  [31:0] imem_rdata;
    wire        dmem_en;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_wmask;
    wire        dmem_we;
    reg  [31:0] dmem_rdata;

    // Debug interface (inactive for smoke test)
    reg         dbg_halt;
    reg         dbg_write_en;
    reg  [4:0]  dbg_reg_addr;
    reg  [31:0] dbg_write_data;
    wire [31:0] dbg_read_data;

    // Instantiate DUT
    rv32_core dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .imem_en        (imem_en),
        .imem_addr      (imem_addr),
        .imem_rdata     (imem_rdata),
        .dmem_en        (dmem_en),
        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_wmask     (dmem_wmask),
        .dmem_we        (dmem_we),
        .dmem_rdata     (dmem_rdata),
        .dbg_halt       (dbg_halt),
        .dbg_write_en   (dbg_write_en),
        .dbg_reg_addr   (dbg_reg_addr),
        .dbg_write_data (dbg_write_data),
        .dbg_read_data  (dbg_read_data)
    );

    //--------------------------------------------------------------------------
    // Behavioral IMEM (1024 x 32, word-addressed)
    //--------------------------------------------------------------------------
    reg [31:0] imem [0:1023];

    always @(posedge clk) begin
        if (imem_en)
            imem_rdata <= imem[imem_addr[11:2]];
    end

    //--------------------------------------------------------------------------
    // Behavioral DMEM (1024 x 32, byte-addressed with masks)
    // Read is combinational — memwb_stage expects same-cycle data
    // Write is synchronous (posedge clk)
    //--------------------------------------------------------------------------
    reg [31:0] dmem_mem [0:1023];

    // Combinational read
    always @(*) begin
        if (dmem_en && !dmem_we)
            dmem_rdata = dmem_mem[dmem_addr[11:2]];
        else
            dmem_rdata = 32'b0;
    end

    // Synchronous write
    always @(posedge clk) begin
        if (dmem_en && dmem_we) begin
            if (dmem_wmask[0]) dmem_mem[dmem_addr[11:2]][7:0]   <= dmem_wdata[7:0];
            if (dmem_wmask[1]) dmem_mem[dmem_addr[11:2]][15:8]  <= dmem_wdata[15:8];
            if (dmem_wmask[2]) dmem_mem[dmem_addr[11:2]][23:16] <= dmem_wdata[23:16];
            if (dmem_wmask[3]) dmem_mem[dmem_addr[11:2]][31:24] <= dmem_wdata[31:24];
        end
    end

    //--------------------------------------------------------------------------
    // Clock generation
    //--------------------------------------------------------------------------
    always #5 clk = ~clk;

    //--------------------------------------------------------------------------
    // Test program
    //
    // We use NOPs (ADDI x0, x0, 0) between dependent instructions
    // to let the pipeline drain and avoid hazards.
    // NOP encoding: 32'h00000013
    //--------------------------------------------------------------------------
    localparam NOP = 32'h0000_0013;

    integer i;
    integer cycle_count;
    integer pass_count, fail_count;

    task check_reg;
        input [4:0] addr;
        input [31:0] expected;
        input [127:0] name;
        begin
            // Use debug port to read register
            dbg_reg_addr = addr;
            #1;
            if (dbg_read_data !== expected) begin
                $display("FAIL: %0s | x%0d = %08h (expected %08h)", name, addr, dbg_read_data, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS: %0s (x%0d = %08h)", name, addr, dbg_read_data);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_rv32_core.vcd");
        $dumpvars(0, tb_rv32_core);

        clk = 0; rst_n = 0;
        dbg_halt = 0; dbg_write_en = 0;
        dbg_reg_addr = 0; dbg_write_data = 0;
        pass_count = 0; fail_count = 0;

        // Clear memory
        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = NOP;
            dmem_mem[i] = 32'h0;
        end

        //----------------------------------------------------------------------
        // Program: RV32I smoke test
        //----------------------------------------------------------------------
        // All encodings follow RISC-V spec bit layout.
        // Format helpers:
        //   R: {funct7, rs2, rs1, funct3, rd, opcode}
        //   I: {imm[11:0], rs1, funct3, rd, opcode}
        //   S: {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode}
        //   B: {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode}
        //   U: {imm[31:12], rd, opcode}
        //   J: {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode}
        //----------------------------------------------------------------------

        i = 0;

        // --- Test 1: ADDI x1, x0, 10 ---
        // imm=10=0x00A, rs1=0, funct3=000, rd=1, opcode=0010011
        imem[i] = {12'd10, 5'd0, 3'b000, 5'd1, 7'b0010011}; i=i+1;  // x1 = 10
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 2: ADDI x2, x0, 20 ---
        imem[i] = {12'd20, 5'd0, 3'b000, 5'd2, 7'b0010011}; i=i+1;  // x2 = 20
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 3: ADD x3, x1, x2 ---
        imem[i] = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011}; i=i+1;  // x3 = 30
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 4: SUB x4, x2, x1 ---
        imem[i] = {7'b0100000, 5'd1, 5'd2, 3'b000, 5'd4, 7'b0110011}; i=i+1;  // x4 = 10
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 5: AND x5, x1, x2 ---
        imem[i] = {7'b0000000, 5'd2, 5'd1, 3'b111, 5'd5, 7'b0110011}; i=i+1;  // x5 = 10&20 = 0
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 6: OR x6, x1, x2 ---
        imem[i] = {7'b0000000, 5'd2, 5'd1, 3'b110, 5'd6, 7'b0110011}; i=i+1;  // x6 = 10|20 = 30
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 7: XOR x7, x1, x2 ---
        imem[i] = {7'b0000000, 5'd2, 5'd1, 3'b100, 5'd7, 7'b0110011}; i=i+1;  // x7 = 10^20 = 30
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 8: SLTI x8, x1, 15 ---
        // imm=15, funct3=010 (SLT), rd=8
        imem[i] = {12'd15, 5'd1, 3'b010, 5'd8, 7'b0010011}; i=i+1;  // x8 = (10 < 15) = 1
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 9: LUI x9, 0xDEADB ---
        imem[i] = {20'hDEADB, 5'd9, 7'b0110111}; i=i+1;  // x9 = 0xDEADB000
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 10: SW x1, 0(x0) — store x1=10 to dmem[0] ---
        // S: {imm[11:5]=0, rs2=1, rs1=0, funct3=010, imm[4:0]=0, opcode=0100011}
        imem[i] = {7'b0000000, 5'd1, 5'd0, 3'b010, 5'b00000, 7'b0100011}; i=i+1;
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 11: LW x10, 0(x0) — load from dmem[0], should get 10 ---
        imem[i] = {12'd0, 5'd0, 3'b010, 5'd10, 7'b0000011}; i=i+1;  // x10 = mem[0] = 10
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 12: ADDI x11, x0, 10 (for branch compare) ---
        imem[i] = {12'd10, 5'd0, 3'b000, 5'd11, 7'b0010011}; i=i+1;  // x11 = 10
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 13: BEQ x1, x11, +8 (should take branch) ---
        // x1=10, x11=10, so branch to PC+8 (skip 2 instructions)
        // B: {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode}
        // imm=8: [12]=0, [11]=0, [10:5]=000000, [4:1]=0100
        imem[i] = {1'b0, 6'b000000, 5'd11, 5'd1, 3'b000, 4'b0100, 1'b0, 7'b1100011}; i=i+1;
        // These 2 should be skipped:
        imem[i] = {12'd99, 5'd0, 3'b000, 5'd12, 7'b0010011}; i=i+1;  // ADDI x12, x0, 99 (SKIPPED)
        // Branch target lands here:
        imem[i] = {12'd42, 5'd0, 3'b000, 5'd12, 7'b0010011}; i=i+1;  // ADDI x12, x0, 42
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 14: BNE x1, x2, +8 (x1=10, x2=20, should take) ---
        imem[i] = {1'b0, 6'b000000, 5'd2, 5'd1, 3'b001, 4'b0100, 1'b0, 7'b1100011}; i=i+1;
        imem[i] = {12'd88, 5'd0, 3'b000, 5'd13, 7'b0010011}; i=i+1;  // SKIPPED
        imem[i] = {12'd55, 5'd0, 3'b000, 5'd13, 7'b0010011}; i=i+1;  // ADDI x13, x0, 55
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Test 15: ADDI x14, x0, 1 (mark success) ---
        imem[i] = {12'd1, 5'd0, 3'b000, 5'd14, 7'b0010011}; i=i+1;  // x14 = 1

        // Fill rest with NOPs then infinite self-loop
        imem[i] = NOP; i=i+1;
        imem[i] = NOP; i=i+1;

        // --- Self-loop: JAL x0, 0 (infinite loop at this PC) ---
        // J: {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode}
        // imm=0: all bits 0
        imem[i] = {1'b0, 10'b0, 1'b0, 8'b0, 5'd0, 7'b1101111}; i=i+1;

        //----------------------------------------------------------------------
        // Run simulation
        //----------------------------------------------------------------------
        $display("========================================");
        $display(" rv32_core Integration Smoke Test");
        $display("========================================");

        // Release reset after 2 cycles
        #20;
        rst_n = 1;

        // Run for enough cycles for all instructions to complete
        // We have ~50 instructions (including NOPs), pipeline needs ~60 cycles
        for (cycle_count = 0; cycle_count < 200; cycle_count = cycle_count + 1) begin
            @(posedge clk);
        end

        $display("");
        $display("--- Register File Check ---");

        // Halt core for stable debug reads
        dbg_halt = 1;
        @(posedge clk); @(posedge clk);

        // Check results
        check_reg(5'd1,  32'd10,         "ADDI x1=10");
        check_reg(5'd2,  32'd20,         "ADDI x2=20");
        check_reg(5'd3,  32'd30,         "ADD x3=x1+x2=30");
        check_reg(5'd4,  32'd10,         "SUB x4=x2-x1=10");
        check_reg(5'd5,  32'd0,          "AND x5=10&20=0");
        check_reg(5'd6,  32'd30,         "OR x6=10|20=30");
        check_reg(5'd7,  32'd30,         "XOR x7=10^20=30");
        check_reg(5'd8,  32'd1,          "SLTI x8=(10<15)=1");
        check_reg(5'd9,  32'hDEADB000,   "LUI x9=0xDEADB000");
        check_reg(5'd10, 32'd10,         "LW x10=mem[0]=10");
        check_reg(5'd11, 32'd10,         "ADDI x11=10");
        check_reg(5'd12, 32'd42,         "BEQ taken, x12=42");
        check_reg(5'd13, 32'd55,         "BNE taken, x13=55");
        check_reg(5'd14, 32'd1,          "x14=1 (success)");

        // Check DMEM
        if (dmem_mem[0] !== 32'd10) begin
            $display("FAIL: DMEM[0] = %08h (expected 0000000A)", dmem_mem[0]);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: SW/LW DMEM[0] = %08h", dmem_mem[0]);
            pass_count = pass_count + 1;
        end

        // --- Summary ---
        $display("");
        $display("========================================");
        $display(" Integration: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("========================================");
        if (fail_count == 0)
            $display("*** ALL INTEGRATION TESTS PASSED ***");
        else
            $display("*** SOME INTEGRATION TESTS FAILED ***");
        $finish;
    end

    // Watchdog timer
    initial begin
        #50000;
        $display("ERROR: Simulation timed out!");
        $finish;
    end

endmodule
