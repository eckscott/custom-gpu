##########################################################################
#
# Filname: vga_sim_new.tcl
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 17 March 2026
#
# This .tcl script will write the ASCII character '!' (0x21) to the VGA
# 
#
##########################################################################


# Start the simulation over
restart

# Run circuit with no input stimulus settings
run 20 ns

# Set the clock to oscillate with a period of 10 ns
add_force clk {0} {1 5} -repeat_every 10
# Run the circuit for a bit
run 40 ns

# Note: there is no top-level reset input to this system. The reset is generated
# within the FPGA by the power-on reset circuitry. No reset is needed for this
# TCL simulation.

# set the top-level inputs
add_force btnc 0
add_force btnl 0
add_force btnr 0
add_force btnu 0
add_force btnd 0
add_force sw 0 -radix hex
add_force RsTx 1

# Run the simulator until the screen has been cleared
run 984970 ns

# Put your test stimulus here
add_force sw 21 -radix hex
add_force btnr 1
run 18 us
add_force btnr 0
run 18 us

# Exit when done
exit

