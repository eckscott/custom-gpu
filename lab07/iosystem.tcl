##########################################################################
#
# iosystem.tcl
# Author: Ethan Scott
# Class: ECEN 423
# Date: 25 February 2026
#
# This .tcl script will apply the input stimulus to the riscv_simple_datapath
# design
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

# set the top-level inputs
add_force btnc 0
add_force btnl 0
add_force btnr 0
add_force btnu 0
add_force btnd 0
add_force sw 0
add_force RsTx 1
run 8 us

puts "Change switches and observe LEDs"
add_force sw a5a5 -radix hex
run 4 us

# ------ Adding my own stimulus ------
puts "--- Testing the multicycle datapath with some custom stimulus ---"
puts "Change switches and observe LEDs (again)"
add_force sw 0001 -radix hex
run 4 us

# Btnu test
puts "Testing btnu"
add_force btnu 1
run 4 us
add_force btnu 0
run 4 us

# Btnr test
puts "Testing btnr"
add_force btnr 1
run 4 us
add_force btnr 0
run 4 us

# Btnl test
puts "Testing btnl"
add_force btnl 1
run 4 us
add_force btnl 0
run 4 us

# Btnd test
puts "Testing btnd"
add_force btnd 1
run 4 us
add_force btnd 0
run 4 us

# Run timer for 1ms to see the timer reach 1ms
puts "Testing timer"
run 1 ms

# Press btnc and observe the impact on timer and seven-segment display
puts "Testing btnc"
add_force btnc 1
run 4 us
add_force btnc 0
run 4 us

exit