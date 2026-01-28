// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 100 picoseconds
`timescale 1 ns / 100 ps 

/***************************************************************************
*
* File: regfile_top.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 27 January 2026
* Modules: regfile_top, regfile, alu, synchronizer, oneshot
*
* Description: This module connects the regfile and the alu modules, creating
*   a simple dataflow circuit similar to the RISC-V datapath circuit. The
*   circuit stores values in the register file by asserting the write signal
*   (btnc) and performs ALU operations on the values stored in the ALU like
*   the RISC-V processor. The register address is set using the values of the
*   lower 15 switches (sw) when (btnl) is asserted. The outputting result of
*   the alu operations is shown on (led), and the upper or lower bits are
*   shown depending on the press of (btnd). (btnu) is treated as the global
*   reset.
*
****************************************************************************/

module regfile_top(
        input logic clk, btnc, btnl, btnu, btnd,
        input logic [15:0] sw,
        output logic [15:0] led
    );

    logic rst;
    logic [14:0] addr_reg;
    logic btnc_sync, btnl_sync, write_sig, alu_zero, sw_load;
    logic [31:0] op1, op2, writeData, se_sw, alu_result;

    // set global reset signal to btnu
    assign rst = btnu;
    // sign extended value of lower 15 switches
    assign se_sw = {{17{sw[14]}}, sw[14:0]};

 
    /**********************************
    ***      REGFILE CONNECTION     ***
    **********************************/
    /* In this block, we load the addr_reg signal with the bottom 15 switches
    *  when btnl is pressed. We then use that signal as the input for the
    *  regfile addresses, setting the first 5 bits to readReg1, the next 5 to
    *  readReg2, and the last 5 towriteReg. The write signal is asserted by
    *  a synchronized and oneshot version of btnc. The writeData is assigned
    *  by a MUX with switch 16 being the select bit. It either loads a sign
    *  extended 32-bit form of the lower 15 switches or the result from the
    *  alu module. The outputting readData signals are loaded into op1 and op2
    *  for the alu module */


    // Instance the synchronizer for btnc
    synchronizer c_sync (.clk(clk), .rst(rst), .in(btnc), .out(btnc_sync));

    // Instance the OneShot module for btnc
    oneshot c_os (.clk(clk), .rst(rst), .in(btnc_sync), .os(write_sig));

    // Instance the synchronizer for btnl
    synchronizer l_sync (.clk(clk), .rst(rst), .in(btnl), .out(btnl_sync));

    // Instance the OneShot module for btnl
    oneshot l_os (.clk(clk), .rst(rst), .in(btnl_sync), .os(sw_load));
    
    /* Load the value of the lower 15 switches into addr_reg when btnl is
    *  pressed */
    always_ff@(posedge clk)
        if (rst)
            addr_reg <= 0;
        else
            if (sw_load)
                addr_reg <= sw[14:0];

    /* A mux that decides what value to load into writeData. If sw[15] is 1,
    *  it will load a sign extended 32-bit value of the lower 15 switches. If
    *  not, it will load the result of the alu module into writeData */
    always_comb
        if (sw[15])
            writeData = se_sw;
        else
            writeData = alu_result;

    // Instantiate the regfile module as described above
    regfile regfile(.clk(clk), .write(write_sig), .readReg1(addr_reg[4:0]),
                    .readReg2(addr_reg[9:5]), .writeReg(addr_reg[14:10]),
                    .writeData(writeData), .readData1(op1),
                    .readData2(op2));

    
    /**********************************
    ***        ALU CONNECTION       ***
    **********************************/
    /* In this block, the alu module is instantiated and connected to the
    *  regfile, where the data read from the regfile is loaded into op1 and
    *  op2. The alu operation is determiend by the lower 4 switches to get
    *  the respective alu_op code. */


    // Instantiate the alu as described above
    alu alu(.op1(op1), .op2(op2), .alu_op(sw[3:0]), .zero(alu_zero),
            .result(alu_result));
    
    // Mux to load readData to leds
    always_comb
        if (btnd)
            led = readData1[31:16];
        else
            led = readData1[15:0];

endmodule
