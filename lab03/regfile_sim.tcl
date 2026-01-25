##########################################################################
#
# regfile_sim.tcl
# Author: Ethan Scott
# Class: ECEN 423
#
# This .tcl script will apply the input stimulus to the regfile design
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

# Set write signal to low
add_force write 0
run 20 ns

# Write -12 to register x5, read from registers x21, x22
add_force write 1
add_force writeData -12 -radix dec
add_force writeReg 5 -radix dec
add_force readReg1 21 -radix dec
add_force readReg2 22 -radix dec
run 20 ns

# Write 13 to register x6, read from registers x23, x6
add_force writeData 13 -radix dec
add_force writeReg 6 -radix dec
add_force readReg1 23 -radix dec
add_force readReg2 6 -radix dec
run 20 ns

# Write 14 to register x0, read from registers x5, x6
add_force writeData 14 -radix dec
add_force writeReg 0 -radix dec
add_force readReg1 5 -radix dec
add_force readReg2 6 -radix dec
run 20ns

# End of simulation
