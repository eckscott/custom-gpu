##########################################################################
#
# Filename: imp_updownbuttoncount.tcl
#
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 9 January 2026
#
# This Tcl script is used to perform implementation
# (placement, routing, and timing analysis) on the updownbuttoncount design.
# It requires the updownbuttoncount_synth.dcp file generated from
# the synthesis step.
#
##########################################################################

# Read the synthesized design checkpoint file
open_checkpoint updownbuttoncount_synth.dcp
# Update the message severity
source ../resources/messages.tcl

# Perform design optimization, placement, and routing
opt_design
place_design
route_design

# Generate a timing report
report_timing_summary -max_paths 10 -report_unconstrained -file updownbuttoncount_timing.rpt -warn_on_violation
# Generate a utilization report
report_utilization -file updownbuttoncount_utilization.rpt

# Generate the bitstream and final design checkpoint
write_bitstream -force updownbuttoncount.bit
write_checkpoint -force updownbuttoncount.dcp