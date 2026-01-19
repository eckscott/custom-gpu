##########################################################################
#
# Filename: synth_calc.tcl
#
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 19 January 2026
#
# This .tcl script is used to synthesize the calc design
#
##########################################################################

# Read the verilog files into the synthesis tool
read_verilog -sv calc.sv
read_verilog -sv ../include/synchronizer.sv
read_verilog -sv ../include/oneshot.sv
read_verilog -sv alu.sv

# Read the constraints file
read_xdc calc.xdc

# Change the error message severity levels
source ../resources/messages.tcl

# Run the sythesis command
synth_design -top calc -part xc7a35tcpg236-1 -verbose -include_dirs {../include}

# Write out the synthesized design checkpoint. This checkpoint file
# is needed for the implementation step.
write_checkpoint -force calc_synth.dcp
