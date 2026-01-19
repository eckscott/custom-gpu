##########################################################################
#
# calc_sim.tcl
# Author: Ethan Scott
# Class: ECEN 423
#
# This .tcl script will apply the input stimulus to the calc design
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

# Issue a reset (btnu) and set all buttons and switches to 0
add_force btnu 1
add_force btnl 0
add_force btnc 0
add_force btnr 0
add_force btnd 0
add_force sw 0
run 10 ns

# Set reset (btnu) back to 0
add_force btnu 0
run 10 ns

# OR OP: op1 = 0, op2(sw) = 0x1234
add_force sw 1234 -radix hex
add_force btnl 0
add_force btnc 1
add_force btnr 1
run 10 ns
add_force btnd 1
run 10 ns
add_force btnd 0
run 50 ns

# AND OP: op1 = 0x1234 op2 = 0x0ff0
add_force sw 0ff0 -radix hex
add_force btnl 0
add_force btnc 1
add_force btnr 0
run 10 ns
add_force btnd 1
run 10 ns
add_force btnd 0
run 50 ns

# ADD OP: op1 = 0x0230 op2 = 0x324f
add_force sw 324f -radix hex
add_force btnl 0
add_force btnc 0
add_force btnr 0
run 10 ns
add_force btnd 1
run 10 ns
add_force btnd 0
run 50 ns

# SUB OP: op1 = 0x347f op2 = 0x2d31
add_force sw 2d31 -radix hex
add_force btnl 0
add_force btnc 0
add_force btnr 1
run 10 ns
add_force btnd 1
run 10 ns
add_force btnd 0
run 50 ns

# XOR OP: op1 = 0x074e op2 = 0xffff
add_force sw ffff -radix hex
add_force btnl 1
add_force btnc 0
add_force btnr 0
run 10 ns
add_force btnd 1
run 10 ns
add_force btnd 0
run 50 ns

# SLT OP: op1 = 0xf8b1 op2 = 0x7346
add_force sw 7346 -radix hex
add_force btnl 1
add_force btnc 0
add_force btnr 1
run 10 ns
add_force btnd 1
run 10 ns
add_force btnd 0
run 50 ns

# SLT OP: op1 = 0x0001 op2 = 0xffff
add_force sw ffff -radix hex
add_force btnl 1
add_force btnc 0
add_force btnr 1
run 10 ns
add_force btnd 1
run 10 ns
add_force btnd 0
run 50 ns

# End of simulation
