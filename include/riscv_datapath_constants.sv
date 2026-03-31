 /***************************************************************************
*
* File: riscv_datapath_constants.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 11 February 2026
*
* Description:
*    This header file contains all of the declared constants for the RISC-V
*    datapath, including the initial PC value and the opcode values for the
*    various instruction types.
*
****************************************************************************/
`ifndef RISCV_DATAPATH_CONSTANTS
`define RISCV_DATAPATH_CONSTANTS
    // Op codes for the various instruction types
    localparam OPCODE_I_TYPE = 7'b0010011;
    localparam OPCODE_R_TYPE = 7'b0110011;
    localparam OPCODE_LW = 7'b0000011;
    localparam OPCODE_SW = 7'b0100011;
    localparam OPCODE_SB_TYPE = 7'b1100011;
    localparam OPCODE_U_TYPE = 7'b0110111;
    localparam OPCODE_JALR = 7'b1100111;
    localparam OPCODE_JAL = 7'b1101111;

    // Bits for bit slicing in decoding the instruction
    localparam OPCODE_MSB = 6;
    localparam OPCODE_LSB = 0;
    localparam IMM_MSB = 31;
    localparam IMM_I_LSB = 20;
    localparam IMM_S_LSB_1 = 25;
    localparam IMM_S_MSB_2 = 11;
    localparam IMM_S_LSB_2 = 7;
    localparam IMM_SB_BIT_11 = 7;
    localparam IMM_SB_BIT_4 = 11;
    localparam IMM_SB_BIT_1 = 8;
    localparam IMM_SB_BIT_10 = 30;
    localparam IMM_SB_BIT_5 = 25;
    localparam IMM_UJ_BIT_19 = 19;
    localparam IMM_UJ_BIT_12 = 12;
    localparam IMM_UJ_BIT_11 = 20;
    localparam IMM_UJ_BIT_10 = 30;
    localparam IMM_UJ_BIT_1 = 21;
    localparam IMM_UJ_MSB = 31;
    localparam IMM_U_MSB = 31;
    localparam IMM_U_LSB = 12;

    // Bit lengths for padding to 32-bit immediates
    localparam IMM_I_SIGN_EXT_BITS = 20;
    localparam IMM_S_SIGN_EXT_BITS = 20;
    localparam IMM_SB_SIGN_EXT_BITS = 19;
    localparam IMM_UJ_SIGN_EXT_BITS = 12;
    localparam IMM_U_0_PAD_BITS = 12;

    // Register addressing in instruction
    localparam RS_2_MSB = 24;
    localparam RS_2_LSB = 20;
    localparam RS_1_MSB = 19;
    localparam RS_1_LSB = 15;
    localparam RD_MSB = 11;
    localparam RD_LSB = 7;

    // States for the control signal state machine
    localparam IF = 3'b000,
               ID = 3'b001,
               EXE = 3'b010,
               MEM = 3'b011,
               WB = 3'b100;

    // Register addressing for funct3 and funct7
    localparam FUNCT3_MSB = 14;
    localparam FUNCT3_LSB = 12;
    localparam FUNCT7_MSB = 31;
    localparam FUNCT7_LSB = 25;

    // Different FUNCT3 codes
    localparam ADD = 3'b000;
    localparam SLL = 3'b001;
    localparam SLT = 3'b010;
    localparam XOR = 3'b100;
    localparam SRL = 3'b101;
    localparam OR = 3'b110;
    localparam AND = 3'b111;

    // Different Branch FUNCT3 codes
    localparam BEQ = 3'b000;
    localparam BNE = 3'b001;
    localparam BLT = 3'b100;
    localparam BGE = 3'b101;

    // Different FUNCT7 codes
    localparam FUNCT7_ADD = 7'b0000000;
    localparam FUNCT7_SRL = 7'b0000000;

`endif