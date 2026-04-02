//-----------------------------------------------------------------------------
// Debug testbench for BEQ compliance test
// Traces PC and register state every cycle
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

`include "defines_riscv.v"

module tb_debug_beq;
    parameter TIMEOUT = 200;
    parameter MEM_SIZE = 4096;

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

    reg [31:0] mem [0:MEM_SIZE-1];

    // IMEM read (synchronous)
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

    // DMEM read (combinational)
    always @(*) begin
        if (dmem_en && !dmem_we)
            dmem_rdata = mem[dmem_addr[15:2]];
        else
            dmem_rdata = 32'b0;
    end

    always #5 clk = ~clk;

    integer cycle;

    initial begin
        $dumpfile("tb_debug_beq.vcd");
        $dumpvars(0, tb_debug_beq);

        clk = 0; rst_n = 0;

        // Load beq test
        $readmemh("firmware.hex", mem);

        #20; rst_n = 1;

        for (cycle = 0; cycle < TIMEOUT; cycle = cycle + 1) begin
            @(posedge clk);

            // Print IF stage PC, current instruction, gp value
            $display("C%0d: IF_PC=%08h  IMEM_ADDR=%08h  INSTR=%08h  gp(x3)=%08h  x1=%08h  x2=%08h  branch=%b  target=%08h",
                cycle,
                dut.u_if_stage.pc_q,
                imem_addr,
                dut.u_idex_stage.if_instr,
                dut.u_reg_file.regs[3],  // gp = TESTNUM
                dut.u_reg_file.regs[1],  // ra
                dut.u_reg_file.regs[2],  // sp
                dut.u_idex_stage.branch_taken,
                dut.u_idex_stage.branch_target
            );

            if (dmem_en && dmem_we && dmem_addr == 32'h0000_1000) begin
                $display("*** TOHOST written: %08h at cycle %0d", dmem_wdata, cycle);
                #20;
                $finish;
            end
        end

        $display("TIMEOUT after %0d cycles", TIMEOUT);
        $finish;
    end

endmodule
