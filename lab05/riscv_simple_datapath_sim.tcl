##########################################################################
#
# riscv_simple_datapath_sim.tcl
# Author: Ethan Scott
# Class: ECEN 423
#
# This .tcl script will apply the input stimulus to the riscv_simple_datapath
# design
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

# Reset PC
add_force rst 1
run 20 ns
add_force rst 0
run 20 ns

# Set write signal to high
add_force RegWrite 1
run 20 ns

# Perform addi x1, x0, 1
add_force instruction -radix hex fe1080e3
run 20 ns
add_force ALUSrc 0
add_force ALUCtrl 0110
run 20 ns

# End of simulation
