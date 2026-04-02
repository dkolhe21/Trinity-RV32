//-----------------------------------------------------------------------------
// Testbench: tb_reg_file
// Tests register file: write/read, x0 hardwire, debug port priority, reset.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_reg_file;

    reg         clk, rst_n;
    reg  [4:0]  rs1_addr, rs2_addr, rd_addr;
    reg  [31:0] rd_data;
    reg         rd_write_en;
    wire [31:0] rs1_data, rs2_data;

    reg  [4:0]  dbg_addr;
    reg  [31:0] dbg_wdata;
    reg         dbg_we;
    wire [31:0] dbg_rdata;

    reg_file uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .rs1_addr     (rs1_addr),
        .rs2_addr     (rs2_addr),
        .rs1_data     (rs1_data),
        .rs2_data     (rs2_data),
        .rd_addr      (rd_addr),
        .rd_data      (rd_data),
        .rd_write_en  (rd_write_en),
        .dbg_addr     (dbg_addr),
        .dbg_wdata    (dbg_wdata),
        .dbg_we       (dbg_we),
        .dbg_rdata    (dbg_rdata)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    always #5 clk = ~clk;

    task check;
        input [31:0] got, expected;
        input [127:0] name;
        begin
            if (got !== expected) begin
                $display("FAIL: %0s = %08h (expected %08h)", name, got, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS: %0s", name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_reg_file.vcd");
        $dumpvars(0, tb_reg_file);

        $display("========================================");
        $display(" Register File Unit Test");
        $display("========================================");

        clk = 0; rst_n = 0;
        rs1_addr = 0; rs2_addr = 0;
        rd_addr = 0; rd_data = 0; rd_write_en = 0;
        dbg_addr = 0; dbg_wdata = 0; dbg_we = 0;

        // Reset
        #20; rst_n = 1; #10;

        // --- x0 always reads 0 ---
        rs1_addr = 0; #1;
        check(rs1_data, 32'h0, "x0 reads zero");

        // --- Write x0 should be ignored ---
        rd_addr = 0; rd_data = 32'hDEAD; rd_write_en = 1;
        @(posedge clk); #1;
        rd_write_en = 0;
        rs1_addr = 0; #1;
        check(rs1_data, 32'h0, "x0 stays zero after write");

        // --- Write x1 and read back ---
        rd_addr = 1; rd_data = 32'hCAFE_BABE; rd_write_en = 1;
        @(posedge clk); #1;
        rd_write_en = 0;
        rs1_addr = 1; #1;
        check(rs1_data, 32'hCAFE_BABE, "x1 write/read");

        // --- Write x2, read via rs2 ---
        rd_addr = 2; rd_data = 32'h1234_5678; rd_write_en = 1;
        @(posedge clk); #1;
        rd_write_en = 0;
        rs2_addr = 2; #1;
        check(rs2_data, 32'h1234_5678, "x2 write/read via rs2");

        // --- Dual read: x1 on rs1, x2 on rs2 simultaneously ---
        rs1_addr = 1; rs2_addr = 2; #1;
        check(rs1_data, 32'hCAFE_BABE, "dual read rs1=x1");
        check(rs2_data, 32'h1234_5678, "dual read rs2=x2");

        // --- Debug read ---
        dbg_addr = 1; #1;
        check(dbg_rdata, 32'hCAFE_BABE, "debug read x1");

        // --- Debug write (priority over pipeline) ---
        rd_addr = 3; rd_data = 32'hAAAA_AAAA; rd_write_en = 1;
        dbg_addr = 3; dbg_wdata = 32'hBBBB_BBBB; dbg_we = 1;
        @(posedge clk); #1;
        rd_write_en = 0; dbg_we = 0;
        rs1_addr = 3; #1;
        check(rs1_data, 32'hBBBB_BBBB, "debug write priority");

        // --- Write to high register x31 ---
        rd_addr = 31; rd_data = 32'hFFFF_0000; rd_write_en = 1;
        @(posedge clk); #1;
        rd_write_en = 0;
        rs1_addr = 31; #1;
        check(rs1_data, 32'hFFFF_0000, "x31 write/read");

        // --- Reset clears all ---
        rst_n = 0; @(posedge clk); #1; rst_n = 1; #1;
        rs1_addr = 1; rs2_addr = 31; #1;
        check(rs1_data, 32'h0, "x1 cleared after reset");
        check(rs2_data, 32'h0, "x31 cleared after reset");

        // --- Summary ---
        $display("========================================");
        $display(" RegFile: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("========================================");
        if (fail_count == 0) $display("*** ALL REGFILE TESTS PASSED ***");
        else $display("*** SOME REGFILE TESTS FAILED ***");
        $finish;
    end

endmodule
