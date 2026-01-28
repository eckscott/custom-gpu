##########################################################################
#
# Filename: imp_regfile_top.tcl
#
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 19 January 2026
#
# This Tcl script is used to perform implementation
# (placement, routing, and timing analysis) on the regfile_top design.
# It requires the regfile_top_synth.dcp file generated from
# the synthesis step.
#
##########################################################################

# Read the synthesized design checkpoint file
open_checkpoint regfile_top_synth.dcp
# Update the message severity
source ../resources/messages.tcl

# Perform design optimization, placement, and routing
opt_design
place_design
route_design

# Generate a timing report
report_timing_summary -max_paths 10 -report_unconstrained -file regfile_top_timing.rpt -warn_on_violation
# Generate a utilization report
report_utilization -file regfile_top_utilization.rpt

# Generate the bitstream and final design checkpoint
write_bitstream -force regfile_top.bit
write_checkpoint -force regfile_top.dcp