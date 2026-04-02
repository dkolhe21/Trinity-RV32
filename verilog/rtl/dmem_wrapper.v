//-----------------------------------------------------------------------------
// Module: dmem_wrapper
// File:   dmem_wrapper.v
//
// Description:
//   Data Memory (DMEM) wrapper using Sky130 OpenRAM SRAM macro.
//   - sky130_sram_2kbyte_1rw1r_32x512_8 (512 x 32-bit = 2 KB)
//   - Port 0 (RW): used for core load/store and BIST writes
//   - Port 1 (R-only): unused (active-low csb1 tied high = disabled)
//   - 4-bit byte write mask for SB/SH/SW
//   - Mux between core load/store and BIST access
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module dmem_wrapper #(
    parameter DEPTH     = 512,    // Number of 32-bit words
    parameter ADDR_BITS = 9       // log2(DEPTH)
) (
    input  wire        clk,
    input  wire        rst_n,

    // Core data port
    input  wire        core_en,              // Data access enable
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [31:0] core_addr,            // Byte address (bits [ADDR_BITS+1:2] used)
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire [31:0] core_wdata,           // Write data (already aligned)
    input  wire [3:0]  core_wmask,           // Byte write mask
    input  wire        core_we,              // Write enable
    output wire [31:0] core_rdata,           // Read data

    // BIST port
    input  wire        bist_en,              // BIST access enable
    input  wire [ADDR_BITS-1:0] bist_addr,   // BIST word address
    input  wire [31:0] bist_wdata,           // BIST write data
    input  wire        bist_we,              // BIST write enable
    output wire [31:0] bist_rdata,           // BIST read data

    // Mode select
    input  wire        bist_mode             // 0=core, 1=BIST
);

    //--------------------------------------------------------------------------
    // Address and control mux
    //--------------------------------------------------------------------------
    wire [ADDR_BITS-1:0] core_word_addr = core_addr[ADDR_BITS+1:2];

    wire [ADDR_BITS-1:0] addr_mux;
    wire                 en_mux;
    wire                 we_mux;
    wire [31:0]          wdata_mux;
    wire [3:0]           wmask_mux;

    assign addr_mux  = (bist_mode) ? bist_addr  : core_word_addr;
    assign en_mux    = (bist_mode) ? bist_en    : core_en;
    assign we_mux    = (bist_mode) ? bist_we    : core_we;
    assign wdata_mux = (bist_mode) ? bist_wdata : core_wdata;
    assign wmask_mux = (bist_mode) ? 4'b1111    : core_wmask;

    //--------------------------------------------------------------------------
    // Port 0 signals (RW)
    //--------------------------------------------------------------------------
    wire        p0_csb   = ~en_mux;              // active-low chip select
    wire        p0_web   = ~(en_mux & we_mux);   // active-low write enable
    wire [31:0] p0_dout;

    //--------------------------------------------------------------------------
    // Sky130 OpenRAM SRAM Macro
    //--------------------------------------------------------------------------
    sky130_sram_2kbyte_1rw1r_32x512_8 u_sram (
    `ifdef USE_POWER_PINS
        .vccd1  (vccd1),
        .vssd1  (vssd1),
    `endif
        // Port 0: RW (Core data / BIST)
        .clk0   (clk),
        .csb0   (p0_csb),
        .web0   (p0_web),
        .wmask0 (wmask_mux),
        .addr0  (addr_mux),
        .din0   (wdata_mux),
        .dout0  (p0_dout),
        // Port 1: R-only (unused, tie off)
        .clk1   (clk),
        .csb1   (1'b1),        // disabled
        .addr1  ({ADDR_BITS{1'b0}}),
        .dout1  ()             // unconnected
    );

    //--------------------------------------------------------------------------
    // Output routing
    //--------------------------------------------------------------------------
    assign core_rdata = p0_dout;
    assign bist_rdata = p0_dout;

endmodule

`default_nettype wire
