// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user project.
 *
 * An example user project is provided in this wrapper.  The
 * example should be removed and replaced with the actual
 * user project.
 *
 *-------------------------------------------------------------
 */

/* verilator lint_off UNUSEDPARAM */
module user_project_wrapper #(
    parameter BITS = 32
) (
/* verilator lint_off UNUSEDSIGNAL */
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // Analog (direct connection to GPIO pad---use with caution)
    // Note that analog I/O is not available on the 7 lowest-numbered
    // GPIO pads, and so the analog_io indexing is offset from the
    // GPIO indexing by 7 (also upper 2 GPIOs do not have analog_io).
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on UNUSEDPARAM */

/*--------------------------------------*/
/* RV32I CPU instantiated here          */
/*--------------------------------------*/

// Tie off unused Wishbone slave
assign wbs_ack_o = 1'b0;
assign wbs_dat_o = 32'b0;

// Tie off unused Logic Analyzer
assign la_data_out = 128'b0;

// Tie off unused interrupts
assign user_irq = 3'b0;

// IO output-enable bars (active-low: 0=output, 1=input)
// io[0..2,4,5] = inputs  (tck, tms, tdi, trst_n, bist_mode)
// io[3,6,7]    = outputs (tdo, bist_done, bist_pass)
// All other IOs: high-impedance (oeb=1)
assign io_oeb[0]  = 1'b1;   // tck      — input
assign io_oeb[1]  = 1'b1;   // tms      — input
assign io_oeb[2]  = 1'b1;   // tdi      — input
assign io_oeb[3]  = 1'b0;   // tdo      — output
assign io_oeb[4]  = 1'b1;   // trst_n   — input
assign io_oeb[5]  = 1'b1;   // bist_mode— input
assign io_oeb[6]  = 1'b0;   // bist_done— output
assign io_oeb[7]  = 1'b0;   // bist_pass— output

// Unused IO pads: tristate
genvar _io;
generate
    for (_io = 8; _io < `MPRJ_IO_PADS; _io = _io + 1) begin : unused_io
        assign io_oeb[_io] = 1'b1;
        assign io_out[_io] = 1'b0;
    end
endgenerate

// Unused io_out for input-only pins
assign io_out[0] = 1'b0;
assign io_out[1] = 1'b0;
assign io_out[2] = 1'b0;
assign io_out[4] = 1'b0;
assign io_out[5] = 1'b0;

// Active-high Caravel reset → active-low CPU reset
wire rst_n_wire;
assign rst_n_wire = ~wb_rst_i;

rv32i_top u_rv32i_top (
    .clk            (wb_clk_i),
    .rst_n          (rst_n_wire),

    // JTAG pins
    .jtag_tck       (io_in[0]),
    .jtag_tms       (io_in[1]),
    .jtag_tdi       (io_in[2]),
    .jtag_tdo       (io_out[3]),
    .jtag_trst_n    (io_in[4]),

    // BIST interface
    .bist_mode_ext  (io_in[5]),
    .bist_done_ext  (io_out[6]),
    .bist_pass_ext  (io_out[7])
);

endmodule	// user_project_wrapper

`default_nettype wire

