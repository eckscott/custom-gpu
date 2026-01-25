// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 100 picoseconds
`timescale 1 ns / 100 ps 

/***************************************************************************
*
* File: regfile.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 24 January 2026
* Module: regfile
*
* Description:
*    
*
****************************************************************************/

module regfile(
        input logic clk, write
        input logic [4:0] readReg1, readReg2, writeReg,
        input logic [31:0] writeData,
        output logic [31:0] readData1, readData2
    );

    

endmodule
