##########################################################################
#
# Filename: updownbuttoncount_sim.tcl
#
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 9 January 2026
#
# This .tcl script is used to synthesize the updownbuttoncount design
#
##########################################################################

# Read the verilog files into the synthesis tool
read_verilog -sv updownbuttoncount.sv
read_verilog -sv ../include/synchronizer.sv
read_verilog -sv ../include/oneshot.sv

# Read the constraints file
read_xdc updownbuttoncount.xdc

# Change the error message severity levels
source ../resources/messages.tcl

# Run the sythesis command
synth_design -top updownbuttoncount -part xc7a35tcpg236-1 -verbose

# Write out the synthesized design checkpoint. This checkpoint file
# is needed for the implementation step.
write_checkpoint -force updownbuttoncount_synth.dcp
