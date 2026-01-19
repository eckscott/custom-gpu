`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_alu.sv
//
//  Author: Mike Wirthlin
//
//////////////////////////////////////////////////////////////////////////////////

// Note for Instructor and TA's: If this testbench is modified, make sure that the exercise questions from the learning  
// suite lab report are accurate with corresponding the simulation timing and answer. 

module tb_alu #(int NUM_RANDOM_TESTS=25)();

    logic zero;
    logic [31:0] op1, op2, result;
    logic [3:0] alu_op;

    int errors = 0;

    typedef struct {
        logic [31:0] operandA;
        logic [31:0] operandB;
    } operand_t;

    // Specific test vectors to test for all operations
    operand_t test_instructions [] = '{
        '{32'h00000000, 32'h00000000}, // Corner cases
        '{32'hFFFFFFFF, 32'hFFFFFFFF}, 
        '{32'h77777777, 32'h77777777}, 
        '{32'hFFFFFFFF, 32'h00000001}, 
        '{32'h00000001, 32'hFFFFFFFF}, 
        '{32'hFFFFFFFF, 32'h00000000}, 
        '{32'h00000000, 32'hFFFFFFFF}, 
        '{32'hAAAAAAAA, 32'h55555555}, // Bit manipulatin patterns
        '{32'h55555555, 32'hAAAAAAAA},
        '{32'h55555555, 32'hFFFF0000},
        '{32'h0000FFFF, 32'h0000FFFF},
        '{32'h00FFFF00, 32'h0000FFFF},
        '{32'hFFFF0000, 32'h0000FFFF},
        '{32'hFFFF0000, 32'h00FFFF00},
        '{32'hFFFF0000, 32'hFFFF0000},
        '{32'h7FFFFFFF, 32'h7FFFFFFF}, // Arithmetic tests. Pos/Pos
        '{32'h00000001, 32'h7FFFFFFF},
        '{32'h7FFFFFFF, 32'h00000001}, 
        '{32'h7FFFFFFF, 32'hFFFFFFFF}, // Pos/Neg
        '{32'hFFFFFFFF, 32'h7FFFFFFF}, // neg/pos
        '{32'hFFFFFFFF, 32'h80000000}, // neg/neg
        '{32'h00001234, 32'h00000000}, // Shifts
        '{32'h00001234, 32'h00000005}, 
        '{32'h00001234, 32'h0000001F}, 
        '{32'h00001234, 32'h00000020}, 
        '{32'hFFFF0000, 32'h00000000}, 
        '{32'hFFFF0000, 32'h00000005}, 
        '{32'hFFFF0000, 32'h0000001F}, 
        '{32'hFFFF0000, 32'h00000020}, 
        '{32'h39FE1CD7, 32'hDB1E0246}, // Random values
        '{32'h00000001, 32'h00000002}  // Last dummy entry
    };

    // ALU operation type
    typedef enum logic [3:0] {
        AND  = 4'b0000,
        OR   = 4'b0001,
        ADD  = 4'b0010,
        SUB  = 4'b0110,
        LT   = 4'b0111,        
        SRL  = 4'b1000,
        SLL  = 4'b1001,
        SRA  = 4'b1010,
        XOR  = 4'b1101
    } aluop_t;

    // ALU operation type constants
    localparam aluop_t ALUOP_AND = AND;
    localparam aluop_t ALUOP_OR = OR;
    localparam aluop_t ALUOP_ADD = ADD;
    localparam aluop_t ALUOP_SUB = SUB;
    localparam aluop_t ALUOP_LT = LT;
    localparam aluop_t ALUOP_SRL = SRL;
    localparam aluop_t ALUOP_SLL = SLL;
    localparam aluop_t ALUOP_SRA = SRA;
    localparam aluop_t ALUOP_XOR = XOR;

    // Function to check if inputs are defined
    function logic [15:0] inputs_defined();
        inputs_defined = 1;
        if (^op1 === 1'bX || ^op2 === 1'bX || ^alu_op === 1'bX)
            inputs_defined = 0;
    endfunction

    // function to check if the outputs are defined
    function logic [15:0] results_defined();
        if (^result === 1'bX || ^zero === 1'bX)
            results_defined = 0;
        else
            results_defined = 1;
    endfunction

    // Task for simulating a single ALU operation
    task sim_alu_op;
        input [3:0] operation;
        input [31:0] operand1, operand2;
        aluop_t op;
        op = aluop_t'(operation);
        begin
            op1 = operand1;
            op2 = operand2;
            alu_op = operation;
            #5 // There is no clock so using a delay
            $display("[%0t] %08h %s (%04b) %08h = %08h (zero=%b)", $time, op1, op.name(), 
                operation, op2, result, zero);
            #5;
        end
    endtask

    // Task for simulating all ALU operations with predefined vectors
    task sim_alu_vectors;
        aluop_t alu_op;
        begin
            for (alu_op = alu_op.first(); alu_op != alu_op.last(); alu_op = alu_op.next()) begin
                $display("Testing opcode = %s (0x%0h)", alu_op.name(), alu_op);
                foreach (test_instructions[i])
                    sim_alu_op(alu_op,test_instructions[i].operandA,test_instructions[i].operandB);
            end            
        end
    endtask

    // Task for simulating random inputs on all ALU operations
    task sim_alu_op_random;
        input int num_tests;
        aluop_t alu_op;
        integer i;
        begin
            for(i=0; i < num_tests; i=i+1) begin
                for (alu_op = alu_op.first(); alu_op != alu_op.last(); alu_op = alu_op.next())
                    sim_alu_op(alu_op,$urandom,$urandom);
            end
        end
    endtask

    // Instance alu module
    alu alu_dut(.*);

    // Start of simulation
    initial begin
        int i,j,test_count;
        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
        $timeformat(-9, 0, " ns", 20);
        $display("*** Start of ALU Testbench Simulation ***");
        
        // Run for some time without valid inputs
        #50
        
        // Set values to all zero
        alu_op = 0;
        op1 = 0;
        op2 = 0;
        #50

        // Test each ALU operation with predefined vectors
        sim_alu_vectors();

        // Test all control inputs with random stimulus
        $display("*** Random Testsb ***");
        sim_alu_op_random(NUM_RANDOM_TESTS);

        if (errors != 0) begin
            $display("*** Simulation Failed ***");
            $display("  *** %0d Errors ***",errors);
            // $fatal;
        end else begin
            $display("*** Simulation Complete ***");
            $display("===== TEST PASSED =====");
        end
        $finish;
        
    end  // end initial

    logic expected_zero;
    assign expected_zero = (result == 0);
    // Check the zero output
    always@(alu_op, op1, op2) begin
        // Wait 5 ns after op has changed
        #5
        // See if any of the inputs are 'x'. If so, ignore
        if (inputs_defined()) begin
            if ((zero == 1'bz) || (zero == 1'bx)) begin
                $display("***Error***: Invalid 'zero' value");
                // $fatal;
                errors = errors + 1;
            end
            else begin
                if (zero != expected_zero) begin
                    $display("***Error***: Invalid 'zero' value. Received %x but expecting %x", zero, expected_zero);
                    // $fatal;
                    errors = errors + 1;
                end
            end
        end
    end


    // Check the result
    logic [31:0] expected_result;
    always@(alu_op, op1, op2) begin
        // Wait 5 ns after op has changed
        #5
        // See if any of the inputs are 'x'. If so, ignore
        if (inputs_defined()) begin
            if (!results_defined()) begin
                $display("[%0t] ****Error****: Invalid result (x's)", $time);
                errors = errors + 1;
                // $fatal;
            end
            else begin
                case(alu_op)
                    ALUOP_AND: expected_result = op1 & op2;
                    ALUOP_OR: expected_result = op1 | op2;
                    ALUOP_ADD: expected_result = op1 + op2;
                    ALUOP_SUB: expected_result = op1 - op2;
                    ALUOP_LT: expected_result = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
                    ALUOP_SRL: expected_result = op1 >> op2[4:0]; 
                    ALUOP_SLL: expected_result = op1 << op2[4:0]; 
                    ALUOP_SRA: expected_result = $unsigned($signed(op1) >>> op2[4:0]); 
                    ALUOP_XOR: expected_result = op1 ^ op2; 
                    default: expected_result = op1 + op2;
                endcase
                if (result != expected_result) begin
                    $display("[%0t] **** Error ****: Invalid 'result' value %x but expecting %x", $time, result, expected_result);
                    // $fatal;
                    errors = errors + 1;
                end
            end
        end
    end

endmodule
