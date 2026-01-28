##########################################################################
#
# Filename: synth_regfile_top.tcl
#
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 27 January 2026
#
# This .tcl script is used to synthesize the regfile_top design
#
##########################################################################

# Read the verilog files into the synthesis tool
read_verilog -sv regfile_top.sv
read_verilog -sv regfile.sv
read_verilog -sv ../include/synchronizer.sv
read_verilog -sv ../include/oneshot.sv
read_verilog -sv ../lab02/alu.sv

# Read the constraints file
read_xdc regfile_top.xdc

# Change the error message severity levels
source ../resources/messages.tcl

# Run the sythesis command
synth_design -top regfile_top -part xc7a35tcpg236-1 -verbose -include_dirs {../include}

# Write out the synthesized design checkpoint. This checkpoint file
# is needed for the implementation step.
write_checkpoint -force regfile_top_synth.dcp
