//-----------------------------------------------------------------------------
// Module: debug_module
// File:   debug_module.v
//
// Description:
//   JTAG-to-Debug bridge. Converts parallel data from JTAG TAP's
//   data register into debug interface signals for rv32_core.
//   Handles clock domain crossing from tck to clk with a simple
//   2-stage synchronizer.
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module debug_module (
    input  wire        clk,            // Core system clock
    input  wire        rst_n,          // Active-low synchronous reset

    // JTAG TAP interface (tck domain)
    input  wire [31:0] jtag_data,      // Parallel data shifted in from TAP
    input  wire        jtag_data_valid,// Pulse from TAP: data is ready
    output wire [31:0] jtag_rdata,     // Data to present to TAP for readback

    // Debug interface to rv32_core (clk domain)
    output reg         dbg_halt,       // Halt core (pipeline freezes)
    output reg         dbg_write_en,   // Write to register file
    output reg  [4:0]  dbg_reg_addr,   // Register index
    output reg  [31:0] dbg_write_data, // Data to write
    input  wire [31:0] dbg_read_data   // Data read from register
);

    //--------------------------------------------------------------------------
    // Debug command register format (shifted in via JTAG):
    //   [31]      = halt bit (1=halt, 0=resume)
    //   [30]      = write enable
    //   [29:25]   = register address (0-31)
    //   [24:0]    = reserved (write data uses separate shift)
    //
    // Simplified: We use the full 32 bits as:
    //   [31]      = halt
    //   [30]      = write_en
    //   [29:25]   = reg_addr[4:0]
    //   [24:0]    = write_data[24:0] (lower 25 bits)
    //
    // For full 32-bit write data, a two-step JTAG sequence is used.
    //--------------------------------------------------------------------------

    //--------------------------------------------------------------------------
    // Clock domain crossing: tck → clk (2-stage synchronizer for valid pulse)
    //--------------------------------------------------------------------------
    reg valid_sync1_q;
    reg valid_sync2_q;
    reg valid_sync3_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_sync1_q <= 1'b0;
            valid_sync2_q <= 1'b0;
            valid_sync3_q <= 1'b0;
        end else begin
            valid_sync1_q <= jtag_data_valid;
            valid_sync2_q <= valid_sync1_q;
            valid_sync3_q <= valid_sync2_q;
        end
    end

    // Rising edge detect on synchronized valid
    wire valid_pulse = valid_sync2_q && !valid_sync3_q;

    //--------------------------------------------------------------------------
    // Synchronized data capture
    //--------------------------------------------------------------------------
    reg [31:0] data_sync_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            data_sync_q <= 32'b0;
        end else if (valid_sync1_q && !valid_sync2_q) begin
            // Capture data when validity is crossing
            data_sync_q <= jtag_data;
        end
    end

    //--------------------------------------------------------------------------
    // Debug command processing
    //--------------------------------------------------------------------------
    // Two-step protocol state
    reg        data_phase_q;  // 0=command phase, 1=data phase

    always @(posedge clk) begin
        if (!rst_n) begin
            dbg_halt       <= 1'b0;
            dbg_write_en   <= 1'b0;
            dbg_reg_addr   <= 5'b0;
            dbg_write_data <= 32'b0;
            data_phase_q   <= 1'b0;
        end else begin
            // Default: clear one-cycle pulse
            dbg_write_en <= 1'b0;

            if (valid_pulse) begin
                if (!data_phase_q) begin
                    // Command phase
                    dbg_halt     <= data_sync_q[31];
                    if (data_sync_q[30]) begin
                        // Write requested → enter data phase
                        dbg_reg_addr <= data_sync_q[29:25];
                        data_phase_q <= 1'b1;
                    end
                end else begin
                    // Data phase: full 32-bit write data
                    dbg_write_data <= data_sync_q;
                    dbg_write_en   <= 1'b1;
                    data_phase_q   <= 1'b0;
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // Read data passthrough (combinational, from core to JTAG)
    //--------------------------------------------------------------------------
    assign jtag_rdata = dbg_read_data;

endmodule

`default_nettype wire
