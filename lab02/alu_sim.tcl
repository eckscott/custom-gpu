##########################################################################
#
# alu_sim.tcl
# Author: Ethan Scott
# Class: ECEN 423
#
# This .tcl script will apply the input stimulus to the alu design. This
# tcl file compares the output to the values previously calculated in the
# preliminary section of this lab
#
##########################################################################

# restart the simulation at time 0
restart

# Run circuit with no input stimulus settings
run 20 ns

# Set original 32-bit values for op1 & op2 (same values as preliminary)
add_force op1 f3212f37 -radix hex
add_force op2 621c3ee7 -radix hex
run 10 ns

# Perform ADD_OP
add_force alu_op 0000
run 10 ns

set result_val [get_value result]
if {$result_val ne "62002e27"} {
    puts "ERROR: RESULT = $result_val, expected 62002e27"
} else {
    puts "PASS: result is correct"
}

# Perform OR_OP
add_force alu_op 0001
run 10 ns

set result_val [get_value result]
if {$result_val ne "f33d3ff7"} {
    puts "ERROR: RESULT = $result_val, expected f33d3ff7"
} else {
    puts "PASS: result is correct"
}

# Perform ADD_OP
add_force alu_op 0010
run 10 ns

set result_val [get_value result]
if {$result_val ne "553d6e1e"} {
    puts "ERROR: RESULT = $result_val, expected 553d6e1e"
} else {
    puts "PASS: result is correct"
}

# Perform SUB_OP
add_force alu_op 0110
run 10 ns

set result_val [get_value result]
if {$result_val ne "9104f050"} {
    puts "ERROR: RESULT = $result_val, expected 9104f050"
} else {
    puts "PASS: result is correct"
}

# Perform SLT_OP
add_force alu_op 0111
run 10 ns

set result_val [get_value result]
if {$result_val ne "00000001"} {
    puts "ERROR: RESULT = $result_val, expected 1"
} else {
    puts "PASS: result is correct"
}

# Perform SRL_OP
add_force alu_op 1000
run 10 ns

set result_val [get_value result]
if {$result_val ne "01e6425e"} {
    puts "ERROR: RESULT = $result_val, expected 01e6425e"
} else {
    puts "PASS: result is correct"
}

# Perform SLL_OP
add_force alu_op 1001
run 10 ns

set result_val [get_value result]
if {$result_val ne "90979b80"} {
    puts "ERROR: RESULT = $result_val, expected 90979b80"
} else {
    puts "PASS: result is correct"
}

# Perform SRA_OP
add_force alu_op 1010
run 10 ns

set result_val [get_value result]
if {$result_val ne "ffe6425e"} {
    puts "ERROR: RESULT = $result_val, expected ffe6425e"
} else {
    puts "PASS: result is correct"
}

# Perform XOR_OP
add_force alu_op 1101
run 10 ns

set result_val [get_value result]
if {$result_val ne "913d11d0"} {
    puts "ERROR: RESULT = $result_val, expected 913d11d0"
} else {
    puts "PASS: result is correct"
}

# End of simulation
