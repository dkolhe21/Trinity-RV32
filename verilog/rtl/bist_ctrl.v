//-----------------------------------------------------------------------------
// Module: bist_ctrl
// File:   bist_ctrl.v
//
// Description:
//   March C- BIST controller for IMEM and DMEM testing.
//   Runs 6 march elements to detect stuck-at and coupling faults.
//
//   Memory interface outputs are driven combinationally from FSM state
//   so writes/reads take effect on the current clock edge.
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module bist_ctrl #(
    parameter DEPTH     = 1024,
    parameter ADDR_BITS = 10
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        bist_start,
    output reg         bist_done,
    output reg         bist_pass,
    output reg         imem_fail,
    output reg         dmem_fail,

    // IMEM BIST port
    output wire                 imem_bist_en,
    output wire [ADDR_BITS-1:0] imem_bist_addr,
    output wire [31:0]          imem_bist_wdata,
    output wire                 imem_bist_we,
    input  wire [31:0]          imem_bist_rdata,

    // DMEM BIST port
    output wire                 dmem_bist_en,
    output wire [ADDR_BITS-1:0] dmem_bist_addr,
    output wire [31:0]          dmem_bist_wdata,
    output wire                 dmem_bist_we,
    input  wire [31:0]          dmem_bist_rdata
);

    //--------------------------------------------------------------------------
    // FSM States
    //--------------------------------------------------------------------------
    localparam [3:0] ST_IDLE       = 4'd0;
    localparam [3:0] ST_WRITE_UP   = 4'd1;   // M1: w(bg) ascending
    localparam [3:0] ST_RW_UP_RD   = 4'd2;   // M2/3: issue read ascending
    localparam [3:0] ST_RW_UP_WAIT = 4'd3;   // M2/3: wait for read data
    localparam [3:0] ST_RW_UP_WR   = 4'd4;   // M2/3: check & write inverse
    localparam [3:0] ST_RW_DN_RD   = 4'd5;   // M4/5: issue read descending
    localparam [3:0] ST_RW_DN_WAIT = 4'd6;   // M4/5: wait for read data
    localparam [3:0] ST_RW_DN_WR   = 4'd7;   // M4/5: check & write inverse
    localparam [3:0] ST_FINAL_RD   = 4'd8;   // M6: issue read ascending
    localparam [3:0] ST_FINAL_WAIT = 4'd9;   // M6: wait for read data
    localparam [3:0] ST_FINAL_CHK  = 4'd10;  // M6: check read data
    localparam [3:0] ST_DONE       = 4'd11;

    reg [3:0] state_q;

    //--------------------------------------------------------------------------
    // Control registers
    //--------------------------------------------------------------------------
    reg [ADDR_BITS-1:0] addr_q;
    reg                 mem_sel_q;      // 0=IMEM, 1=DMEM
    reg                 fail_flag_q;
    reg                 march_odd_q;    // 0=march2/4 (expect 0), 1=march3/5 (expect 1)

    localparam [ADDR_BITS-1:0] ADDR_MAX = DEPTH[ADDR_BITS-1:0] - 1'b1;

    wire [31:0] pattern_zero = 32'h00000000;
    wire [31:0] pattern_one  = 32'hFFFFFFFF;

    // Expected pattern depends on march phase
    wire [31:0] expect_val = march_odd_q ? pattern_one : pattern_zero;
    wire [31:0] write_val  = march_odd_q ? pattern_zero : pattern_one;

    wire [31:0] current_rdata = mem_sel_q ? dmem_bist_rdata : imem_bist_rdata;

    //--------------------------------------------------------------------------
    // Combinational memory bus outputs
    // Drive based on current FSM state so memory sees correct values
    // on the same clock edge.
    //--------------------------------------------------------------------------
    reg                 mem_en_comb;
    reg [ADDR_BITS-1:0] mem_addr_comb;
    reg [31:0]          mem_wdata_comb;
    reg                 mem_we_comb;

    always @(*) begin
        mem_en_comb    = 1'b0;
        mem_addr_comb  = addr_q;
        mem_wdata_comb = 32'b0;
        mem_we_comb    = 1'b0;

        case (state_q)
            ST_WRITE_UP: begin
                mem_en_comb    = 1'b1;
                mem_addr_comb  = addr_q;
                mem_wdata_comb = pattern_zero;
                mem_we_comb    = 1'b1;
            end
            ST_RW_UP_RD, ST_RW_DN_RD, ST_FINAL_RD: begin
                mem_en_comb   = 1'b1;
                mem_addr_comb = addr_q;
                mem_we_comb   = 1'b0;
            end
            ST_RW_UP_WR, ST_RW_DN_WR: begin
                mem_en_comb    = 1'b1;
                mem_addr_comb  = addr_q;
                mem_wdata_comb = write_val;
                mem_we_comb    = 1'b1;
            end
            default: begin
                mem_en_comb = 1'b0;
            end
        endcase
    end

    // Route to correct memory based on mem_sel_q
    assign imem_bist_en    = mem_en_comb & ~mem_sel_q;
    assign imem_bist_addr  = mem_addr_comb;
    assign imem_bist_wdata = mem_wdata_comb;
    assign imem_bist_we    = mem_we_comb & ~mem_sel_q;

    assign dmem_bist_en    = mem_en_comb & mem_sel_q;
    assign dmem_bist_addr  = mem_addr_comb;
    assign dmem_bist_wdata = mem_wdata_comb;
    assign dmem_bist_we    = mem_we_comb & mem_sel_q;

    //--------------------------------------------------------------------------
    // FSM (only updates internal state, no output driving)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state_q     <= ST_IDLE;
            addr_q      <= {ADDR_BITS{1'b0}};
            mem_sel_q   <= 1'b0;
            fail_flag_q <= 1'b0;
            march_odd_q <= 1'b0;
            bist_done   <= 1'b0;
            bist_pass   <= 1'b0;
            imem_fail   <= 1'b0;
            dmem_fail   <= 1'b0;
        end else begin

            case (state_q)
                //--------------------------------------------------------------
                ST_IDLE: begin
                    bist_done <= 1'b0;
                    if (bist_start) begin
                        state_q     <= ST_WRITE_UP;
                        addr_q      <= {ADDR_BITS{1'b0}};
                        mem_sel_q   <= 1'b0;
                        fail_flag_q <= 1'b0;
                        march_odd_q <= 1'b0;
                        imem_fail   <= 1'b0;
                        dmem_fail   <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                // M1: ⇑ w(0)
                //--------------------------------------------------------------
                ST_WRITE_UP: begin
                    // Write is driven combinationally above
                    if (addr_q == ADDR_MAX) begin
                        addr_q      <= {ADDR_BITS{1'b0}};
                        march_odd_q <= 1'b0;
                        state_q     <= ST_RW_UP_RD;
                    end else begin
                        addr_q <= addr_q + 1'b1;
                    end
                end

                //--------------------------------------------------------------
                // M2/3: ⇑ r(x),w(~x) — issue read
                //--------------------------------------------------------------
                ST_RW_UP_RD: begin
                    state_q <= ST_RW_UP_WAIT;
                end

                // Wait 1 cycle for sync memory read latency
                ST_RW_UP_WAIT: begin
                    state_q <= ST_RW_UP_WR;
                end

                // Check read data, write inverse
                ST_RW_UP_WR: begin
                    if (current_rdata != expect_val) begin
                        fail_flag_q <= 1'b1;
                    end
                    // Write is driven combinationally
                    if (addr_q == ADDR_MAX) begin
                        if (!march_odd_q) begin
                            // M2 done → M3
                            addr_q      <= {ADDR_BITS{1'b0}};
                            march_odd_q <= 1'b1;
                            state_q     <= ST_RW_UP_RD;
                        end else begin
                            // M3 done → M4 (descending)
                            addr_q      <= ADDR_MAX;
                            march_odd_q <= 1'b0;
                            state_q     <= ST_RW_DN_RD;
                        end
                    end else begin
                        addr_q  <= addr_q + 1'b1;
                        state_q <= ST_RW_UP_RD;
                    end
                end

                //--------------------------------------------------------------
                // M4/5: ⇓ r(x),w(~x) — issue read
                //--------------------------------------------------------------
                ST_RW_DN_RD: begin
                    state_q <= ST_RW_DN_WAIT;
                end

                ST_RW_DN_WAIT: begin
                    state_q <= ST_RW_DN_WR;
                end

                ST_RW_DN_WR: begin
                    if (current_rdata != expect_val) begin
                        fail_flag_q <= 1'b1;
                    end
                    if (addr_q == {ADDR_BITS{1'b0}}) begin
                        if (!march_odd_q) begin
                            // M4 done → M5
                            addr_q      <= ADDR_MAX;
                            march_odd_q <= 1'b1;
                            state_q     <= ST_RW_DN_RD;
                        end else begin
                            // M5 done → M6 (final read)
                            addr_q  <= {ADDR_BITS{1'b0}};
                            state_q <= ST_FINAL_RD;
                        end
                    end else begin
                        addr_q  <= addr_q - 1'b1;
                        state_q <= ST_RW_DN_RD;
                    end
                end

                //--------------------------------------------------------------
                // M6: ⇑ r(0) — final verify
                //--------------------------------------------------------------
                ST_FINAL_RD: begin
                    state_q <= ST_FINAL_WAIT;
                end

                ST_FINAL_WAIT: begin
                    state_q <= ST_FINAL_CHK;
                end

                ST_FINAL_CHK: begin
                    if (current_rdata != pattern_zero) begin
                        fail_flag_q <= 1'b1;
                    end

                    if (addr_q == ADDR_MAX) begin
                        if (!mem_sel_q) begin
                            // IMEM done → switch to DMEM
                            imem_fail   <= fail_flag_q;
                            mem_sel_q   <= 1'b1;
                            addr_q      <= {ADDR_BITS{1'b0}};
                            fail_flag_q <= 1'b0;
                            march_odd_q <= 1'b0;
                            state_q     <= ST_WRITE_UP;
                        end else begin
                            dmem_fail <= fail_flag_q;
                            state_q   <= ST_DONE;
                        end
                    end else begin
                        addr_q  <= addr_q + 1'b1;
                        state_q <= ST_FINAL_RD;
                    end
                end

                //--------------------------------------------------------------
                ST_DONE: begin
                    bist_done <= 1'b1;
                    bist_pass <= ~imem_fail & ~dmem_fail;
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
