# implement_multicycle_buttoncount.tcl
#

# Read all of the verilog files and constraints
source read_verilog_iosystem.tcl

# Run the sythesis command
synth_design -top multicycle_iosystem -part xc7a35tcpg236-1 -verbose -include_dirs {../include} -generic {TEXT_MEM=buttoncount_text.mem}

# Perform design optimization, placement, and routing
opt_design
place_design
route_design

# Generate reports
report_timing_summary -max_paths 10 -report_unconstrained -file multicycle_buttoncount_timing.rpt -warn_on_violation
report_utilization -file multicycle_buttoncount_utilization.rpt

# Generate the bitstream and final design checkpoint
write_bitstream -force multicycle_buttoncount.bit
# write_checkpoint -force multicycle_iosystem.dcp
