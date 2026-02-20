##########################################################################
#
# Filename: synth_riscv_multicycle.tcl
#
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 19 February 2026
#
# This .tcl script is used to synthesize the riscv_multicycle design
#
##########################################################################

# Read the verilog files into the synthesis tool
read_verilog -sv riscv_multicycle.sv
read_verilog -sv ../lab05/riscv_simple_datapath.sv
read_verilog -sv ../lab03/regfile.sv
read_verilog -sv ../lab02/alu.sv

# Change the error message severity levels
source ../resources/messages.tcl

# Run the sythesis command
synth_design -top riscv_multicycle -part xc7a35tcpg236-1 -verbose -include_dirs {../include} -mode out_of_context

# Write out the synthesized design checkpoint. This checkpoint file
# is needed for the implementation step.
write_checkpoint -force riscv_multicycle_synth.dcp