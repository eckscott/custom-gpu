// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 100 picoseconds
`timescale 1 ns / 100 ps 

/***************************************************************************
*
* File: updownbuttoncount.sv
*
* Author: Ethan Scott
* Class: ECEN 423, Sec 01, Winter 2026
* Date: 9 January 2026
* Module: updownbuttoncount
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

module updownbuttoncount(
        input logic clk,
        input logic btnc, btnu, btnd, btnl, btnr,
        input logic [15:0] sw,
        output logic [15:0] led
    );

    // The internal 16-bit count signal.
    logic [15:0] count_i;
    // The increment counter output from the one shot module
    logic inc1_count, dec1_count, inc_sw_count, dec_sw_count;
    logic btnu_sync, btnd_sync, btnl_sync, btnr_sync;
    // reset signal
    logic rst;

    // Assign the 'rst' signal to button c
    assign rst = btnc;

    /********************************************************
    ************ synchronizer & oneshot for btnu ************
    ********************************************************/

    // Instance the synchronizer for btnu
    synchronizer u_sync (.clk(clk), .rst(rst), .in(btnu), .out(btnu_sync));

    // Instance the OneShot module
    oneshot u_os (.clk(clk), .rst(rst), .in(btnu_sync), .os(inc1_count));

    /********************************************************
    ************ synchronizer & oneshot for btnd ************
    ********************************************************/

    // Instance the synchronizer for btnd
    synchronizer d_sync (.clk(clk), .rst(rst), .in(btnd), .out(btnd_sync));

    // Instance the OneShot module
    oneshot d_os (.clk(clk), .rst(rst), .in(btnd_sync), .os(dec1_count));

    /********************************************************
    ************ synchronizer & oneshot for btnl ************
    ********************************************************/

    // Instance the synchronizer for btnl
    synchronizer l_sync (.clk(clk), .rst(rst), .in(btnl), .out(btnl_sync));

    // Instance the OneShot module
    oneshot l_os (.clk(clk), .rst(rst), .in(btnl_sync), .os(inc_sw_count));

    /********************************************************
    ************ synchronizer & oneshot for btnr ************
    ********************************************************/

    // Instance the synchronizer for btnr
    synchronizer r_sync (.clk(clk), .rst(rst), .in(btnr), .out(btnr_sync));

    // Instance the OneShot module
    oneshot r_os (.clk(clk), .rst(rst), .in(btnr_sync), .os(dec_sw_count));

    // 16-bit Counter. Increments once each time button-up is pressed,
    // decrements once each time button-down is pressed, increments
    // the value of the switches (sw) each time button-left is pressed,
    // and decrements the value of the switches (sw) each time button-right
    // is pressed
    //
    always_ff@(posedge clk)
        if (rst)
            count_i <= 0;
        else if (inc1_count)
            count_i <= count_i + 1;
        else if (dec1_count)
            count_i <= count_i - 1;
        else if (inc_sw_count)
            count_i <= count_i + sw;
        else if (dec_sw_count)
            count_i <= count_i - sw;

    // Assign the 'led' output the value of the internal count_i signal.
    assign led = count_i;

endmodule
