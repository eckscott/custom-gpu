##########################################################################
#
# updownbuttoncount_sim.tcl
# Author: Ethan Scott
# Class: ECEN 423
#
# This .tcl script will apply the input stimulus to the updownbuttoncount
# design.
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

# Issue a reset (btnc) and set inc (btnu) to 0
add_force btnc 1
add_force btnu 0
run 10 ns

# Set reset (btnc) back to 0
add_force btnc 0
run 10 ns

# Up count by 3 with 3 btnu button presses
add_force btnu 1
run 10 ns
add_force btnu 0
run 10 ns
add_force btnu 1
run 10 ns
add_force btnu 0
run 10 ns
add_force btnu 1
run 10 ns
add_force btnu 0
run 10 ns

# Down count by 3 with 3 btnd button presses
add_force btnd 1
run 10 ns
add_force btnd 0
run 10 ns
add_force btnd 1
run 10 ns
add_force btnd 0
run 10 ns
add_force btnd 1
run 10 ns
add_force btnd 0
run 10 ns

# Up count by 9 with 3 btnl button presses and the switches set to 3
add_force sw 11
run 50 ns
add_force btnl 1
run 10 ns
add_force btnl 0
run 10 ns
add_force btnl 1
run 10 ns
add_force btnl 0
run 10 ns
add_force btnl 1
run 10 ns
add_force btnl 0
run 10 ns

# Down count by 9 with 3 btnr button presses and the switches set to 3
add_force btnr 1
run 10 ns
add_force btnr 0
run 10 ns
add_force btnr 1
run 10 ns
add_force btnr 0
run 10 ns
add_force btnr 1
run 10 ns
add_force btnr 0
run 50 ns

# Issue a reset (btnc) for one clock cycle
add_force btnc 1
run 10 ns

# Return rst to 0
add_force btnc 0
run 50 ns

# End of simulation
