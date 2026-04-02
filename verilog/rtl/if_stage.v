//-----------------------------------------------------------------------------
// Module: if_stage
// File:   if_stage.v
//
// Description:
//   Instruction Fetch stage for 3-stage RV32I pipeline.
//   Maintains the Program Counter (PC) and drives IMEM interface.
//   Supports stall (hold PC), flush (invalidate), and branch/jump
//   target redirection.
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module if_stage (
    input  wire        clk,
    input  wire        rst_n,

    // Pipeline control
    input  wire        stall,          // Hold PC, don't advance
    input  wire        flush,          // Invalidate fetched instruction

    // Branch/Jump redirect
    input  wire        branch_taken,   // Branch or jump resolved as taken
    input  wire [31:0] branch_target,  // Target address for branch/jump

    // IMEM interface
    output wire        imem_en,        // Fetch enable
    output wire [31:0] imem_addr,      // Instruction address (PC)
    input  wire [31:0] imem_rdata,     // Fetched instruction word

    // Outputs to ID/EX stage
    output reg  [31:0] pc_out,         // PC of fetched instruction
    output reg  [31:0] instr_out,      // Fetched instruction
    output reg         valid_out       // 1 = instruction is valid
);

    //--------------------------------------------------------------------------
    // PC Register (_d / _q pattern)
    //--------------------------------------------------------------------------
    reg  [31:0] pc_q;       // Current PC (registered)
    reg  [31:0] pc_q_prev;  // Previous PC (for alignment with synchronous IMEM)
    reg         flush_q;    // Flush extension
    wire [31:0] pc_d;       // Next PC (combinational)

    // Next PC logic
    assign pc_d = (branch_taken) ? branch_target :
                  (stall)        ? pc_q :
                                   pc_q + 32'd4;

    // PC register update
    always @(posedge clk) begin
        if (!rst_n) begin
            pc_q      <= 32'b0;
            pc_q_prev <= 32'b0;
            flush_q   <= 1'b0;
        end else begin
            flush_q <= flush;
            if (!stall) begin
                 pc_q <= pc_d;
                 if (branch_taken)
                     pc_q_prev <= branch_target;
                 else
                     pc_q_prev <= pc_q;
            end
        end
    end

    //--------------------------------------------------------------------------
    // IMEM fetch signals
    //--------------------------------------------------------------------------
    assign imem_en   = ~stall;       // Don't fetch during stall
    assign imem_addr = pc_q;         // Current PC drives IMEM address

    //--------------------------------------------------------------------------
    // IF/ID pipeline register
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            pc_out    <= 32'b0;
            instr_out <= 32'b0;
            valid_out <= 1'b0;
        end else if (flush || flush_q) begin
            // Branch/jump taken — invalidate this instruction (2 cycle penalty)
            pc_out    <= 32'b0;
            instr_out <= 32'h00000013;  // NOP (ADDI x0, x0, 0)
            valid_out <= 1'b0;
        end else if (stall) begin
            // Hold current values
            pc_out    <= pc_out;
            instr_out <= instr_out;
            valid_out <= valid_out;
        end else begin
            // Normal fetch
            pc_out    <= pc_q_prev;
            instr_out <= imem_rdata;
            valid_out <= 1'b1;
        end
    end

endmodule

`default_nettype wire
