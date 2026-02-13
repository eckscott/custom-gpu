// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 100 picoseconds
`timescale 1 ns / 100 ps 
// Header files containing all of the alu_op codes declared as constants
// and the opcode values and bit slicing values for the RISC-V datapath
`include "riscv_alu_constants.sv"
`include "riscv_datapath_constants.sv"
/***************************************************************************
*
* File: riscv_simple_datapath.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 24 January 2026
* Module: riscv_simple_datapath
*
* Description: 
*
****************************************************************************/

module riscv_simple_datapath(
        input logic clk, rst,
        input logic [31:0] instruction, dReadData,
        input logic PCsrc, ALUsrc, RegWrite, MemtoReg, ALUCtrl, loadPC,

        output logic [31:0] PC, dAddress, dWriteData, WriteBackData,
        output logic Zero
    );

localparam INITIAL_PC = 32'h0040_0000;
localparam PC_NORMAL_INCREMENT = 4;

// 32-bit sign extended immediate values for each different operation type
logic [31:0] immI, immS, immSB;

assign immI = {IMM_I_SIGN_EXT_BITS{instruction[IMM_MSB]},
               instruction[IMM_MSB:IMM_I_LSB]}; 
assign immS = {IMM_S_SIGN_EXT_BITS{instruction[IMM_MSB]},
               instruction[IMM_MSB:IMM_S_LSB_1],
               instruction[IMM_S_MSB_2:IMM_S_LSB_2]};
assign immSB = {IMM_SB_SIGN_EXT_BITS{instruction[IMM_MSB]},
                instruction[IMM_MSB],
                instruction[IMM_SB_BIT_11],
                instruction[IMM_SB_BIT_10:IMM_SB_BIT_5],
                instruction[IMM_SB_BIT_4:IMM_SB_BIT_1],
                0};

/* This block updates the PC register on the posedge of the clock and resets
*  to INITIAL_PC when the global (rst) is asserted. The PC is updated to PC + 4
*  when PCCsrc is 1, and updates to PC + immSB when PCsrc is 0
*/
always_ff@(posedge clk) begin
    if (rst)
        PC <= INITIAL_PC;
    else if (loadPC)
        PC <= PCsrc ? (PC + PC_NORMAL_INCREMENT) : (PC + immSB);   
end

/**********************************
***      REGFILE CONNECTION     ***
**********************************/
/* This block of code decodes the instruction for the 2 read registers and the
*  destination register for all operations, and instances the regfile module
*  that handles all the reading and writing of data to and from registers.
*  Details on the exact function of each signal can be seen in the regfile.sv
*  file */

// read reg2, read reg1, and destination register
logic [4:0] rs2, rs1, rd;
assign rs2 = instruction[RS_2_MSB:RS_2_LSB];
assign rs1 = instruction[RS_1_MSB:RS_1_LSB];
assign rd = instruction[RD_MSB:RD_LSB];

// readData1 & readData2 signals
logic [31:0] reg1_data, reg2_data;

// Instance the regfile module as described above
regfile regfile(.clk(clk), .write(RegWrite), .readReg1(rs1),
                    .readReg2(rs2), .writeReg(rd),
                    .writeData(dWriteData), .readData1(reg1_data),
                    .readData2(reg2_data));

/**********************************
***         ALU CONNECTION      ***
**********************************/
/* This block of code instances the ALU module as well as the needed
*  intermediate signals. A MUX is created to decide which value to use for
*  the second operand in ALU operations, either the data from register 2 or
*  an immediate value, determined by the ALUsrc signal.
*/

// intermediate signal to store 2nd operand in ALU operations and result of
// ALU operation
logic [31:0] op2, alu_result;

// MUX to determine whether op2 is loaded with the data from register 2 or
// an immediate value, determined by (ALUsrc)
always_comb begin
    if (ALUsrc) begin
        if (instruction[OPCODE_MSB:OPCODE_LSB] == OP_IMM_OPCODE)
            op2 = immI;
        else if (instruction[OPCODE_MSB:OPCODE_LSB] == OP_STORE_OPCODE)
            op2 = immS;
        else if (instruction[OPCODE_MSB:OPCODE_LSB] == OP_BRANCH_OPCODE)
            op2 = immSB;
    end
    else
        op2 = reg2_data;
end

// Instantiate the ALU module as described above. Further details on the
// function of each signal can be found in the alu.sv file
alu alu(.op1(reg1_data), .op2(op2), .alu_op(ALUCtrl), .zero(Zero),
        .result(alu_result));

/**********************************
***      MEMORY INTERFACE       ***
**********************************/
/* The instruction memory and data memory are not explicitly modeled in this
*  datapath, but the connections to the data memory are made here. The address
*  for the data memory (dAddress) is the output of the ALU, and the data to be
*  written to the data memory is the data from register 2 (reg2_data) */

assign dWriteData = reg2_data;
assign dAddress = alu_result;

/**********************************
***          WRITE BACK         ***
**********************************/
/* The value to be written back to the register file determined by the MemtoReg
*  signal. If MemtoReg is 1, the value to be written back is the data read from
*  the data memory (dReadData), and if MemtoReg is 0, the value to be written
*  back is the result of the ALU operation (alu_result) */

assign WriteBackData = MemtoReg ? dReadData : alu_result;



endmodule
