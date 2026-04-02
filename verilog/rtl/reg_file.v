//-----------------------------------------------------------------------------
// Module: reg_file
// File:   reg_file.v
//
// Description:
//   32x32-bit register file for RV32I.
//   - Two combinational read ports (rs1, rs2)
//   - One synchronous write port (rd)
//   - x0 hardwired to zero
//   - Debug port for JTAG register access
//   - Debug write takes priority over pipeline write
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module reg_file (
    input  wire        clk,
    input  wire        rst_n,

    // Read port 1
    input  wire [4:0]  rs1_addr,
    output wire [31:0] rs1_data,

    // Read port 2
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs2_data,

    // Write port (from pipeline writeback)
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    input  wire        rd_write_en,

    // Debug port (from JTAG debug module)
    input  wire [4:0]  dbg_addr,
    input  wire [31:0] dbg_wdata,
    input  wire        dbg_we,
    output wire [31:0] dbg_rdata
);

    //--------------------------------------------------------------------------
    // Register storage (x0 through x31)
    //--------------------------------------------------------------------------
    reg [31:0] regs [1:31];  // x1 to x31 (x0 is implicit zero)

    //--------------------------------------------------------------------------
    // Read ports (combinational) — x0 always returns 0
    //--------------------------------------------------------------------------
    assign rs1_data  = (rs1_addr == 5'b0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data  = (rs2_addr == 5'b0) ? 32'b0 : regs[rs2_addr];
    assign dbg_rdata = (dbg_addr == 5'b0) ? 32'b0 : regs[dbg_addr];

    //--------------------------------------------------------------------------
    // Write port (synchronous, posedge clk)
    // Debug write takes priority over pipeline write
    //--------------------------------------------------------------------------
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else begin
            // Debug write has priority
            if (dbg_we && (dbg_addr != 5'b0)) begin
                regs[dbg_addr] <= dbg_wdata;
            end else if (rd_write_en && (rd_addr != 5'b0)) begin
                regs[rd_addr] <= rd_data;
            end
        end
    end

endmodule

`default_nettype wire
