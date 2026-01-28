##########################################################################
#
# regfile_top_sim.tcl
# Author: Ethan Scott
# Class: ECEN 423
#
# This .tcl script will apply the input stimulus to the regfile_top design
#
##########################################################################

# restart the simulation at time 0
restart

# Run circuit with no input stimulus settings
run 20 ns

# Set the clock to oscillate with a period of 10 ns
add_force clk {0} {1 5} -repeat_every 10

# Run the circuit for two clock cycles
run 20 ns

# Assert global reset
add_force btnu 1
run 20 ns
add_force btnu 0
run 20 ns

#### Load value of 0x00001234 to register x1 ####
# Set write address to 1
add_force sw 0000010000000000
add_force run 10 ns
add_force btnl 1
run 20 ns
add_force btnl 0
run 20 ns

# Load constant 0x00001234 to register x1
add_force sw a0001234 -radix hex
add_force run 10 ns
add_force btnc 1
run 20 ns
add_force btnc 0
run 20 ns

#### Write the value 0x00003678 to register x2 ####
# Set write address to 2
add_force sw 0000100000000000
add_force run 10 ns
add_force btnl 1
run 20 ns
add_force btnl 0
run 20 ns

# Write value 0x00003678 to register x2
add_force sw a0003678 -radix hex
run 10 ns
add_force btnc 1
run 20 ns
add_force btnc 0
run 20 ns

#### and x3, x1, x2 ####
add_force sw 0000110001000001
run 10 ns
add_force btnl 1
run 20 ns
add_force btnl 0
run 20 ns

add_force sw 0
run 10 ns
add_force btnc 1
run 20 ns
add_force btnc 0
run 20 ns

# End of simulation
