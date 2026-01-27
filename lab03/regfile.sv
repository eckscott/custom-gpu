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
* Description: This module creates a regfile like the one in the RISC-V
*   processor. The register file contains 32 registers (x0 - x31) each
*   being 32-bits wide. The operations in this module handle the writing
*   of data (writeData) to specific registers (writeReg) when the write signal
*   is high (write). It also handles the reading of data (readData1, readData2)
*   from specific registers (readReg1, readReg2). It is configured to be write
*   first design, and always maints the value of 0 in x0.
*
****************************************************************************/

module regfile(
        input logic clk, write,
        input logic [4:0] readReg1, readReg2, writeReg,
        input logic [31:0] writeData,
        output logic [31:0] readData1, readData2
    );

    logic [31:0] register[31:0];

    // Initialize all the registers to 0
    integer i;
    initial
        for (i = 0; i < 32; i = i + 1)
            register[i] = 0;

    /* The sequential logic block that describes the memory of the register
    *  file in write-first mode. The readData registers read from the registers
    *  at readReg1 and readReg2. When the write signal goes high, on the next
    *  posedge clock cycle the data from writeData will be written into the
    *  address of writeReg. This block also protects register 0x to always
    *  be 0.
    */
    always_ff@(posedge clk) begin
        readData1 <= register[readReg1];
        readData2 <= register[readReg2];
        if (write && writeReg != 0) begin
            register[writeReg] <= writeData;
            if (readReg1 == writeReg)
                readData1 <= writeData;
            if (readReg2 == writeReg)
                readData2 <= writeData;
        end 
    end

endmodule
