//-----------------------------------------------------------------------------
// Module: memwb_stage
// File:   memwb_stage.v
//
// Description:
//   Memory Access + Writeback stage for 3-stage RV32I pipeline.
//   - Drives DMEM interface for loads and stores
//   - Generates byte write masks for SB/SH/SW
//   - Sign/zero extends load data for LB/LBU/LH/LHU/LW
//   - Selects writeback source (ALU result, load data, or PC+4)
//   - Outputs register write signals to reg_file
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module memwb_stage (
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire        clk,            // Kept for interface consistency
    input  wire        rst_n,          // Kept for interface consistency
    /* verilator lint_on UNUSEDSIGNAL */

    // Pipeline control
    input  wire        stall,          // Hold pipeline

    // Inputs from ID/EX stage
    input  wire [31:0] ex_alu_result,  // ALU result (address for ld/st)
    input  wire [31:0] ex_rs2_data,    // rs2 data (store value)
    input  wire [4:0]  ex_rd_addr,     // Destination register
    input  wire        ex_reg_write_en,// Write enable for rd
    input  wire        ex_mem_read_en, // Load instruction
    input  wire        ex_mem_write_en,// Store instruction
    input  wire        ex_mem_to_reg,  // 1=load data, 0=ALU result
    input  wire [2:0]  ex_mem_size,    // Byte/half/word select (funct3)
    input  wire [31:0] ex_pc_plus4,    // PC+4 for JAL/JALR link
    input  wire        ex_jump_en,     // Jump instruction (use PC+4)
    input  wire        ex_valid,       // Instruction is valid

    // DMEM interface
    output wire        dmem_en,        // Memory access enable
    output wire [31:0] dmem_addr,      // Memory byte address
    output wire [31:0] dmem_wdata,     // Write data (shifted)
    output wire [3:0]  dmem_wmask,     // Byte write mask
    output wire        dmem_we,        // 1=store, 0=load
    input  wire [31:0] dmem_rdata,     // Read data from memory

    // Register writeback (to reg_file)
    output wire [4:0]  wb_rd_addr,     // Destination register
    output wire [31:0] wb_rd_data,     // Writeback data
    output wire        wb_rd_write_en, // Writeback enable

    // Forwarded signals for hazard detection in ID/EX
    output wire [4:0]  wb_rd_addr_fwd,
    output wire        wb_reg_write_en_fwd,
    output wire        wb_mem_to_reg_fwd
);

    

    //--------------------------------------------------------------------------
    // DMEM control signals (combinational)
    //--------------------------------------------------------------------------
    assign dmem_en   = ex_valid && (ex_mem_read_en || ex_mem_write_en) && !stall;
    assign dmem_addr = ex_alu_result;
    assign dmem_we   = ex_mem_write_en;

    //--------------------------------------------------------------------------
    // Store data alignment and byte mask (combinational)
    //--------------------------------------------------------------------------
    wire [1:0] byte_offset = ex_alu_result[1:0];

    reg [31:0] store_data;
    reg [3:0]  store_mask;

    always @(*) begin
        // Defaults
        store_data = 32'b0;
        store_mask = 4'b0000;

        case (ex_mem_size)
            `F3_LB_SB: begin  // SB
                case (byte_offset)
                    2'b00: begin store_data = {24'b0, ex_rs2_data[7:0]};       store_mask = 4'b0001; end
                    2'b01: begin store_data = {16'b0, ex_rs2_data[7:0], 8'b0}; store_mask = 4'b0010; end
                    2'b10: begin store_data = {8'b0, ex_rs2_data[7:0], 16'b0}; store_mask = 4'b0100; end
                    2'b11: begin store_data = {ex_rs2_data[7:0], 24'b0};       store_mask = 4'b1000; end
                endcase
            end
            `F3_LH_SH: begin  // SH
                case (byte_offset[1])
                    1'b0: begin store_data = {16'b0, ex_rs2_data[15:0]};        store_mask = 4'b0011; end
                    1'b1: begin store_data = {ex_rs2_data[15:0], 16'b0};        store_mask = 4'b1100; end
                endcase
            end
            `F3_LW_SW: begin  // SW
                store_data = ex_rs2_data;
                store_mask = 4'b1111;
            end
            default: begin
                store_data = 32'b0;
                store_mask = 4'b0000;
            end
        endcase
    end

    assign dmem_wdata = store_data;
    assign dmem_wmask = store_mask;

    //--------------------------------------------------------------------------
    // Load data sign/zero extension (combinational)
    //--------------------------------------------------------------------------
    reg [31:0] load_data;

    always @(*) begin
        load_data = 32'b0;

        case (ex_mem_size)
            `F3_LB_SB: begin  // LB (signed byte)
                case (byte_offset)
                    2'b00: load_data = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
                    2'b01: load_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: load_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: load_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            `F3_LH_SH: begin  // LH (signed halfword)
                case (byte_offset[1])
                    1'b0: load_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    1'b1: load_data = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                endcase
            end
            `F3_LW_SW: begin  // LW (full word)
                load_data = dmem_rdata;
            end
            `F3_LBU: begin  // LBU (unsigned byte)
                case (byte_offset)
                    2'b00: load_data = {24'b0, dmem_rdata[7:0]};
                    2'b01: load_data = {24'b0, dmem_rdata[15:8]};
                    2'b10: load_data = {24'b0, dmem_rdata[23:16]};
                    2'b11: load_data = {24'b0, dmem_rdata[31:24]};
                endcase
            end
            `F3_LHU: begin  // LHU (unsigned halfword)
                case (byte_offset[1])
                    1'b0: load_data = {16'b0, dmem_rdata[15:0]};
                    1'b1: load_data = {16'b0, dmem_rdata[31:16]};
                endcase
            end
            default: begin
                load_data = dmem_rdata;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Writeback mux (combinational)
    //--------------------------------------------------------------------------
    // JAL/JALR: rd = PC + 4
    // Load:     rd = load_data
    // ALU:      rd = alu_result
    wire [31:0] wb_data_mux;
    assign wb_data_mux = (ex_jump_en)    ? ex_pc_plus4 :
                         (ex_mem_to_reg) ? load_data :
                                           ex_alu_result;

    //--------------------------------------------------------------------------
    // Writeback outputs
    //--------------------------------------------------------------------------
    assign wb_rd_addr     = ex_rd_addr;
    assign wb_rd_data     = wb_data_mux;
    assign wb_rd_write_en = ex_reg_write_en && ex_valid && !stall;

    //--------------------------------------------------------------------------
    // Hazard forwarding info (to ID/EX stage)
    //--------------------------------------------------------------------------
    assign wb_rd_addr_fwd      = ex_rd_addr;
    assign wb_reg_write_en_fwd = ex_reg_write_en && ex_valid;
    assign wb_mem_to_reg_fwd   = ex_mem_to_reg;

endmodule

`default_nettype wire
