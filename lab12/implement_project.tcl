# implement_project.tcl

# Read all of the verilog files and constraints
source ../resources/iosystem/read_iosystem.tcl

# Read local files
read_verilog -sv ../lab02/alu.sv
read_verilog -sv ../lab03/regfile.sv
read_verilog -sv ../lab11/riscv_final.sv
read_verilog -sv riscv_io_final.sv

# Run the sythesis command (note the memory files are passed in as generics to the top-level module)
synth_design -top riscv_io_final -part xc7a35tcpg236-1 -verbose -include_dirs {../include} \
    -generic {TEXT_MEM=project_text.mem} \
    -generic {DATA_MEM=project_data.mem} \

# Perform design optimization, placement, and routing
opt_design
place_design
route_design

# Generate reports
report_timing_summary -max_paths 10 -report_unconstrained -file project_timing.rpt -warn_on_violation
report_utilization -file project_utilization.rpt

# Generate the bitstream and final design checkpoint
write_bitstream -force project.bit
write_checkpoint -force project.dcp
