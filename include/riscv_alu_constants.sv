 /***************************************************************************
*
* File: riscv_alu_constants.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 19 January 2026
*
* Description:
*    This header file contains all of the declared constants alu_op codes
*    for alu functionality.
*
****************************************************************************/
 
    // Various possible alu_op commands
    localparam AND_OP = 4'b0000;
    localparam OR_OP = 4'b0001;
    localparam ADD_OP = 4'b0010;
    localparam SUB_OP = 4'b0110;
    localparam SLT_OP = 4'b0111;
    localparam SRL_OP = 4'b1000;
    localparam SLL_OP = 4'b1001;
    localparam SRA_OP = 4'b1010;
    localparam XOR_OP = 4'b1101;