// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 100 picoseconds
`timescale 1 ns / 100 ps 
// Header files containing all of the alu_op codes declared as constants
// and the opcode values and bit slicing values for the RISC-V datapath
`include "riscv_alu_constants.sv"
`include "riscv_datapath_constants.sv"
/***************************************************************************
*
* File: riscv_final.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 11 March 2026
* Modules: regfile.sv, alu.sv
* Description: Basic RISCV processor with 5 stage pipelining implemented.
*    This module accomplishes the same purpose described in
*    ../lab08/riscv_basic_pipeline.sv but now implements forwarding as well.
*    The module reads in an instruction (IF), decodes it (ID), executes all 
*    needed logic (EX), performs any memory reads or memory writes (MEM),
*    and writes back the data into the register if needed (WB). All signals
*    are differentiated by their respective pipeline stage by those same
*    prefixes.
* 
****************************************************************************/

module riscv_final #(parameter logic [31:0] INITIAL_PC = 32'h0040_0000)(
    input logic clk, rst,
    input logic [31:0] instruction, dReadData,
    output logic [31:0] PC, ALUResult, dAddress, dWriteData, WriteBackData,
    output logic MemRead, MemWrite, iMemRead
);

localparam PC_NORMAL_INCREMENT = 4'b0100;

localparam FW_MEM = 2'b01;
localparam FW_WB = 2'b10;
localparam NO_FW = 2'b00;

// opcode instruction pipeline
logic [6:0] id_inst_op, ex_inst_op, mem_inst_op;
// PC signals used for instruction fetch and instruction decode stages
logic [31:0] if_PC, id_PC;
/* the control signals that are decoded from the instruction in this stage
*  as well as the pipeline registers used to pass it on to the next stage */
logic [3:0] id_ALUCtrl, ex_ALUCtrl;
logic id_ALUSrc, ex_ALUSrc, id_MemWrite, ex_MemWrite, id_MemRead, ex_MemRead, id_Branch,
      ex_Branch, id_RegWrite, ex_RegWrite, id_MemtoReg, ex_MemtoReg;
// 32-bit sign extended immediate values for each different operation type
logic [31:0] id_immI, ex_immI, id_immS, ex_immS, id_immSB, ex_immSB, id_immU, ex_immU;
logic [31:0] id_immUJ, ex_immUJ, mem_immUJ;
// ex_PC signal
logic [31:0] ex_PC;
// intermediate signals needed to connect to regfile as described below
logic [4:0] id_rs1, id_rs2, ex_writeReg, id_writeReg, ex_rs1, ex_rs2;
// writeReg pipeline signal
logic [4:0] mem_writeReg, wb_writeReg, mem_rs1, mem_rs2;
// Second operand for ALU operations and result
logic [31:0] ex_read1, ex_temp_read1, ex_read2, ex_op2, ex_alu_result, ex_final_alu_result;
// branch signals for alu output
logic ex_Zero, ex_Less_Than;
// Pipeline registers for alu_result and branch signals
logic [31:0] mem_alu_result;
logic mem_Zero, mem_Less_Than;
// Pipeline ctrl signals for mem stage
logic mem_Branch, mem_MemWrite, mem_MemRead, mem_MemtoReg, mem_RegWrite;
// branch target addr signal and pipeline PC signal
logic [31:0] mem_branch_addr, mem_jal_addr, mem_jalr_addr, mem_PC;
// PC pipelined to the wb stage
logic [31:0] wb_PC;
// PCSrc control signal used to determine how the PC is incremented
logic mem_PCSrc, wb_PCSrc;
// signals for pipelining
logic [31:0] wb_alu_result, mem_PC_target, wb_PC_target;
logic wb_MemtoReg, wb_RegWrite;
// write back data
logic [31:0] wb_writeData, mem_read2, wb_read2, ex_mem2;
// forward select signals for the MUX
logic [1:0] forwardA, forwardB;
logic is_forwarded;
logic [31:0] ex_op1, ex_temp_op2, ex_final_op2;
// Hazard detection signals
logic load_use_hazard, branch_mem_taken, branch_wb_taken, loadPC;
// Branch funct3 to determine which branch to perform
logic [2:0] id_branch_f3, ex_branch_f3, mem_branch_f3;


//////////////////////////////////////////////////////////////////////
// IF: Instruction Fetch
//////////////////////////////////////////////////////////////////////


// logic for determining if there's a load_use_hazard
assign load_use_hazard = (ex_MemRead) &&
                        ((ex_writeReg == id_rs1) || (ex_writeReg == id_rs2)) &&
                        (!(mem_Branch && mem_PCSrc)) ? 1 : 0;

// Setting loadPC to 0 if there is a load_use_hazard
assign loadPC = ~load_use_hazard;

// Setting iMemRead to 0 if there is a load_use_hazard
assign iMemRead = ~load_use_hazard;

// Setting branch_mem_taken signal high if mem_PCSrc is high (if branch taken)
assign branch_mem_taken = mem_PCSrc;

// Setting branch_wb_taken signal high if wb_PCSrc is high (branch taken)
assign branch_wb_taken = wb_PCSrc;

/* This block increments the program counter in the instruction fetch register.
*  It resets to the INITIAL_PC value on assertion of the global rst signal,
*  and increments based on the calculated if_pc_inc as described above */
always_ff @(posedge clk) begin
    if (rst)
        if_PC <= INITIAL_PC;
    else begin
        if (loadPC) begin
            if (mem_PCSrc)
                if_PC <= wb_PC_target;
            else
                if_PC <= if_PC + PC_NORMAL_INCREMENT;
        end
    end
end

/* This block passes the PC from the instruction fetch stage to the instruction
*  decode stage on the clock cycle */
always_ff @(posedge clk) begin
    if (rst)
        id_PC <= INITIAL_PC;
    else
        if (loadPC)
            id_PC <= if_PC;
end


//////////////////////////////////////////////////////////////////////
// ID: Instruction Decode
//////////////////////////////////////////////////////////////////////


/**********************************
***       CONTROL SIGNALS       ***
**********************************/

/* Combinational logic to determine the id_ALUCtrl signal based on the instruction
*  opcode and funct3 and funct7 fields. In this module, the id_ALUCtrl signal is
*  set to ADD_OP for lw an sw instructions, and set to SUB_OP for branch
*  instructions */
always_comb begin
    if ((instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW) || 
        (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SW) ||
        (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_U_TYPE))
        id_ALUCtrl = ADD_OP;
    else if (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SB_TYPE)
        id_ALUCtrl = SUB_OP;
    else begin
        case(instruction[FUNCT3_MSB:FUNCT3_LSB])
            ADD: id_ALUCtrl = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_I_TYPE) ?
                 ADD_OP : 
                 (instruction[FUNCT7_MSB:FUNCT7_LSB] == FUNCT7_ADD) ? 
                 ADD_OP : SUB_OP;
            SLL: id_ALUCtrl = SLL_OP;
            SLT: id_ALUCtrl = SLT_OP;
            XOR: id_ALUCtrl = XOR_OP;
            SRL: id_ALUCtrl = (instruction[FUNCT7_MSB:FUNCT7_LSB] == FUNCT7_SRL) ?
                 SRL_OP : SRA_OP;
            OR: id_ALUCtrl = OR_OP;
            AND: id_ALUCtrl = AND_OP;
            default: id_ALUCtrl = ADD_OP;
        endcase
    end       
end

// Assign func3 bits for pipelining
assign id_branch_f3 = instruction[FUNCT3_MSB:FUNCT3_LSB];

/* Set id_ALUSrc to 1 for instructions that require an immediate value, and 0
   for all other instructions */
assign id_ALUSrc = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_I_TYPE) ||
                   (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW) ||
                   (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SW) ||
                   (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_U_TYPE) ||
                   (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_JAL) ||
                   (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_JALR);

/* Combinational logic blocks to assign id_MemRead and id_MemWrite signals depending
*  on if the instruction is a lw or a sw */
assign id_MemWrite = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SW);
assign id_MemRead = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW);

/* Combinational logic block to determine whether the instruction is a branch
*  or not */
assign id_Branch = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SB_TYPE) ||
                   (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_JAL) ||
                   (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_JALR);

/* Combinational logic for id_RegWrite Ctrl Signal which is only asserted for
*  R_type, I_type, or lw instructions */
assign id_RegWrite = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_R_TYPE) ||
                     (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_I_TYPE) ||
                     (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW) ||
                     (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_U_TYPE) ||
                     (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_JAL) ||
                     (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_JALR);

// Assert the id_MemtoReg signal for lw instructions, and deassert for all other
assign id_MemtoReg = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW);

// ID Pipeline register passing information for ctrl signals down the pipeline
always_ff @(posedge clk) begin
    if (rst) begin
        ex_ALUCtrl <= 4'b0000;
        ex_ALUSrc <= 1'b0;
        ex_MemWrite <= 1'b0;
        ex_MemRead <= 1'b0;
        ex_Branch <= 1'b0;
        ex_RegWrite <= 1'b0;
        ex_MemtoReg <= 1'b0;
    end
    else begin
        if (load_use_hazard || branch_mem_taken || branch_wb_taken) begin
            ex_ALUCtrl <= 4'b0000;
            ex_ALUSrc <= 1'b0;
            ex_MemWrite <= 1'b0;
            ex_MemRead <= 1'b0;
            ex_Branch <= 1'b0;
            ex_RegWrite <= 1'b0;
            ex_MemtoReg <= 1'b0;
        end
        else begin
            ex_ALUCtrl <= id_ALUCtrl;
            ex_ALUSrc <= id_ALUSrc;
            ex_MemWrite <= id_MemWrite;
            ex_MemRead <= id_MemRead;
            ex_Branch <= id_Branch;
            ex_RegWrite <= id_RegWrite;
            ex_MemtoReg <= id_MemtoReg;
        end
    end
end

/**********************************
***      IMMEDIATE VALUES       ***
**********************************/

/* Combinational logic blocks to decode the immediate values for the the 4
*  different instruction types*/
assign id_immI = {{IMM_I_SIGN_EXT_BITS{instruction[IMM_MSB]}},
                instruction[IMM_MSB:IMM_I_LSB]}; 
assign id_immS = {{IMM_S_SIGN_EXT_BITS{instruction[IMM_MSB]}},
               instruction[IMM_MSB:IMM_S_LSB_1],
               instruction[IMM_S_MSB_2:IMM_S_LSB_2]};
assign id_immSB = {{IMM_SB_SIGN_EXT_BITS{instruction[IMM_MSB]}},
                instruction[IMM_MSB],
                instruction[IMM_SB_BIT_11],
                instruction[IMM_SB_BIT_10:IMM_SB_BIT_5],
                instruction[IMM_SB_BIT_4:IMM_SB_BIT_1],
                1'b0};
assign id_immU = {instruction[IMM_U_MSB:IMM_U_LSB],
                 12'b0};
assign id_immUJ = {{IMM_UJ_SIGN_EXT_BITS{instruction[IMM_UJ_MSB]}},
                instruction[IMM_UJ_MSB],
                instruction[IMM_UJ_BIT_19:IMM_UJ_BIT_12],
                instruction[IMM_UJ_BIT_11],
                instruction[IMM_UJ_BIT_10:IMM_UJ_BIT_1],
                1'b0};

// ID Pipeline register passing information for immediate vals down pipeline
always_ff @(posedge clk) begin
    if (rst) begin
        ex_immI <= 0;
        ex_immS <= 0;
        ex_immSB <= 0;
        ex_immU <= 0;
        ex_immUJ <= 0;
    end
    else begin
        if (load_use_hazard || branch_mem_taken || branch_wb_taken) begin
            ex_immI <= 0;
            ex_immS <= 0;
            ex_immSB <= 0;
            ex_immU <= 0;
            ex_immUJ <= 0;
        end
        else begin
            ex_immI <= id_immI;
            ex_immS <= id_immS;
            ex_immSB <= id_immSB;
            ex_immU <= id_immU;
            ex_immUJ <= id_immUJ;
        end
    end
end

// Pipeline PC register
always_ff @(posedge clk)
    if (rst)
        ex_PC <= INITIAL_PC;
    else
        ex_PC <= id_PC;

/**********************************
***        REGISTER FILE        ***
**********************************/

// decoding the instruction to determine rs1, rs2, and rd
assign id_rs2 = instruction[RS_2_MSB:RS_2_LSB];
assign id_rs1 = instruction[RS_1_MSB:RS_1_LSB];
assign id_writeReg = instruction[RD_MSB:RD_LSB];

/* Instance the register file. The 2 readAddresses (readReg1 & readReg2)
*  are determined by the instruction decoding. The Write signals are
*  Piplined down and the WB signals are connected back to this module */
regfile rf(.clk(clk), .write(wb_RegWrite), .readReg1(id_rs1),
           .readReg2(id_rs2), .writeReg(wb_writeReg),
           .writeData(WriteBackData), .readData1(ex_temp_read1),
           .readData2(ex_read2));

// Pipeline register addresses
always_ff @(posedge clk)begin
    if (rst) begin
        ex_rs1 <= 0;
        ex_rs2 <= 0;
        ex_writeReg <= 0;
        ex_branch_f3 <= 0;
    end
    else begin
        if (load_use_hazard || branch_mem_taken || branch_wb_taken) begin
            ex_rs1 <= 0;
            ex_rs2 <= 0;
            ex_writeReg <= 0;
            ex_branch_f3 <= 0;
        end
        else begin
            ex_rs1 <= id_rs1;
            ex_rs2 <= id_rs2;
            ex_writeReg <= id_writeReg;
            ex_branch_f3 <= id_branch_f3;
        end
    end
end

// instruction code opcode
assign id_inst_op = instruction[OPCODE_MSB:OPCODE_LSB];

// pipeline instruction code opcode
always_ff @(posedge clk) begin
    if (rst)
        ex_inst_op <= 0;
    else
        if (load_use_hazard || branch_mem_taken || branch_wb_taken)
            ex_inst_op <= 0;
        else
            ex_inst_op <= id_inst_op;
end

//////////////////////////////////////////////////////////////////////
// EX: Execute
//////////////////////////////////////////////////////////////////////


// Pipeline register addresses
always_ff @(posedge clk)begin
    if (rst) begin
        mem_rs1 <= 0;
        mem_rs2 <= 0;
        mem_writeReg <= 0;
    end
    else begin
        if (branch_mem_taken) begin
            mem_rs1 <= 0;
            mem_rs2 <= 0;
            mem_writeReg <= 0;
        end
        else begin
            mem_rs1 <= ex_rs1;
            mem_rs2 <= ex_rs2;
            mem_writeReg <= ex_writeReg;
        end
    end
end

/**********************************
***        ALU OPERATIONS       ***
**********************************/

// MUX to determine whether ex_op2 is loaded with the data from register 2 or
// an immediate value, determined by (ALUSrc)
always_comb begin
    if (ex_ALUSrc) begin
        if (ex_inst_op == OPCODE_SW) begin
            ex_op2 = ex_immS;
        end
        else if (ex_inst_op == OPCODE_SB_TYPE) begin
            ex_op2 = ex_immSB;
        end
        else if (ex_inst_op == OPCODE_U_TYPE) begin
            ex_op2 = ex_immU;
        end
        else begin
            ex_op2 = ex_immI;
        end
    end
    else begin
        ex_op2 = ex_read2;
    end
end

/**********************************
***          FORWARDING         ***
**********************************/

/* MUX to set the forwardA select signal in preparation for the next
*  always_comb block */
always_comb begin
    if (mem_RegWrite && (mem_writeReg != 0) && (mem_writeReg == ex_rs1))
        forwardA = FW_MEM;
    else if (wb_RegWrite && (wb_writeReg != 0) && (wb_writeReg == ex_rs1))
        forwardA = FW_WB;
    else
        forwardA = NO_FW;
end

/* MUX to set the forwardB select signal in preparation for the next
*  always_comb block */
always_comb begin
    if (mem_RegWrite && (mem_writeReg != 0) && (mem_writeReg == ex_rs2))
        forwardB = FW_MEM;
    else if (wb_RegWrite && (wb_writeReg != 0) && (wb_writeReg == ex_rs2))
        forwardB = FW_WB;
    else
        forwardB = NO_FW;
end

/* MUX to determine which signals are used in the ALU operation, either
* the normal value interpreted from instruction or a forwarded value from
* the MEM stage or the WB stage */
always_comb begin
    case(forwardA)
        NO_FW: ex_read1 = ex_temp_read1;
        FW_MEM: ex_read1 = mem_alu_result;
        FW_WB: ex_read1 = wb_writeData;
        default: ex_read1 = ex_temp_read1;
    endcase
end

/* MUX to determine which signals are used in the ALU operation, either
* the normal value interpreted from instruction or a forwarded value from
* the MEM stage or the WB stage */
always_comb begin
    case(forwardB)
        NO_FW: begin
            ex_temp_op2 = ex_op2;
            is_forwarded = 0;
        end
        FW_MEM: begin
            ex_temp_op2 = mem_alu_result;
            is_forwarded = 1;
        end
        FW_WB: begin
            ex_temp_op2 = wb_writeData;
            is_forwarded = 1;
        end
        default: begin
            ex_temp_op2 = ex_op2;
            is_forwarded = 0;
        end
    endcase
end

// Correct any overwritten immediate value from incorrect forwarding
assign ex_final_op2 = ex_ALUSrc ? ex_op2 : ex_temp_op2;

// Forwarding for branch and sw instructions
assign ex_mem2 = is_forwarded ? ex_temp_op2 : ex_read2;

// for lui instruction (set op1 to 0, undoing forwarding)
assign ex_op1 = (ex_inst_op == OPCODE_U_TYPE) ? 0 : ex_read1;

// Instantiate the ALU module as described above. Further details on the
// function of each signal can be found in the alu.sv file
alu alu(.op1(ex_op1), .op2(ex_final_op2), .alu_op(ex_ALUCtrl), .zero(ex_Zero),
        .result(ex_alu_result));

// if it's a jump command, change the alu result to be PC+4 to store it in a register
always_comb begin
    if ((ex_inst_op == OPCODE_JAL) ||
        (ex_inst_op == OPCODE_JALR))
        ex_final_alu_result = ex_PC + PC_NORMAL_INCREMENT;
    else
        ex_final_alu_result = ex_alu_result;
end

// Less than signal for branch operations
assign ex_Less_Than = (ex_alu_result[ALU_MSB] == 1'b1);

// Pipeline ALU output and Zero signal
always_ff @(posedge clk) begin
    if (rst) begin
        mem_Zero <= 0;
        mem_Less_Than <= 0;
        mem_alu_result <= 0;
        mem_read2 <= 0;
        mem_branch_f3 <= 0;
        mem_immUJ <= 0;
        mem_inst_op <= 0;
    end
    else begin
        if (branch_mem_taken) begin
            mem_Zero <= 0;
            mem_alu_result <= 0;
            mem_read2 <= 0;
            mem_Less_Than <= 0;
            mem_branch_f3 <= 0;
            mem_immUJ <= 0;
            mem_inst_op <= 0;
        end
        else begin
            mem_Zero <= ex_Zero;
            mem_Less_Than <= ex_Less_Than;
            mem_alu_result <= ex_final_alu_result;
            mem_read2 <= ex_mem2;
            mem_branch_f3 <= ex_branch_f3;
            mem_immUJ <= ex_immUJ;
            mem_inst_op <= ex_inst_op;
        end
    end
end

/**********************************
***      Branch Target Addr     ***
**********************************/

// calculate branch target address
assign mem_branch_addr = ex_PC + ex_immSB;
// calculate jal target address
assign mem_jal_addr = ex_PC + ex_immUJ;
// calculate jalr target address
assign mem_jalr_addr = ex_alu_result;

// always comb block to decide which jump address to use for PC target
always_comb begin
    if (ex_inst_op == OPCODE_JAL)
        mem_PC_target = mem_jal_addr;
    else if (ex_inst_op == OPCODE_SB_TYPE)
        mem_PC_target = mem_branch_addr;
    else
        mem_PC_target = mem_jalr_addr;
end

// Pipeline PC and branch addr calculated
always_ff @(posedge clk) begin
    if (rst) begin
        wb_PC_target <= 0;
        mem_PC <= INITIAL_PC;
    end
    else begin
        if (branch_mem_taken) begin
            wb_PC_target <= 0;
            mem_PC <= ex_PC;
        end
        else begin
            wb_PC_target <= mem_PC_target;
            mem_PC <= ex_PC;
        end
    end
end

/**********************************
***    Pipelining ID signals    ***
**********************************/

// Pipeline necessary signals generated in ID for further stages
always_ff @(posedge clk) begin
    if (rst) begin
        mem_Branch <= 0;
        mem_MemWrite <= 0;
        mem_MemRead <= 0;
        mem_MemtoReg <= 0;
        mem_RegWrite <= 0;
    end
    else begin
        if (branch_mem_taken) begin
            mem_Branch <= 0;
            mem_MemWrite <= 0;
            mem_MemRead <= 0;
            mem_MemtoReg <= 0;
            mem_RegWrite <= 0;
        end
        else begin
            mem_Branch <= ex_Branch;
            mem_MemWrite <= ex_MemWrite;
            mem_MemRead <= ex_MemRead;
            mem_MemtoReg <= ex_MemtoReg;
            mem_RegWrite <= ex_RegWrite;
        end
    end
end


//////////////////////////////////////////////////////////////////////
// MEM: Memory Access
//////////////////////////////////////////////////////////////////////


/**********************************
***         Data Memory         ***
**********************************/

assign dAddress = mem_alu_result;
assign MemRead = mem_MemRead;   
assign MemWrite = mem_MemWrite;

/**********************************
***         Branch Logic        ***
**********************************/

// Set PCSrc to 1 if branch instruction condition is met
always_comb begin
    if ((mem_inst_op == OPCODE_JAL) ||
        (mem_inst_op == OPCODE_JALR))
        mem_PCSrc = 1;
    else begin
        case (mem_branch_f3)
            BEQ: mem_PCSrc = mem_Branch & mem_Zero;
            BNE: mem_PCSrc = mem_Branch & (~mem_Zero);
            BLT: mem_PCSrc = mem_Branch & mem_Less_Than & (~mem_Zero);
            BGE: mem_PCSrc = mem_Branch & (~mem_Less_Than);
            default: mem_PCSrc = 0;
        endcase
    end
end

// Pipeline the branch logic signal and PC to next stage
always_ff @(posedge clk) begin
    if (rst) begin
        wb_PCSrc <= 1'b0;
        wb_PC <= INITIAL_PC;
    end
    else begin
        wb_PCSrc <= mem_PCSrc;
        wb_PC <= mem_PC;
    end
end

/**********************************
***    Pipelining MEM signals    ***
**********************************/


// Pipeline signals to be used in the wb stage
always_ff @(posedge clk) begin
    if (rst) begin
        wb_alu_result <= 0;
        wb_MemtoReg <= 1'b0;
        wb_RegWrite <= 1'b0;
        wb_writeReg <= 1'b0;
        wb_read2 <= 0;
    end
    else begin
        wb_alu_result <= mem_alu_result;
        wb_MemtoReg <= mem_MemtoReg;
        wb_RegWrite <= mem_RegWrite;
        wb_writeReg <= mem_writeReg;
        wb_read2 <= mem_read2;
    end
end


//////////////////////////////////////////////////////////////////////
// WB: Write Back
//////////////////////////////////////////////////////////////////////


// Assign writeBackData to be MemRead value if MemtoReg is high
assign wb_writeData = wb_MemtoReg ? dReadData : wb_alu_result;

// Assign top level ports
assign WriteBackData = wb_writeData;
assign dWriteData = mem_read2;
assign ALUResult = ex_alu_result;
assign PC = if_PC;

endmodule
