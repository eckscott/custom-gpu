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
*  when ALU_src is 1, and updates to PC + immSB when ALU_src is 0
*/
always_ff@(posedge clk) begin
    if (rst)
        PC <= INITIAL_PC;
    else if (loadPC)
        PC <= PCsrc ? (PC + 4) : (PC + immSB);   
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

// Instance the regfile module as described above
regfile regfile(.clk(clk), .write(RegWrite), .readReg1(rs1),
                    .readReg2(rs2), .writeReg(rd),
                    .writeData(dWriteData), .readData1(),
                    .readData2());




endmodule
