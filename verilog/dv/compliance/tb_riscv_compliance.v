//-----------------------------------------------------------------------------
// Testbench: tb_riscv_compliance
// Generic testbench that loads a .hex file into IMEM and runs it.
// Passes when TOHOST (dmem address 0x1000) is written with value 1.
// Fails if TOHOST != 1 or if simulation times out.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

`include "defines_riscv.v"

module tb_riscv_compliance;

    parameter TIMEOUT = 100000;
    parameter MEM_SIZE = 4096;  // words

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
        .dbg_halt       (1'b0),
        .dbg_write_en   (1'b0),
        .dbg_reg_addr   (5'b0),
        .dbg_write_data (32'b0),
        .dbg_read_data  ()
    );

    // Unified memory (both IMEM and DMEM mapped to same array)
    reg [31:0] mem [0:MEM_SIZE-1];

    // IMEM read (synchronous — if_stage has pipeline register)
    always @(posedge clk) begin
        if (imem_en)
            imem_rdata <= mem[imem_addr[15:2]];
    end

    // DMEM write (synchronous)
    always @(posedge clk) begin
        if (dmem_en && dmem_we) begin
            if (dmem_wmask[0]) mem[dmem_addr[15:2]][7:0]   <= dmem_wdata[7:0];
            if (dmem_wmask[1]) mem[dmem_addr[15:2]][15:8]  <= dmem_wdata[15:8];
            if (dmem_wmask[2]) mem[dmem_addr[15:2]][23:16] <= dmem_wdata[23:16];
            if (dmem_wmask[3]) mem[dmem_addr[15:2]][31:24] <= dmem_wdata[31:24];
        end
    end

    // DMEM read (combinational — memwb_stage expects same-cycle data)
    always @(*) begin
        if (dmem_en && !dmem_we)
            dmem_rdata = mem[dmem_addr[15:2]];
        else
            dmem_rdata = 32'b0;
    end

    always #5 clk = ~clk;

    // TOHOST address (word address 0x1000 / byte addr 0x1000)
    localparam TOHOST_ADDR = 32'h0000_1000;

    integer cycle;
    reg test_done;
    reg [31:0] tohost_val;

    initial begin
        $dumpfile("tb_riscv_compliance.vcd");
        $dumpvars(0, tb_riscv_compliance);

        clk = 0; rst_n = 0; test_done = 0;

        // Load hex file specified by +firmware= plusarg
        $readmemh("firmware.hex", mem);

        #20; rst_n = 1;

        for (cycle = 0; cycle < TIMEOUT; cycle = cycle + 1) begin
            @(posedge clk); #1;

            // Monitor writes to TOHOST
            if (dmem_en && dmem_we && dmem_addr == TOHOST_ADDR) begin
                tohost_val = dmem_wdata;
                test_done = 1;
            end

            if (test_done) begin
                if (tohost_val == 32'h0000_0001) begin
                    $display("PASS: riscv-test completed successfully at cycle %0d", cycle);
                end else begin
                    $display("FAIL: riscv-test failed with TOHOST=%08h at cycle %0d", tohost_val, cycle);
                    // Extract test number: bits [31:1] give the failing test case
                    $display("  Failing test case: %0d", tohost_val >> 1);
                end
                $finish;
            end
        end

        $display("FAIL: Simulation timed out after %0d cycles", TIMEOUT);
        $display("  DEBUG: Stuck at PC=%08h, Instr=%08h", dut.if_pc, dut.if_instr);
        $finish;
    end

endmodule
