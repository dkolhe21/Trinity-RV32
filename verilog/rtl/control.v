//-----------------------------------------------------------------------------
// Module: control
// File:   control.v
//
// Description:
//   RV32I instruction decoder. Pure combinational.
//   Decodes 32-bit instruction into ALU op, immediate, source/dest
//   register addresses, and memory/branch/jump control signals.
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module control (
    input  wire [31:0] instr,          // 32-bit instruction word

    // Register addresses
    output wire [4:0]  rs1_addr,       // Source register 1
    output wire [4:0]  rs2_addr,       // Source register 2
    output wire [4:0]  rd_addr,        // Destination register

    // ALU control
    output reg  [3:0]  alu_op,         // ALU operation select
    output reg         alu_src,        // 0 = rs2, 1 = immediate

    // Immediate
    output reg  [31:0] imm,            // Sign-extended immediate

    // Memory control
    output reg         mem_read_en,    // Load instruction
    output reg         mem_write_en,   // Store instruction
    output reg         mem_to_reg,     // 1 = load data to rd, 0 = ALU result
    output reg  [2:0]  mem_size,       // funct3 for byte/half/word

    // Branch / Jump
    output reg         branch_en,      // Conditional branch
    output reg         jump_en,        // JAL or JALR
    output reg         jalr_en,        // JALR (base+offset, not PC+offset)

    // Register write
    output reg         reg_write_en    // Write result to rd
);

    

    //--------------------------------------------------------------------------
    // Instruction field extraction
    //--------------------------------------------------------------------------
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rd_addr  = instr[11:7];

    //--------------------------------------------------------------------------
    // Immediate generation (combinational)
    //--------------------------------------------------------------------------
    always @(*) begin
        // Default
        imm = 32'b0;

        case (opcode)
            // I-type: LOAD, OP_IMM, JALR
            `OPC_LOAD,
            `OPC_OP_IMM,
            `OPC_JALR: begin
                imm = {{20{instr[31]}}, instr[31:20]};
            end

            // S-type: STORE
            `OPC_STORE: begin
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end

            // B-type: BRANCH
            `OPC_BRANCH: begin
                imm = {{19{instr[31]}}, instr[31], instr[7],
                        instr[30:25], instr[11:8], 1'b0};
            end

            // U-type: LUI, AUIPC
            `OPC_LUI,
            `OPC_AUIPC: begin
                imm = {instr[31:12], 12'b0};
            end

            // J-type: JAL
            `OPC_JAL: begin
                imm = {{11{instr[31]}}, instr[31], instr[19:12],
                        instr[20], instr[30:21], 1'b0};
            end

            default: begin
                imm = 32'b0;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Control signal decode (combinational)
    //--------------------------------------------------------------------------
    always @(*) begin
        // Default all control signals to safe/inactive values
        alu_op       = `ALU_ADD;
        alu_src      = 1'b0;
        mem_read_en  = 1'b0;
        mem_write_en = 1'b0;
        mem_to_reg   = 1'b0;
        mem_size     = 3'b010;  // Word by default
        branch_en    = 1'b0;
        jump_en      = 1'b0;
        jalr_en      = 1'b0;
        reg_write_en = 1'b0;

        case (opcode)
            //------------------------------------------------------------------
            // R-type ALU (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU)
            //------------------------------------------------------------------
            `OPC_OP: begin
                alu_src      = 1'b0;  // rs2
                reg_write_en = 1'b1;
                case (funct3)
                    `F3_ADD_SUB: alu_op = (funct7 == `F7_ALT) ? `ALU_SUB : `ALU_ADD;
                    `F3_SLL:     alu_op = `ALU_SLL;
                    `F3_SLT:     alu_op = `ALU_SLT;
                    `F3_SLTU:    alu_op = `ALU_SLTU;
                    `F3_XOR:     alu_op = `ALU_XOR;
                    `F3_SRL_SRA: alu_op = (funct7 == `F7_ALT) ? `ALU_SRA : `ALU_SRL;
                    `F3_OR:      alu_op = `ALU_OR;
                    `F3_AND:     alu_op = `ALU_AND;
                    default:    alu_op = `ALU_ADD;
                endcase
            end

            //------------------------------------------------------------------
            // I-type ALU Immediate (ADDI, ANDI, ORI, XORI, SLTI, SLTIU,
            //                       SLLI, SRLI, SRAI)
            //------------------------------------------------------------------
            `OPC_OP_IMM: begin
                alu_src      = 1'b1;  // immediate
                reg_write_en = 1'b1;
                case (funct3)
                    `F3_ADD_SUB: alu_op = `ALU_ADD;   // ADDI (no SUBI)
                    `F3_SLL:     alu_op = `ALU_SLL;   // SLLI
                    `F3_SLT:     alu_op = `ALU_SLT;   // SLTI
                    `F3_SLTU:    alu_op = `ALU_SLTU;   // SLTIU
                    `F3_XOR:     alu_op = `ALU_XOR;   // XORI
                    `F3_SRL_SRA: alu_op = (funct7 == `F7_ALT) ? `ALU_SRA : `ALU_SRL;
                    `F3_OR:      alu_op = `ALU_OR;    // ORI
                    `F3_AND:     alu_op = `ALU_AND;   // ANDI
                    default:    alu_op = `ALU_ADD;
                endcase
            end

            //------------------------------------------------------------------
            // Load (LB, LH, LW, LBU, LHU)
            //------------------------------------------------------------------
            `OPC_LOAD: begin
                alu_src      = 1'b1;  // base + offset
                alu_op       = `ALU_ADD;
                mem_read_en  = 1'b1;
                mem_to_reg   = 1'b1;
                mem_size     = funct3;
                reg_write_en = 1'b1;
            end

            //------------------------------------------------------------------
            // Store (SB, SH, SW)
            //------------------------------------------------------------------
            `OPC_STORE: begin
                alu_src      = 1'b1;  // base + offset
                alu_op       = `ALU_ADD;
                mem_write_en = 1'b1;
                mem_size     = funct3;
            end

            //------------------------------------------------------------------
            // Branch (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            //------------------------------------------------------------------
            `OPC_BRANCH: begin
                alu_src   = 1'b0;  // rs2 for comparison
                branch_en = 1'b1;
                // Use SUB for comparison; branch logic checks funct3
                alu_op    = `ALU_SUB;
            end

            //------------------------------------------------------------------
            // LUI
            //------------------------------------------------------------------
            `OPC_LUI: begin
                alu_src      = 1'b1;
                alu_op       = `ALU_PASS_B;  // Pass immediate directly
                reg_write_en = 1'b1;
            end

            //------------------------------------------------------------------
            // AUIPC
            //------------------------------------------------------------------
            `OPC_AUIPC: begin
                alu_src      = 1'b1;
                alu_op       = `ALU_ADD;  // PC + upper immediate
                reg_write_en = 1'b1;
            end

            //------------------------------------------------------------------
            // JAL
            //------------------------------------------------------------------
            `OPC_JAL: begin
                jump_en      = 1'b1;
                reg_write_en = 1'b1;  // rd = PC + 4
            end

            //------------------------------------------------------------------
            // JALR
            //------------------------------------------------------------------
            `OPC_JALR: begin
                alu_src      = 1'b1;  // rs1 + offset
                alu_op       = `ALU_ADD;
                jump_en      = 1'b1;
                jalr_en      = 1'b1;
                reg_write_en = 1'b1;  // rd = PC + 4
            end

            default: begin
                // All signals stay at defaults (inactive)
            end
        endcase
    end

endmodule

`default_nettype wire
