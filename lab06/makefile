################################
# Simulation
################################

assemble_tb:
	java -jar ../resources/rars1_6.jar ../lab05/simple_datapath.s mc CompactDataAtZero a dump .text HexText simple_datapath_text.mem
	java -jar ../resources/rars1_6.jar ../lab05/simple_datapath.s mc CompactDataAtZero a dump .data HexText simple_datapath_data.mem

analyze_riscv_multicycle: assemble_tb ../include/riscv_memory.sv ../lab05/riscv_simple_datapath.sv ../include/tb_riscv_pkg.sv tb_multicycle.sv ../lab02/alu.sv ../lab03/regfile.sv riscv_multicycle.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_riscv_multicycle: analyze_riscv_multicycle
	xelab riscv_multicycle -debug typical -nolog -timescale 1ns/100ps

elab_tb_multicycle: analyze_riscv_multicycle
	xelab tb_multicycle -debug typical -nolog -timescale 1ns/100ps

sim_riscv_multicycle_gui: elab_riscv_multicycle
	xsim riscv_multicycle -gui --nolog

sim_tb_multicycle: elab_tb_multicycle
	xsim tb_multicycle --log sim_tb_multicycle.log --runall

assemble_bounds: bounds.s
	java -jar ../resources/rars1_6.jar bounds.s mc CompactDataAtZero a dump .text HexText bounds_text.mem
	java -jar ../resources/rars1_6.jar bounds_data.s mc CompactDataAtZero a dump .data HexText bounds_data.mem

analyze_tb_bounds: assemble_bounds ../include/riscv_memory.sv ../lab05/riscv_simple_datapath.sv ../include/tb_riscv_pkg.sv tb_multicycle.sv ../lab02/alu.sv ../lab03/regfile.sv riscv_multicycle.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_tb_bounds: analyze_tb_bounds
	xelab tb_multicycle -debug typical -nolog -timescale 1ns/100ps -generic "instruction_memory_filename=bounds_text.mem" -generic "data_memory_filename=bounds_data.mem" -s tb_multicycle_bounds

sim_tb_multicycle_bounds: elab_tb_bounds
	xsim tb_multicycle_bounds --log sim_tb_multicycle_bounds.log --runall

################################
# Implementation
################################

riscv_multicycle_synth.dcp: synth_riscv_multicycle.tcl riscv_multicycle.sv
	vivado -mode batch -script synth_riscv_multicycle.tcl -nojournal -log riscv_multicycle_synth.log

################################
# Clean
################################

clean:
	rm -rf xsim.dir .Xil tb_multicycle.wdb xsim*.jou xelab.pb xvlog.log xvlog.pb vivado*.str vivado*.jou
	rm -f sim_tb_multicycle*.log *.wdb
	rm -f sim_tb_multicycle_bounds*.log
	rm -f riscv_multicycle_synth.dcp riscv_multicycle_synth*.log
	rm -f *.bit *.dcp *.rpt
	rm -f *.log, *.mem
