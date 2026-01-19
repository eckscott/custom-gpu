// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 100 picoseconds
`timescale 1 ns / 100 ps 
// Header file containing all of the alu_op codes declared as constants
`include "riscv_alu_constants.sv"

/***************************************************************************
*
* File: alu.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 19 January 2026
* Module: alu
*
* Description:
*    This module includes combinational logic for the operations of the ALU.
*    This module takse 2 32-bit inputs (op1 and op2) each respectively
*    representing the 2 operands for basic arithmetic logic. This module can
*    handle bitwise AND, OR, two's complement addition, two's complement
*    subtraction, set less than, shift right logical, shift left logical,
*    shift right arithmetic, and XOR operation on the two operands and stores
*    the result in the output 32-bit result register. The module also takes
*    a 4 bit input opcode (alu_op) which determines which operation to perform
*
****************************************************************************/

module alu(
        input logic [31:0] op1, op2, 
        input logic [3:0] alu_op,       
        output logic zero,         
        output logic [31:0] result
    );

    /* The combinational logic block that performs an arithmetic operation
    *  on the two operands based on the value of alu_op. alu_op constants are
    *  defined in the riscv_alu_constants header file included at the top
    */
    always_comb begin
        case(alu_op)
            AND_OP:
                result = op1 & op2;
            OR_OP:
                result = op1 | op2;
            ADD_OP:
                result = $signed(op1) + $signed(op2);
            SUB_OP:
                result = $signed(op1) - $signed(op2);
            SLT_OP:
                result = $signed(op1) < $signed(op2);
            SRL_OP:
                result = op1 >> op2[4:0];
            SLL_OP:
                result = op1 << op2[4:0];
            SRA_OP:
                result = $unsigned($signed(op1) >>> op2[4:0]);
            XOR_OP:
                result = op1 ^ op2;
            default:
                result = $signed(op1) + $signed(op2);
        endcase
    end

    assign zero = (result == 0);

    

endmodule
