// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 100 picoseconds
`timescale 1 ns / 100 ps 
// Header file containing all of the alu_op codes declared as constants
`include "riscv_alu_constants.sv"

/***************************************************************************
*
* File: calc.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 19 January 2026
* Module: calc
*
* Description: This calculator module instances the alu module,
*              synchronizer module, and oneshot module to create a calculator
*              using the alu operations. It takes a previously stored value
*              (accum) that came from the previous alu result, and performs
*              an operation with another operand inputted by the user on the
*              switches (sw) which then displays the resulting values via the
*              leds. The operation is decided by certain combination of button
*              presses from btnl, btnc, and btnr. Btnd updates the value of
*              the leds, and btnu resets everything back to zero. 
*
****************************************************************************/

module calc(
        input logic clk, btnc, btnl, btnu, btnr, btnd,
        input logic [15:0] sw,
        output logic [15:0] led
    );

    logic [15:0] accum;     // accumulator that holds the curr val of the calc
    logic [31:0] alu_result;  // result of alu operation
    logic [31:0] se_accum, se_sw; // se stands for "sign extended". Here,
                                 // se_accum is the sign extended value of
                                 // accum, and se_sw is the sign extended
                                 // value of the switches (sw)
    logic btnd_sync, update_accum, alu_zero;
    logic rst;
    logic [3:0] alu_op;

    assign rst = btnu;

    // logic for sign extending accum and sw into 32 bit registers
    assign se_accum = {{16{accum[15]}}, accum};
    assign se_sw = {{16{sw[15]}}, sw};


    /********************************************************
    ************ ALU module for arithmetic operations *******
    ********************************************************/

    // instance the alu module to perform arithmetic operations for the
    // calculator
    alu alu (.op1(se_accum), .op2(se_sw), .alu_op(alu_op), .zero(alu_zero), .result(alu_result));


    /********************************************************
    ************ synchronizer & oneshot for btnd ************
    ********************************************************/

    // Instance the synchronizer for btnd
    synchronizer d_sync (.clk(clk), .rst(rst), .in(btnd), .out(btnd_sync));

    // Instance the OneShot module
    oneshot d_os (.clk(clk), .rst(rst), .in(btnd_sync), .os(update_accum));


    /* This is the accumulator register. It resets on the global reset
    *  which in this case is btnu. It is updated on every btnd press with
    *  the first 16-bits of the result output of the ALU module. It then
    *  assigns the value of the led to this accumulator value
    */
    always_ff@(posedge clk) begin
        if (rst)
            accum <= 0;
        else begin
            if (update_accum)
                accum <= alu_result[15:0];
        end
    end

    assign led = accum;


    /* The combinational logic for determining what the alu_op is based
    *  on the button push combination of btnl, btnc, and btnr
    */
    assign alu_op = (btnl && btnc && btnr) ? SRA_OP :
                    (btnl && btnc && (~btnr)) ? SLL_OP:
                    (btnl && (~btnc) && btnr) ? SLT_OP:
                    (btnl && (~btnc) && (~btnr)) ? XOR_OP:
                    ((~btnl) && btnc && btnr) ? OR_OP:
                    ((~btnl) && btnc && (~btnr)) ? AND_OP:
                    ((~btnl) && (~btnc) && btnr) ? SUB_OP: ADD_OP;

endmodule
