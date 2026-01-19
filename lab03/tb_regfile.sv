`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_regfile.sv
//
//////////////////////////////////////////////////////////////////////////////////

// Note for Instructor and TA's: If this testbench is modified, make sure that the exercise questions from the learning  
// suite lab report are accurate with corresponding the simulation timing and answer. 

module tb_regfile();

	logic tb_clk, tb_write;
    logic tb_init = 0;
    logic [4:0] regAddrA, regAddrB, regAddrWrite;
    logic [31:0] regWriteData, regReadDataA, regReadDataB;
    integer num_random = 300;

    // clock generation
    initial begin
        tb_clk = 0;
        forever #5 tb_clk <= ~tb_clk; // 100MHz clock
    end

	// Instance regfile module
    regfile my_regfile(.clk(tb_clk), .readReg1(regAddrA), .readReg2(regAddrB), .writeReg(regAddrWrite),
        .writeData(regWriteData), .write(tb_write), .readData1(regReadDataA), .readData2(regReadDataB));


    regfileBehavioralModel model(.clk(tb_clk), .initialized(tb_init), .regAddrA(regAddrA), .regAddrB(regAddrB), .regAddrWrite(regAddrWrite),
                             .regWriteData(regWriteData), .regWrite(tb_write), .regReadDataA(regReadDataA),
                             .regReadDataB(regReadDataB));

    task register_event(input logic [4:0] addrA, input logic [4:0] addrB, 
        input logic [4:0] addrW, input logic [31:0] data, input logic write_en = '0);
        @(negedge tb_clk);
        regAddrWrite=addrW;
        regWriteData=data;
        regAddrA=addrA;
        regAddrB=addrB;
        tb_write = write_en;
        $write("[%0t] A=%08h B=%08h:", $time, regReadDataA, regReadDataB);
        $write(" addrA=%02h addrB=%02h addrW=%02h, we=%01b dataW=%08h", regAddrA, regAddrB, regAddrWrite, write_en, regWriteData);
        @(negedge tb_clk);
        tb_write = 0;
        $display(" : dataA=%08h dataB=%08h", regReadDataA, regReadDataB);
    endtask

    // Write a word to the register file
    task write_word(input [4:0] addr, input [31:0] data);
        register_event(0, 0, addr, data, 1);
    endtask

    // Read words from the register file
    task read_words(input [4:0] addrA, input [4:0] addrB);
        register_event(addrA, addrB, 0, 0, 0);
    endtask

	initial begin
	    int i,j;

        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
		$timeformat(-9, 0, " ns", 20);
		$display("*** Start of Regfile Testbench Simulation ***");		
		// Run for some time without valid inputs
		#50		
		// execute a few clocks without any initialization
        repeat(3) @(negedge tb_clk);
        // Initilize inputs
        regAddrA=0;
        regAddrB=0; 
        regAddrWrite=0;
        regWriteData=0;
        tb_write = 0;
        // Run a few clock cycles.
        repeat(3) @(negedge tb_clk);
        tb_init = 1;
        @(negedge tb_clk);
        // Check to see if all register values are initialized to zero
		$display("*** Read initial values of register at time %0t", $time);
        for(i=0; i < 32; i=i+1)
            read_words(i,i);
        repeat(5) @(negedge tb_clk);

		$display("*** Testing x0 register at time %0t", $time);
        // Write non-zero values to register x0 (simultaneous write/and read to x0)
        for(i=0; i < 32; i=i+1)
            register_event(0, 0, 0, $urandom, 1);
        repeat(5) @(negedge tb_clk);
        // initialize memories (with non-zero value in 0)
		$display("*** Testing write to each register at %0t", $time);
        for(i=1; i < 32; i=i+1) begin
            write_word(i,i);
            read_words(i,i);
        end
        repeat(5) @(negedge tb_clk);

        // Perform simultaneous reads and writes to the same register
		$display("*** Testing simultaneous reads and writes to each register at %0t", $time);
        for(i=0; i < 32; i=i+1)
            register_event(i, i-1, i, i|i<<8|i<<16|i<<24, 1);
        repeat(5) @(negedge tb_clk);

        // read contents of memory
		$display("*** Testing different read addresses at %0t", $time);
        for(i=0; i < 32; i=i+1)
            read_words(i,~i);

        // simulate some transactions
		$display("*** Testing random transactions at %0t", $time);
        for(i=0; i < num_random; i=i+1) begin
            j=$urandom_range(0,3);
            regAddrA=$urandom_range(0,31);
            regAddrB=~$urandom_range(0,31);
            register_event($urandom_range(0,31), $urandom_range(0,31), $urandom_range(0,31),
                i|i<<8|i<<16|i<<24, (j==0));
        end

		// Random delay
        repeat(30) @(negedge tb_clk);

		$display("*** Successful simulation. Ended at %0t *** ", $time);
        $display("===== TEST PASSED =====");
        $finish;
        
	end  // end initial

endmodule

// Behavioral module that will test Register file
module regfileBehavioralModel(clk, initialized, regAddrA, regAddrB, regAddrWrite, regWriteData, regWrite,
    regReadDataA, regReadDataB);

	input wire logic clk;
    input wire logic initialized;
    input wire logic [4:0] regAddrA;
    input wire logic [4:0] regAddrB;
	input wire logic [4:0] regAddrWrite;
    input wire logic [31:0] regWriteData;
	input wire logic regWrite;
    input wire logic [31:0] regReadDataA, regReadDataB;

    logic [31:0] tmpfile [31:0];
    logic [31:0] l_readA, l_readB;

	// Initialize state
	integer i;
	initial begin
	    //$display("Initializing Register File Model");
        for (i=0;i<32;i=i+1)
           tmpfile[i] = 0;
    end

	// checking state
	always@(negedge clk) begin
		if (initialized) begin
			if (l_readA != regReadDataA) begin
				$display("*** Error: Model read port A=0x%h but should be 0x%h at time %0t", 
                    regReadDataA, l_readA,  $time);
				$finish;
			end
			if (l_readB != regReadDataB) begin
				$display("*** Error: Model read port B=0x%h but should be 0x%h at time %0t", 
                    regReadDataB, l_readB,  $time);
				$finish;
			end
			if (^regReadDataB[0] === 1'bX) begin
				$display("**** Error: 'x' Values on B read port at time %0t (is memory initialized?)", $time);
				$finish;
			end
			if (^regReadDataA[0] === 1'bX) begin
				$display("**** Error: 'x' Values on A read port at time %0t (is memory initialized?)", $time);
				$finish;
			end
		end
	end

    // Register file behavioral model
	always@(posedge clk) begin
        if (initialized) begin
            l_readA <= tmpfile[regAddrA];
            l_readB <= tmpfile[regAddrB];
            if (regWrite && regAddrWrite !=0) begin
                tmpfile[regAddrWrite] <= regWriteData;
                // if reading same register we are wrting, return new data
                if (regAddrA == regAddrWrite)
                    l_readA <= regWriteData;
                if (regAddrB == regAddrWrite)
                    l_readB <= regWriteData;
            end        
        end
    end

endmodule
