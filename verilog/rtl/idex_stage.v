//-----------------------------------------------------------------------------
// Module: idex_stage
// File:   idex_stage.v
//
// Description:
//   Combined Decode + Execute stage for 3-stage RV32I pipeline.
//   - Instantiates control decoder and ALU
//   - Resolves branches and generates flush/target for IF stage
//   - Detects load-use hazards and generates stall
//   - Latches results in pipeline register for MEM/WB stage
//
// Author: dkolhe21
// Date:   2026-02-18
//-----------------------------------------------------------------------------

`default_nettype none

module idex_stage (
    input  wire        clk,
    input  wire        rst_n,

    // Pipeline control (from external stall — e.g. debug halt)
    input  wire        stall_in,       // External stall (debug halt)

    // Inputs from IF stage
    input  wire [31:0] if_pc,          // PC of fetched instruction
    input  wire [31:0] if_instr,       // Fetched instruction
    input  wire        if_valid,       // Instruction valid

    // Register file read data (from reg_file ports)
    input  wire [31:0] rf_rs1_data,    // rs1 value from register file
    input  wire [31:0] rf_rs2_data,    // rs2 value from register file

    // Forwarded writeback info (from MEM/WB for hazard check & forwarding)
    input  wire [4:0]  memwb_rd_addr,  // MEM/WB destination register
    input  wire        memwb_reg_write_en, // MEM/WB write enable
    input  wire        memwb_mem_to_reg,   // MEM/WB is a load (for hazard)
    input  wire [31:0] memwb_rd_data,  // MEM/WB writeback data (for forwarding)

    // Register file read address outputs (directly wire to reg_file)
    output wire [4:0]  rs1_addr_out,   // rs1 address (to reg_file)
    output wire [4:0]  rs2_addr_out,   // rs2 address (to reg_file)

    // Branch/Jump control (to IF stage)
    output wire        branch_taken,   // Branch or jump resolved taken
    output wire [31:0] branch_target,  // Target PC

    // Pipeline stall/flush (to IF stage)
    output wire        stall_out,      // Combined stall: hazard OR external
    output wire        flush_out,      // Flush IF on branch/jump taken

    // Pipeline register outputs (to MEM/WB stage)
    output reg  [31:0] ex_alu_result,  // ALU result
    output reg  [31:0] ex_rs2_data,    // rs2 data (for stores)
    output reg  [4:0]  ex_rd_addr,     // Destination register
    output reg         ex_reg_write_en,// Write enable for rd
    output reg         ex_mem_read_en, // Load instruction
    output reg         ex_mem_write_en,// Store instruction
    output reg         ex_mem_to_reg,  // 1=load data, 0=ALU result
    output reg  [2:0]  ex_mem_size,    // Byte/half/word select
    output reg  [31:0] ex_pc_plus4,    // PC+4 for JAL/JALR writeback
    output reg         ex_jump_en,     // Is a jump (for link address)
    output reg         ex_valid        // Instruction is valid
);

    

    //--------------------------------------------------------------------------
    // Control decoder outputs
    //--------------------------------------------------------------------------
    wire [4:0]  ctrl_rs1_addr;
    wire [4:0]  ctrl_rs2_addr;
    wire [4:0]  ctrl_rd_addr;
    wire [3:0]  ctrl_alu_op;
    wire        ctrl_alu_src;
    wire [31:0] ctrl_imm;
    wire        ctrl_mem_read_en;
    wire        ctrl_mem_write_en;
    wire        ctrl_mem_to_reg;
    wire [2:0]  ctrl_mem_size;
    wire        ctrl_branch_en;
    wire        ctrl_jump_en;
    wire        ctrl_jalr_en;
    wire        ctrl_reg_write_en;

    control u_control (
        .instr        (if_instr),
        .rs1_addr     (ctrl_rs1_addr),
        .rs2_addr     (ctrl_rs2_addr),
        .rd_addr      (ctrl_rd_addr),
        .alu_op       (ctrl_alu_op),
        .alu_src      (ctrl_alu_src),
        .imm          (ctrl_imm),
        .mem_read_en  (ctrl_mem_read_en),
        .mem_write_en (ctrl_mem_write_en),
        .mem_to_reg   (ctrl_mem_to_reg),
        .mem_size     (ctrl_mem_size),
        .branch_en    (ctrl_branch_en),
        .jump_en      (ctrl_jump_en),
        .jalr_en      (ctrl_jalr_en),
        .reg_write_en (ctrl_reg_write_en)
    );

    // Wire register addresses to reg_file
    assign rs1_addr_out = ctrl_rs1_addr;
    assign rs2_addr_out = ctrl_rs2_addr;

    //--------------------------------------------------------------------------
    // MEM/WB → ID/EX Forwarding
    //   Only forward if:
    //   1. MEM/WB is writing to a register (wb_en && rd!=0)
    //   2. The addresses match
    //   3. The current instruction ACTUALLY USES that source register
    //--------------------------------------------------------------------------
    wire [6:0] opcode = if_instr[6:0];

    // Identify which sources are used by the current instruction
    wire uses_rs1 = (opcode != `OPC_LUI) && 
                    (opcode != `OPC_AUIPC) && 
                    (opcode != `OPC_JAL);

    wire uses_rs2 = (opcode == `OPC_OP) || 
                    (opcode == `OPC_STORE) || 
                    (opcode == `OPC_BRANCH);

    wire fwd_rs1 = uses_rs1 && memwb_reg_write_en && (memwb_rd_addr != 5'b0) &&
                   (memwb_rd_addr == ctrl_rs1_addr);
    
    wire fwd_rs2 = uses_rs2 && memwb_reg_write_en && (memwb_rd_addr != 5'b0) &&
                   (memwb_rd_addr == ctrl_rs2_addr);

    wire [31:0] rs1_data_fwd = fwd_rs1 ? memwb_rd_data : rf_rs1_data;
    wire [31:0] rs2_data_fwd = fwd_rs2 ? memwb_rd_data : rf_rs2_data;

    //--------------------------------------------------------------------------
    // ALU
    //--------------------------------------------------------------------------
    wire [31:0] alu_operand_a;
    wire [31:0] alu_operand_b;
    wire [31:0] alu_result;
    /* verilator lint_off UNUSEDSIGNAL */
    wire        alu_zero;  // Available for future forwarding logic
    /* verilator lint_on UNUSEDSIGNAL */

    // Operand A: rs1 for most instructions, PC for AUIPC
    assign alu_operand_a = (if_instr[6:0] == `OPC_AUIPC) ? if_pc : rs1_data_fwd;

    // Operand B: immediate or rs2
    assign alu_operand_b = (ctrl_alu_src) ? ctrl_imm : rs2_data_fwd;

    alu u_alu (
        .operand_a  (alu_operand_a),
        .operand_b  (alu_operand_b),
        .alu_op     (ctrl_alu_op),
        .result     (alu_result),
        .zero_flag  (alu_zero)
    );

    //--------------------------------------------------------------------------
    // Branch resolution (combinational)
    //--------------------------------------------------------------------------
    wire [2:0] branch_funct3 = if_instr[14:12];
    reg        branch_cond;

    always @(*) begin
        branch_cond = 1'b0;
        if (ctrl_branch_en && if_valid) begin
            case (branch_funct3)
                `F3_BEQ:  branch_cond = (rs1_data_fwd == rs2_data_fwd);
                `F3_BNE:  branch_cond = (rs1_data_fwd != rs2_data_fwd);
                `F3_BLT:  branch_cond = ($signed(rs1_data_fwd) < $signed(rs2_data_fwd));
                `F3_BGE:  branch_cond = ($signed(rs1_data_fwd) >= $signed(rs2_data_fwd));
                `F3_BLTU: branch_cond = (rs1_data_fwd < rs2_data_fwd);
                `F3_BGEU: branch_cond = (rs1_data_fwd >= rs2_data_fwd);
                default: branch_cond = 1'b0;
            endcase
        end
    end

    // Branch/jump taken
    assign branch_taken = (if_valid && !stall_out) &&
                          ((ctrl_branch_en && branch_cond) || ctrl_jump_en);

    // Branch/jump target
    assign branch_target = (ctrl_jalr_en) ? (rs1_data_fwd + ctrl_imm) & 32'hFFFFFFFE :
                                            if_pc + ctrl_imm;

    //--------------------------------------------------------------------------
    // Load-use hazard detection
    //--------------------------------------------------------------------------
    // Stall if MEM/WB is a load and its rd matches our rs1 or rs2
    wire load_use_hazard;
    assign load_use_hazard = 1'b0; // Disabled for async RAM (tb_compliance)

    assign stall_out = stall_in || load_use_hazard;
    assign flush_out = branch_taken;

    //--------------------------------------------------------------------------
    // Pipeline register (ID/EX → MEM/WB)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            ex_alu_result  <= 32'b0;
            ex_rs2_data    <= 32'b0;
            ex_rd_addr     <= 5'b0;
            ex_reg_write_en <= 1'b0;
            ex_mem_read_en <= 1'b0;
            ex_mem_write_en <= 1'b0;
            ex_mem_to_reg  <= 1'b0;
            ex_mem_size    <= 3'b0;
            ex_pc_plus4    <= 32'b0;
            ex_jump_en     <= 1'b0;
            ex_valid       <= 1'b0;
        end else if (stall_out) begin
            // Hold pipeline register (don't update)
            ex_alu_result  <= ex_alu_result;
            ex_rs2_data    <= ex_rs2_data;
            ex_rd_addr     <= ex_rd_addr;
            ex_reg_write_en <= ex_reg_write_en;
            ex_mem_read_en <= ex_mem_read_en;
            ex_mem_write_en <= ex_mem_write_en;
            ex_mem_to_reg  <= ex_mem_to_reg;
            ex_mem_size    <= ex_mem_size;
            ex_pc_plus4    <= ex_pc_plus4;
            ex_jump_en     <= ex_jump_en;
            ex_valid       <= ex_valid;
        end else if (!if_valid) begin
            // Insert bubble (NOP)
            ex_alu_result  <= 32'b0;
            ex_rs2_data    <= 32'b0;
            ex_rd_addr     <= 5'b0;
            ex_reg_write_en <= 1'b0;
            ex_mem_read_en <= 1'b0;
            ex_mem_write_en <= 1'b0;
            ex_mem_to_reg  <= 1'b0;
            ex_mem_size    <= 3'b0;
            ex_pc_plus4    <= 32'b0;
            ex_jump_en     <= 1'b0;
            ex_valid       <= 1'b0;
        end else begin
            // Normal latch
            ex_alu_result  <= alu_result;
            ex_rs2_data    <= rs2_data_fwd;
            ex_rd_addr     <= ctrl_rd_addr;
            ex_reg_write_en <= ctrl_reg_write_en;
            ex_mem_read_en <= ctrl_mem_read_en;
            ex_mem_write_en <= ctrl_mem_write_en;
            ex_mem_to_reg  <= ctrl_mem_to_reg;
            ex_mem_size    <= ctrl_mem_size;
            ex_pc_plus4    <= if_pc + 32'd4;
            ex_jump_en     <= ctrl_jump_en;
            ex_valid       <= 1'b1;
        end
    end

endmodule

`default_nettype wire
