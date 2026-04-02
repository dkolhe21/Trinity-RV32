//-----------------------------------------------------------------------------
// Module: jtag_tap
// File:   jtag_tap.v
//
// Description:
//   IEEE 1149.1 compliant JTAG TAP controller.
//   - 16-state TAP FSM
//   - 5-bit instruction register
//   - Shift register for serial TDI/TDO
//   - Supported instructions: BYPASS, IDCODE, DEBUG_ACCESS, BIST_CTRL
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module jtag_tap #(
    parameter IR_LEN    = 5,
    parameter ID_CODE   = 32'h00000001  // Placeholder ID code
) (
    // JTAG pins
    input  wire        tck,            // Test Clock
    input  wire        tms,            // Test Mode Select
    input  wire        tdi,            // Test Data In
    output reg         tdo,            // Test Data Out
    input  wire        trst_n,         // Test Reset (active-low)

    // Debug interface outputs (active in DEBUG_ACCESS instruction)
    output reg  [31:0] dbg_data_out,   // Parallel data shifted in
    input  wire [31:0] dbg_data_in,    // Parallel data to shift out
    output reg         dbg_data_valid, // Pulse: shift-in complete (Update-DR)

    // BIST control outputs (active in BIST_CTRL instruction)
    output reg         bist_start,     // Start BIST
    input  wire        bist_done,      // BIST complete
    input  wire        bist_pass       // BIST result
);

    //--------------------------------------------------------------------------
    // TAP FSM States
    //--------------------------------------------------------------------------
    localparam [3:0] TLR         = 4'd0;   // Test-Logic-Reset
    localparam [3:0] RTI         = 4'd1;   // Run-Test/Idle
    localparam [3:0] SEL_DR      = 4'd2;   // Select-DR-Scan
    localparam [3:0] CAP_DR      = 4'd3;   // Capture-DR
    localparam [3:0] SHIFT_DR    = 4'd4;   // Shift-DR
    localparam [3:0] EXIT1_DR    = 4'd5;   // Exit1-DR
    localparam [3:0] PAUSE_DR    = 4'd6;   // Pause-DR
    localparam [3:0] EXIT2_DR    = 4'd7;   // Exit2-DR
    localparam [3:0] UPDATE_DR   = 4'd8;   // Update-DR
    localparam [3:0] SEL_IR      = 4'd9;   // Select-IR-Scan
    localparam [3:0] CAP_IR      = 4'd10;  // Capture-IR
    localparam [3:0] SHIFT_IR    = 4'd11;  // Shift-IR
    localparam [3:0] EXIT1_IR    = 4'd12;  // Exit1-IR
    localparam [3:0] PAUSE_IR    = 4'd13;  // Pause-IR
    localparam [3:0] EXIT2_IR    = 4'd14;  // Exit2-IR
    localparam [3:0] UPDATE_IR   = 4'd15;  // Update-IR

    //--------------------------------------------------------------------------
    // JTAG Instruction encodings
    //--------------------------------------------------------------------------
    localparam [IR_LEN-1:0] INSTR_BYPASS       = 5'b11111;
    localparam [IR_LEN-1:0] INSTR_IDCODE       = 5'b00001;
    localparam [IR_LEN-1:0] INSTR_DEBUG_ACCESS = 5'b00010;
    localparam [IR_LEN-1:0] INSTR_BIST_CTRL   = 5'b00100;

    //--------------------------------------------------------------------------
    // TAP FSM
    //--------------------------------------------------------------------------
    reg [3:0] state_q;

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            state_q <= TLR;
        end else begin
            case (state_q)
                TLR:       state_q <= (tms) ? TLR      : RTI;
                RTI:       state_q <= (tms) ? SEL_DR   : RTI;
                SEL_DR:    state_q <= (tms) ? SEL_IR   : CAP_DR;
                CAP_DR:    state_q <= (tms) ? EXIT1_DR : SHIFT_DR;
                SHIFT_DR:  state_q <= (tms) ? EXIT1_DR : SHIFT_DR;
                EXIT1_DR:  state_q <= (tms) ? UPDATE_DR: PAUSE_DR;
                PAUSE_DR:  state_q <= (tms) ? EXIT2_DR : PAUSE_DR;
                EXIT2_DR:  state_q <= (tms) ? UPDATE_DR: SHIFT_DR;
                UPDATE_DR: state_q <= (tms) ? SEL_DR   : RTI;
                SEL_IR:    state_q <= (tms) ? TLR      : CAP_IR;
                CAP_IR:    state_q <= (tms) ? EXIT1_IR : SHIFT_IR;
                SHIFT_IR:  state_q <= (tms) ? EXIT1_IR : SHIFT_IR;
                EXIT1_IR:  state_q <= (tms) ? UPDATE_IR: PAUSE_IR;
                PAUSE_IR:  state_q <= (tms) ? EXIT2_IR : PAUSE_IR;
                EXIT2_IR:  state_q <= (tms) ? UPDATE_IR: SHIFT_IR;
                UPDATE_IR: state_q <= (tms) ? SEL_DR   : RTI;
                default:   state_q <= TLR;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Instruction Register
    //--------------------------------------------------------------------------
    reg [IR_LEN-1:0] ir_shift_q;
    reg [IR_LEN-1:0] ir_q;

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            ir_shift_q <= {IR_LEN{1'b0}};
            ir_q       <= INSTR_IDCODE;  // Default instruction per IEEE 1149.1
        end else begin
            case (state_q)
                CAP_IR:    ir_shift_q <= ir_q;
                SHIFT_IR:  ir_shift_q <= {tdi, ir_shift_q[IR_LEN-1:1]};
                UPDATE_IR: ir_q       <= ir_shift_q;
                default: begin
                    ir_shift_q <= ir_shift_q;
                    ir_q       <= ir_q;
                end
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Data Register (32-bit) and Bypass Register (1-bit)
    //--------------------------------------------------------------------------
    reg [31:0] dr_shift_q;
    reg        bypass_q;

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dr_shift_q <= 32'b0;
            bypass_q   <= 1'b0;
        end else begin
            case (state_q)
                CAP_DR: begin
                    case (ir_q)
                        INSTR_IDCODE:       dr_shift_q <= ID_CODE;
                        INSTR_DEBUG_ACCESS: dr_shift_q <= dbg_data_in;
                        INSTR_BIST_CTRL:    dr_shift_q <= {30'b0, bist_pass, bist_done};
                        default:            dr_shift_q <= 32'b0;
                    endcase
                    bypass_q <= 1'b0;
                end
                SHIFT_DR: begin
                    if (ir_q == INSTR_BYPASS) begin
                        bypass_q <= tdi;
                    end else begin
                        dr_shift_q <= {tdi, dr_shift_q[31:1]};
                    end
                end
                default: begin
                    dr_shift_q <= dr_shift_q;
                    bypass_q   <= bypass_q;
                end
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Update-DR actions
    //--------------------------------------------------------------------------
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dbg_data_out   <= 32'b0;
            dbg_data_valid <= 1'b0;
            bist_start     <= 1'b0;
        end else begin
            dbg_data_valid <= 1'b0;
            bist_start     <= 1'b0;

            if (state_q == UPDATE_DR) begin
                case (ir_q)
                    INSTR_DEBUG_ACCESS: begin
                        dbg_data_out   <= dr_shift_q;
                        dbg_data_valid <= 1'b1;
                    end
                    INSTR_BIST_CTRL: begin
                        bist_start <= dr_shift_q[0];
                    end
                    default: begin
                        dbg_data_out   <= dbg_data_out;
                        dbg_data_valid <= 1'b0;
                    end
                endcase
            end
        end
    end

    //--------------------------------------------------------------------------
    // TDO output mux (active only during Shift-DR/IR, latched on negedge tck)
    //--------------------------------------------------------------------------
    reg tdo_d;

    always @(*) begin
        tdo_d = 1'b0;
        case (state_q)
            SHIFT_IR: tdo_d = ir_shift_q[0];
            SHIFT_DR: begin
                if (ir_q == INSTR_BYPASS)
                    tdo_d = bypass_q;
                else
                    tdo_d = dr_shift_q[0];
            end
            default: tdo_d = 1'b0;
        endcase
    end

    always @(negedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tdo <= 1'b0;
        end else begin
            tdo <= tdo_d;
        end
    end

endmodule

`default_nettype wire
