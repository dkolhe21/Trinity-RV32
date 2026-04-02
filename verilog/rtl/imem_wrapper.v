//-----------------------------------------------------------------------------
// Module: imem_wrapper
// File:   imem_wrapper.v
//
// Description:
//   Instruction Memory (IMEM) wrapper using Sky130 OpenRAM SRAM macro.
//   - sky130_sram_2kbyte_1rw1r_32x512_8 (512 x 32-bit = 2 KB)
//   - Port 0 (RW): used for BIST writes
//   - Port 1 (R-only): used for core instruction fetch
//   - Mux between core fetch and BIST access
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module imem_wrapper #(
    parameter DEPTH     = 512,    // Number of 32-bit words
    parameter ADDR_BITS = 9       // log2(DEPTH)
) (
    input  wire        clk,
    input  wire        rst_n,

    // Core fetch port
    input  wire        core_en,             // Fetch enable
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [31:0] core_addr,           // Byte address from core
    /* verilator lint_on UNUSEDSIGNAL */
    output wire [31:0] core_rdata,          // Instruction word out

    // BIST port
    input  wire        bist_en,             // BIST access enable
    input  wire [ADDR_BITS-1:0] bist_addr,  // BIST word address
    input  wire [31:0] bist_wdata,          // BIST write data
    input  wire        bist_we,             // BIST write enable
    output wire [31:0] bist_rdata,          // BIST read data

    // Mode select
    input  wire        bist_mode            // 0=core, 1=BIST
);

    //--------------------------------------------------------------------------
    // Address mux
    //--------------------------------------------------------------------------
    wire [ADDR_BITS-1:0] core_word_addr = core_addr[ADDR_BITS+1:2];

    // Port 0 (RW): Used by BIST for writes and reads
    wire        p0_csb   = ~(bist_mode & bist_en);     // active-low chip select
    wire        p0_web   = ~(bist_mode & bist_we);      // active-low write enable
    wire [3:0]  p0_wmask = 4'b1111;                     // BIST always writes full word
    wire [ADDR_BITS-1:0] p0_addr = bist_addr;
    wire [31:0] p0_din   = bist_wdata;
    wire [31:0] p0_dout;

    // Port 1 (R-only): Used by core for instruction fetch
    wire        p1_csb   = ~(~bist_mode & core_en);    // active-low chip select
    wire [ADDR_BITS-1:0] p1_addr = core_word_addr;
    wire [31:0] p1_dout;

    //--------------------------------------------------------------------------
    // Sky130 OpenRAM SRAM Macro
    //--------------------------------------------------------------------------
    sky130_sram_2kbyte_1rw1r_32x512_8 u_sram (
    `ifdef USE_POWER_PINS
        .vccd1  (vccd1),
        .vssd1  (vssd1),
    `endif
        // Port 0: RW (BIST)
        .clk0   (clk),
        .csb0   (p0_csb),
        .web0   (p0_web),
        .wmask0 (p0_wmask),
        .addr0  (p0_addr),
        .din0   (p0_din),
        .dout0  (p0_dout),
        // Port 1: R-only (Core fetch)
        .clk1   (clk),
        .csb1   (p1_csb),
        .addr1  (p1_addr),
        .dout1  (p1_dout)
    );

    //--------------------------------------------------------------------------
    // Output routing
    //--------------------------------------------------------------------------
    assign core_rdata = p1_dout;
    assign bist_rdata = p0_dout;

endmodule

`default_nettype wire
