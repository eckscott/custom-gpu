// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 100 picoseconds
`timescale 1 ns / 100 ps 
// Header files containing all of the alu_op codes declared as constants
// and the opcode values and bit slicing values for the RISC-V datapath
`include "riscv_alu_constants.sv"
`include "riscv_datapath_constants.sv"
/***************************************************************************
*
* File: riscv_multicycle.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 18 February 2026
* Modules: riscv_simple_datapath
*
* Description: This module implements a multicycle RISC-V processor. It
* instantiates the datapath module and contains the control logic for the
* control signals that are sent to the datapath. The control logic is
* implemented as a synchronous state machine, where each state corresponds to
* a stage of the instruction execution process (IF, ID, EXE, MEM, WB). Like
* the datapath, this module is parameterized by the initial PC value, and also
* has the same input and output signals as the datapath, taking in an
* instruction as an input and being able to produce the resulting PC and
* data memory address and write data as outputs.
*
****************************************************************************/

module riscv_multicycle #(parameter logic [31:0] INITIAL_PC = 32'h0040_0000)(
        input logic clk, rst,
        input logic [31:0] instruction, dReadData,
        output logic [31:0] PC, dAddress, dWriteData, WriteBackData,
        output logic MemRead, MemWrite
    );

// Instance the control signals that are connected back to the datapath
logic ALUSrc, MemtoReg, PCSrc, zero, RegWrite, loadPC;
logic [3:0] ALUCtrl;


/**********************************
***    DATAPATH INSTANTIATION   ***
**********************************/
/* This is where the datapath module is instantiated. The same (INITIAL_PC)
*  parameter is passed to the datapath module as is passed to this top level,
*  and the (clk), (rst), (instruction), (dReadData), (PC), (dAddress),
*  (dWriteData), and (WriteBackData) signals are all connected directly from
*  this module to the datapath module. The control signals are determined by
*  synchronouse state machine logic as described below.*/

riscv_simple_datapath #(.INITIAL_PC(INITIAL_PC)) datapath (
    .clk(clk), .rst(rst), .instruction(instruction), .dReadData(dReadData),
    .PCSrc(PCSrc), .ALUSrc(ALUSrc), .RegWrite(RegWrite), .MemtoReg(MemtoReg),
    .ALUCtrl(ALUCtrl), .loadPC(loadPC), .PC(PC), .dAddress(dAddress),
    .dWriteData(dWriteData), .WriteBackData(WriteBackData), .Zero(zero)
);

/**********************************
***     DATAFLOW STATE LOGIC    ***
**********************************/
// Current state and next state variables for control signal SM
logic [2:0] cs, ns;

/* This always_ff block handles the synchronouse state transitions for the
* control signals. Each state is 1 clock cycle long. */
always_ff@(posedge clk) begin
    if (rst)
        cs <= IF;
    else
        cs <= ns;
end

/* This combinational logic block determines the next state based on the
*  current state. Here, the control signals for (RegWrite), (MemRead), 
*  (MemWrite), and (loadPC) are set accordingly.*/
always_comb begin
    loadPC = 0;
    RegWrite = 0;
    MemRead = 0;
    MemWrite = 0;
    case (cs)
        IF: begin
            ns = ID;
        end 
        ID: ns = EXE;
        EXE: ns = MEM;
        MEM:begin
            ns = WB;
            MemRead = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW);
            MemWrite = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SW);
        end
        WB: begin
            ns = IF;
            loadPC = 1;
            RegWrite = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_R_TYPE) ||
                       (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_I_TYPE) ||
                       (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW);
        end
        default: begin
            ns = IF;
            loadPC = 0;
            RegWrite = 0;
            MemRead = 0;
            MemWrite = 0;
        end
    endcase
end


/**********************************
***       CONTROL SIGNALS       ***
**********************************/

/* Set ALUSrc to 1 for instructions that require an immediate value, and 0
   for all other instructions */
assign ALUSrc = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_I_TYPE) ||
                (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW) ||
                (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SW);

/* Combinational logic to determine the ALUCtrl signal based on the instruction
*  opcode and funct3 and funct7 fields. In this module, the ALUCtrl signal is
*  set to ADD_OP for lw an sw instructions, and set to SUB_OP for branch
*  instructions */
always_comb begin
    if ((instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW) || 
        (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SW))
        ALUCtrl = ADD_OP;
    else if (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SB_TYPE)
        ALUCtrl = SUB_OP;
    else begin
        case(instruction[FUNCT3_MSB:FUNCT3_LSB])
            ADD: ALUCtrl = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_I_TYPE) ?
                 ADD_OP : 
                 (instruction[FUNCT7_MSB:FUNCT7_LSB] == FUNCT7_ADD) ? 
                 ADD_OP : SUB_OP;
            SLL: ALUCtrl = SLL_OP;
            SLT: ALUCtrl = SLT_OP;
            XOR: ALUCtrl = XOR_OP;
            SRL: ALUCtrl = (instruction[FUNCT7_MSB:FUNCT7_LSB] == FUNCT7_SRL) ?
                 SRL_OP : SRA_OP;
            OR: ALUCtrl = OR_OP;
            AND: ALUCtrl = AND_OP;
            default: ALUCtrl = ADD_OP;
        endcase
    end       
end

// Assert the MemtoReg signal for lw instructions, and deassert for all other
assign MemtoReg = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_LW);

/* Assert the PCSrc signal for branch instructions where the Zero signal is
   high, indicating the beq condition is met. */
assign PCSrc = (instruction[OPCODE_MSB:OPCODE_LSB] == OPCODE_SB_TYPE) && zero;

endmodule
