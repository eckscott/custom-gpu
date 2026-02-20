##########################################################################
#
# riscv_multicycle_sim.tcl
# Author: Ethan Scott
# Class: ECEN 423
#
# This .tcl script will apply the input stimulus to the riscv_multicycle
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

# Perform addi x1, x0, 1
add_force instruction -radix hex 00100093
run 50 ns

# Perform addi x2, x1, -3
add_force instruction -radix hex ffd08113
run 50 ns

# Perform andi x3, x2, -1
add_force instruction -radix hex fff17193
run 50 ns

# End of simulation
