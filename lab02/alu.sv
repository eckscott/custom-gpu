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
*    This module includes a state machine that will provide a one cycle
*    signal every time one of the buttons is pressed. This signal
*    is used to increment or decrement a counter that is displayed on the LEDs.
*    The top button (btnu) is used to increment the counter by 1.
*    The bottom button (btnd) is used to decrement the counter by 1.
*    The left button (btnl) is used to increment the counter by the value
*    indicated on the switches (sw).
*    The right button (btnr) is used to decrement the counter by the value
*    indicated on the swithces (sw).
*    The center button (btnc) is used as a synchronous reset.
*
****************************************************************************/

module alu(
        input logic [31:0] op1, op2,    // Operands 1 and 2
        input logic [3:0] alu_op,       // alu_op code (indicates which op)
        output logic zero,              // Indicates when ALU result is 0
        output logic [31:0] result      // ALU Result
    );

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

    

endmodule
