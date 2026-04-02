//-----------------------------------------------------------------------------
// Debug testbench for add compliance test with forwarding trace
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

`include "defines_riscv.v"

module tb_debug_fwd;
    parameter TIMEOUT = 1000;
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

    always @(posedge clk) begin
        if (imem_en)
            imem_rdata <= mem[imem_addr[15:2]];
    end

    always @(posedge clk) begin
        if (dmem_en && dmem_we) begin
            if (dmem_wmask[0]) mem[dmem_addr[15:2]][7:0]   <= dmem_wdata[7:0];
            if (dmem_wmask[1]) mem[dmem_addr[15:2]][15:8]  <= dmem_wdata[15:8];
            if (dmem_wmask[2]) mem[dmem_addr[15:2]][23:16] <= dmem_wdata[23:16];
            if (dmem_wmask[3]) mem[dmem_addr[15:2]][31:24] <= dmem_wdata[31:24];
        end
    end

    always @(*) begin
        if (dmem_en && !dmem_we)
            dmem_rdata = mem[dmem_addr[15:2]];
        else
            dmem_rdata = 32'b0;
    end

    always #5 clk = ~clk;

    integer cycle;

    initial begin
        clk = 0; rst_n = 0;
        $readmemh("hex/rv32ui-p-lb.hex", mem);
        #20; rst_n = 1;

        for (cycle = 0; cycle < TIMEOUT; cycle = cycle + 1) begin
            @(posedge clk);
            #1; // Small delay to let combinational settle

            $display("C%0d: PC=%08h INSTR=%08h valid=%b | fwd_rs1=%b fwd_rs2=%b | rs1_rf=%08h rs2_rf=%08h rs1_fwd=%08h rs2_fwd=%08h | wb_en=%b wb_rd=%0d wb_data=%08h | gp=%08h",
                cycle,
                dut.u_idex_stage.if_pc,
                dut.u_idex_stage.if_instr,
                dut.u_idex_stage.if_valid,
                dut.u_idex_stage.fwd_rs1,
                dut.u_idex_stage.fwd_rs2,
                dut.u_idex_stage.rf_rs1_data,
                dut.u_idex_stage.rf_rs2_data,
                dut.u_idex_stage.rs1_data_fwd,
                dut.u_idex_stage.rs2_data_fwd,
                dut.u_idex_stage.memwb_reg_write_en,
                dut.u_idex_stage.memwb_rd_addr,
                dut.u_idex_stage.memwb_rd_data,
                dut.u_reg_file.regs[3]
            );

            if (dmem_en && dmem_we && dmem_addr == 32'h0000_1000) begin
                $display("*** TOHOST: %08h", dmem_wdata);
                #20; $finish;
            end
        end
        $display("TIMEOUT"); $finish;
    end
endmodule
